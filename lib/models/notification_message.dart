class NotificationMessage {
  final int id;
  final int messageId;
  final String title;
  final String body;
  final int importance;
  final String receivedAt;
  final bool isRead;
  final String? readAt;
  final String buildingCode;

  const NotificationMessage({
    required this.id,
    required this.messageId,
    required this.title,
    required this.body,
    required this.importance,
    required this.receivedAt,
    required this.isRead,
    this.readAt,
    required this.buildingCode,
  });

  NotificationMessage copyWith({bool? isRead, String? readAt}) {
    return NotificationMessage(
      id: id,
      messageId: messageId,
      title: title,
      body: body,
      importance: importance,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      buildingCode: buildingCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'title': title,
      'body': body,
      'importance': importance,
      'received_at': receivedAt,
      'is_read': isRead ? 1 : 0,
      'read_at': readAt,
      'building_code': buildingCode,
    };
  }

  static NotificationMessage fromMap(Map<String, dynamic> map) {
    return NotificationMessage(
      id: map['id'] as int,
      messageId: map['message_id'] as int,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      importance: map['importance'] as int? ?? 0,
      receivedAt: map['received_at'] as String? ?? '',
      isRead: (map['is_read'] as int? ?? 0) == 1,
      readAt: map['read_at'] as String?,
      buildingCode: map['building_code'] as String? ?? '',
    );
  }
}
