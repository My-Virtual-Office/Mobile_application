// lib/main.dart
//
// ✅ تهيئة الإشعارات قبل runApp
// ✅ ربط NotificationNavigator بالـ Navigator
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:virtual_office/features/chat/services/notification_service.dart';
import 'features/chat/providers/connection_provider.dart';
import 'features/chat/screens/connection_screen.dart';
// استورد شاشاتك الأخرى حسب الـ routes

// ══════════════════════════════════════════════════════════
//  main — @pragma ضرورية عشان تشتغل في background
// ══════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ هيّئ الإشعارات أول حاجة قبل أي حاجة تانية
  await NotificationService().initialize();

  runApp(const MyApp());
}

// ══════════════════════════════════════════════════════════
//  MyApp
// ══════════════════════════════════════════════════════════
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // NavigatorKey عشان نقدر نعمل navigate من أي مكان
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // 2️⃣ سجّل الـ handler بعد ما الـ widget اتبنى
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationNavigator.register((channelId, threadId, isDm) {
        _handleNotificationNavigation(channelId, threadId, isDm);
      });
    });
  }

  @override
  void dispose() {
    NotificationNavigator.dispose();
    super.dispose();
  }

  /// التنقل لما المستخدم يضغط على إشعار
  void _handleNotificationNavigation(
    String channelId,
    String? threadId,
    bool isDm,
  ) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    final connectionProvider = _navigatorKey.currentContext
        ?.read<ConnectionProvider>();

    // لو مش متصل، ارجع لشاشة الاتصال الأول
    if (connectionProvider == null || !connectionProvider.isConnected) return;

    if (threadId != null) {
      // افتح الثريد مباشرة
      nav.pushNamed(
        '/thread',
        arguments: {'channelId': channelId, 'threadId': threadId},
      );
    } else {
      // افتح الـ channel أو DM
      nav.pushNamed('/chat', arguments: {'channelId': channelId, 'isDm': isDm});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ConnectionProvider())],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Virtual Office',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF534AB7),
          useMaterial3: true,
        ),
        home: const ConnectionScreen(),
        // أضف routes حسب تطبيقك
        routes: {
          '/chat': (ctx) => const _ChatRouteWrapper(),
          // '/thread': (ctx) => const _ThreadRouteWrapper(),
        },
      ),
    );
  }
}

// ── Helper wrapper لو بتستخدم named routes ──────────────────
class _ChatRouteWrapper extends StatelessWidget {
  const _ChatRouteWrapper();

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final channelId = args['channelId'] as String;
    final isDm = args['isDm'] as bool? ?? false;
    final cp = context.read<ConnectionProvider>();

    // استبدل بـ ChatScreen الفعلية
    // return ChatScreen(
    //   channelId: channelId,
    //   title: isDm ? 'DM' : '# Channel',
    //   isDm: isDm,
    //   currentUserId: cp.userId,
    //   currentUserRole: cp.userRole,
    // );
    return const Scaffold(body: Center(child: Text('Chat')));
  }
}
