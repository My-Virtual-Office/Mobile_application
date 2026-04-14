import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';

class ChannelProvider extends ChangeNotifier {
  final ChatRepository _repo;
  ChannelProvider(this._repo);

  List<ChannelResponse> _channels = [];
  List<ChannelResponse> _dms = [];
  bool _loadingChannels = false;
  bool _loadingDms = false;
  String? _error;
  final Map<String, int> _unread = {};

  List<ChannelResponse> get channels => _channels;
  List<ChannelResponse> get dms => _dms;
  bool get loadingChannels => _loadingChannels;
  bool get loadingDms => _loadingDms;
  String? get error => _error;
  int unreadCount(String id) => _unread[id] ?? 0;

  // ─── Load channels (USER + ADMIN) ─────────────────────────
  Future<void> loadChannels(int workspaceId) async {
    _loadingChannels = true;
    _error = null;
    notifyListeners();
    try {
      _channels = await _repo.loadWorkspaceChannels(workspaceId);
      await _refreshUnreadBatch(_channels);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingChannels = false;
      notifyListeners();
    }
  }

  // ─── Load DMs (USER + ADMIN) ──────────────────────────────
  Future<void> loadDms() async {
    _loadingDms = true;
    _error = null;
    notifyListeners();
    try {
      _dms = await _repo.loadDms();
      await _refreshUnreadBatch(_dms);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingDms = false;
      notifyListeners();
    }
  }

  Future<bool> joinChannel(String channelId) async {
    try {
      await _repo.joinChannel(channelId);

      final ch = await _repo.getChannel(channelId);
      if (!_channels.any((c) => c.id == channelId)) {
        _channels.insert(0, ch);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Get single channel (USER + ADMIN) ────────────────────
  Future<ChannelResponse?> getChannel(String channelId) async {
    try {
      return await _repo.getChannel(channelId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Create channel (USER + ADMIN) ────────────────────────
  Future<ChannelResponse?> createChannel({
    required String name,
    required int workspaceId,
    required List<int> members,
  }) async {
    try {
      final ch = await _repo.createChannel(
        CreateChannelRequest(
          name: name,
          workspaceId: workspaceId,
          members: members,
        ),
      );
      _channels.insert(0, ch);
      notifyListeners();
      return ch;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Join channel (USER + ADMIN, GROUP only) ──────────────

  // ─── Leave channel (USER + ADMIN, GROUP only) ─────────────
  Future<bool> leaveChannel(String channelId) async {
    try {
      await _repo.leaveChannel(channelId);
      _channels.removeWhere((c) => c.id == channelId);
      _unread.remove(channelId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Open / create DM (USER + ADMIN) ──────────────────────
  Future<ChannelResponse?> openDm(int targetUserId) async {
    try {
      final ch = await _repo.openDm(targetUserId);
      if (!_dms.any((d) => d.id == ch.id)) _dms.insert(0, ch);
      notifyListeners();
      return ch;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Mark channel as read (USER + ADMIN) ──────────────────
  Future<void> markAsRead(String channelId, String lastMsgId) async {
    try {
      await _repo.markChannelAsRead(channelId, lastMsgId);
      _unread[channelId] = 0;
      notifyListeners();
    } catch (_) {}
  }

  // ─── Refresh unread for one channel ──────────────────────
  Future<void> refreshUnread(String channelId) async {
    try {
      final res = await _repo.getChannelUnreadCount(channelId);
      _unread[channelId] = res.unreadCount;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshUnreadBatch(List<ChannelResponse> list) async {
    for (final ch in list) {
      try {
        final res = await _repo.getChannelUnreadCount(ch.id);
        _unread[ch.id] = res.unreadCount;
      } catch (_) {}
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
