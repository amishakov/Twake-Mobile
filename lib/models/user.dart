import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User with EquatableMixin {
  @JsonKey(required: true)
  final String? id;
  String? username;
  @JsonKey(name: 'firstname')
  String? firstName;
  @JsonKey(name: 'lastname')
  String? lastName;
  String? thumbnail;

  User({this.id, this.username});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, username, firstName, lastName, thumbnail];
}
