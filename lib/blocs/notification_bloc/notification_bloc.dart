import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs/auth_bloc/auth_bloc.dart';
import 'package:twake/blocs/channels_bloc/channels_bloc.dart';
import 'package:twake/blocs/connection_bloc/connection_bloc.dart';
import 'package:twake/blocs/directs_bloc/directs_bloc.dart';
import 'package:twake/blocs/notification_bloc/notification_event.dart';
import 'package:twake/blocs/profile_bloc/profile_bloc.dart';
import 'package:twake/pages/chat/chat.dart';
import 'package:twake/pages/tabs_controller.dart';
import 'package:twake/pages/thread_page.dart';
import 'package:twake/services/notifications.dart';
import 'package:twake/blocs/notification_bloc/notification_state.dart';
import 'package:twake/models/notification.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:twake/services/service_bundle.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

export 'package:twake/blocs/notification_bloc/notification_event.dart';
export 'package:twake/blocs/notification_bloc/notification_state.dart';
export 'package:twake/models/notification.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  late Notifications service;
  ConnectionBloc? connectionBloc;
  late IO.Socket socket;
  var socketConnectionState = SocketConnectionState.DISCONNECTED;

  AuthBloc? authBloc;
  GlobalKey<NavigatorState>? navigator;

  final logger = Logger();
  final _api = Api();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Map<String, dynamic>? subscriptionRooms = {};
  late StreamSubscription _subscription;
  late StreamSubscription _authSubscription;

  NotificationBloc({
    this.authBloc,
    this.connectionBloc,
    this.navigator,
  }) : super(NotificationsAbsent()) {
    // iOS permission for Firebase push-notifications.
    if (Platform.isIOS) _iOSpermission();

    service = Notifications(
      onMessageCallback: onMessageCallback,
      onResumeCallback: onResumeCallback,
      onLaunchCallback: onLaunchCallback,
      shouldNotify: shouldNotify,
    );
    socket = IO.io(
      authBloc!.repository.socketIOHost,
      IO.OptionBuilder()
          .setPath('/socket')
          .enableAutoConnect()
          .disableAutoConnect()
          .enableReconnection()
          .setTransports(['websocket']).build(),
    );
    _authSubscription = authBloc!.listen((state) {
      if (state is Unauthenticated || state is HostReset) {
        for (String room in subscriptionRooms!.keys) {
          unsubscribe(room);
        }
        service.cancelAll();
      }
    });
    _subscription = connectionBloc!.listen((state) {
      if (state is ConnectionActive) {
        reinit();
      }
    });
    setupListeners();
    if (connectionBloc!.state is ConnectionActive) {
      if (socket.disconnected) socket.connect();
    }
    // launch health check on socket io
    // so that on it will make sure that the app is constantly
    // connected to socket endpoint
    socketIOHealthCheck();
  }

  void _iOSpermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  void socketIOHealthCheck() {
    // if user has logged out then terminate health check
    if (authBloc!.state is Unauthenticated) {
      logger.w('UNAUTHENTICATED FOR SOCKET IO');
      return;
    }
    // otherwise loop endlessly
    Future.delayed(Duration(seconds: 5)).then((_) => socketIOHealthCheck());
    // wait another 10 seconds for connection to appear
    if (connectionBloc!.state is ConnectionLost) return;
    // if not connected reconnect
    if (socket.disconnected ||
        socketConnectionState == SocketConnectionState.DISCONNECTED)
      socket = socket.connect();
  }

  void setupListeners() {
    socket.onReconnect((_) async {
      logger.d('RECONNECTED, RESETTING SUBSCRIPTIONS');
      await _api.autoProlongToken();
    });
    socket.onConnect((msg) async {
      logger.d('CONNECTED ON SOCKET IO');
      await _api.autoProlongToken();
      socketConnectionState = SocketConnectionState.CONNECTED;
      while (socketConnectionState != SocketConnectionState.AUTHENTICATED &&
          authBloc!.repository.accessToken != null) {
        // print('AUTHENTICATING SOCKEIO');
        if (socket.disconnected) socket = socket.connect();
        socket.emit(SocketIOEvent.AUTHENTICATE, {
          'token': authBloc!.repository.accessToken,
        });
        await Future.delayed(Duration(seconds: 5));
      }
    });
    socket.onError((e) => logger.e('ERROR ON SOCKET \n$e'));
    socket.onDisconnect((msg) {
      logger.e('DISCONNECTED FROM SOCKET\n$msg');
      socketConnectionState = SocketConnectionState.DISCONNECTED;
    });
    socket.on(SocketIOEvent.AUTHENTICATED, (data) async {
      logger.d('AUTHENTICATED ON SOCKET: $data');
      socketConnectionState = SocketConnectionState.AUTHENTICATED;
      await setSubscriptions();
    });
    // socket.onPing((ping) {
    // logger.d('PING $ping');
    // });
    socket.on(SocketIOEvent.EVENT, (data) {
      // logger.d('GOT EVENT: $data');
      handleSocketEvent(data);
    });
    socket.on(SocketIOEvent.RESOURCE, (data) {
      // logger.d('GOT RESOURCE: $data');
      handleSocketResource(data);
    });
    socket.on(SocketIOEvent.JOIN_ERROR, (data) {
      logger.d('FAILED TO JOIN TO SOCKEIO ROOM: $data');
    });
    socket.on(SocketIOEvent.JOIN_SUCCESS, (data) {
      // logger.d('SUCCESSFUL JOIN: $data');
    });
  }

  void reinit() async {
    while (true) {
      if (connectionBloc!.state is ConnectionLost) return;
      if (socket.disconnected) socket = socket.connect();
      // Wait for the socket to authenticate;
      await Future.delayed(Duration(seconds: 3));
      if (this.socketConnectionState == SocketConnectionState.AUTHENTICATED) {
        break;
      }
    }
    for (String room in subscriptionRooms!.keys) {
      unsubscribe(room);
    }
    setSubscriptions();
    this.add(BadgeUpdateEvent());
  }

  Future<void> setSubscriptions() async {
    await Future.delayed(Duration(seconds: 3));
    subscriptionRooms = await (_api.get(
      Endpoint.notificationRooms,
      params: {
        'company_id': ProfileBloc.selectedCompanyId,
        'workspace_id': ProfileBloc.selectedWorkspaceId,
      },
    ) as FutureOr<Map<String, dynamic>?>);
    for (String room in subscriptionRooms!.keys) {
      subscribe(room);
    }
  }

  void subscribe(String path, [String tag = 'twake']) {
    socket.emit(SocketIOEvent.JOIN, {'name': path, 'token': tag});
    // logger.d('SUBSCRIBED ON $path');
  }

  void unsubscribe(String path, [String tag = 'twake']) {
    socket.emit(SocketIOEvent.LEAVE, {'name': path, 'token': tag});
    // logger.d('UNSUBSCRIBED FROM $path');
  }

  @override
  Stream<NotificationState> mapEventToState(NotificationEvent event) async* {
    if (event is DirectMessageEvent) {
      yield DirectMessageNotification(event.data as MessageNotification);
    } else if (event is ChannelMessageEvent) {
      yield ChannelMessageNotification(event.data as MessageNotification);
    } else if (event is ThreadMessageEvent) {
      yield ThreadMessageNotification(event.data);
    } else if (event is ChannelMessageSocketEvent) {
      yield ChannelMessageArrived(event.data as SocketMessageUpdateNotification);
    } else if (event is DirectMessageSocketEvent) {
      yield DirectMessageArrived(event.data as SocketMessageUpdateNotification);
    } else if (event is ChannelThreadSocketEvent) {
      yield ChannelThreadMessageArrived(event.data as SocketMessageUpdateNotification);
    } else if (event is DirectThreadSocketEvent) {
      yield DirectThreadMessageArrived(event.data as SocketMessageUpdateNotification);
    } else if (event is ThreadMessageDeletedEvent) {
      yield ThreadMessageDeleted(event.data as SocketMessageUpdateNotification);
    } else if (event is MessageDeletedEvent) {
      yield MessageDeleted(event.data as SocketMessageUpdateNotification);
    } else if (event is ChannelUpdateEvent) {
      yield ChannelUpdated(event.data);
    } else if (event is ChannelDeleteEvent) {
      yield ChannelDeleted(event.data);
    } else if (event is ReinitSubscriptions) {
      reinit();
    } else if (event is CancelPendingSubscriptions) {
      service.cancelNotificationForChannel(event.channelId);
    } else if (event is BadgeUpdateEvent) {
      yield BadgesUpdated(DateTime.now().toString());
    } else if (event is DirectUpdateEvent) {
      yield DirectUpdated(event.data);
    } else if (event is DirectDeleteEvent) {
      yield DirectDeleted(event.data);
    }
  }

  bool shouldNotify(MessageNotification data) {
    // print('Data channel id: ${data.channelId}');
    // print('ProfileBloc id: ${ProfileBloc.selectedChannelId}');
    // print('Data thread id: ${data.threadId}');
    // print('ProfileBloc selected thread id: ${ProfileBloc.selectedThreadId}');

    if (data.channelId == ProfileBloc.selectedChannelId &&
        (ProfileBloc.selectedThreadId == data.threadId ||
            ProfileBloc.selectedThreadId == null)) return false;
    return true;
  }

  void onMessageCallback(NotificationData data) {
    if (data is MessageNotification) {
      // print("ON MESSAGE CALLBACK:\n${data.toJson()} ");
      if (data.threadId!.isNotEmpty && data.threadId != data.messageId) {
        // logger.d('adding ThreadMessageEvent');
        this.add(ThreadMessageEvent(data));
      } else if (data.workspaceId == 'direct') {
        // logger.d('adding DirectMessageEvent');
        this.add(DirectMessageEvent(data));
      } else {
        // logger.d('adding ChannelMessageEvent');
        this.add(ChannelMessageEvent(data));
      }
      navigate(data);
    }
  }

  onResumeCallback(MessageNotification data) {
    onMessageCallback(data);
  }

  void navigate(MessageNotification data) {
    // navigator.currentState.popUntil((_) => false); // navigator.popAndPushNamed(
    // navigator.currentState.push(
    // MaterialPageRoute(
    // builder: (ctx) => MainPage(),
    // ),
    // );
    navigator!.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (ctx) => TabsController()),
      (_) => false,
    );
    void Function(BuildContext) messagePage;
    if (data.workspaceId == 'direct')
      messagePage = (ctx) => Chat<DirectsBloc>();
    else
      messagePage = (ctx) => Chat<ChannelsBloc>();

    navigator!.currentState!.push(
      MaterialPageRoute(builder: messagePage as Widget Function(BuildContext)),
    );
    if (data.threadId != data.messageId) {
      if (data.workspaceId == 'direct')
        messagePage = (ctx) => ThreadPage<DirectsBloc>();
      else
        messagePage = (ctx) => ThreadPage<ChannelsBloc>();
      // await Future.delayed(Duration(seconds: 4));
      navigator!.currentState!.push(
        MaterialPageRoute(
          builder: messagePage,
        ),
      );
    }
  }

  void onLaunchCallback(NotificationData data) {
    logger.w('ON LAUNCH HERE IS the notification\n$data');
    throw 'Have to implement navigation to the right page';
  }

  void handleSocketResource(Map resource) {
    final type = getSocketResourceType(resource);
    // logger.w('RESOURCE ID: $type');
    if (type == SocketResourceType.ChannelUpdate) {
      final data =
          SocketChannelUpdateNotification.fromJson(resource['resource']);
      this.add(ChannelUpdateEvent(data));
    } else if (type == SocketResourceType.ChannelDelete) {
      final data =
          SocketChannelUpdateNotification.fromJson(resource['resource']);
      this.add(ChannelDeleteEvent(data));
    } else if (type == SocketResourceType.BadgeUpdate) {
      this.add(BadgeUpdateEvent());
    } else if (type == SocketResourceType.DirectUpdate) {
      this.add(
        DirectUpdateEvent(
          SocketDirectUpdateNotification.fromJson(resource['resource']),
        ),
      );
    } else if (type == SocketResourceType.DirectDelete) {
      this.add(
        DirectDeleteEvent(
          SocketDirectRemovedNotification(
            directId: resource['resource']['id'],
          ),
        ),
      );
    }
  }

  void handleSocketEvent(Map event) {
    final type = getSocketEventType(event);
    final id = getRoomSubscriberId(event['name']);
    NotificationData data;
    event['data']['channel_id'] = id;
    data = SocketMessageUpdateNotification.fromJson(event['data']);
    switch (type) {
      case SocketEventType.Unknown:
        // throw Exception('Got unknown event:\n$event');
        break;

      case SocketEventType.ChannelMessage:
        this.add(ChannelMessageSocketEvent(data as SocketMessageUpdateNotification));
        break;

      case SocketEventType.DirectMessage:
        this.add(DirectMessageSocketEvent(data as SocketMessageUpdateNotification));
        break;

      case SocketEventType.ChannelThreadMessage:
        this.add(ChannelThreadSocketEvent(data as SocketMessageUpdateNotification));
        break;

      case SocketEventType.DirectThreadMessage:
        this.add(DirectThreadSocketEvent(data as SocketMessageUpdateNotification));
        break;

      case SocketEventType.ThreadMessageDeleted:
        this.add(ThreadMessageDeletedEvent(data as SocketMessageUpdateNotification));
        break;

      case SocketEventType.MessageDeleted:
        this.add(MessageDeletedEvent(data as SocketMessageUpdateNotification));
        break;
    }
  }

  SocketEventType getSocketEventType(Map event) {
    if (!subscriptionRooms!.containsKey(event['name']))
      return SocketEventType.Unknown;
    final type = subscriptionRooms![event['name']]['type'];
    if (event['data']['action'] == 'update') {
      if (type == 'CHANNEL') {
        if (event['data']['thread_id'] != null &&
            event['data']['thread_id'] != '') {
          return SocketEventType.ChannelThreadMessage;
        } else
          return SocketEventType.ChannelMessage;
      } else if (type == 'DIRECT') {
        if (event['data']['thread_id'] != null &&
            event['data']['thread_id'] != '') {
          return SocketEventType.DirectThreadMessage;
        } else {
          return SocketEventType.DirectMessage;
        }
      }
    } else if (event['data']['action'] == 'remove') {
      if (event['data']['thread_id'] != null &&
          event['data']['thread_id'] != '') {
        return SocketEventType.ThreadMessageDeleted;
      } else
        return SocketEventType.MessageDeleted;
    }
    return SocketEventType.Unknown;
  }

  SocketResourceType getSocketResourceType(Map resource) {
    if (!subscriptionRooms!.containsKey(resource['room']))
      return SocketResourceType.Unknown;
    final type = subscriptionRooms![resource['room']]['type'];
    if (type == 'CHANNELS_LIST') {
      if (resource['type'] == 'channel' ||
          resource['type'] == 'channel_activity' ||
          resource['type'] == 'channel_member') {
        if (resource['action'] == 'saved' || resource['action'] == 'updated') {
          return SocketResourceType.ChannelUpdate;
        } else if (resource['action'] == 'deleted')
          return SocketResourceType.ChannelDelete;
      }
    } else if (type == 'NOTIFICATIONS') {
      return SocketResourceType.BadgeUpdate;
    } else if (type == 'DIRECTS_LIST') {
      if (resource['type'] == 'channel' ||
          resource['type'] == 'channel_activity') {
        return SocketResourceType.DirectUpdate;
      } else if (resource['type'] == 'channel_member') {
        if (resource['action'] == 'deleted')
          return SocketResourceType.DirectDelete;
      }
    }
    return SocketResourceType.Unknown;
  }

  String? getRoomSubscriberId(String? name) {
    if (!subscriptionRooms!.containsKey(name)) return null;
    return subscriptionRooms![name!]['id'];
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _authSubscription.cancel();
    return super.close();
  }
}

class SocketIOEvent {
  static const AUTHENTICATE = 'authenticate';
  static const AUTHENTICATED = 'authenticated';
  static const JOIN_SUCCESS = 'realtime:join:success';
  static const JOIN_ERROR = 'realtime:join:error';
  static const RESOURCE = 'realtime:resource';
  static const EVENT = 'realtime:event';
  static const JOIN = 'realtime:join';
  static const LEAVE = 'realtime:leave';
}

enum SocketConnectionState {
  CONNECTED,
  AUTHENTICATED,
  DISCONNECTED,
}

enum SocketEventType {
  ChannelMessage,
  ChannelThreadMessage,
  DirectMessage,
  DirectThreadMessage,
  MessageDeleted,
  ThreadMessageDeleted,
  Unknown,
}

enum SocketResourceType {
  ChannelUpdate,
  ChannelDelete,
  DirectUpdate,
  DirectDelete,
  BadgeUpdate,
  Unknown,
}
