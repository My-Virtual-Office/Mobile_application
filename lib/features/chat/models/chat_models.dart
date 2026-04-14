// ============================================================
// CHAT SERVICE — Dart Models (FIXED for null safety)
// ============================================================

// ─── RESPONSE MODELS ────────────────────────────────────────

class ChannelResponse {
  final String id;
  final String name;
  final String type;
  final int? workspaceId;
  final List<int> members;
  final int? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChannelResponse({
    required this.id,
    required this.name,
    required this.type,
    this.workspaceId,
    this.members = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'GROUP',
      workspaceId: json['workspaceId'] as int?,
      members:
          (json['members'] as List<dynamic>?)?.map((e) => e as int).toList() ??
          [],
      createdBy: json['createdBy'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    if (workspaceId != null) 'workspaceId': workspaceId,
    'members': members,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  bool get isDm => type == 'DM';
  bool get isGroup => type == 'GROUP';
}

// ────────────────────────────────────────────────────────────

class MessageResponse {
  final String id;
  final String channelId;
  final int senderId;
  final String senderUsername;
  final String content;
  final String type;
  final String? threadId;
  final String? replyToId;
  final List<int> mentions;
  final String? clientMessageId;
  final bool deleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MessageResponse({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    this.type = 'TEXT',
    this.threadId,
    this.replyToId,
    this.mentions = const [],
    this.clientMessageId,
    this.deleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    // Safe extraction with null checks
    final id = json['id'] as String? ?? '';
    final channelId = json['channelId'] as String? ?? '';
    final senderId = json['senderId'] as int? ?? 0;
    final content = json['content'] as String? ?? '';
    final type = json['type'] as String? ?? 'TEXT';
    final threadId = json['threadId'] as String?;
    final replyToId = json['replyToId'] as String?;
    final clientMessageId = json['clientMessageId'] as String?;
    final deleted = json['deleted'] as bool? ?? false;

    // Extract username safely
    String senderUsername = json['senderUsername'] as String? ?? '';
    if (senderUsername.isEmpty) {
      senderUsername = 'User $senderId';
    }

    // Parse mentions safely
    List<int> mentions = [];
    if (json['mentions'] != null) {
      final mentionsList = json['mentions'] as List<dynamic>;
      mentions = mentionsList.map((e) => e as int).toList();
    }

    // Parse dates safely
    DateTime? deletedAt;
    if (json['deletedAt'] != null) {
      deletedAt = DateTime.tryParse(json['deletedAt'] as String);
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'] as String);
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      updatedAt = DateTime.tryParse(json['updatedAt'] as String);
    }

    return MessageResponse(
      id: id,
      channelId: channelId,
      senderId: senderId,
      senderUsername: senderUsername,
      content: content,
      type: type,
      threadId: threadId,
      replyToId: replyToId,
      mentions: mentions,
      clientMessageId: clientMessageId,
      deleted: deleted,
      deletedAt: deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'senderId': senderId,
    'senderUsername': senderUsername,
    'content': content,
    'type': type,
    if (threadId != null) 'threadId': threadId,
    if (replyToId != null) 'replyToId': replyToId,
    'mentions': mentions,
    if (clientMessageId != null) 'clientMessageId': clientMessageId,
    'deleted': deleted,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  bool get isReply => replyToId != null;
  bool get hasThread => threadId != null;
  bool get hasMentions => mentions.isNotEmpty;
}

// ─── Rest of the models remain the same ─────────────────────

class ThreadResponse {
  final String id;
  final String channelId;
  final String rootMessageId;
  final String name;
  final int? createdBy;
  final bool deleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ThreadResponse({
    required this.id,
    required this.channelId,
    required this.rootMessageId,
    required this.name,
    this.createdBy,
    this.deleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ThreadResponse.fromJson(Map<String, dynamic> json) {
    return ThreadResponse(
      id: json['id'] as String? ?? '',
      channelId: json['channelId'] as String? ?? '',
      rootMessageId: json['rootMessageId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdBy: json['createdBy'] as int?,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'rootMessageId': rootMessageId,
    'name': name,
    if (createdBy != null) 'createdBy': createdBy,
    'deleted': deleted,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

// ─── PaginatedResponse ─────────────────────────────────────

class PaginatedResponse<T> {
  final List<T> content;
  final int totalPages;
  final int totalElements;
  final int currentPage;

  const PaginatedResponse({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.currentPage,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    return PaginatedResponse<T>(
      content: contentList
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      totalPages: json['totalPages'] as int? ?? 1,
      totalElements: json['totalElements'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
    );
  }

  bool get hasMore => currentPage < totalPages;
  bool get isEmpty => content.isEmpty;
}

// ─── UnreadCountResponse ───────────────────────────────────

class UnreadCountResponse {
  final int unreadCount;
  final String? lastReadMessageId;

  const UnreadCountResponse({
    required this.unreadCount,
    this.lastReadMessageId,
  });

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) {
    return UnreadCountResponse(
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastReadMessageId: json['lastReadMessageId'] as String?,
    );
  }
}

// ─── WebSocketTicketResponse ───────────────────────────────

class WebSocketTicketResponse {
  final String ticket;

  const WebSocketTicketResponse({required this.ticket});

  factory WebSocketTicketResponse.fromJson(Map<String, dynamic> json) {
    return WebSocketTicketResponse(ticket: json['ticket'] as String? ?? '');
  }
}

// ─── TypingNotification ────────────────────────────────────

class TypingNotification {
  final int userId;
  final String channelId;
  final String? threadId;
  final bool typing;

  const TypingNotification({
    required this.userId,
    required this.channelId,
    this.threadId,
    required this.typing,
  });

  factory TypingNotification.fromJson(Map<String, dynamic> json) {
    return TypingNotification(
      userId: json['userId'] as int? ?? 0,
      channelId: json['channelId'] as String? ?? '',
      threadId: json['threadId'] as String?,
      typing: json['typing'] as bool? ?? false,
    );
  }
}

// ─── WsError ───────────────────────────────────────────────

class WsError {
  final String code;
  final String message;

  const WsError({required this.code, required this.message});

  factory WsError.fromJson(Map<String, dynamic> json) {
    return WsError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unknown error',
    );
  }
}

// ─── REQUEST MODELS (unchanged) ────────────────────────────

class CreateChannelRequest {
  final String name;
  final int workspaceId;
  final List<int> members;

  const CreateChannelRequest({
    required this.name,
    required this.workspaceId,
    required this.members,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'workspaceId': workspaceId,
    'members': members,
  };
}

class CreateDmRequest {
  final int targetUserId;

  const CreateDmRequest({required this.targetUserId});

  Map<String, dynamic> toJson() => {'targetUserId': targetUserId};
}

class SendMessageRequest {
  final String content;
  final String? threadId;
  final String? replyToId;
  final List<int>? mentions;
  final String? clientMessageId;

  const SendMessageRequest({
    required this.content,
    this.threadId,
    this.replyToId,
    this.mentions,
    this.clientMessageId,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    if (threadId != null) 'threadId': threadId,
    if (replyToId != null) 'replyToId': replyToId,
    if (mentions != null) 'mentions': mentions,
    if (clientMessageId != null) 'clientMessageId': clientMessageId,
  };
}

class EditMessageRequest {
  final String content;

  const EditMessageRequest({required this.content});

  Map<String, dynamic> toJson() => {'content': content};
}

class MarkReadRequest {
  final String lastReadMessageId;

  const MarkReadRequest({required this.lastReadMessageId});

  Map<String, dynamic> toJson() => {'lastReadMessageId': lastReadMessageId};
}

class CreateThreadRequest {
  final String rootMessageId;
  final String name;

  const CreateThreadRequest({required this.rootMessageId, required this.name});

  Map<String, dynamic> toJson() => {
    'rootMessageId': rootMessageId,
    'name': name,
  };
}

// ─── STOMP PAYLOADS ─────────────────────────────────────────

class StompSendMessage {
  final String channelId;
  final String content;
  final String? threadId;
  final String? replyToId;
  final List<int>? mentions;
  final String? clientMessageId;

  const StompSendMessage({
    required this.channelId,
    required this.content,
    this.threadId,
    this.replyToId,
    this.mentions,
    this.clientMessageId,
  });

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'content': content,
    if (threadId != null) 'threadId': threadId,
    if (replyToId != null) 'replyToId': replyToId,
    if (mentions != null) 'mentions': mentions,
    if (clientMessageId != null) 'clientMessageId': clientMessageId,
  };
}

class StompTypingEvent {
  final String channelId;
  final String? threadId;
  final bool typing;

  const StompTypingEvent({
    required this.channelId,
    this.threadId,
    required this.typing,
  });

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    if (threadId != null) 'threadId': threadId,
    'typing': typing,
  };
}
