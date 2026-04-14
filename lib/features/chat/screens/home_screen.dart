import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/channel_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'channels_screen.dart';
import 'dms_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      appBar: AppBar(
        title: const Text('Virtual Office'),
        actions: [
          const _ConnectionDot(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () => _confirmDisconnect(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _InfoCard(provider: provider),
              const SizedBox(height: 20),
              const Text('Chat',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.tag_rounded,
                title: 'Channels',
                subtitle: 'Group workspace channels',
                color: AppTheme.primary,
                colorSurface: AppTheme.primarySurface,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider.value(value: provider),
                        ChangeNotifierProvider(
                            create: (_) => ChannelProvider(provider.repository!)),
                      ],
                      child: const ChannelsScreen(),
                    ),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Direct Messages',
                subtitle: 'One-on-one conversations',
                color: AppTheme.success,
                colorSurface: AppTheme.successSurface,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider.value(value: provider),
                        ChangeNotifierProvider(
                            create: (_) => ChannelProvider(provider.repository!)),
                      ],
                      child: const DmsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    final cp = context.read<ConnectionProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('Close WebSocket and return to connection screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); cp.disconnect(); },
            child: const Text('Disconnect', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot();
  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (_, p, __) => Container(
        width: 8, height: 8,
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            color: p.isConnected ? AppTheme.success : AppTheme.error,
            shape: BoxShape.circle),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ConnectionProvider provider;
  const _InfoCard({required this.provider});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.successSurface, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16)),
            const SizedBox(width: 10),
            const Text('Connected', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 12), const Divider(), const SizedBox(height: 12),
          _Row('Server', provider.httpUrl, Icons.link_rounded),
          const SizedBox(height: 6),
          _Row('User ID', '${provider.userId}', Icons.person_rounded),
          const SizedBox(height: 6),
          _Row('Role', provider.userRole, Icons.shield_outlined),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value; final IconData icon;
  const _Row(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppTheme.textTertiary), const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  final Color color, colorSurface; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle,
      required this.color, required this.colorSurface, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: colorSurface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 18),
      ),
    );
  }
}
