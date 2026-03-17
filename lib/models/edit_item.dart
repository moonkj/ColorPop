class EditItem {
  final String id;
  final String imagePath;
  final DateTime createdAt;
  final DateTime? editedAt;

  const EditItem({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    this.editedAt,
  });

  EditItem copyWith({
    String? id,
    String? imagePath,
    DateTime? createdAt,
    DateTime? editedAt,
  }) {
    return EditItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
      };

  factory EditItem.fromJson(Map<String, dynamic> json) => EditItem(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
      );

  // 상대 시간 표시 (예: "2시간 전")
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(editedAt ?? createdAt);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${(diff.inDays / 7).floor()}주 전';
  }
}
