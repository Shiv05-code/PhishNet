import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/figma_glass_button.dart';
import 'results_screen.dart';
import '../widgets/auth_widgets.dart';

class CaptureScreen extends StatefulWidget {
  final bool isGuest;

  const CaptureScreen({super.key, this.isGuest = false});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isReadingText = false;
  bool _isTextMode = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(source: source);

    // The user canceled the picker or camera.
    if (image == null) return;

    setState(() {
      _isReadingText = true;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await recognizer.processImage(inputImage);
      final extractedText = recognizedText.text.trim();

      if (!mounted) return;

      if (extractedText.isEmpty) {
        _showMessage('No readable text was found. Try a clearer image.');
        return;
      }

      setState(() {
        _isTextMode = true;
        _textController.text = extractedText;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: extractedText.length),
        );
      });

      _textFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;

      _showMessage('We could not read that image. Please try another one.');
    } finally {
      await recognizer.close();

      if (mounted) {
        setState(() {
          _isReadingText = false;
        });
      }
    }
  }

  void _openTextInput() {
    setState(() {
      _isTextMode = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocusNode.requestFocus();
      }
    });
  }

  Future<void> _submitTypedText() async {
    await _submitText(_textController.text);
  }

  Future<void> _submitText(String input) async {
    final text = input.trim();

    if (text.isEmpty) {
      _showMessage('Enter a message before submitting.');
      return;
    }

    if (text.length > 8000) {
      _showMessage('Your message must be 8,000 characters or fewer.');
      return;
    }

    _textFocusNode.unfocus();

    if (!mounted) return;

    Navigator.of(
      context,
    ).push(slideRoute(ResultsScreen(isGuest: widget.isGuest)));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: const FigmaAppBar(title: 'Capture'),
      drawer: AppDrawer(currentPage: 'Capture', isGuest: widget.isGuest),
      body: FigmaGradientBackground(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: 520,
                      minHeight: constraints.maxHeight,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FDFCF9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xB8FFFFFF),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x300B718E),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: [
                          Text(
                            _isTextMode ? 'Insert Text' : 'Tap to Upload',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'SFProText',
                              fontSize: AppTypography.heading,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Upload comes first.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isTextMode
                                ? FigmaGlassButton(
                                    key: const ValueKey('compact-upload'),
                                    width: double.infinity,
                                    height: 54,
                                    semanticLabel: 'Upload image',
                                    onPressed: _isReadingText
                                        ? () {}
                                        : () =>
                                              _chooseImage(ImageSource.gallery),
                                    child: const Text(
                                      'Upload Image',
                                      style: TextStyle(
                                        fontFamily: 'SFProText',
                                        fontSize: AppTypography.heading,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  )
                                : FigmaGlassUploadButton(
                                    key: const ValueKey('large-upload'),
                                    onPressed: _isReadingText
                                        ? () {}
                                        : () =>
                                              _chooseImage(ImageSource.gallery),
                                  ),
                          ),

                          const SizedBox(height: 18),

                          // Scan comes second.
                          FigmaGlassButton(
                            width: double.infinity,
                            height: 54,
                            semanticLabel: 'Scan with camera',
                            onPressed: _isReadingText
                                ? () {}
                                : () => _chooseImage(ImageSource.camera),
                            child: const Text(
                              'Scan',
                              style: TextStyle(
                                fontFamily: 'SFProText',
                                fontSize: AppTypography.heading,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Insert Text stays third.
                          FigmaGlassButton(
                            width: double.infinity,
                            height: 54,
                            semanticLabel: 'Insert text',
                            onPressed: _openTextInput,
                            child: const Text(
                              'Insert Text',
                              style: TextStyle(
                                fontFamily: 'SFProText',
                                fontSize: AppTypography.heading,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),

                          // Text box opens underneath Insert Text.
                          if (_isTextMode) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _textController,
                              focusNode: _textFocusNode,
                              minLines: 5,
                              maxLines: 10,
                              maxLength: 8000,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitTypedText(),
                              onTapOutside: (_) => _textFocusNode.unfocus(),
                              decoration: const InputDecoration(
                                hintText: 'Type or paste a suspicious message',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white70,
                              ),
                            ),
                          ],

                          if (_isReadingText) ...[
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            const Text('Reading text from image...'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
