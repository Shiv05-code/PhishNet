import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../services/chat_service.dart';
import '../services/image_text_reader.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_rich_text.dart';
import '../widgets/chat_thinking.dart';
import '../widgets/chat_typewriter.dart';
import '../widgets/chat_welcome.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'app_colors.dart';
import '../widgets/recent_chats_drawer.dart';

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

/// Starter follow-ups shown under the newest answer. They fill the input and
/// never send on their own, like the welcome starters.
const _followUps = [
  'What should I do next?',
  'Is it safe to click links?',
  'How do I report this?',
];

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _picker = ImagePicker();
  late final ChatService _chat = widget.service ?? ChatService.instance;
  String? _hint;

  /// A photo chosen or pasted but not sent yet.
  String? _pendingImage;

  /// Answers still being typed out. Only answers that arrive while this
  /// screen is open are typed; earlier ones appear in full.
  final Set<ChatMessage> _typing = {};

  /// Answers the user asked to show in full right away.
  final Set<ChatMessage> _skip = {};

  /// How many messages have been looked at, so new ones are noticed once.
  int _seen = 0;

  /// False while the user has scrolled up, so typing does not pull them down.
  bool _autoFollow = true;

  @override
  void initState() {
    super.initState();
    _chat.openFor(widget.scan);
    _seen = _chat.messages.length;
    _chat.addListener(_onChatChanged);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _chat.removeListener(_onChatChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (!mounted) return;
    final messages = _chat.messages;
    if (messages.length < _seen) {
      // The conversation was cleared or replaced.
      _seen = messages.length;
      _typing.clear();
      _skip.clear();
    }
    for (final m in messages.skip(_seen)) {
      if (!m.fromUser && m.imagePath == null) _typing.add(m);
    }
    _seen = messages.length;
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
    final image = _pendingImage;
    if (text.trim().isEmpty && image == null) {
      setState(() => _hint = 'Please type a question first.');
      return;
    }
    setState(() {
      _hint = null;
      _pendingImage = null;
      _autoFollow = true;
    });
    if (image != null) {
      // The photo and any typed question go together, as one message.
      final sent = await _chat.sendImage(
        image,
        question: text.trim().isEmpty ? null : text,
      );
      if (!sent) {
        if (_chat.canRetry) {
          // The question is already in the chat; "Try again" resends it.
          _controller.clear();
        } else if (mounted) {
          // The scan failed: give the photo back so it can be sent again.
          setState(() => _pendingImage = image);
        }
        return;
      }
      _controller.clear();
      return;
    }
    if (text.trim().isNotEmpty) {
      _controller.clear();
      await _chat.ask(text);
    }
  }

  /// Follows the newest text only while the user is at the bottom. Scrolling
  /// up pauses it, so the user can read earlier messages while answers type.
  void _onScroll() {
    if (_scroll.hasClients) {
      _autoFollow = _scroll.position.extentAfter < 24;
    }
  }

  /// Keeps the view at the newest text while an answer types out, if
  /// [_onScroll] says the user is still at the bottom.
  void _followEnd() {
    if (!_autoFollow || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _onTyped(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      _typing.remove(message);
      _skip.remove(message);
    });
  }

  void _showAll(ChatMessage message) => setState(() => _skip.add(message));

  Future<void> _copy(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Copied',
            style: TextStyle(fontSize: AppTypography.label),
          ),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// The + button: choose where the photo comes from, like Messages.
  Future<void> _showAttachMenu() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'Add a photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.title,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              _AttachOption(
                icon: Icons.photo_library_outlined,
                title: 'Choose from Camera Roll',
                subtitle: 'Pick a screenshot or photo you already have',
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              _AttachOption(
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                subtitle: 'Use the camera to photograph a message now',
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null || !mounted) return;
      setState(() {
        _pendingImage = picked.path;
        _hint = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _hint = 'We couldn\'t open your photos. Please try again.',
      );
    }
  }

  /// Reads an image from the clipboard (long-press the input > Paste Image).
  Future<void> _pasteImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        setState(() => _hint = 'There is no image on the clipboard.');
        return;
      }
      final path = await saveTempImage(bytes);
      if (!mounted) return;
      setState(() {
        _pendingImage = path;
        _hint = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _hint = 'We couldn\'t paste that image. Please try again.',
      );
    }
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

  /// Follow-ups appear once the newest answer is fully on screen, and not
  /// while something is being sent or an error is showing.
  bool _showFollowUps(List<ChatMessage> messages) {
    if (_chat.sending || _chat.error != null || messages.isEmpty) return false;
    final last = messages.last;
    return !last.fromUser && last.imagePath == null && !_typing.contains(last);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _chat.messages;

    return Scaffold(
      key: _scaffoldKey,
      appBar: FigmaAppBar(
        title: 'AI Chat',
        showChatHistoryButton: true,
        onChatHistoryPressed: () {
          _scaffoldKey.currentState?.openEndDrawer();
        },
      ),
      drawer: const AppDrawer(currentPage: 'AI Chat'),

      endDrawer: RecentChatsDrawer(
        conversations: _chat.conversations,
        activeConversationId: _chat.activeConversationId,
        onNewChat: () {
          if (!_chat.startNewChat()) return;

          Navigator.of(context).pop();
          _controller.clear();
        },
        onOpenChat: (id) {
          if (!_chat.openConversation(id)) return;

          Navigator.of(context).pop();
          _controller.clear();
        },
      ),

      body: FigmaGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: messages.isEmpty && !_chat.sending
                    ? ChatWelcome(
                        hasScan: _chat.scan != null,
                        onPick: _usePrompt,
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        // Builds only the bubbles on screen, not every message.
                        itemCount:
                            messages.length +
                            (_chat.sending ? 1 : 0) +
                            (_showFollowUps(messages) ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < messages.length) {
                            final m = messages[index];
                            return _Bubble(
                              key: ObjectKey(m),
                              message: m,
                              typing: _typing.contains(m),
                              skip: _skip.contains(m),
                              onTyped: () => _onTyped(m),
                              onProgress: _followEnd,
                              onShowAll: () => _showAll(m),
                              onCopy: () => _copy(m),
                            );
                          }
                          if (_chat.sending && index == messages.length) {
                            return const ChatThinking();
                          }
                          return _FollowUps(onPick: _usePrompt);
                        },
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
                pendingImage: _pendingImage,
                onAttach: _showAttachMenu,
                onPasteImage: _pasteImage,
                onRemoveImage: () => setState(() => _pendingImage = null),
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
  const _Bubble({
    super.key,
    required this.message,
    required this.typing,
    required this.skip,
    required this.onTyped,
    required this.onProgress,
    required this.onShowAll,
    required this.onCopy,
  });

  final ChatMessage message;
  final bool typing;
  final bool skip;
  final VoidCallback onTyped;
  final VoidCallback onProgress;
  final VoidCallback onShowAll;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final image = message.imagePath;
    final answerLabel = _verdictLabel(message.riskLevel);
    final bubble = Semantics(
      container: true,
      label: image != null
          ? message.text == ChatService.photoText
                ? 'You attached a photo'
                : 'You attached a photo and asked: ${message.text}'
          : mine
          ? 'You asked: ${message.text}'
          : answerLabel == null
          ? 'PhishNet answered: ${message.text}'
          : 'PhishNet answered: $answerLabel. ${message.text}',
      child: ExcludeSemantics(
        child: Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(bottom: mine ? 12 : 4),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            decoration: BoxDecoration(
              color: mine ? AppColors.primaryBlue : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: image != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(image),
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      if (message.text != ChatService.photoText) ...[
                        const SizedBox(height: 10),
                        Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: AppTypography.body,
                            height: 1.35,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.riskLevel != null)
                        _VerdictStrip(riskLevel: message.riskLevel!),
                      if (mine)
                        Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: AppTypography.body,
                            height: 1.35,
                            color: Colors.white,
                          ),
                        )
                      else if (typing)
                        ChatTypewriter(
                          text: message.text,
                          color: AppColors.text,
                          skip: skip,
                          onDone: onTyped,
                          onProgress: onProgress,
                        )
                      else
                        ChatRichText(text: message.text, color: AppColors.text),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (mine || image != null) return bubble;
    // Actions sit outside the excluded bubble so screen readers can reach them.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: typing
              ? TextButton.icon(
                  onPressed: onShowAll,
                  icon: const Icon(Icons.fast_forward_rounded, size: 20),
                  label: const Text(
                    'Show all',
                    style: TextStyle(fontSize: AppTypography.label),
                  ),
                )
              : TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  label: const Text(
                    'Copy answer',
                    style: TextStyle(fontSize: AppTypography.label),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Plain-language label for a scan's risk level, or null for chat answers.
String? _verdictLabel(String? riskLevel) => switch (riskLevel) {
  'high' => 'High risk. Do not click links or reply.',
  'medium' => 'Medium risk. Check before you act.',
  'low' => 'Low risk. Stay cautious.',
  _ => null,
};

/// A colored, icon-and-text banner that states the scan's verdict. Color is
/// never the only signal: the icon and words carry the meaning too.
class _VerdictStrip extends StatelessWidget {
  const _VerdictStrip({required this.riskLevel});
  final String riskLevel;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (riskLevel) {
      'high' => (AppColors.dangerRed, Icons.gpp_bad_outlined),
      'medium' => (AppColors.cautionAmber, Icons.report_problem_outlined),
      _ => (AppColors.accentGreen, Icons.verified_user_outlined),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _verdictLabel(riskLevel)!,
              style: const TextStyle(
                fontSize: AppTypography.label,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable starter follow-ups under the newest answer.
class _FollowUps extends StatelessWidget {
  const _FollowUps({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final question in _followUps)
            ActionChip(
              label: Text(
                question,
                style: const TextStyle(fontSize: AppTypography.label),
              ),
              backgroundColor: AppColors.cardSurface,
              side: const BorderSide(color: AppColors.primaryBlue),
              onPressed: () => onPick(question),
            ),
        ],
      ),
    );
  }
}

/// One large, labeled choice in the + menu: an icon, a title and a short
/// explanation, with a tall tap target.
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fieldFill, width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryBlue,
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppTypography.emphasis,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AppTypography.label,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
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
    required this.pendingImage,
    required this.onAttach,
    required this.onPasteImage,
    required this.onRemoveImage,
    required this.onSubmit,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final String? pendingImage;
  final VoidCallback onAttach;
  final VoidCallback onPasteImage;
  final VoidCallback onRemoveImage;
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
          if (pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(pendingImage!),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      semanticLabel: 'Photo ready to send',
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      tooltip: 'Remove photo',
                      iconSize: 18,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(32, 32),
                      ),
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filled(
                tooltip: 'Add a photo',
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.fieldFill,
                  foregroundColor: AppColors.primaryBlue,
                  minimumSize: const Size(56, 56),
                ),
                onPressed: enabled ? onAttach : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  contextMenuBuilder: (context, editableTextState) =>
                      AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: [
                          ...editableTextState.contextMenuButtonItems,
                          ContextMenuButtonItem(
                            label: 'Paste Image',
                            onPressed: () {
                              editableTextState.hideToolbar();
                              onPasteImage();
                            },
                          ),
                        ],
                      ),
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
                    hintText: 'Ask me anything…',
                    hintStyle: const TextStyle(
                      fontSize: AppTypography.emphasis,
                      color: AppColors.muted,
                    ),
                    filled: true,
                    fillColor: AppColors.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
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
