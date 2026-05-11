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
  DateTime? _lastOpenedAt;
  int? _currentUserCredits;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadOtherUser();
    await _loadCredits();
    _checkGig();
    _listenToMessages();
  }

  Future<void> _loadOtherUser() async {
    final doc = await _chatService.getUserProfile(widget.otherUserId);
    if (mounted) setState(() => _otherUser = doc);
  }

  Future<void> _loadCredits() async {
    final uid = _chatService.currentUid;
    if (uid == null) return;
    final doc = await _chatService.getUserProfile(uid);
    if (mounted) setState(() => _currentUserCredits = (doc?['credits'] as int?) ?? 0);
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
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 100) {
        if (!_showScrollToBottom) setState(() => _showScrollToBottom = true);
      } else {
        if (_showScrollToBottom) setState(() => _showScrollToBottom = false);
      }
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

  bool _isOwnMessage(ChatMessage message) => message.senderId == _chatService.currentUid;

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    if (date.year == now.year && date.month == now.month && date.day == now.day - 1) return 'Yesterday';
    return '${date.day} ${_monthName(date.month)}${date.year != now.year ? ' ${date.year}' : ''}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getStatusText(ChatMessage message) {
    if (!_isOwnMessage(message)) return '';
    switch (message.status) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.viewed:
        return 'Viewed';
      case MessageStatus.played:
        return 'Played';
    }
  }

  bool _isNewMessage(ChatMessage message) {
    if (_lastOpenedAt == null) return false;
    return message.createdAt.isAfter(_lastOpenedAt!);
  }

  bool _isNewDay(ChatMessage current, ChatMessage? previous) {
    if (previous == null) return true;
    final curr = current.createdAt;
    final prev = previous.createdAt;
    return curr.year != prev.year || curr.month != prev.month || curr.day != prev.day;
  }

  String? _formatDistance(double? meters) {
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final name = _otherUser?['fullName'] as String? ?? 'Chat';
    final currentUid = _chatService.currentUid;
    final isProvider = _gig != null && _gig!['provider_id'] == currentUid;
    final isClient = _gig != null && _gig!['client_id'] == currentUid;
    final gigStatus = _gig?['status'] as String?;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor, size: 22),
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
                                ? DecorationImage(image: NetworkImage(_otherUser!['photoUrl'] as String), fit: BoxFit.cover)
                                : null,
                            color: const Color(0xFF1A1F71),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Register Gig / Pending button
                  GestureDetector(
                    onTap: () {
                      if (_gig != null) {
                        _handleGigAction(isProvider, isClient);
                      } else {
                        _showRegisterGigPrompt();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gig != null ? Colors.orange : const Color(0xFF1A1F71)),
                      ),
                      child: Text(
                        _gig != null ? 'Pending' : 'Register Gig',
                        style: TextStyle(fontSize: 12, color: _gig != null ? Colors.orange : const Color(0xFF1A1F71), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),

            // Gig Banner
            _buildBanner(isDark, _gig, isProvider, name),

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
                        final previous = index > 0 ? _messages[index - 1] : null;
                        final isOwn = _isOwnMessage(message);
                        final showDateDivider = _isNewDay(message, previous);
                        final showNewDivider = _isNewMessage(message) && (previous == null || !_isNewMessage(previous!));

                        return Column(
                          children: [
                            if (showDateDivider)
                              _DateDivider(label: _getDateLabel(message.createdAt), secondaryColor: secondaryColor),
                            if (showNewDivider)
                              _NewMessagesDivider(isDark: isDark),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isOwn ? const Color(0xFF1A1F71) : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8)),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft: isOwn ? const Radius.circular(14) : const Radius.circular(4),
                                          bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(14),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            message.text ?? '',
                                            style: TextStyle(fontSize: 13, color: isOwn ? Colors.white : textColor),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(message.createdAt),
                                                style: TextStyle(fontSize: 9, color: isOwn ? Colors.white60 : secondaryColor),
                                              ),
                                              if (_getStatusText(message).isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getStatusText(message),
                                                  style: TextStyle(fontSize: 9, color: isOwn ? Colors.white60 : secondaryColor),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: secondaryColor, size: 24),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontSize: 14, color: textColor),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 13, color: secondaryColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1F71)),
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
                  onPressed: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  backgroundColor: const Color(0xFF1A1F71),
                  child: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(bool isDark, Map<String, dynamic>? gig, bool isProvider, String name) {
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    String text;
    Color textColor;

    if (gig == null) {
      text = 'Did you offer your services to $name? Register it now to get ratings and reviews to boost your reputation.';
      textColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    } else if (gig['status'] == 'pending') {
      text = isProvider
          ? 'Waiting for $name to rate and review your work'
          : '$name is waiting for your rating and review';
      textColor = Colors.orange;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _showRegisterGigPrompt() async {
    // Check credits
    if (_currentUserCredits != null && _currentUserCredits! < 1) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Credits'),
            content: const Text('You need credits to register a gig. Credits allow clients to rate and review your work.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Buy Credits')),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Gig'),
        content: Text('Do you want to register a gig with ${_otherUser?['fullName'] ?? 'this user'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Get provider's services
    final currentUserDoc = await _chatService.getUserProfile(_chatService.currentUid!);
    final services = List<String>.from(currentUserDoc?['services'] ?? []);

    if (services.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to add services first. Go to your profile to add them.')),
        );
      }
      return;
    }

    final service = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = services.first;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Service'),
              content: DropdownButtonFormField<String>(
                value: selected,
                items: services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDialogState(() => selected = v!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Confirm')),
              ],
            );
          },
        );
      },
    );

    if (service == null || !mounted) return;

    try {
      await _chatService.registerGig(widget.otherUserId, service);
      _checkGig();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register gig: $e')),
        );
      }
    }
  }

  void _handleGigAction(bool isProvider, bool isClient) {
    if (isProvider) {
      _showCancelGigPrompt();
    } else if (isClient) {
      _showClientOptions();
    }
  }

  Future<void> _showCancelGigPrompt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Gig'),
        content: const Text('Do you want to cancel this gig?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatService.cancelGig(widget.otherUserId);
      _checkGig();
    }
  }

  void _showClientOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Submit Review & Rating'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReviewSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Cancel Gig', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCancelGigPrompt();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewSheet() {
    int rating = 5;
    final reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text('Rate & Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setSheetState(() => rating = i + 1),
                        child: Icon(
                          i < rating ? Icons.star : Icons.star_outline,
                          color: const Color(0xFFFFD700),
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Write your review (optional)...',
                      hintStyle: TextStyle(fontSize: 13, color: const Color(0xFF6B7280)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _chatService.submitReview(
                          widget.otherUserId,
                          rating,
                          reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
                        );
                        _checkGig();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Review submitted!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1F71),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Submit Review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String label;
  final Color secondaryColor;

  const _DateDivider({required this.label, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(label, style: TextStyle(fontSize: 11, color: secondaryColor, fontWeight: FontWeight.w400)),
      ),
    );
  }
}

class _NewMessagesDivider extends StatelessWidget {
  final bool isDark;

  const _NewMessagesDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          'New Messages',
          style: TextStyle(fontSize: 11, color: const Color(0xFF1A1F71).withValues(alpha: isDark ? 0.8 : 0.6), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
