import 'package:equatable/equatable.dart';
import 'package:twake/blocs/messages_bloc/messsage_loaded_type.dart';
import 'package:twake/models/message.dart';
import 'package:twake/utils/twacode.dart';

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();

  Map<String, dynamic> toMap();
}

class LoadMessages extends MessagesEvent {
  final String? channelId;
  final String? threadId;
  final bool? forceFromApi;
  const LoadMessages({
    this.channelId,
    this.threadId,
    this.forceFromApi,
  });

  @override
  List<Object?> get props => [threadId, channelId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'thread_id': threadId,
    };
  }
}

class LoadMoreMessages extends MessagesEvent {
  final String? channelId;
  final String? threadId;
  final String? beforeId;
  final int? beforeTimeStamp;

  const LoadMoreMessages({
    this.channelId,
    this.threadId,
    this.beforeId,
    this.beforeTimeStamp,
  });

  @override
  List<Object?> get props => [beforeId, beforeTimeStamp];

  @override
  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'thread_id': threadId,
      'before_message_id': beforeId,
    };
  }
}

class LoadSingleMessage extends MessagesEvent {
  final String? messageId;
  final String? channelId;
  final String? threadId;
  final String? workspaceId;
  final String? companyId;
  const LoadSingleMessage({
    this.channelId,
    this.threadId,
    this.messageId,
    this.workspaceId,
    this.companyId,
  });

  @override
  List<Object?> get props => [messageId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'workspace_id': workspaceId,
      'channel_id': channelId,
      'message_id': messageId,
      'thread_id': threadId,
    };
  }
}

class ModifyResponsesCount extends MessagesEvent {
  final String? threadId;
  final String? channelId;

  const ModifyResponsesCount({
    this.channelId,
    this.threadId,
  });

  @override
  List<Object?> get props => [this.threadId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'thread_id': threadId,
    };
  }
}

class RemoveMessage extends MessagesEvent {
  final String? messageId;
  final String? channelId;
  final String? threadId;
  final bool onNotify;

  const RemoveMessage({
    this.threadId,
    this.messageId,
    this.channelId,
    this.onNotify: false,
  });

  @override
  List<Object?> get props => [messageId, threadId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'thread_id': threadId,
      'channel_id': channelId,
    };
  }
}

class SendMessage extends MessagesEvent {
  final String? content;
  final String? threadId;
  final String? channelId;
  final List<dynamic>? prepared;

  const SendMessage({
    this.content,
    this.threadId,
    this.channelId,
    this.prepared,
  });
  @override
  List<Object?> get props => [content, threadId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'original_str': content,
      'thread_id': threadId,
      'channel_id': channelId,
      'prepared': this.prepared ?? TwacodeParser(content).message,
    };
  }
}

class ClearMessages extends MessagesEvent {
  const ClearMessages();

  @override
  List<Object> get props => [];

  @override
  Map<String, dynamic> toMap() => {};
}

class UpdateThreadMessage extends MessagesEvent {
  final Message? threadMessage;
  const UpdateThreadMessage(this.threadMessage);

  @override
  List<Object> get props => [];

  @override
  Map<String, dynamic> toMap() {
    return const {};
  }
}

class SelectMessage extends MessagesEvent {
  final String? messageId;
  const SelectMessage(this.messageId);
  @override
  List<Object?> get props => [messageId];

  @override
  Map<String, dynamic> toMap() {
    return {
      'thread_id': messageId,
    };
  }
}

class GenerateErrorSendingMessage extends MessagesEvent {
  @override
  List<Object> get props => [];

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}

class GenerateErrorLoadingMore extends MessagesEvent {
  @override
  List<Object> get props => [];

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}

class FinishLoadingMessages extends MessagesEvent {
  final MessageLoadedType messageLoadedType;

  FinishLoadingMessages({this.messageLoadedType = MessageLoadedType.normal});

  @override
  List<Object> get props => [messageLoadedType];

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}

class InfinitelyLoadMessages extends MessagesEvent {
  @override
  List<Object> get props => [];

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}
