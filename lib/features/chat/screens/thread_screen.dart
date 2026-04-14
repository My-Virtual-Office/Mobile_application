import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:virtual_office/features/chat/repositories/chat_repository.dart';
import '../models/chat_models.dart';
import '../providers/thread_provider.dart';
import '../providers/thread_message_provider.dart';
import '../providers/connection_provider.dart';
import '../widgets/chat_widgets.dart';
import '../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
// ThreadsListScreen
// ═══════════════════════════════════════════════════════════════
class ThreadsListScreen extends StatefulWidget {
  final String channelId;
  final int currentUserId;
  final String currentUserRole;

  const ThreadsListScreen({
    super.key,
    required this.channelId,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<ThreadsListScreen> createState() => _ThreadsListScreenState();
}

class _ThreadsListScreenState extends State<ThreadsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ThreadProvider>().loadThreads(widget.channelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSecondary,
      appBar: AppBar(title: const Text('Threads')),
      body: Consumer<ThreadProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.threads.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return ChatErrorBanner(
              message: provider.error!,
              onDismiss: provider.clearError,
            );
          }
          if (provider.threads.isEmpty) {
            return const ChatEmptyState(
              icon: Icons.forum_rounded,
              title: 'No threads yet',
              subtitle: 'Long-press a message to start a thread',
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadThreads(widget.channelId),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.threads.length,
              itemBuilder: (_, i) {
                final t = provider.threads[i];
                return _ThreadTile(
                  thread: t,
                  unread: provider.threadUnread(t.id),
                  canDelete: provider.canDeleteThread(t),
                  onTap: () => _openThread(t),
                  onDelete: () => _confirmDelete(provider, t),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openThread(ThreadResponse t) {
    final tp = context.read<ThreadProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThreadScreen(
          threadId: t.id,
          channelId: widget.channelId,
          threadName: t.name,
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
        ),
      ),
    ).then((_) => tp.refreshUnread(t.id));
  }

  void _confirmDelete(ThreadProvider provider, ThreadResponse t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete thread?'),
        content: Text('Delete "${t.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteThread(t.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thread tile ──────────────────────────────────────────────
class _ThreadTile extends StatelessWidget {
  final ThreadResponse thread;
  final int unread;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ThreadTile({
    required this.thread,
    required this.unread,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
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
            color: const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.forum_rounded,
            size: 18,
            color: Color(0xFF534AB7),
          ),
        ),
        title: Text(
          thread.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          'By User ${thread.createdBy ?? '?'}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF534AB7),
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
            if (canDelete)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppTheme.textTertiary,
                ),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppTheme.error,
                        ),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.error)),
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

// ═══════════════════════════════════════════════════════════════
// ThreadScreen — messages inside a thread
// ═══════════════════════════════════════════════════════════════
class ThreadScreen extends StatefulWidget {
  final String threadId;
  final String channelId;
  final String threadName;
  final int currentUserId;
  final String currentUserRole;

  const ThreadScreen({
    super.key,
    required this.threadId,
    required this.channelId,
    required this.threadName,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late ThreadMessageProvider _provider;

  // ✅ Save repository reference to avoid using context in dispose
  late final ChatRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ConnectionProvider>().repository!;
    _provider = ThreadMessageProvider(
      _repository,
      threadId: widget.threadId,
      channelId: widget.channelId,
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );
    _provider.init();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    // ✅ Use saved repository reference instead of context
    final msgs = _provider.messages;
    if (msgs.isNotEmpty) {
      _repository.markThreadAsRead(widget.threadId, msgs.last.id);
    }
    _provider.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _provider.loadMore();
    }
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_provider.editingMessage != null) {
      _provider.submitEdit(text);
    } else {
      _provider.sendMessage(text);
    }
    _textCtrl.clear();
  }

  void _startEdit(MessageResponse msg) {
    _provider.setEditing(msg);
    _textCtrl.text = msg.content;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _textCtrl.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.threadName, style: const TextStyle(fontSize: 15)),
              const Text(
                'Thread',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: AppTheme.borderLight),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _ThreadMessagesList(
                scrollCtrl: _scrollCtrl,
                onStartEdit: _startEdit,
              ),
            ),
            Consumer<ThreadMessageProvider>(
              builder: (_, p, __) =>
                  TypingIndicatorWidget(typingUsers: p.typingUsers),
            ),
            Consumer<ThreadMessageProvider>(
              builder: (_, p, __) => ReplyEditBanner(
                replyTo: p.replyTo,
                editingMessage: p.editingMessage,
                onClear: () {
                  if (p.editingMessage != null) {
                    p.clearEdit();
                    _textCtrl.clear();
                  } else
                    p.clearReply();
                },
              ),
            ),
            Consumer<ThreadMessageProvider>(
              builder: (_, p, __) => ChatComposer(
                controller: _textCtrl,
                onSend: _send,
                onTyping: _provider.onUserTyping,
                isEditing: p.editingMessage != null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadMessagesList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final void Function(MessageResponse) onStartEdit;

  const _ThreadMessagesList({
    required this.scrollCtrl,
    required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThreadMessageProvider>(
      builder: (context, provider, _) {
        if (provider.loading)
          return const Center(child: CircularProgressIndicator());
        if (provider.messages.isEmpty) {
          return const ChatEmptyState(
            icon: Icons.forum_rounded,
            title: 'No messages yet',
            subtitle: 'Start the conversation below',
          );
        }
        final msgs = provider.messages.reversed.toList();
        return ListView.builder(
          controller: scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: msgs.length + (provider.loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == msgs.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final msg = msgs[i];
            final isMe = msg.senderId == provider.currentUserId;

            return MessageBubble(
              message: msg,
              isMe: isMe,
              canEdit: provider.canEdit(msg),
              canDelete: provider.canDelete(msg),
              onReply: () => provider.setReplyTo(msg),
              onEdit: provider.canEdit(msg) ? () => onStartEdit(msg) : null,
              onDelete: provider.canDelete(msg)
                  ? () => provider.deleteMessage(msg)
                  : null,
            );
          },
        );
      },
    );
  }
}
