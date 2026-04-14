// lib/features/chat/repositories/chat_repository.dart
//
// التعديل الوحيد عن النسخة الأصلية:
//   ✅ _onMessage  → بتستدعي _sendNotificationForMessage
//   ✅ _sendNotificationForMessage → بتستخدم NotificationService الجديدة
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:virtual_office/features/chat/services/notification_service.dart';
import '../models/chat_models.dart';
import '../api/chat_api_client.dart';
import '../services/chat_websocket_service.dart';

class ChatRepository {
  final ChatApiClient api;
  final ChatWebSocketService ws;
  final _uuid = const Uuid();

  // ─── Local state ──────────────────────────────────────────
  final Map<String, ChannelResponse> _channels = {};
  final Map<String, List<MessageResponse>> _messages = {};
  final Map<String, Map<int, bool>> _typingUsers = {};
  final Map<int, String> _usernames = {};

  // ─── Streams ──────────────────────────────────────────────
  final _channelsCtrl = StreamController<List<ChannelResponse>>.broadcast();
  final _messagesCtrl =
      StreamController<Map<String, List<MessageResponse>>>.broadcast();
  final _typingCtrl = StreamController<Map<String, Map<int, bool>>>.broadcast();

  Stream<List<ChannelResponse>> get channelsStream => _channelsCtrl.stream;
  Stream<Map<String, List<MessageResponse>>> get messagesStream =>
      _messagesCtrl.stream;
  Stream<Map<String, Map<int, bool>>> get typingStream => _typingCtrl.stream;

  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;

  // ─── أعداد القنوات المفتوحة حالياً ──────────────────────
  // نستخدمها عشان نعرف هل المستخدم شايف القناة دي أم لا
  final Set<String> _activeChannels = {};
  final Set<String> _activeThreads = {};

  ChatRepository({required this.api, required this.ws}) {
    _msgSub = ws.messageStream.listen(_onMessage);
    _typingSub = ws.typingStream.listen(_onTyping);
  }

  // ══════════════════════════════════════════════════════════
  //  WS HANDLERS
  // ══════════════════════════════════════════════════════════

  void _onMessage(MessageResponse msg) {
    final key = msg.threadId ?? msg.channelId;

    final list = List<MessageResponse>.from(_messages[key] ?? []);

    if (msg.deleted) {
      final idx = list.indexWhere((m) => m.id == msg.id);
      if (idx != -1) list[idx] = msg;
    } else {
      if (msg.clientMessageId != null) {
        list.removeWhere((m) => m.clientMessageId == msg.clientMessageId);
      }
      final idx = list.indexWhere((m) => m.id == msg.id);
      if (idx == -1) {
        list.add(msg);
      } else {
        list[idx] = msg;
      }
    }

    _messages[key] = list;
    _messagesCtrl.add(Map.from(_messages));

    // ✅ إرسال الإشعار — فقط لو NEW_MESSAGE (مش edited/deleted)
    if (!msg.deleted) {
      _maybeSendNotification(msg);
    }
  }

  /// يُرسل إشعاراً إذا:
  ///   1. الرسالة مش من المستخدم الحالي
  ///   2. المستخدم مش شايف القناة/الثريد ده دلوقتي (active)
  void _maybeSendNotification(MessageResponse msg) {
    final currentUserId = api.getUserId();

    // لا إشعار لرسائل المستخدم نفسه
    if (msg.senderId == currentUserId) return;

    // لا إشعار لو المستخدم شايف الشاشة دي حالياً
    final key = msg.threadId ?? msg.channelId;
    if (msg.threadId != null && _activeThreads.contains(msg.threadId)) return;
    if (msg.threadId == null && _activeChannels.contains(msg.channelId)) return;

    _sendNotificationForMessage(msg);
  }

  Future<void> _sendNotificationForMessage(MessageResponse msg) async {
    try {
      final channel = _channels[msg.channelId];
      final isDm = channel?.isDm ?? false;
      final notif = NotificationService();

      if (isDm) {
        // ── DM ────────────────────────────────────────────
        await notif.showDirectMessage(
          channelId: msg.channelId,
          senderName: msg.senderUsername,
          content: msg.content,
          messageId: msg.id,
        );
      } else if (msg.threadId != null) {
        // ── Thread message ────────────────────────────────
        await notif.showThreadMessage(
          channelId: msg.channelId,
          threadId: msg.threadId!,
          threadName: 'Thread',
          senderName: msg.senderUsername,
          content: msg.content,
          messageId: msg.id,
        );
      } else {
        // ── Channel message ───────────────────────────────
        await notif.showChannelMessage(
          channelId: msg.channelId,
          channelName: channel?.name ?? 'Channel',
          senderName: msg.senderUsername,
          content: msg.content,
          messageId: msg.id,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to send notification: $e');
    }
  }

  Future<void> _sendChannelInviteNotification({
    required String channelId,
    required String channelName,
    required int addedByUserId,
  }) async {
    try {
      if (addedByUserId == api.getUserId()) return;
      await NotificationService().showSystemNotification(
        title: 'Added to Channel',
        body: 'User $addedByUserId added you to #$channelName',
        payload: {
          'channelId': channelId,
          'isDm': 'false',
          'type': 'channel_invite',
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to send channel invite notification: $e');
    }
  }

  void _onTyping(TypingNotification n) {
    final key = n.threadId ?? n.channelId;
    final map = Map<int, bool>.from(_typingUsers[key] ?? {});
    if (n.typing) {
      map[n.userId] = true;
    } else {
      map.remove(n.userId);
    }
    _typingUsers[key] = map;
    _typingCtrl.add(Map.from(_typingUsers));
  }

  // ══════════════════════════════════════════════════════════
  //  CONNECT / DISCONNECT
  // ══════════════════════════════════════════════════════════

  Future<void> connect() => ws.connect();
  void disconnect() => ws.disconnect();

  // ══════════════════════════════════════════════════════════
  //  CHANNELS
  // ══════════════════════════════════════════════════════════

  Future<ChannelResponse> createChannel(CreateChannelRequest req) async {
    final ch = await api.createChannel(req);
    _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
    ws.subscribeToChannel(ch.id);
    return ch;
  }

  Future<List<ChannelResponse>> loadWorkspaceChannels(int workspaceId) async {
    final res = await api.getChannels(workspaceId: workspaceId);
    for (final ch in res.content) _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
    return res.content;
  }

  Future<List<ChannelResponse>> loadDms() async {
    final res = await api.getDirectMessages();
    for (final ch in res.content) _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
    return res.content;
  }

  Future<ChannelResponse> getChannel(String channelId) async {
    final ch = await api.getChannel(channelId);
    _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
    return ch;
  }

  Future<void> joinChannel(String channelId) async {
    await api.joinChannel(channelId);
    ws.subscribeToChannel(channelId);
    final ch = await api.getChannel(channelId);
    _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
  }

  Future<void> leaveChannel(String channelId) async {
    await api.leaveChannel(channelId);
    ws.unsubscribeFromChannel(channelId);
    _channels.remove(channelId);
    _messages.remove(channelId);
    _activeChannels.remove(channelId);
    _channelsCtrl.add(channels);
    _messagesCtrl.add(Map.from(_messages));
  }

  Future<ChannelResponse> openDm(int targetUserId) async {
    final ch = await api.getOrCreateDm(targetUserId);
    _channels[ch.id] = ch;
    _channelsCtrl.add(channels);
    return ch;
  }

  // ══════════════════════════════════════════════════════════
  //  ENTER / EXIT — تتبّع الشاشة الحالية
  // ══════════════════════════════════════════════════════════

  Future<List<MessageResponse>> enterChannel(String channelId) async {
    _activeChannels.add(channelId); // ← المستخدم شايف القناة دي
    ws.subscribeToChannel(channelId);
    final res = await api.getMessages(channelId);
    _messages[channelId] = res.content;
    _messagesCtrl.add(Map.from(_messages));
    return res.content;
  }

  void exitChannel(String channelId) {
    _activeChannels.remove(channelId); // ← المستخدم مش شايفها
    ws.unsubscribeFromChannel(channelId);
  }

  Future<List<MessageResponse>> enterThread(
    String threadId,
    String channelId,
  ) async {
    _activeThreads.add(threadId); // ← المستخدم شايف الثريد ده
    ws.subscribeToThread(threadId);
    final res = await api.getThreadMessages(threadId);
    _messages[threadId] = res.content;
    _messagesCtrl.add(Map.from(_messages));
    return res.content;
  }

  void exitThread(String threadId) {
    _activeThreads.remove(threadId); // ← المستخدم مش شايفه
    ws.unsubscribeFromThread(threadId);
  }

  // ══════════════════════════════════════════════════════════
  //  MESSAGES
  // ══════════════════════════════════════════════════════════

  Future<List<MessageResponse>> loadMoreChannelMessages(
    String channelId, {
    required String before,
  }) async {
    final older = await api.getMessagesBefore(channelId, before: before);
    final existing = List<MessageResponse>.from(_messages[channelId] ?? []);
    _messages[channelId] = [...older, ...existing];
    _messagesCtrl.add(Map.from(_messages));
    return older;
  }

  Future<List<MessageResponse>> catchUpChannelMessages(
    String channelId, {
    required String after,
  }) async {
    final newer = await api.getMessagesAfter(channelId, after: after);
    if (newer.isEmpty) return [];
    final existing = List<MessageResponse>.from(_messages[channelId] ?? []);
    for (final msg in newer) {
      if (!existing.any((m) => m.id == msg.id)) existing.add(msg);
    }
    _messages[channelId] = existing;
    _messagesCtrl.add(Map.from(_messages));
    return newer;
  }

  Future<List<MessageResponse>> loadMoreThreadMessages(
    String threadId, {
    required String before,
  }) async {
    final older = await api.getThreadMessagesBefore(threadId, before: before);
    final existing = List<MessageResponse>.from(_messages[threadId] ?? []);
    _messages[threadId] = [...older, ...existing];
    _messagesCtrl.add(Map.from(_messages));
    return older;
  }

  Future<List<MessageResponse>> catchUpThreadMessages(
    String threadId, {
    required String after,
  }) async {
    final newer = await api.getThreadMessagesAfter(threadId, after: after);
    if (newer.isEmpty) return [];
    final existing = List<MessageResponse>.from(_messages[threadId] ?? []);
    for (final msg in newer) {
      if (!existing.any((m) => m.id == msg.id)) existing.add(msg);
    }
    _messages[threadId] = existing;
    _messagesCtrl.add(Map.from(_messages));
    return newer;
  }

  Future<void> sendMessage({
    required String channelId,
    required String content,
    String? threadId,
    String? replyToId,
    List<int>? mentions,
    String? clientMessageId,
  }) async {
    final clientId = clientMessageId ?? _uuid.v4();
    final storeKey = threadId ?? channelId;
    final currentUserId = api.getUserId();

    // Optimistic placeholder
    final optimistic = MessageResponse(
      id: 'tmp_$clientId',
      channelId: channelId,
      senderId: currentUserId,
      senderUsername: 'Me',
      content: content,
      threadId: threadId,
      replyToId: replyToId,
      mentions: mentions ?? [],
      clientMessageId: clientId,
      createdAt: DateTime.now(),
    );
    _messages[storeKey] = [...(_messages[storeKey] ?? []), optimistic];
    _messagesCtrl.add(Map.from(_messages));

    // Try WebSocket first
    try {
      ws.sendMessage(
        StompSendMessage(
          channelId: channelId,
          content: content,
          threadId: threadId,
          replyToId: replyToId,
          mentions: mentions,
          clientMessageId: clientId,
        ),
      );
      return;
    } catch (_) {}

    // REST fallback
    try {
      await api.sendMessage(
        channelId,
        SendMessageRequest(
          content: content,
          threadId: threadId,
          replyToId: replyToId,
          mentions: mentions,
          clientMessageId: clientId,
        ),
      );
    } catch (e) {
      _messages[storeKey]?.removeWhere((m) => m.id == 'tmp_$clientId');
      _messagesCtrl.add(Map.from(_messages));
      rethrow;
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final updated = await api.editMessage(
      messageId,
      EditMessageRequest(content: newContent),
    );
    for (final list in _messages.values) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        list[idx] = updated;
        break;
      }
    }
    _messagesCtrl.add(Map.from(_messages));
  }

  Future<void> deleteMessage(String messageId, String storeKey) async {
    await api.deleteMessage(messageId);
    final list = _messages[storeKey];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        list[idx] = MessageResponse(
          id: list[idx].id,
          channelId: list[idx].channelId,
          senderId: list[idx].senderId,
          senderUsername: list[idx].senderUsername,
          content: '',
          threadId: list[idx].threadId,
          replyToId: list[idx].replyToId,
          deleted: true,
          createdAt: list[idx].createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    _messagesCtrl.add(Map.from(_messages));
  }

  // ══════════════════════════════════════════════════════════
  //  TYPING
  // ══════════════════════════════════════════════════════════

  void startTyping(String channelId, {String? threadId}) => ws.sendTyping(
    StompTypingEvent(channelId: channelId, threadId: threadId, typing: true),
  );

  void stopTyping(String channelId, {String? threadId}) => ws.sendTyping(
    StompTypingEvent(channelId: channelId, threadId: threadId, typing: false),
  );

  // ══════════════════════════════════════════════════════════
  //  READ RECEIPTS
  // ══════════════════════════════════════════════════════════

  Future<void> markChannelAsRead(String channelId, String lastMsgId) =>
      api.markChannelAsRead(channelId, lastMsgId);

  Future<UnreadCountResponse> getChannelUnreadCount(String channelId) =>
      api.getChannelUnreadCount(channelId);

  Future<void> markThreadAsRead(String threadId, String lastMsgId) =>
      api.markThreadAsRead(threadId, lastMsgId);

  Future<UnreadCountResponse> getThreadUnreadCount(String threadId) =>
      api.getThreadUnreadCount(threadId);

  // ══════════════════════════════════════════════════════════
  //  THREADS
  // ══════════════════════════════════════════════════════════

  Future<ThreadResponse> createThread(
    String channelId,
    String rootMessageId,
    String name,
  ) => api.createThread(
    channelId,
    CreateThreadRequest(rootMessageId: rootMessageId, name: name),
  );

  Future<List<ThreadResponse>> getChannelThreads(
    String channelId, {
    int page = 1,
  }) async {
    final res = await api.getChannelThreads(channelId, page: page);
    return res.content;
  }

  Future<ThreadResponse> getThread(String threadId) => api.getThread(threadId);

  Future<void> deleteThread(String threadId) async {
    await api.deleteThread(threadId);
    _messages.remove(threadId);
    _messagesCtrl.add(Map.from(_messages));
  }

  // ─── Getters ──────────────────────────────────────────────
  List<ChannelResponse> get channels => _channels.values.toList();
  List<ChannelResponse> get groupChannels =>
      channels.where((c) => c.isGroup).toList();
  List<ChannelResponse> get dmChannels =>
      channels.where((c) => c.isDm).toList();
  List<MessageResponse> messagesFor(String key) => _messages[key] ?? [];

  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _channelsCtrl.close();
    _messagesCtrl.close();
    _typingCtrl.close();
    ws.dispose();
  }
}
