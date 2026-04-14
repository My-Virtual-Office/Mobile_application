import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';

class MessageProvider extends ChangeNotifier {
  final ChatRepository _repo;
  final int currentUserId;
  final String currentUserRole;

  MessageProvider(
    this._repo, {
    required this.currentUserId,
    required this.currentUserRole,
  });

  // ─── State ────────────────────────────────────────────────
  String? _channelId;
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

  // ─── Getters ──────────────────────────────────────────────
  String? get channelId => _channelId;
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

  // ─── Permission helpers ───────────────────────────────────
  bool get isAdmin => currentUserRole == 'ADMIN';

  bool isMe(MessageResponse msg) => msg.senderId == currentUserId;

  bool canEdit(MessageResponse msg) => !msg.deleted && isMe(msg);

  bool canDelete(MessageResponse msg) {
    if (msg.deleted) return false;
    if (isMe(msg)) return true;
    return isAdmin;
  }

  // ─── Enter channel ────────────────────────────────────────
  Future<void> enterChannel(String channelId) async {
    if (_channelId == channelId) return;
    await _cleanup();

    _channelId = channelId;
    _messages = [];
    _hasMore = true;
    _error = null;
    _loading = true;
    if (!_isDisposed) notifyListeners();

    try {
      _messages = await _repo.enterChannel(channelId);
      // Sort messages by date (oldest first, newest last)
      _messages.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

      _listenStreams(channelId);

      _wsSub = _repo.ws.connectionStateStream.listen((state) {
        if (_isDisposed) return;
        if (state == WsConnectionState.connected && _messages.isNotEmpty) {
          _repo
              .catchUpChannelMessages(channelId, after: _messages.last.id)
              .then((newer) {
                if (_isDisposed) return;
                if (newer.isNotEmpty) {
                  _messages = _repo.messagesFor(channelId);
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

  // ─── Load more (scroll up) ────────────────────────────────
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty || _channelId == null)
      return;
    _loadingMore = true;
    if (!_isDisposed) notifyListeners();
    try {
      final older = await _repo.loadMoreChannelMessages(
        _channelId!,
        before: _messages.first.id,
      );
      if (_isDisposed) return;
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        _messages = _repo.messagesFor(_channelId!);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Send message ─────────────────────────────────────────
  Future<void> sendMessage(String content) async {
    if (_channelId == null || content.trim().isEmpty) return;
    final replyId = _replyTo?.id;
    clearReply();
    stopTyping();
    try {
      await _repo.sendMessage(
        channelId: _channelId!,
        content: content.trim(),
        replyToId: replyId,
        clientMessageId: null,
      );
    } catch (e) {
      _error = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Edit message ─────────────────────────────────────
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

  // ─── Delete message ───────────────────────────────────
  Future<void> deleteMessage(MessageResponse msg) async {
    if (!canDelete(msg) || _channelId == null) return;
    try {
      await _repo.deleteMessage(msg.id, _channelId!);
    } catch (e) {
      _error = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  // ─── Reply / Edit state ───────────────────────────────
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

  // ─── Typing ───────────────────────────────────────────
  void onUserTyping() {
    if (_channelId == null) return;
    if (!_iAmTyping) {
      _iAmTyping = true;
      _repo.startTyping(_channelId!);
    }
    _typingTimeout?.cancel();
    _typingTimeout = Timer(const Duration(seconds: 3), stopTyping);
  }

  void stopTyping() {
    if (_channelId == null || !_iAmTyping) return;
    _iAmTyping = false;
    _typingTimeout?.cancel();
    _repo.stopTyping(_channelId!);
  }

  // ─── WS listeners ─────────────────────────────────────
  void _listenStreams(String channelId) {
    _msgSub = _repo.messagesStream.listen((all) {
      if (_isDisposed) return;
      final updated = all[channelId];
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
      final map = all[channelId] ?? {};
      _typingUsers
        ..clear()
        ..addAll(map);
      if (!_isDisposed) notifyListeners();
    });
  }

  Future<void> _cleanup() async {
    await _msgSub?.cancel();
    await _typingSub?.cancel();
    await _wsSub?.cancel();
    _msgSub = null;
    _typingSub = null;
    _wsSub = null;

    _typingTimeout?.cancel();
    _typingTimeout = null;

    if (_channelId != null) _repo.exitChannel(_channelId!);
    _iAmTyping = false;
    _replyTo = null;
    _editingMessage = null;
    _typingUsers.clear();
    _channelId = null;
  }

  void clearError() {
    _error = null;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanup();
    super.dispose();
  }
}
