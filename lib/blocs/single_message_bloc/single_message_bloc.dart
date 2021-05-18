import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs/profile_bloc/profile_bloc.dart';
import 'package:twake/blocs/single_message_bloc/single_message_event.dart';
import 'package:twake/models/message.dart';
import 'package:twake/blocs/single_message_bloc/single_message_state.dart';
import 'package:twake/utils/twacode.dart';

export 'package:twake/blocs/single_message_bloc/single_message_event.dart';
export 'package:twake/models/message.dart';
export 'package:twake/blocs/single_message_bloc/single_message_state.dart';

class SingleMessageBloc extends Bloc<SingleMessageEvent, SingleMessageState> {
  final Message message;
  static final RegExp _userId = RegExp('@([a-zA-z0-9_]+):([a-zA-z0-9-]+)');

  SingleMessageBloc(this.message)
      : super(MessageReady(
          id: message.id,
          responsesCount: message.responsesCount,
          creationDate: message.creationDate,
          content: message.content!.prepared,
          threadId: message.threadId,
          text: (message.content!.originalStr ?? '').replaceAllMapped(_userId,
              (match) {
            final end = message.content!.originalStr!.indexOf(':', match.start);
            return message.content!.originalStr!.substring(match.start, end);
          }),
          charCount: (message.content!.originalStr ?? ' ').length,
          reactions: message.reactions,
          userId: message.userId,
          sender: message.sender,
          thumbnail: message.thumbnail,
        ));

  @override
  Stream<SingleMessageState> mapEventToState(SingleMessageEvent event) async* {
    // message.logger.d('GOT MESSAGE EVENT $event');
    if (event is UpdateContent) {
      message.updateContent({
        'company_id': ProfileBloc.selectedCompanyId,
        'channel_id': message.channelId,
        'workspace_id': event.workspaceId ?? ProfileBloc.selectedWorkspaceId,
        'message_id': message.id,
        'thread_id': message.threadId,
        'original_str': event.content,
        'prepared': TwacodeParser(event.content).message,
      });
      yield messageReady;
    } else if (event is UpdateReaction) {
      message.updateReactions(
        userId: event.userId ?? ProfileBloc.userId,
        body: {
          'company_id': event.companyId ?? ProfileBloc.selectedCompanyId,
          'channel_id': message.channelId,
          'workspace_id': event.workspaceId ?? ProfileBloc.selectedWorkspaceId,
          'message_id': message.id,
          'thread_id': message.threadId,
          'reaction': event.emojiCode,
        },
      );
      yield messageReady;
    } else if (event is UpdateResponseCount) {
      message.responsesCount += event.modifier;
      yield messageReady;
    } else if (event is UpdateViewport) {
      yield ViewportUpdated(event.position);
    }
  }

  MessageReady get messageReady {
    final hash = message.reactions!.map((r) => r['name']).join().hashCode +
        message.reactions!.fold(0, (count, v) => count += v['count']);
    return MessageReady(
      id: message.id,
      responsesCount: message.responsesCount,
      creationDate: message.creationDate,
      content: message.content!.prepared,
      text: (message.content!.originalStr ?? '').replaceAllMapped(_userId,
          (match) {
        final end = message.content!.originalStr!.indexOf(':', match.start);
        return message.content!.originalStr!.substring(match.start, end);
      }),
      charCount: (message.content!.originalStr ?? '').length,
      reactions: message.reactions,
      hash: hash as int?,
      userId: message.userId,
      threadId: message.threadId,
      sender: message.sender,
      thumbnail: message.thumbnail,
    );
  }
}
