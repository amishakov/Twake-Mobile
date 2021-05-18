import 'package:json_annotation/json_annotation.dart';
import 'package:twake/models/collection_item.dart';
import 'package:twake/utils/bool_int.dart';

export 'package:twake/utils/bool_int.dart';

// part 'base_channel.g.dart';

abstract class BaseChannel extends CollectionItem {
  @JsonKey(required: true, nullable: false)
  String? id;

  @JsonKey(required: true)
  String? name;

  @JsonKey(defaultValue: '👽')
  String? icon;

  String? description;

  @JsonKey(name: 'members_count', defaultValue: 0)
  int? membersCount;

  @JsonKey(name: 'last_activity', defaultValue: 0)
  int? lastActivity;

  @JsonKey(name: 'last_message', defaultValue: {})
  Map<String, dynamic>? lastMessage;

  @JsonKey(name: 'user_last_access', defaultValue: 0)
  int? lastAccess;

  @JsonKey(
    name: 'has_unread',
    // defaultValue: 0,
    fromJson: boolToInt,
    toJson: boolToInt,
  )
  int? hasUnread;

  @JsonKey(name: 'messages_unread', defaultValue: 0)
  int? messagesUnread;

  @JsonKey(name: 'is_selected', defaultValue: 0)
  int? isSelected;

  @JsonKey(defaultValue: <String>[])
  List<String>? permissions;

  BaseChannel({
    this.id,
  }) : super(id);
}
