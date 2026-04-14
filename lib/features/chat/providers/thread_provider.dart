import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';

class ThreadProvider extends ChangeNotifier {
  final ChatRepository _repo;
  final int currentUserId;
  final String currentUserRole;

  ThreadProvider(this._repo,
      {required this.currentUserId, required this.currentUserRole});

  List<ThreadResponse> _threads = [];
  bool _loading = false;
  String? _error;
  String? _channelId;
  final Map<String, int> _unread = {};

  List<ThreadResponse> get threads => _threads;
  bool get loading => _loading;
  String? get error => _error;
  int threadUnread(String tid) => _unread[tid] ?? 0;
  bool get isAdmin => currentUserRole == 'ADMIN';

  bool canDeleteThread(ThreadResponse t) {
    if (t.deleted) return false;
    if (t.createdBy == currentUserId) return true;
    return isAdmin;
  }

  // ─── Load threads for a channel (USER + ADMIN) ────────────
  Future<void> loadThreads(String channelId) async {
    _channelId = channelId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _threads = await _repo.getChannelThreads(channelId);
      await _loadUnread();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Get single thread (USER + ADMIN) ─────────────────────
  Future<ThreadResponse?> getThread(String threadId) async {
    try {
      return await _repo.getThread(threadId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Create thread (USER + ADMIN) ─────────────────────────
  Future<ThreadResponse?> createThread({
    required String channelId,
    required String rootMessageId,
    required String name,
  }) async {
    try {
      final t =
          await _repo.createThread(channelId, rootMessageId, name);
      _threads.insert(0, t);
      notifyListeners();
      return t;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Delete thread (USER own, ADMIN any non-admin) ────────
  Future<bool> deleteThread(String threadId) async {
    try {
      await _repo.deleteThread(threadId);
      _threads.removeWhere((t) => t.id == threadId);
      _unread.remove(threadId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Mark thread as read (USER + ADMIN) ───────────────────
  Future<void> markAsRead(String threadId, String lastMsgId) async {
    try {
      await _repo.markThreadAsRead(threadId, lastMsgId);
      _unread[threadId] = 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUnread(String threadId) async {
    try {
      final res = await _repo.getThreadUnreadCount(threadId);
      _unread[threadId] = res.unreadCount;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadUnread() async {
    for (final t in _threads) {
      try {
        final res = await _repo.getThreadUnreadCount(t.id);
        _unread[t.id] = res.unreadCount;
      } catch (_) {}
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
