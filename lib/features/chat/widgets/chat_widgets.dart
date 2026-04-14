import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chat_models.dart';

// ─── Search bar ───────────────────────────────────────────────
class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────
class ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const ChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────
class ChatErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const ChatErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.errorSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppTheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────
class MessageBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenThread;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.canEdit,
    required this.canDelete,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onOpenThread,
  });

  @override
  Widget build(BuildContext context) {
    if (message.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Message deleted',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primarySurface,
                child: Text(
                  message.senderUsername.isNotEmpty
                      ? message.senderUsername[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderUsername,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  if (message.replyToId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppTheme.primary.withOpacity(0.15)
                            : AppTheme.bgTertiary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: isMe
                                ? AppTheme.primary
                                : AppTheme.textTertiary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Replying to a message',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primary : AppTheme.bgSecondary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(
                          isMe || message.replyToId != null ? 16 : 4,
                        ),
                        topRight: Radius.circular(
                          !isMe || message.replyToId != null ? 16 : 4,
                        ),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      border: isMe
                          ? null
                          : Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.updatedAt != message.createdAt)
                          const Text(
                            'edited · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        Text(
                          _fmtTime(message.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        if (onOpenThread != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onOpenThread,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_rounded,
                                    size: 10,
                                    color: AppTheme.primary,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Thread',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppTheme.primary),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            if (onOpenThread != null)
              ListTile(
                leading: const Icon(
                  Icons.forum_rounded,
                  color: AppTheme.primary,
                ),
                title: const Text('Open / create thread'),
                onTap: () {
                  Navigator.pop(context);
                  onOpenThread!();
                },
              ),
            if (canEdit && onEdit != null)
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppTheme.textSecondary,
                ),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (canDelete && onDelete != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Reply / Edit banner ──────────────────────────────────────
class ReplyEditBanner extends StatelessWidget {
  final MessageResponse? replyTo;
  final MessageResponse? editingMessage;
  final VoidCallback onClear;
  const ReplyEditBanner({
    super.key,
    this.replyTo,
    this.editingMessage,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (replyTo == null && editingMessage == null)
      return const SizedBox.shrink();
    final isEdit = editingMessage != null;
    final msg = editingMessage ?? replyTo!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(
          top: BorderSide(color: AppTheme.borderLight),
          left: BorderSide(
            color: isEdit ? AppTheme.warning : AppTheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_rounded : Icons.reply_rounded,
            size: 16,
            color: isEdit ? AppTheme.warning : AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit
                      ? 'Editing message'
                      : 'Replying to ${msg.senderUsername}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isEdit ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
                Text(
                  msg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppTheme.textTertiary,
            ),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────
class TypingIndicatorWidget extends StatelessWidget {
  final List<int> typingUsers;
  const TypingIndicatorWidget({super.key, required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();
    final text = typingUsers.length == 1
        ? 'User ${typingUsers.first} is typing...'
        : '${typingUsers.length} people are typing...';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ─── Composer ─────────────────────────────────────────────────
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  final bool isEditing;
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onTyping,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              onChanged: (_) => onTyping(),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: isEditing ? 'Edit message...' : 'Message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppTheme.bgSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) {
              final has = val.text.trim().isNotEmpty;
              return Material(
                color: has
                    ? (isEditing ? AppTheme.warning : AppTheme.primary)
                    : AppTheme.bgTertiary,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: has ? onSend : null,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      isEditing ? Icons.check_rounded : Icons.send_rounded,
                      size: 18,
                      color: has ? Colors.white : AppTheme.textTertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
