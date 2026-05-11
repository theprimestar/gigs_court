import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/chat_service.dart';
import '../widgets/loading_dots.dart';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;

  const ChatDetailScreen({super.key, required this.otherUserId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  Map<String, dynamic>? _otherUser;
  Map<String, dynamic>? _gig;
  bool _isLoading = true;
  bool _showScrollToBottom = false;
  bool _isSending = false;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadOtherUser();
    await _checkGig();
    _listenToMessages();
  }

  Future<void> _loadOtherUser() async {
    final doc = await _chatService.getUserProfile(widget.otherUserId);
    if (mounted) setState(() => _otherUser = doc);
  }

  Future<void> _checkGig() async {
    final gig = await _chatService.getGig(widget.otherUserId);
    if (mounted) setState(() => _gig = gig);
  }

  void _listenToMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = _chatService.getMessages(widget.otherUserId).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottomIfNeeded();
      }
    });
    _chatService.markAsRead(widget.otherUserId);
  }

  void _scrollToBottomIfNeeded() {
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 100) {
      if (!_showScrollToBottom) setState(() => _showScrollToBottom = true);
    } else {
      if (_showScrollToBottom) setState(() => _showScrollToBottom = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatService.sendTextMessage(widget.otherUserId, text);
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  bool _isOwnMessage(ChatMessage message) {
    return message.senderId == _chatService.currentUid;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = const Color(0xFF6B7280);
    final name = _otherUser?['fullName'] as String? ?? 'Chat';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(bottom: BorderSide(color: secondaryColor.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => context.pop(),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile/${widget.otherUserId}'),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: _otherUser?['photoUrl'] != null && (_otherUser!['photoUrl'] as String).isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_otherUser!['photoUrl'] as String),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: const Color(0xFF1A1F71),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.handshake_outlined, color: textColor, size: 22),
                    onPressed: _gig != null ? () => _cancelGig() : () => _registerGig(),
                  ),
                ],
              ),
            ),

            // Gig banner
            if (_gig != null)
              _GigBanner(
                gig: _gig!,
                isDark: isDark,
              ),

            if (_gig == null)
              _RegisterBanner(isDark: isDark, otherName: name),

            // Messages
            Expanded(
              child: _isLoading
                  ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isOwn = _isOwnMessage(message);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isOwn) const SizedBox(width: 4),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isOwn
                                        ? const Color(0xFF1A1F71)
                                        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isOwn ? const Radius.circular(16) : Radius.zero,
                                      bottomRight: isOwn ? Radius.zero : const Radius.circular(16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        message.text ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isOwn ? Colors.white : textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isOwn ? Colors.white70 : secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(top: BorderSide(color: secondaryColor.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 13, color: secondaryColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A1F71),
                      ),
                      child: _isSending
                          ? const LoadingDots(color: Colors.white)
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Scroll to bottom FAB
            if (_showScrollToBottom)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () => _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
                  backgroundColor: const Color(0xFF1A1F71),
                  child: const Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerGig() async {
    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register Gig'),
        content: Text('Do you want to register a gig with ${_otherUser?['fullName'] ?? 'this user'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show service picker
    final service = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Service'),
        content: const Text('Service selection coming soon...'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );

    if (service == null) return;

    try {
      await _chatService.registerGig(widget.otherUserId, service);
      _checkGig();
    } catch (_) {}
  }

  Future<void> _cancelGig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Gig'),
        content: const Text('Do you want to cancel this gig?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.cancelGig(widget.otherUserId);
      _checkGig();
    }
  }
}

class _RegisterBanner extends StatelessWidget {
  final bool isDark;
  final String otherName;

  const _RegisterBanner({required this.isDark, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      child: Text(
        'Did you offer your services to $otherName? Register it now to get ratings and reviews to boost your reputation.',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GigBanner extends StatelessWidget {
  final Map<String, dynamic> gig;
  final bool isDark;

  const _GigBanner({required this.gig, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isProvider = gig['provider_id'] == ChatService().currentUid;
    final status = gig['status'] as String? ?? 'pending';

    String text;
    if (status == 'pending') {
      text = isProvider
          ? 'Waiting for client to rate and review your work'
          : 'Provider is waiting for your rating and review';
    } else {
      text = 'Gig $status';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
