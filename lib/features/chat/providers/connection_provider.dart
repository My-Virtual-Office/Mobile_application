import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../api/chat_api_client.dart';
import '../services/chat_websocket_service.dart';
import '../repositories/chat_repository.dart';

enum ConnectionStatus { idle, connecting, connected, failed }

class ConnectionProvider extends ChangeNotifier {
  // ─── Saved config ─────────────────────────────────────────
  String _httpUrl = AppConstants.defaultHttpUrl;
  String _wsUrl = AppConstants.defaultWsUrl;
  int _userId = int.parse(AppConstants.defaultUserId);
  String _userRole = AppConstants.defaultUserRole;

  String get httpUrl => _httpUrl;
  String get wsUrl => _wsUrl;
  int get userId => _userId;
  String get userRole => _userRole;

  // ─── Connection state ─────────────────────────────────────
  ConnectionStatus _status = ConnectionStatus.idle;
  String? _errorMessage;

  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isConnecting => _status == ConnectionStatus.connecting;

  // ─── Repository ───────────────────────────────────────────
  ChatRepository? _repository;
  ChatRepository? get repository => _repository;

  // ─── Load saved config ────────────────────────────────────
  Future<void> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _httpUrl =
        prefs.getString(AppConstants.kApiBaseUrl) ??
        AppConstants.defaultHttpUrl;
    _wsUrl =
        prefs.getString(AppConstants.kWsBaseUrl) ?? AppConstants.defaultWsUrl;
    _userId =
        int.tryParse(prefs.getString(AppConstants.kUserId) ?? '') ??
        int.parse(AppConstants.defaultUserId);
    _userRole =
        prefs.getString(AppConstants.kUserRole) ?? AppConstants.defaultUserRole;
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.kApiBaseUrl, _httpUrl);
    await prefs.setString(AppConstants.kWsBaseUrl, _wsUrl);
    await prefs.setString(AppConstants.kUserId, '$_userId');
    await prefs.setString(AppConstants.kUserRole, _userRole);
  }

  // ─── Connect ──────────────────────────────────────────────
  Future<void> connect({
    required String httpUrl,
    required String wsUrl,
    required int userId,
    required String userRole,
  }) async {
    _httpUrl = httpUrl.trim().replaceAll(RegExp(r'/$'), '');
    _wsUrl = wsUrl.trim().replaceAll(RegExp(r'/$'), '');

    // تأكد من أن wsUrl يبدأ بـ ws://
    if (!_wsUrl.startsWith('ws://') && !_wsUrl.startsWith('wss://')) {
      _wsUrl = 'ws://$_wsUrl';
    }

    _userId = userId;
    _userRole = userRole;

    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _repository?.dispose();
      _repository = null;

      final apiClient = ChatApiClient(
        baseUrl: _httpUrl,
        getUserId: () => _userId,
        getUserRole: () => _userRole,
      );

      await apiClient.healthCheck(); // هذه الجملة هي التي تفشل

      final wsService = ChatWebSocketService(
        apiClient: apiClient,
        wsBaseUrl: _wsUrl,
      );

      _repository = ChatRepository(api: apiClient, ws: wsService);

      await _repository!.connect();

      await Future.delayed(const Duration(milliseconds: 500));

      final channels = await _repository!.loadWorkspaceChannels(1);
      print('📢 Auto-subscribing to ${channels.length} channels');
      for (final ch in channels) {
        _repository!.ws.subscribeToChannel(ch.id);
        print('  ✅ Subscribed to channel: ${ch.name} (${ch.id})');
      }

      final dms = await _repository!.loadDms();
      for (final dm in dms) {
        _repository!.ws.subscribeToChannel(dm.id);
        print('  ✅ Subscribed to DM: ${dm.name} (${dm.id})');
      }

      _status = ConnectionStatus.connected;
      await _saveConfig();
    } catch (e) {
      _status = ConnectionStatus.failed;
      _errorMessage =
          'Cannot reach server at $_httpUrl. Make sure the server is running and both devices are on the same network.';
      print('❌ Connection failed: $e');
    }

    notifyListeners();
  }

  void disconnect() {
    _repository?.dispose();
    _repository = null;
    _status = ConnectionStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void resetError() {
    _errorMessage = null;
    if (_status == ConnectionStatus.failed) _status = ConnectionStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }
}
