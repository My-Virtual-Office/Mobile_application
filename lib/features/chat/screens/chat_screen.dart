import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:virtual_office/features/chat/repositories/chat_repository.dart';
import '../models/chat_models.dart';
import '../providers/message_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/thread_provider.dart';
import '../widgets/chat_widgets.dart';
import '../../../core/theme/app_theme.dart';
import 'thread_screen.dart';

class ChatScreen extends StatefulWidget {
  final String channelId;
  final String title;
  final bool isDm;
  final int currentUserId;
  final String currentUserRole;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.title,
    required this.currentUserId,
    required this.currentUserRole,
    this.isDm = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late MessageProvider _msgProvider;
  late ChannelProvider _channelProvider;

  // Save repository reference to avoid using context in dispose
  late final ChatRepository _repository;

  @override
  void initState() {
    super.initState();

    _repository = context.read<ConnectionProvider>().repository!;
    _channelProvider = context.read<ChannelProvider>();

    _msgProvider = MessageProvider(
      _repository,
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );

    _msgProvider.enterChannel(widget.channelId);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    final msgs = _msgProvider.messages;
    if (msgs.isNotEmpty) {
      _channelProvider.markAsRead(widget.channelId, msgs.last.id);
    }

    _msgProvider.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _msgProvider.loadMore();
    }
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_msgProvider.editingMessage != null) {
      _msgProvider.submitEdit(text);
    } else {
      _msgProvider.sendMessage(text);
    }
    _textCtrl.clear();
  }

  void _startEdit(MessageResponse msg) {
    _msgProvider.setEditing(msg);
    _textCtrl.text = msg.content;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _textCtrl.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _msgProvider,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (!widget.isDm)
              IconButton(
                icon: const Icon(Icons.forum_rounded, size: 20),
                tooltip: 'Threads',
                onPressed: () => _openThreadsList(context),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: AppTheme.borderLight),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _MessagesList(
                scrollCtrl: _scrollCtrl,
                channelId: widget.channelId,
                isDm: widget.isDm,
                currentUserId: widget.currentUserId,
                currentUserRole: widget.currentUserRole,
                onStartEdit: _startEdit,
              ),
            ),
            Consumer<MessageProvider>(
              builder: (_, p, __) =>
                  TypingIndicatorWidget(typingUsers: p.typingUsers),
            ),
            Consumer<MessageProvider>(
              builder: (_, p, __) => ReplyEditBanner(
                replyTo: p.replyTo,
                editingMessage: p.editingMessage,
                onClear: () {
                  if (p.editingMessage != null) {
                    p.clearEdit();
                    _textCtrl.clear();
                  } else {
                    p.clearReply();
                  }
                },
              ),
            ),
            Consumer<MessageProvider>(
              builder: (_, p, __) => ChatComposer(
                controller: _textCtrl,
                onSend: _send,
                onTyping: _msgProvider.onUserTyping,
                isEditing: p.editingMessage != null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openThreadsList(BuildContext context) {
    final cp = context.read<ConnectionProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ThreadProvider(
            cp.repository!,
            currentUserId: cp.userId,
            currentUserRole: cp.userRole,
          ),
          child: ThreadsListScreen(
            channelId: widget.channelId,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      ),
    );
  }
}

// ─── Messages list ────────────────────────────────────────────
class _MessagesList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final String channelId;
  final bool isDm;
  final int currentUserId;
  final String currentUserRole;
  final void Function(MessageResponse) onStartEdit;

  const _MessagesList({
    required this.scrollCtrl,
    required this.channelId,
    required this.isDm,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.messages.isEmpty) {
          return const ChatEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            subtitle: 'Be the first to say something!',
          );
        }

        // Messages are already sorted (oldest first, newest last)
        final msgs = provider.messages;

        return ListView.builder(
          controller: scrollCtrl,
          reverse: false,
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
            final isMe = msg.senderId == currentUserId;

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
              onOpenThread: !isDm ? () => _handleThread(context, msg) : null,
            );
          },
        );
      },
    );
  }

  void _handleThread(BuildContext context, MessageResponse msg) {
    if (msg.threadId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreadScreen(
            threadId: msg.threadId!,
            channelId: channelId,
            threadName: 'Thread',
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
          ),
        ),
      );
    } else {
      final cp = context.read<ConnectionProvider>();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => ChangeNotifierProvider.value(
          value: cp,
          child: _CreateThreadSheet(
            message: msg,
            channelId: channelId,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
          ),
        ),
      );
    }
  }
}

// ─── Create thread sheet ──────────────────────────────────────
class _CreateThreadSheet extends StatefulWidget {
  final MessageResponse message;
  final String channelId;
  final int currentUserId;
  final String currentUserRole;

  const _CreateThreadSheet({
    required this.message,
    required this.channelId,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<_CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends State<_CreateThreadSheet> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Thread name is required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<ConnectionProvider>().repository!;
      final thread = await repo.createThread(
        widget.channelId,
        widget.message.id,
        name,
      );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreadScreen(
            threadId: thread.id,
            channelId: widget.channelId,
            threadName: thread.name,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Start a Thread',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: AppTheme.primary, width: 3),
              ),
            ),
            child: Text(
              widget.message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Thread name',
              hintText: 'e.g. discussion, follow-up...',
            ),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
                  : const Text('Create Thread'),
            ),
          ),
        ],
      ),
    );
  }
}
