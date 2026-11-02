import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_welcome.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'app_colors.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.scan, this.service});

  /// The scan this chat is about (from the Results screen). Null when Chat is
  /// opened from the menu: any earlier conversation is kept.
  final ChatScanContext? scan;

  /// For tests; defaults to the shared service that keeps the conversation.
  final ChatService? service;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final ChatService _chat = widget.service ?? ChatService.instance;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _chat.openFor(widget.scan);
    _chat.addListener(_onChatChanged);
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _hint = 'Please type a question first.');
      return;
    }
    setState(() => _hint = null);
    _controller.clear();
    await _chat.ask(text);
  }

  /// Fills the input with a starter question so the user can read, edit or
  /// send it. Chips never send on their own, so a mis-tap costs nothing.
  void _usePrompt(String question) {
    _controller.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    setState(() => _hint = null);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _chat.messages;
    final hasScan = _chat.scan != null && _chat.scan!.message.isNotEmpty;
    return Scaffold(
      appBar: const FigmaAppBar(title: 'AI Chat'),
      drawer: const AppDrawer(currentPage: 'AI Chat'),
      body: FigmaGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: messages.isEmpty && !_chat.sending && !hasScan
                    ? ChatWelcome(hasScan: false, onPick: _usePrompt)
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (hasScan) _ScannedMessageBubble(scan: _chat.scan!),
                          if (hasScan && messages.isEmpty && !_chat.sending)
                            _ScanPrompt(onPick: _usePrompt),
                          for (final m in messages) _Bubble(message: m),
                          if (_chat.sending) const _Thinking(),
                        ],
                      ),
              ),
              if (_chat.error != null)
                _ErrorBanner(
                  message: _chat.error!,
                  onRetry: _chat.canRetry ? _chat.retry : null,
                ),
              _InputBar(
                controller: _controller,
                hint: _hint,
                enabled: !_chat.sending,
                onSubmit: _submit,
                onChanged: () {
                  if (_hint != null) setState(() => _hint = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    return Semantics(
      container: true,
      label: mine
          ? 'You asked: ${message.text}'
          : 'PhishNet answered: ${message.text}',
      child: ExcludeSemantics(
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            decoration: BoxDecoration(
              color: mine ? AppColors.primaryBlue : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: AppTypography.body,
                height: 1.35,
                color: mine ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'PhishNet is writing an answer',
      child: const ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Writing an answer…',
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: AppTypography.body,
                  color: AppColors.text,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Try again',
                  style: TextStyle(fontSize: AppTypography.emphasis),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onSubmit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final VoidCallback onSubmit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: AppTypography.label,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ChatService.maxQuestionLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(fontSize: AppTypography.emphasis),
                  decoration: InputDecoration(
                    labelText: 'Your question',
                    hintText: 'Type your question here',
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send question',
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  minimumSize: const Size(56, 56),
                ),
                onPressed: enabled ? onSubmit : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannedMessageBubble extends StatelessWidget {
  const _ScannedMessageBubble({required this.scan});
  final ChatScanContext scan;

  @override
  Widget build(BuildContext context) {
    final risk = scan.assessment?['risk_level'] as String?;
    final (label, color) = switch (risk) {
      'high' => ('High Risk', const Color(0xFFD64545)),
      'medium' => ('Medium Risk', const Color(0xFFE08A1E)),
      'low' => ('Low Risk', const Color(0xFF2E9E5B)),
      _ => (null, AppColors.primaryBlue),
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message you checked',
              style: TextStyle(
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scan.message,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTypography.body,
                height: 1.3,
                color: AppColors.text,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanPrompt extends StatelessWidget {
  const _ScanPrompt({required this.onPick});
  final void Function(String question) onPick;

  static const _questions = [
    'Is this a scam?',
    'Is it safe to click the link?',
    'What should I do?',
    'Who might be sending this?',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'What would you like to know about this message?',
            style: TextStyle(
              fontSize: AppTypography.body,
              height: 1.35,
              color: AppColors.text,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in _questions)
              ActionChip(
                label: Text(
                  q,
                  style: const TextStyle(
                    fontSize: AppTypography.body,
                    color: AppColors.primaryBlue,
                  ),
                ),
                backgroundColor: const Color(0xD9FDFCF9),
                onPressed: () => onPick(q),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
