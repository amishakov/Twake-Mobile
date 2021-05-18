import 'package:equatable/equatable.dart';
import 'package:twake/models/base_channel.dart';

abstract class ChannelState extends Equatable {
  const ChannelState();
}

class ChannelsLoaded extends ChannelState {
  final List<BaseChannel?>? channels;
  final BaseChannel? selected;
  final String? force;
  const ChannelsLoaded({
    this.channels,
    this.force,
    this.selected,
  });
  @override
  List<Object?> get props => [channels, force];
}

class ChannelPicked extends ChannelsLoaded {
  final int? hasUnread;
  const ChannelPicked({
    List<BaseChannel?>? channels,
    BaseChannel? selected,
    this.hasUnread: 0,
  }) : super(channels: channels, selected: selected);

  @override
  List<Object?> get props => [selected!.id, hasUnread];
}

class ChannelsLoading extends ChannelState {
  const ChannelsLoading();
  @override
  List<Object> get props => [];
}

class ChannelsEmpty extends ChannelState {
  const ChannelsEmpty();
  @override
  List<Object> get props => [];
}

class ErrorLoadingChannels extends ChannelsLoaded {
  const ErrorLoadingChannels({List<BaseChannel?>? channels})
      : super(channels: channels);

  @override
  List<Object> get props => [];
}
