import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/channel_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/chat_widgets.dart';
import '../../../core/theme/app_theme.dart';
import 'chat_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ChannelProvider>().loadChannels(1),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(ChannelResponse ch) async {
    final cp = context.read<ConnectionProvider>();
    final chp = context.read<ChannelProvider>();

    // ✅ IMPORTANT: Join channel before opening
    await chp.joinChannel(ch.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: chp),
            ChangeNotifierProvider.value(value: cp),
          ],
          child: ChatScreen(
            channelId: ch.id,
            title: '# ${ch.name}',
            currentUserId: cp.userId,
            currentUserRole: cp.userRole,
          ),
        ),
      ),
    ).then((_) => chp.refreshUnread(ch.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, _) {
          if (provider.loadingChannels && provider.channels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final filtered = _query.isEmpty
              ? provider.channels
              : provider.channels
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();

          return Column(
            children: [
              ChatSearchBar(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                hint: 'Search channels...',
              ),
              if (provider.error != null)
                ChatErrorBanner(
                  message: provider.error!,
                  onDismiss: provider.clearError,
                ),
              Expanded(
                child: filtered.isEmpty
                    ? ChatEmptyState(
                        icon: Icons.tag_rounded,
                        title: _query.isEmpty
                            ? 'No channels yet'
                            : 'No results',
                        subtitle: _query.isEmpty ? 'Tap + to create one' : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.loadChannels(1),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _ChannelTile(
                            channel: filtered[i],
                            unread: provider.unreadCount(filtered[i].id),
                            onTap: () => _open(filtered[i]),
                            onLeave: () => _confirmLeave(filtered[i]),
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

  void _showCreateDialog(BuildContext context) {
    // Capture providers BEFORE dialog opens
    final chp = context.read<ChannelProvider>();
    final cp = context.read<ConnectionProvider>();
    showDialog(
      context: context,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chp),
          ChangeNotifierProvider.value(value: cp),
        ],
        child: _CreateChannelDialog(onCreated: _open),
      ),
    );
  }

  void _confirmLeave(ChannelResponse ch) {
    final chp = context.read<ChannelProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave channel?'),
        content: Text('Leave # ${ch.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              chp.leaveChannel(ch.id);
            },
            child: const Text('Leave', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Channel tile ─────────────────────────────────────────────
class _ChannelTile extends StatelessWidget {
  final ChannelResponse channel;
  final int unread;
  final VoidCallback onTap;
  final VoidCallback onLeave;
  const _ChannelTile({
    required this.channel,
    required this.unread,
    required this.onTap,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          channel.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${channel.members.length} members',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: AppTheme.textTertiary,
              ),
              onSelected: (v) {
                if (v == 'leave') onLeave();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app_rounded,
                        size: 16,
                        color: AppTheme.error,
                      ),
                      SizedBox(width: 8),
                      Text('Leave', style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Create channel dialog ────────────────────────────────────
class _CreateChannelDialog extends StatefulWidget {
  final void Function(ChannelResponse) onCreated;
  const _CreateChannelDialog({required this.onCreated});

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _nameCtrl = TextEditingController();
  final _membersCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _membersCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name required');
      return;
    }
    final myId = context.read<ConnectionProvider>().userId;
    final extras = _membersCtrl.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    final members = {myId, ...extras}.toList();
    setState(() {
      _loading = true;
      _error = null;
    });
    final ch = await context.read<ChannelProvider>().createChannel(
      name: name,
      workspaceId: 1,
      members: members,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ch != null) {
      Navigator.pop(context);
      widget.onCreated(ch);
    } else
      setState(
        () => _error = context.read<ChannelProvider>().error ?? 'Failed',
      );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Channel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Channel name',
              hintText: 'general',
              prefixText: '# ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _membersCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Member IDs (optional)',
              hintText: '2, 3, 4',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your ID is added automatically',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
