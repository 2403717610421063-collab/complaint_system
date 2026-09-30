import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String complaintId;
  final String complaintTitle;

  const ChatScreen({
    super.key,
    required this.complaintId,
    required this.complaintTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────────────────
  static const _purple      = Color(0xFF7B2FBE);
  static const _purpleDark  = Color(0xFF4A1680);
  static const _purpleDeep  = Color(0xFF2D0E5E);
  static const _purpleLight = Color(0xFFF3E8FF);
  static const _purpleBorder = Color(0xFFE9D8FD);
  static const _bg          = Color(0xFFF3F0FA);

  final TextEditingController _messageCtrl  = TextEditingController();
  final ScrollController       _scrollCtrl  = ScrollController();
  final FocusNode              _focusNode   = FocusNode();

  late String _currentUserId;
  String _userRole = 'user';
  bool   _isSending = false;
  bool   _isTyping  = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _getUserRole();
    ChatService.markAllAsRead(widget.complaintId);

    _messageCtrl.addListener(() {
      final typing = _messageCtrl.text.trim().isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });
  }

  Future<void> _getUserRole() async {
    setState(() => _userRole = 'user');
  }

  // ─── Send ────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageCtrl.clear();
    setState(() => _isTyping = false);

    await ChatService.sendMessage(
      complaintId: widget.complaintId,
      message: text,
      senderRole: _userRole,
    );

    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Long press options ───────────────────────────────────────────────────────

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2))),
          // Message preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _purpleLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _purpleBorder),
            ),
            child: Text(message.message,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(fontSize: 13,
                    color: _purpleDark, fontWeight: FontWeight.w500)),
          ),
          _optionTile(
            icon: Icons.copy_rounded,
            label: 'Copy Message',
            color: _purple,
            bg: _purpleLight,
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.message));
              Navigator.pop(context);
              _snack('Message copied');
            },
          ),
          const SizedBox(height: 10),
          _optionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Message',
            color: const Color(0xFFEF4444),
            bg: const Color(0xFFFEF2F2),
            onTap: () {
              ChatService.deleteMessage(widget.complaintId, message.id);
              Navigator.pop(context);
              _snack('Message deleted');
            },
          ),
        ]),
      ),
    );
  }

  Widget _optionTile({required IconData icon, required String label,
    required Color color, required Color bg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      body: Column(children: [
        // ── HEADER ────────────────────────────────────────────────────────
        _buildHeader(),

        // ── MESSAGES ──────────────────────────────────────────────────────
        Expanded(child: _buildMessageList()),

        // ── INPUT ─────────────────────────────────────────────────────────
        _buildInputBar(),
      ]),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_purple, _purpleDark, _purpleDeep],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(children: [
        Positioned(top: -15, right: -20,
            child: Container(width: 130, height: 130,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
        Positioned(bottom: 5, right: 60,
            child: Container(width: 60, height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: const Color(0xFFB06AFF).withOpacity(0.18)))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 15),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.35), width: 2),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              // Title + ID
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.complaintTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('ID: ${widget.complaintId}',
                      style: GoogleFonts.nunito(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ])),
              // Online indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Active', style: GoogleFonts.nunito(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Message List ─────────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: ChatService.getMessages(widget.complaintId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_purple),
              strokeWidth: 2.5,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final messages = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg.senderId == _currentUserId;
            final showDate = index == 0 ||
                !_isSameDay(messages[index - 1].timestamp, msg.timestamp);
            return Column(children: [
              if (showDate) _buildDateDivider(msg.timestamp),
              _buildBubble(msg, isMe),
            ]);
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateDivider(DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) label = 'Today';
    else if (d == today.subtract(const Duration(days: 1))) label = 'Yesterday';
    else label = DateFormat('dd MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: _purpleBorder.withOpacity(0.6))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _purpleLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purpleBorder),
            ),
            child: Text(label, style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w700, color: _purple)),
          ),
        ),
        Expanded(child: Divider(color: _purpleBorder.withOpacity(0.6))),
      ]),
    );
  }

  // ─── Message Bubble ───────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name + role
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 4, right: isMe ? 4 : 0, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: _purpleLight, shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent_rounded,
                          color: _purple, size: 12),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    '${message.senderName} · ${message.senderRole}',
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Bubble
            GestureDetector(
              onLongPress: isMe ? () => _showMessageOptions(message) : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                      colors: [_purple, _purpleDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? _purple.withOpacity(0.3)
                            : const Color(0xFF4A1680).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isMe
                        ? null
                        : Border.all(color: _purpleBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.message,
                          style: GoogleFonts.nunito(
                            color: isMe ? Colors.white : const Color(0xFF1E0A3C),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          )),
                      const SizedBox(height: 5),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          DateFormat('HH:mm').format(message.timestamp),
                          style: GoogleFonts.nunito(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withOpacity(0.65)
                                  : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 5),
                          Icon(
                            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 13,
                            color: message.isRead
                                ? const Color(0xFF93C5FD)
                                : Colors.white.withOpacity(0.6),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: _purpleLight, shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 44, color: _purple),
        ),
        const SizedBox(height: 18),
        Text('No messages yet', style: GoogleFonts.spaceGrotesk(
            fontSize: 17, fontWeight: FontWeight.w700,
            color: const Color(0xFF1E0A3C))),
        const SizedBox(height: 6),
        Text('Start the conversation below',
            style: GoogleFonts.nunito(fontSize: 13,
                color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _purpleLight, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _purpleBorder),
          ),
          child: Text('ID: ${widget.complaintId}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _purple)),
        ),
      ]),
    );
  }

  // ─── Input Bar ───────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1680).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16, right: 12, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isTyping ? _purple : _purpleBorder,
                width: _isTyping ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E0A3C)),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.nunito(
                        fontSize: 14, color: const Color(0xFFB0A8C8),
                        fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              // Attachment icon (stub)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 8),
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _purpleLight, borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.attach_file_rounded,
                        color: _purple, size: 16),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Send button
        GestureDetector(
          onTap: _sendMessage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: _isTyping
                  ? const LinearGradient(
                  colors: [_purple, _purpleDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: _isTyping ? null : const Color(0xFFE9D8FD),
              shape: BoxShape.circle,
              boxShadow: _isTyping
                  ? [BoxShadow(
                  color: _purple.withOpacity(0.4),
                  blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: _isSending
                ? const Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white))))
                : Icon(Icons.send_rounded,
                color: _isTyping ? Colors.white : _purple, size: 20),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}