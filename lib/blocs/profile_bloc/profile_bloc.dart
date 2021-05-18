import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_segment/flutter_segment.dart';
import 'package:twake/blocs/notification_bloc/notification_bloc.dart';
import 'package:twake/blocs/profile_bloc/profile_event.dart';
import 'package:twake/models/base_channel.dart';
import 'package:twake/models/company.dart';
import 'package:twake/models/workspace.dart';
import 'package:twake/repositories/profile_repository.dart';
import 'package:twake/blocs/profile_bloc/profile_state.dart';

export 'package:twake/blocs/profile_bloc/profile_event.dart';
export 'package:twake/blocs/profile_bloc/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  static late ProfileRepository repository;
  final NotificationBloc? notificationBloc;
  late StreamSubscription _subscription;

  ProfileBloc(ProfileRepository rpstr, {this.notificationBloc})
      : super(
          ProfileLoaded(
            userId: rpstr.id,
            firstName: rpstr.firstName,
            lastName: rpstr.lastName,
            thumbnail: rpstr.thumbnail,
            email: rpstr.email,
            badges: rpstr.badges,
          ),
        ) {
    repository = rpstr;
    _subscription = notificationBloc!.listen((NotificationState state) {
      if (state is BadgesUpdated || state is ChannelUpdated) {
        // Logger().w("GOT NOTIFICATION EVENT $state");
        this.add(UpdateBadges());
      }
    });

    if (!kDebugMode) // only send statistic when in release mode
      Segment.identify(userId: rpstr.consoleId ?? rpstr.id).then((r) {
        // ProfileRepository.logger.w('Identified user: ${rpstr.id}');
        Segment.track(eventName: 'twake-mobile:open_client');
      }).onError((dynamic e, s) {
        ProfileRepository.logger.e(e);
      });
  }

  bool isMe(String? userId) => repository.id == userId;

  static String? get userId => repository.id;

  static String? get firstName => repository.firstName;

  static String? get lastName => repository.lastName;

  static String? get thumbnail => repository.thumbnail;

  static String? get username => repository.username;

  static String? get email => repository.email;

  static String? get selectedCompanyId => repository.selectedCompanyId;

  static String? get selectedWorkspaceId => repository.selectedWorkspaceId;

  static String? get selectedChannelId => repository.selectedChannelId;

  static String? get selectedThreadId => repository.selectedThreadId;

  static Company? get selectedCompany => repository.selectedCompany;

  static Workspace? get selectedWorkspace => repository.selectedWorkspace;

  static BaseChannel? get selectedChannel => repository.selectedChannel;

  static set selectedCompanyId(String? val) {
    repository.selectedCompanyId = val;
    repository.save();
  }

  static set selectedWorkspaceId(String? val) {
    repository.selectedWorkspaceId = val;
    repository.save();
  }

  static set selectedChannelId(String? val) {
    repository.selectedChannelId = val;
  }

  static set selectedThreadId(String? val) {
    repository.selectedThreadId = val;
  }

  static set selectedCompany(Company? val) {
    repository.selectedCompany = val;
  }

  static set selectedWorkspace(Workspace? val) => val;

  static set selectedChannel(BaseChannel? val) => val;

  @override
  Stream<ProfileState> mapEventToState(ProfileEvent event) async* {
    if (event is ReloadProfile) {
      await repository.reload();
      yield ProfileLoaded(
        userId: repository.id,
        firstName: repository.firstName,
        lastName: repository.lastName,
        thumbnail: repository.thumbnail,
        email: repository.email,
        badges: repository.badges,
      );
    } else if (event is UpdateBadges) {
      await repository.syncBadges();
      final state = ProfileLoaded(
        userId: repository.id,
        firstName: repository.firstName,
        lastName: repository.lastName,
        thumbnail: repository.thumbnail,
        email: repository.email,
        badges: repository.badges,
      );
      // Logger().w("SYNCING BADGES: ${this.state != state}");
      yield state;
    } else if (event is ClearProfile) {
      await repository.clean();
      yield ProfileEmpty();
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
