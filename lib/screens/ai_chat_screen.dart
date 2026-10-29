import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import '../services/chat_service.dart';
import '../services/image_text_reader.dart';
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
  final _picker = ImagePicker();
  late final ChatService _chat = widget.service ?? ChatService.instance;
  String? _hint;

  /// A photo chosen or pasted but not sent yet.
  String? _pendingImage;

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
    final image = _pendingImage;
    if (text.trim().isEmpty && image == null) {
      setState(() => _hint = 'Please type a question first.');
      return;
    }
    setState(() {
      _hint = null;
      _pendingImage = null;
    });
    if (image != null) {
      await _chat.sendImage(image);
      if (_chat.error != null) {
        // Keep the photo and the typed text so the user can try again.
        if (mounted) setState(() => _pendingImage = image);
        return;
      }
    }
    if (text.trim().isNotEmpty) {
      _controller.clear();
      await _chat.ask(text);
    }
  }

  /// The + button: choose where the photo comes from, like Messages.
  Future<void> _showAttachMenu() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(
                'Photo Library',
                style: TextStyle(fontSize: AppTypography.emphasis),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(
                'Take Photo',
                style: TextStyle(fontSize: AppTypography.emphasis),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final messages = _chat.messages;
    return Scaffold(
      appBar: const FigmaAppBar(title: 'AI Chat'),
      drawer: const AppDrawer(currentPage: 'AI Chat'),
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
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
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
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final image = message.imagePath;
    return Semantics(
      container: true,
      label: image != null
          ? 'You attached a photo'
          : mine
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
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(image),
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Text(
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
