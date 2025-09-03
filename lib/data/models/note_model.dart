import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'note_model.g.dart';

@JsonSerializable()
class NoteModel extends Equatable {
  final String? id; // Supabase ID
  final String title;
  final String content; // Quill Delta JSON
  final String markdown;
  final String plainText;
  final String groupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int version;

  const NoteModel({
    this.id,
    required this.title,
    required this.content,
    required this.markdown,
    required this.plainText,
    required this.groupId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.version = 1,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  Map<String, dynamic> toJson() => _$NoteModelToJson(this);

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? markdown,
    String? plainText,
    String? groupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? version,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      markdown: markdown ?? this.markdown,
      plainText: plainText ?? this.plainText,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        markdown,
        plainText,
        groupId,
        createdAt,
        updatedAt,
        isDeleted,
        version,
      ];
}
