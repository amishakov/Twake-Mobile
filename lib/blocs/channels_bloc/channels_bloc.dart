import 'dart:async';

import 'package:twake/blocs/base_channel_bloc/base_channel_bloc.dart';
import 'package:twake/blocs/notification_bloc/notification_bloc.dart';
import 'package:twake/blocs/profile_bloc/profile_bloc.dart';
import 'package:twake/blocs/workspaces_bloc/workspaces_bloc.dart';
import 'package:twake/blocs/channels_bloc/channel_event.dart';
import 'package:twake/models/channel.dart';
import 'package:twake/repositories/collection_repository.dart';
import 'package:twake/blocs/channels_bloc/channel_state.dart';
import 'package:twake/blocs/workspaces_bloc/workspace_state.dart';
import 'package:twake/services/endpoints.dart';

export 'package:twake/blocs/channels_bloc/channel_event.dart';
export 'package:twake/blocs/channels_bloc/channel_state.dart';

class ChannelsBloc extends BaseChannelBloc {
  final WorkspacesBloc? workspacesBloc;
  final NotificationBloc? notificationBloc;

  late StreamSubscription _subscription;
  late StreamSubscription _notificationSubscription;

  ChannelsBloc({
    required CollectionRepository<Channel> repository,
    this.workspacesBloc,
    this.notificationBloc,
  }) : super(
            repository: repository,
            initState: repository.isEmpty
                ? ChannelsEmpty()
                : ChannelsLoaded(channels: repository.items)) {
    _subscription = workspacesBloc!.listen((WorkspaceState state) {
      if (state is WorkspacesLoaded) {
        // repository.logger.e('WORKSPACE SELECTED ${state.selected.name}');
        selectedBeforeId = selectedParentId;
        selectedParentId = state.selected!.id;
        this.add(ReloadChannels(workspaceId: selectedParentId));
        notificationBloc!.add(ReinitSubscriptions());
      }
    });
    _notificationSubscription =
        notificationBloc!.listen((NotificationState state) async {
      if (state is BaseChannelMessageNotification &&
          state.data.workspaceId != 'direct') {
        while (true) {
          if (selectedParentId == state.data.workspaceId &&
              this.state is ChannelsLoaded) {
            this.add(ChangeSelectedChannel(state.data.channelId));
            break;
          } else {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      } else if (state is ChannelUpdated) {
        this.add(UpdateSingleChannel(state.data));
      } else if (state is ChannelDeleted) {
        this.add(RemoveChannel(
          channelId: state.data.channelId,
          workspaceId: state.data.workspaceId,
        ));
      }
    });
    selectedParentId = workspacesBloc!.repository.selected!.id;
  }

  @override
  Stream<ChannelState> mapEventToState(ChannelsEvent event) async* {
    if (event is ReloadChannels) {
      yield ChannelsLoading();
      bool success = await repository!.reload(
        queryParams: {
          'workspace_id': event.workspaceId ?? selectedParentId,
          'company_id': workspacesBloc!.selectedCompanyId,
        },
        filters: [
          ['workspace_id', '=', event.workspaceId ?? selectedParentId]
        ],
        sortFields: {'name': true},
        onApiLoaded: () {
          this.add(ReEmitChannels());
        },
      );
      if (!success) {
        repository!.logger.d('Failed to change workspace');
        if (selectedBeforeId != null)
          workspacesBloc!.add(ChangeSelectedWorkspace(selectedBeforeId));
        yield ErrorLoadingChannels(channels: repository!.items);
      }
      if (repository!.isEmpty) yield ChannelsEmpty();
      yield ChannelsLoaded(
        selected: repository!.selected,
        channels: repository!.items,
        force: DateTime.now().toString(),
      );
    } else if (event is ClearChannels) {
      await repository!.clean();
      yield ChannelsEmpty();
    } else if (event is ChangeSelectedChannel) {
      // repository.logger.w('CHANNEL ${event.channelId} is selected');
      repository!.select(event.channelId,
          saveToStore: false,
          apiEndpoint: Endpoint.channelsRead,
          params: {
            "company_id": ProfileBloc.selectedCompanyId,
            "workspace_id": selectedParentId,
            "channel_id": event.channelId
          });

      repository!.selected!.messagesUnread = 0;
      repository!.selected!.hasUnread = 0;
      repository!.saveOne(repository!.selected);
      if (!event.shouldYield) return;
      final newState = ChannelPicked(
        channels: repository!.items,
        selected: repository!.selected,
        hasUnread: repository!.selected!.hasUnread,
      );
      ProfileBloc.selectedChannelId = event.channelId;
      ProfileBloc.selectedThreadId = null;

      // repository.logger
      // .e("CURRENT CHANNEL STATE: ${this.state}\nWILL YIELD: $newState");
      yield newState;
      notificationBloc!.add(CancelPendingSubscriptions(event.channelId));
    } else if (event is ModifyMessageCount) {
      await this.updateMessageCount(event);
      if (event.workspaceId == selectedParentId) {
        yield ChannelsLoaded(
          channels: repository!.items,
          force: DateTime.now().toString(),
        );
      }
    } else if (event is UpdateSingleChannel) {
      // repository.logger.d('UPDATING CHANNELS\n${event.data.toJson()}');
      var item = await repository!.getItemById(event.data.channelId) as Channel?;
      if (item != null) {
        item.icon = event.data.icon ?? item.icon ?? '👽';
        item.name = event.data.name ?? item.name;
        item.description = event.data.description ?? item.description;
        item.visibility = event.data.visibility ?? item.visibility;
        item.lastMessage = event.data.lastMessage ?? item.lastMessage;
      } else {
        await repository!.reload(
          queryParams: {
            'workspace_id': selectedParentId,
            'company_id': workspacesBloc!.selectedCompanyId,
          },
          filters: [
            ['workspace_id', '=', selectedParentId]
          ],
          sortFields: {'name': true},
        );
        yield ChannelsLoaded(
          selected: repository!.selected,
          channels: repository!.items,
          force: DateTime.now().toString(),
        );

        return;
      }
      await repository!.saveOne(item);
      if (event.data.workspaceId == selectedParentId) {
        repository!.items!.removeWhere((c) => c!.id == item.id);
        repository!.items!.add(item);
      }
      repository!.items!.sort((c1, c2) => c1!.name!.compareTo(c2!.name!));
      yield ChannelsLoaded(
        channels: repository!.items,
        force: DateTime.now().toString(),
      );
    } else if (event is ReEmitChannels) {
      repository!.items!.sort((c1, c2) => c1!.name!.compareTo(c2!.name!));

      yield ChannelsLoaded(
        channels: repository!.items,
        // force: DateTime.now().toString(),
      );
    } else if (event is LoadSingleChannel) {
      throw 'Not implemented yet';
    } else if (event is RemoveChannel) {
      repository!.items!.removeWhere((i) => i!.id == event.channelId);
      if (event.workspaceId == selectedParentId) {
        yield ChannelsLoaded(
          channels: repository!.items,
          force: DateTime.now().toString(),
        );
      }
    } else if (event is ModifyChannelState) {
      await updateChannelState(event);
      yield ChannelsLoaded(
        channels: repository!.items,
        force: DateTime.now().toString(),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    _notificationSubscription.cancel();
    return super.close();
  }
}
