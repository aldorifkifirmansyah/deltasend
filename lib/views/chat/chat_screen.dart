import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../utils/app_assets.dart';
import '../customer/customer_bottom_bar.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String currentUserId;
  final String customerId;
  final String driverId;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.customerId,
    required this.driverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  String _otherUserName = 'Chat';
  bool _isSending = false;

  static const Color _primaryBlue = Color(0xFF133D87);

  static const Color _headerBlue = Color(0xFF608BC0);

  static const Color _textDark = Color(0xFF1A1D23);

  static const Color _textGrey = Color(0xFF6F7784);

  String get _otherUserId => widget.currentUserId == widget.customerId
      ? widget.driverId
      : widget.customerId;

  bool get _isCustomer => widget.currentUserId == widget.customerId;

  @override
  void initState() {
    super.initState();

    _initializeChat();
    _loadOtherUserName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      await _chatService.ensureChatExists(
        orderId: widget.orderId,
        customerId: widget.customerId,
        driverId: widget.driverId,
      );

      await _chatService.markMessagesAsRead(
        orderId: widget.orderId,
        currentUserId: widget.currentUserId,
      );
    } catch (error) {
      if (!mounted) return;

      _showSnackBar(error.toString());
    }
  }

  Future<void> _loadOtherUserName() async {
    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .get();

      final String? name = document.data()?['name'] as String?;

      if (!mounted || name == null || name.trim().isEmpty) {
        return;
      }

      setState(() {
        _otherUserName = name.trim();
      });
    } catch (_) {
      // Gunakan nama default jika profil gagal dimuat.
    }
  }

  Future<void> _sendMessage() async {
    final String message = _messageController.text.trim();

    if (message.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      await _chatService.sendMessage(
        orderId: widget.orderId,
        senderId: widget.currentUserId,
        content: message,
      );

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      _showSnackBar(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatOrderId(String orderId) {
    final String cleanId = orderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    final String shortId = cleanId.length > 8
        ? cleanId.substring(0, 8)
        : cleanId;

    return '#ORD-$shortId';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final String hour = date.hour.toString().padLeft(2, '0');

    final String minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      extendBody: false,
      bottomNavigationBar: _isCustomer
          ? const CustomerBottomBar(selectedIndex: 2)
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                SvgPicture.asset(AppAssets.logo, width: 195),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildMessages()),
                        _buildInputBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
      decoration: const BoxDecoration(
        color: _headerBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _otherUserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatOrderId(widget.orderId),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<List<MessageModel>>(
      stream: _chatService.watchMessages(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat pesan.',
              style: GoogleFonts.inter(
                color: const Color(0xFFD14343),
                fontSize: 13,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primaryBlue),
          );
        }

        final List<MessageModel> messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _headerBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: _primaryBlue,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Belum ada pesan',
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mulai percakapan dengan mengirim pesan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _textGrey, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          itemCount: messages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'Hari ini',
                    style: GoogleFonts.inter(
                      color: _textGrey,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return _buildMessageBubble(messages[index - 1]);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final bool isMine = message.senderId == widget.currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFDDEEFF) : const Color(0xFFF0F1F4),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(13),
            topRight: const Radius.circular(13),
            bottomLeft: Radius.circular(isMine ? 13 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 13),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: GoogleFonts.inter(
                color: _textDark,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            if (message.sentAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(message.sentAt),
                style: GoogleFonts.inter(color: _textGrey, fontSize: 9.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5EAF0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                _sendMessage();
              },
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.inter(color: _textDark, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF9BA5B3),
                  fontSize: 12,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    _showSnackBar('Fitur lampiran belum tersedia.');
                  },
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: _textGrey,
                    size: 21,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC5D8EE)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC5D8EE)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryBlue, width: 1.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 43,
            height: 43,
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFEAF3FF),
                foregroundColor: const Color(0xFF0066FF),
                disabledBackgroundColor: const Color(0xFFE9EDF2),
                elevation: 0,
                shape: const CircleBorder(),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryBlue,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
