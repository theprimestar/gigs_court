import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../widgets/loading_dots.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToConversations();
  }

  void _listenToConversations() {
    _chatService.getConversations().listen((conversations) {
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    });
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = const Color(0xFF6B7280);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
            : _conversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_outlined, size: 48, color: secondaryColor),
                          const SizedBox(height: 16),
                          Text(
                            'No conversations yet.\nDiscover providers on the Home screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final convo = _conversations[index];
                      return _ConversationTile(
                        conversation: convo,
                        onTap: () => context.push('/chat/${convo.otherUserId}'),
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      );
                    },
                  ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final VoidCallback onTap;
  final Color textColor;
  final Color secondaryColor;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: conversation.otherUserPhoto.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(conversation.otherUserPhoto),
                  fit: BoxFit.cover,
                )
              : null,
          color: const Color(0xFF1A1F71),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.otherUserName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(fontSize: 10, color: secondaryColor),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.gigStatus == 'pending'
                  ? 'Gig pending...'
                  : conversation.lastMessage ?? '',
              style: TextStyle(
                fontSize: 12,
                color: conversation.gigStatus == 'pending'
                    ? const Color(0xFF1A1F71)
                    : secondaryColor,
                fontWeight: conversation.gigStatus == 'pending'
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F71),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}/${time.year}';
  }
}
