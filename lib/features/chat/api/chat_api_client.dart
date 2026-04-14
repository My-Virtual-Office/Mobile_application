import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';

// ============================================================
// ChatApiClient
//
// Auth: NO JWT. The chat service expects Nginx-forwarded headers:
//   X-User-Id:   integer user ID  (e.g. "42")
//   X-User-Role: "ADMIN" or "USER"
//
// For local dev (no Nginx), we set these headers manually.
// ============================================================

class ChatApiException implements Exception {
  final int statusCode;
  final String message;
  const ChatApiException({required this.statusCode, required this.message});
  @override
  String toString() => 'ChatApiException($statusCode): $message';
}

class ChatApiClient {
  final String baseUrl;
  final int Function() getUserId;
  final String Function() getUserRole;

  static const _prefix = '/api/chat';

  ChatApiClient({
    required this.baseUrl,
    required this.getUserId,
    required this.getUserRole,
  });

  // ─── Headers ─────────────────────────────────────────────
  // Simulates what Nginx would inject after JWT validation
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-User-Id':   '${getUserId()}',
        'X-User-Role': getUserRole(),
      };

  // ─── HTTP helpers ─────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params]) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    return _handle(res);
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http
        .post(uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 10));
    return _handle(res);
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return _handle(res);
  }

  Future<void> _delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    _handleNoContent(res);
  }

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'content': decoded};
    }
    String msg = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      msg = body['message'] ?? body['error'] ?? msg;
    } catch (_) {}
    throw ChatApiException(statusCode: res.statusCode, message: msg);
  }

  void _handleNoContent(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ChatApiException(
          statusCode: res.statusCode, message: 'Request failed');
    }
  }

  // ─── Health check (no auth headers needed) ───────────────
  Future<void> healthCheck() async {
    final uri = Uri.parse('$baseUrl$_prefix/health');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ChatApiException(
          statusCode: res.statusCode,
          message: 'Health check failed — is the service running on $baseUrl?');
    }
  }

  // ─── WebSocket ticket ─────────────────────────────────────
  Future<WebSocketTicketResponse> getWsTicket() async {
    final json = await _post('$_prefix/ws-ticket');
    return WebSocketTicketResponse.fromJson(json);
  }

  // ─── Channels ─────────────────────────────────────────────
  Future<ChannelResponse> createChannel(CreateChannelRequest req) async {
    final json = await _post('$_prefix/channels', req.toJson());
    return ChannelResponse.fromJson(json);
  }

  Future<PaginatedResponse<ChannelResponse>> getChannels({
    required int workspaceId,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get('$_prefix/channels', {
      'workspaceId': '$workspaceId',
      'page': '$page',
      'limit': '$limit',
    });
    return PaginatedResponse.fromJson(json, ChannelResponse.fromJson);
  }

  Future<ChannelResponse> getChannel(String channelId) async {
    final json = await _get('$_prefix/channels/$channelId');
    return ChannelResponse.fromJson(json);
  }

  Future<void> joinChannel(String channelId) =>
      _post('$_prefix/channels/$channelId/join').then((_) {});

  Future<void> leaveChannel(String channelId) =>
      _post('$_prefix/channels/$channelId/leave').then((_) {});

  // ─── DMs ──────────────────────────────────────────────────
  Future<ChannelResponse> getOrCreateDm(int targetUserId) async {
    final json = await _post('$_prefix/dm',
        CreateDmRequest(targetUserId: targetUserId).toJson());
    return ChannelResponse.fromJson(json);
  }

  Future<PaginatedResponse<ChannelResponse>> getDirectMessages({
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get('$_prefix/dm', {
      'page': '$page',
      'limit': '$limit',
    });
    return PaginatedResponse.fromJson(json, ChannelResponse.fromJson);
  }

  // ─── Messages ─────────────────────────────────────────────
  Future<MessageResponse> sendMessage(
      String channelId, SendMessageRequest req) async {
    final json =
        await _post('$_prefix/channels/$channelId/messages', req.toJson());
    return MessageResponse.fromJson(json);
  }

  Future<PaginatedResponse<MessageResponse>> getMessages(
    String channelId, {
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _get('$_prefix/channels/$channelId/messages', {
      'page': '$page',
      'limit': '$limit',
    });
    return PaginatedResponse.fromJson(json, MessageResponse.fromJson);
  }

  Future<List<MessageResponse>> getMessagesBefore(
    String channelId, {
    required String before,
    int limit = 50,
  }) async {
    final json = await _get('$_prefix/channels/$channelId/messages',
        {'before': before, 'limit': '$limit'});
    final list = json['content'] as List? ?? [];
    return list
        .map((e) => MessageResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageResponse>> getMessagesAfter(
    String channelId, {
    required String after,
    int limit = 50,
  }) async {
    final json = await _get('$_prefix/channels/$channelId/messages',
        {'after': after, 'limit': '$limit'});
    final list = json['content'] as List? ?? [];
    return list
        .map((e) => MessageResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessageResponse> editMessage(
      String messageId, EditMessageRequest req) async {
    final json = await _put('$_prefix/messages/$messageId', req.toJson());
    return MessageResponse.fromJson(json);
  }

  Future<void> deleteMessage(String messageId) =>
      _delete('$_prefix/messages/$messageId');

  // ─── Threads ──────────────────────────────────────────────
  Future<ThreadResponse> createThread(
      String channelId, CreateThreadRequest req) async {
    final json =
        await _post('$_prefix/channels/$channelId/threads', req.toJson());
    return ThreadResponse.fromJson(json);
  }

  Future<PaginatedResponse<ThreadResponse>> getChannelThreads(
    String channelId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get('$_prefix/channels/$channelId/threads',
        {'page': '$page', 'limit': '$limit'});
    return PaginatedResponse.fromJson(json, ThreadResponse.fromJson);
  }

  Future<ThreadResponse> getThread(String threadId) async {
    final json = await _get('$_prefix/threads/$threadId');
    return ThreadResponse.fromJson(json);
  }

  Future<void> deleteThread(String threadId) =>
      _delete('$_prefix/threads/$threadId');

  Future<PaginatedResponse<MessageResponse>> getThreadMessages(
    String threadId, {
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _get('$_prefix/threads/$threadId/messages',
        {'page': '$page', 'limit': '$limit'});
    return PaginatedResponse.fromJson(json, MessageResponse.fromJson);
  }

  Future<List<MessageResponse>> getThreadMessagesBefore(
      String threadId, {required String before, int limit = 50}) async {
    final json = await _get('$_prefix/threads/$threadId/messages',
        {'before': before, 'limit': '$limit'});
    final list = json['content'] as List? ?? [];
    return list
        .map((e) => MessageResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageResponse>> getThreadMessagesAfter(
      String threadId, {required String after, int limit = 50}) async {
    final json = await _get('$_prefix/threads/$threadId/messages',
        {'after': after, 'limit': '$limit'});
    final list = json['content'] as List? ?? [];
    return list
        .map((e) => MessageResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Read receipts ────────────────────────────────────────
  Future<void> markChannelAsRead(
      String channelId, String lastReadMessageId) async {
    await _post('$_prefix/channels/$channelId/read',
        MarkReadRequest(lastReadMessageId: lastReadMessageId).toJson());
  }

  Future<UnreadCountResponse> getChannelUnreadCount(
      String channelId) async {
    final json = await _get('$_prefix/channels/$channelId/unread');
    return UnreadCountResponse.fromJson(json);
  }

  Future<void> markThreadAsRead(
      String threadId, String lastReadMessageId) async {
    await _post('$_prefix/threads/$threadId/read',
        MarkReadRequest(lastReadMessageId: lastReadMessageId).toJson());
  }

  Future<UnreadCountResponse> getThreadUnreadCount(
      String threadId) async {
    final json = await _get('$_prefix/threads/$threadId/unread');
    return UnreadCountResponse.fromJson(json);
  }
}
