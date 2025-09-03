import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'group_model.g.dart';

@JsonSerializable()
class GroupModel extends Equatable {
  final String? id; // Supabase ID
  final String name;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int version;

  const GroupModel({
    this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.version = 1,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) =>
      _$GroupModelFromJson(json);

  Map<String, dynamic> toJson() => _$GroupModelToJson(this);

  GroupModel copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? version,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        color,
        createdAt,
        updatedAt,
        isDeleted,
        version,
      ];
}
