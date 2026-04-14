import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/channel_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/chat_widgets.dart';
import '../../../core/theme/app_theme.dart';
import 'chat_screen.dart';

class DmsScreen extends StatefulWidget {
  const DmsScreen({super.key});

  @override
  State<DmsScreen> createState() => _DmsScreenState();
}

class _DmsScreenState extends State<DmsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<ChannelProvider>().loadDms());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      appBar: AppBar(
        title: const Text('Direct Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showNewDmDialog(context),
          ),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, provider, _) {
          if (provider.loadingDms && provider.dms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final filtered = _query.isEmpty
              ? provider.dms
              : provider.dms
                  .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              ChatSearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  hint: 'Search conversations...'),
              if (provider.error != null)
                ChatErrorBanner(message: provider.error!, onDismiss: provider.clearError),
              Expanded(
                child: filtered.isEmpty
                    ? ChatEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: _query.isEmpty ? 'No conversations yet' : 'No results',
                        subtitle: _query.isEmpty ? 'Tap pencil to start a DM' : null)
                    : RefreshIndicator(
                        onRefresh: () => provider.loadDms(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _DmTile(
                            dm: filtered[i],
                            unread: provider.unreadCount(filtered[i].id),
                            onTap: () => _open(filtered[i]),
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

  void _open(ChannelResponse dm) {
    final cp = context.read<ConnectionProvider>();
    final chp = context.read<ChannelProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: chp),
            ChangeNotifierProvider.value(value: cp),
          ],
          child: ChatScreen(
            channelId: dm.id,
            title: dm.name.isNotEmpty ? dm.name : 'Direct Message',
            isDm: true,
            currentUserId: cp.userId,
            currentUserRole: cp.userRole,
          ),
        ),
      ),
    ).then((_) => chp.refreshUnread(dm.id));
  }

  void _showNewDmDialog(BuildContext context) {
    final chp = context.read<ChannelProvider>();
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: chp,
        child: _NewDmDialog(onOpened: _open),
      ),
    );
  }
}

class _DmTile extends StatelessWidget {
  final ChannelResponse dm;
  final int unread;
  final VoidCallback onTap;
  const _DmTile({required this.dm, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = dm.name.isNotEmpty
        ? dm.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'DM';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.successSurface,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success)),
          ),
          Positioned(bottom: 0, right: 0,
            child: Container(width: 10, height: 10,
                decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bg, width: 1.5)))),
        ]),
        title: Text(dm.name.isNotEmpty ? dm.name : 'User ${dm.members.lastOrNull ?? ''}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
                color: AppTheme.textPrimary)),
        subtitle: const Text('Tap to open',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: unread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.success, borderRadius: BorderRadius.circular(12)),
                child: Text(unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)))
            : null,
      ),
    );
  }
}

class _NewDmDialog extends StatefulWidget {
  final void Function(ChannelResponse) onOpened;
  const _NewDmDialog({required this.onOpened});

  @override
  State<_NewDmDialog> createState() => _NewDmDialogState();
}

class _NewDmDialogState extends State<_NewDmDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _open() async {
    final id = int.tryParse(_ctrl.text.trim());
    if (id == null) { setState(() => _error = 'Enter a valid user ID'); return; }
    setState(() { _loading = true; _error = null; });
    final ch = await context.read<ChannelProvider>().openDm(id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ch != null) { Navigator.pop(context); widget.onOpened(ch); }
    else setState(() => _error = context.read<ChannelProvider>().error ?? 'Failed');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Direct Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _ctrl, autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Target User ID', hintText: '2',
                  prefixIcon: Icon(Icons.person_rounded, size: 18)),
              onSubmitted: (_) => _open()),
          if (_error != null) ...[const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.error))],
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _loading ? null : _open,
            child: _loading ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Open')),
      ],
    );
  }
}
