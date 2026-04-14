import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';

class ThreadMessageProvider extends ChangeNotifier {
  final ChatRepository _repo;
  final String threadId;
  final String channelId;
  final int currentUserId;
  final String currentUserRole;

  ThreadMessageProvider(
    this._repo, {
    required this.threadId,
    required this.channelId,
    required this.currentUserId,
    required this.currentUserRole,
  });

  List<MessageResponse> _messages = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  MessageResponse? _replyTo;
  MessageResponse? _editingMessage;

  final Map<int, bool> _typingUsers = {};
  Timer? _typingTimeout;
  bool _iAmTyping = false;

  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _wsSub;

  // ✅ Flag to prevent updates after dispose
  bool _isDisposed = false;

  List<MessageResponse> get messages => _messages;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  MessageResponse? get replyTo => _replyTo;
  MessageResponse? get editingMessage => _editingMessage;
  List<int> get typingUsers =>
      _typingUsers.entries.where((e) => e.value).map((e) => e.key).toList();
  bool get someoneTyping => typingUsers.isNotEmpty;
  bool get isAdmin => currentUserRole == 'ADMIN';

  bool canEdit(MessageResponse msg) =>
      !msg.deleted && msg.senderId == currentUserId;

  bool canDelete(MessageResponse msg) {
    if (msg.deleted) return false;
    if (msg.senderId == currentUserId) return true;
    return isAdmin;
  }

  // ─── Init: subscribe WS + load messages ───────────────────
  Future<void> init() async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      _messages = await _repo.enterThread(threadId, channelId);
      // Sort messages by date
      _messages.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      _msgSub = _repo.messagesStream.listen((all) {
        if (_isDisposed) return;
        final updated = all[threadId];
        if (updated != null) {
          _messages = updated;
          _messages.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.now();
            final bDate = b.createdAt ?? DateTime.now();
            return aDate.compareTo(bDate);
          });
          if (!_isDisposed) notifyListeners();
        }
      });

      _typingSub = _repo.typingStream.listen((all) {
        if (_isDisposed) return;
        final map = all[threadId] ?? {};
        _typingUsers
          ..clear()
          ..addAll(map);
        if (!_isDisposed) notifyListeners();
      });

      // Auto catch-up after reconnect
      _wsSub = _repo.ws.connectionStateStream.listen((state) {
        if (_isDisposed) return;
        if (state == WsConnectionState.connected && _messages.isNotEmpty) {
          _repo.catchUpThreadMessages(threadId, after: _messages.last.id).then((
            newer,
          ) {
            if (_isDisposed) return;
            if (newer.isNotEmpty) {
              _messages = _repo.messagesFor(threadId);
              _messages.sort((a, b) {
                final aDate = a.createdAt ?? DateTime.now();
                final bDate = b.createdAt ?? DateTime.now();
                return aDate.compareTo(bDate);
              });
              if (!_isDisposed) notifyListeners();
            }
          });
        }
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Load older messages (scroll up) ─────────────────────
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    _loadingMore = true;
    if (!_isDisposed) notifyListeners();
    try {
      final older = await _repo.loadMoreThreadMessages(
        threadId,
        before: _messages.first.id,
      );
      if (_isDisposed) return;
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        _messages = _repo.messagesFor(threadId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Send message to thread ───────────────────────────────
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final replyId = _replyTo?.id;
    clearReply();
    stopTyping();
    try {
      await _repo.sendMessage(
        channelId: channelId,
        content: content.trim(),
        threadId: threadId,
        replyToId: replyId,
        clientMessageId: null,
      );
    } catch (e) {
      _error = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Edit (own only) ──────────────────────────────────────
  Future<void> submitEdit(String newContent) async {
    if (_editingMessage == null || newContent.trim().isEmpty) return;
    if (!canEdit(_editingMessage!)) return;
    final msgId = _editingMessage!.id;
    clearEdit();
    try {
      await _repo.editMessage(msgId, newContent.trim());
    } catch (e) {
      _error = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Delete ───────────────────────────────────────────────
  Future<void> deleteMessage(MessageResponse msg) async {
    if (!canDelete(msg)) return;
    try {
      await _repo.deleteMessage(msg.id, threadId);
    } catch (e) {
      _error = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Reply / Edit state ───────────────────────────────────
  void setReplyTo(MessageResponse msg) {
    _replyTo = msg;
    _editingMessage = null;
    if (!_isDisposed) notifyListeners();
  }

  void clearReply() {
    _replyTo = null;
    if (!_isDisposed) notifyListeners();
  }

  void setEditing(MessageResponse msg) {
    if (!canEdit(msg)) return;
    _editingMessage = msg;
    _replyTo = null;
    if (!_isDisposed) notifyListeners();
  }

  void clearEdit() {
    _editingMessage = null;
    if (!_isDisposed) notifyListeners();
  }

  // ─── Typing ───────────────────────────────────────────────
  void onUserTyping() {
    if (!_iAmTyping) {
      _iAmTyping = true;
      _repo.startTyping(channelId, threadId: threadId);
    }
    _typingTimeout?.cancel();
    _typingTimeout = Timer(const Duration(seconds: 3), stopTyping);
  }

  void stopTyping() {
    if (!_iAmTyping) return;
    _iAmTyping = false;
    _typingTimeout?.cancel();
    _repo.stopTyping(channelId, threadId: threadId);
  }

  void clearError() {
    _error = null;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _msgSub?.cancel();
    _typingSub?.cancel();
    _wsSub?.cancel();
    _typingTimeout?.cancel();
    _repo.exitThread(threadId);
    super.dispose();
  }
}
