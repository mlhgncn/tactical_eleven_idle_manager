class InboxMessage {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory InboxMessage.fromMap(Map<String, dynamic> map) {
    return InboxMessage(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
