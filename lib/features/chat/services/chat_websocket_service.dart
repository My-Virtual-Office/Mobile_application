import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/chat_models.dart';
import '../api/chat_api_client.dart';

enum WsConnectionState { disconnected, connecting, connected, error }

class ChatWebSocketService {
  final ChatApiClient apiClient;
  final String wsBaseUrl;

  StompClient? _stompClient;

  final _connectionState = StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionState.stream;
  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  final _messageController = StreamController<MessageResponse>.broadcast();
  Stream<MessageResponse> get messageStream => _messageController.stream;

  final _typingController = StreamController<TypingNotification>.broadcast();
  Stream<TypingNotification> get typingStream => _typingController.stream;

  final _errorController = StreamController<WsError>.broadcast();
  Stream<WsError> get errorStream => _errorController.stream;

  final Map<String, StompUnsubscribe> _subs = {};

  ChatWebSocketService({required this.apiClient, required this.wsBaseUrl});

  // ─── Connect ──────────────────────────────────────────────
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting)
      return;

    _setState(WsConnectionState.connecting);

    late WebSocketTicketResponse ticketRes;
    try {
      ticketRes = await apiClient.getWsTicket();
      print('✅ Got WebSocket ticket: ${ticketRes.ticket}');
    } catch (e) {
      print('❌ Failed to get WebSocket ticket: $e');
      _setState(WsConnectionState.error);
      return;
    }

    // Use ws:// URL for direct WebSocket
    final url = '$wsBaseUrl/api/chat/connect?ticket=${ticketRes.ticket}';
    print('🔌 Connecting to WebSocket: $url');

    _stompClient = StompClient(
      config: StompConfig(
        url: url,
        onConnect: _onConnected,
        onDisconnect: (_) {
          print('⚠️ WebSocket disconnected');
          _setState(WsConnectionState.disconnected);
        },
        onStompError: (frame) {
          print('❌ STOMP error: ${frame.body}');
          _setState(WsConnectionState.error);
        },
        onWebSocketError: (error) {
          print('❌ WebSocket error: $error');
          _setState(WsConnectionState.error);
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _stompClient!.activate();
  }

  void _onConnected(StompFrame frame) {
    print('✅ WebSocket STOMP connected successfully');
    _setState(WsConnectionState.connected);

    // Subscribe to personal error queue
    _stompClient!.subscribe(
      destination: '/user/queue/errors',
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          final payload = json['payload'] as Map<String, dynamic>;
          print('❌ WebSocket error from server: ${payload['message']}');
          _errorController.add(WsError.fromJson(payload));
        } catch (_) {}
      },
    );
  }

  // ─── Disconnect ───────────────────────────────────────────
  void disconnect() {
    _unsubscribeAll();
    _stompClient?.deactivate();
    _stompClient = null;
    _setState(WsConnectionState.disconnected);
  }

  // ─── Channel subscriptions ────────────────────────────────
  void subscribeToChannel(String channelId) {
    if (!_isConnected) {
      print('⚠️ Cannot subscribe to channel $channelId - not connected');
      return;
    }
    print('📡 Subscribing to channel: $channelId');
    _subscribeTo(
      'channel/$channelId',
      '/topic/channel/$channelId',
      _handleEvent,
    );
    _subscribeTo(
      'channel/$channelId/typing',
      '/topic/channel/$channelId/typing',
      _handleTypingEvent,
    );
  }

  void unsubscribeFromChannel(String channelId) {
    print('📡 Unsubscribing from channel: $channelId');
    _unsubscribe('channel/$channelId');
    _unsubscribe('channel/$channelId/typing');
  }

  // ─── Thread subscriptions ─────────────────────────────────
  void subscribeToThread(String threadId) {
    if (!_isConnected) return;
    print('📡 Subscribing to thread: $threadId');
    _subscribeTo('thread/$threadId', '/topic/thread/$threadId', _handleEvent);
    _subscribeTo(
      'thread/$threadId/typing',
      '/topic/thread/$threadId/typing',
      _handleTypingEvent,
    );
  }

  void unsubscribeFromThread(String threadId) {
    _unsubscribe('thread/$threadId');
    _unsubscribe('thread/$threadId/typing');
  }

  // ─── Send message via STOMP ───────────────────────────────
  void sendMessage(StompSendMessage payload) {
    if (!_isConnected) {
      print('⚠️ Cannot send message - WebSocket not connected');
      return;
    }
    final jsonBody = jsonEncode(payload.toJson());
    print('📤 Sending message via STOMP: $jsonBody');
    _stompClient!.send(destination: '/app/chat/send', body: jsonBody);
  }

  // ─── Send typing event ────────────────────────────────────
  void sendTyping(StompTypingEvent payload) {
    if (!_isConnected) return;
    _stompClient!.send(
      destination: '/app/chat/typing',
      body: jsonEncode(payload.toJson()),
    );
  }

  // ─── Event handlers ───────────────────────────────────────
  void _handleEvent(StompFrame frame) {
    if (frame.body == null) return;
    try {
      final json = jsonDecode(frame.body!) as Map<String, dynamic>;
      final action = json['action'] as String;
      final payload = json['payload'] as Map<String, dynamic>;

      print(
        '📨 Received STOMP event: action=$action, payload=${payload['id']}',
      );

      switch (action) {
        case 'NEW_MESSAGE':
          print('🆕 New message received');
          _messageController.add(MessageResponse.fromJson(payload));
          break;
        case 'EDIT_MESSAGE':
          print('✏️ Edit message received');
          _messageController.add(MessageResponse.fromJson(payload));
          break;
        case 'DELETE_MESSAGE':
          print('🗑️ Delete message received');
          _messageController.add(MessageResponse.fromJson(payload));
          break;
        case 'THREAD_DELETED':
          print('🧵 Thread deleted');
          break;
        default:
          print('⚠️ UNKNOWN ACTION: $action');
      }
    } catch (e) {
      print('❌ Error handling STOMP event: $e');
    }
  }

  void _handleTypingEvent(StompFrame frame) {
    if (frame.body == null) return;
    try {
      final json = jsonDecode(frame.body!) as Map<String, dynamic>;
      final payload = json['payload'] as Map<String, dynamic>;
      _typingController.add(TypingNotification.fromJson(payload));
    } catch (_) {}
  }

  // ─── Helpers ──────────────────────────────────────────────
  bool get _isConnected => _state == WsConnectionState.connected;

  void _subscribeTo(
    String key,
    String destination,
    void Function(StompFrame) callback,
  ) {
    if (_subs.containsKey(key)) {
      print('  Already subscribed to $destination');
      return;
    }
    print('  ➕ Subscribing to $destination');
    final unsub = _stompClient!.subscribe(
      destination: destination,
      callback: callback,
    );
    _subs[key] = unsub;
  }

  void _setState(WsConnectionState s) {
    _state = s;
    _connectionState.add(s);
  }

  void _unsubscribe(String key) => _subs.remove(key)?.call();

  void _unsubscribeAll() {
    for (final unsub in _subs.values) unsub();
    _subs.clear();
  }

  void dispose() {
    disconnect();
    _connectionState.close();
    _messageController.close();
    _typingController.close();
    _errorController.close();
  }
}
