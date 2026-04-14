// lib/core/services/notification_service.dart
//
// ✅ يشتغل في التلات حالات: Foreground / Background / Terminated
// ✅ awesome_notifications: ^0.9.x
// ──────────────────────────────────────────────────────────────
// المتطلبات في pubspec.yaml:
//   awesome_notifications: ^0.9.3
//
// Android: في AndroidManifest.xml داخل <application>:
//   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//   <uses-permission android:name="android.permission.VIBRATE"/>
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//
// iOS: في ios/Runner/AppDelegate.swift أضف:
//   import awesome_notifications  (يتعمل أوتوماتيك مع flutter)
// ──────────────────────────────────────────────────────────────

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

// ─── Keys ثابتة للـ channels ────────────────────────────────
class NotifChannels {
  static const String channel = 'chat_channel';
  static const String dm = 'dm_channel';
  static const String thread = 'thread_channel';
  static const String system = 'system_channel';
}

// ─── Service ─────────────────────────────────────────────────
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  // ══════════════════════════════════════════════════════════
  //  INITIALIZE — استدعيه في main() قبل runApp()
  // ══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;

    await AwesomeNotifications().initialize(
      null, // null = أيقونة التطبيق الافتراضية
      [
        // ── Channel Messages ──────────────────────────────
        NotificationChannel(
          channelKey: NotifChannels.channel,
          channelName: 'Channel Messages',
          channelDescription: 'إشعارات رسائل القنوات',
          defaultColor: const Color(0xFF534AB7),
          ledColor: const Color(0xFF534AB7),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
        // ── Direct Messages ───────────────────────────────
        NotificationChannel(
          channelKey: NotifChannels.dm,
          channelName: 'Direct Messages',
          channelDescription: 'إشعارات الرسائل المباشرة',
          defaultColor: const Color(0xFF22C55E),
          ledColor: const Color(0xFF22C55E),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
        // ── Thread Messages ───────────────────────────────
        NotificationChannel(
          channelKey: NotifChannels.thread,
          channelName: 'Thread Messages',
          channelDescription: 'إشعارات رسائل الثريدات',
          defaultColor: const Color(0xFF8B5CF6),
          ledColor: const Color(0xFF8B5CF6),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
        // ── System (invites, etc.) ────────────────────────
        NotificationChannel(
          channelKey: NotifChannels.system,
          channelName: 'System Notifications',
          channelDescription: 'دعوات القنوات والإشعارات النظامية',
          defaultColor: const Color(0xFFF97316),
          ledColor: const Color(0xFFF97316),
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
      debug: false,
    );

    // ── طلب الإذن (Android 13+ / iOS) ──────────────────────
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    // ── تسجيل الـ listeners ──────────────────────────────────
    // @pragma("vm:entry-point") على كل handler ضرورية عشان
    // تشتغل وقت background/terminated بدون tree-shaking
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceived,
      onNotificationCreatedMethod: onNotificationCreated,
      onNotificationDisplayedMethod: onNotificationDisplayed,
      onDismissActionReceivedMethod: onDismissActionReceived,
    );

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  // ══════════════════════════════════════════════════════════
  //  STATIC HANDLERS — لازم يكونوا static + @pragma
  //  ده اللي بيخلي الـ background/terminated يشتغل
  // ══════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  static Future<void> onNotificationCreated(
    ReceivedNotification received,
  ) async {
    debugPrint('🔔 Notification created: id=${received.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayed(
    ReceivedNotification received,
  ) async {
    debugPrint('👁️ Notification displayed: id=${received.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceived(ReceivedAction action) async {
    debugPrint('❌ Notification dismissed: id=${action.id}');
  }

  /// يُستدعى لما المستخدم يضغط على الإشعار
  /// يشتغل في الثلاث حالات (foreground / background / terminated)
  @pragma('vm:entry-point')
  static Future<void> onActionReceived(ReceivedAction action) async {
    debugPrint('👆 Notification tapped: id=${action.id}');

    final payload = action.payload;
    if (payload == null) return;

    final channelId = payload['channelId'];
    final threadId = payload['threadId'];
    final isDm = payload['isDm'] == 'true';

    if (channelId != null) {
      // أبلّغ الـ navigator بالـ route المطلوب
      NotificationNavigator.navigate(channelId, threadId, isDm);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SHOW NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  /// رسالة في قناة عادية
  Future<void> showChannelMessage({
    required String channelId,
    required String channelName,
    required String senderName,
    required String content,
    String? messageId,
  }) async {
    await _show(
      channelKey: NotifChannels.channel,
      title: '#$channelName',
      body: _formatBody(senderName, content),
      payload: {
        'channelId': channelId,
        'isDm': 'false',
        'messageId': messageId ?? '',
        'type': 'channel_message',
      },
    );
  }

  /// رسالة مباشرة DM
  Future<void> showDirectMessage({
    required String channelId,
    required String senderName,
    required String content,
    String? messageId,
  }) async {
    await _show(
      channelKey: NotifChannels.dm,
      title: senderName,
      body: _truncate(content),
      payload: {
        'channelId': channelId,
        'isDm': 'true',
        'messageId': messageId ?? '',
        'type': 'dm',
      },
    );
  }

  /// رسالة في thread
  Future<void> showThreadMessage({
    required String channelId,
    required String threadId,
    required String threadName,
    required String senderName,
    required String content,
    String? messageId,
  }) async {
    await _show(
      channelKey: NotifChannels.thread,
      title: 'Thread: $threadName',
      body: _formatBody(senderName, content),
      payload: {
        'channelId': channelId,
        'threadId': threadId,
        'isDm': 'false',
        'messageId': messageId ?? '',
        'type': 'thread_message',
      },
    );
  }

  /// إشعار نظامي (مثلاً: تمت إضافتك لقناة)
  Future<void> showSystemNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    await _show(
      channelKey: NotifChannels.system,
      title: title,
      body: body,
      payload: payload,
      layout: NotificationLayout.Default,
    );
  }

  // ── helpers ──────────────────────────────────────────────

  Future<void> _show({
    required String channelKey,
    required String title,
    required String body,
    Map<String, String>? payload,
    NotificationLayout layout = NotificationLayout.BigText,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          channelKey: channelKey,
          title: title,
          body: body,
          notificationLayout: layout,
          payload: payload,
          category: NotificationCategory.Message,
          wakeUpScreen: true,
          // fullScreenIntent: false, — شغّله لو عايز يفتح على شاشة القفل
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  String _truncate(String text, [int max = 120]) =>
      text.length > max ? '${text.substring(0, max)}...' : text;

  String _formatBody(String sender, String content) =>
      '$sender: ${_truncate(content)}';

  // ── إلغاء ─────────────────────────────────────────────────

  Future<void> cancelAll() => AwesomeNotifications().cancelAll();

  Future<void> cancel(int id) => AwesomeNotifications().cancel(id);
}

// ══════════════════════════════════════════════════════════
//  NAVIGATION — ربط الإشعار بالـ Route
// ══════════════════════════════════════════════════════════
//
// الفكرة:
//   • لما التطبيق foreground  → ننفّذ الـ callback مباشرة
//   • لما background/terminated → نحفظ الـ pending route
//     وننفذه بعد ما الـ app يعمل build أول مرة
//
class NotificationNavigator {
  // Callback يسجّله الـ widget الرئيسي (مثلاً MaterialApp)
  static void Function(String channelId, String? threadId, bool isDm)? _handler;

  // Route معلّق لما التطبيق كان terminated أو background
  static _PendingRoute? _pending;

  /// سجّل الـ handler من main widget
  static void register(
    void Function(String channelId, String? threadId, bool isDm) handler,
  ) {
    _handler = handler;

    // لو في pending route ينتظر، نفّذه فوراً
    if (_pending != null) {
      final p = _pending!;
      _pending = null;
      handler(p.channelId, p.threadId, p.isDm);
    }
  }

  /// استدعيه من onActionReceived
  static void navigate(String channelId, String? threadId, bool isDm) {
    if (_handler != null) {
      _handler!(channelId, threadId, isDm);
    } else {
      // التطبيق لسه بيبدأ → احفظ الـ route
      _pending = _PendingRoute(channelId, threadId, isDm);
    }
  }

  static void dispose() {
    _handler = null;
    _pending = null;
  }
}

class _PendingRoute {
  final String channelId;
  final String? threadId;
  final bool isDm;
  _PendingRoute(this.channelId, this.threadId, this.isDm);
}
