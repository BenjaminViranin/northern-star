class NoteHistoryEntry {
  final int id;
  final String operation;
  final DateTime changedAt;
  final Map<String, dynamic> data;

  const NoteHistoryEntry({
    required this.id,
    required this.operation,
    required this.changedAt,
    required this.data,
  });

  factory NoteHistoryEntry.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final idValue = json['id'];
    return NoteHistoryEntry(
      id: idValue is int ? idValue : int.parse(idValue.toString()),
      operation: (json['operation'] as String?) ?? 'update',
      changedAt: DateTime.parse(json['changed_at'] as String),
      data: data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map),
    );
  }

  String get title => (data['title'] as String?) ?? '';

  String get content => (data['content'] as String?) ?? '';
}

class NoteHistoryRestoreResult {
  final bool applied;
  final Map<String, dynamic>? note;

  const NoteHistoryRestoreResult({
    required this.applied,
    this.note,
  });
}
