import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../models/scan_result.dart';
import 'package:share_plus/share_plus.dart';
import 'history_screen.dart';
import '../models/saved_scan.dart';

class FamilySocialScreen extends StatefulWidget {
  final ScanResult? result;
  final String message;

  const FamilySocialScreen({super.key, this.result, this.message = ''});

  @override
  State<FamilySocialScreen> createState() => _FamilySocialScreenState();
}

class _FamilySocialScreenState extends State<FamilySocialScreen> {
  ScanResult? _selectedResult;
  String _selectedMessage = '';

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.result;
    _selectedMessage = widget.message;
  }

  Future<void> _chooseMessage() async {
    final selected = await Navigator.of(context).push<SavedScan>(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          onScanSelected: (scan) {
            Navigator.of(context).pop(scan);
          },
        ),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedResult = selected.result;
      _selectedMessage = selected.description;
    });
  }

  Future<void> _shareMessage(BuildContext context, String name) async {
    final text = _selectedMessage.trim().isEmpty
        ? 'No scanned message is available.'
        : _selectedMessage.trim();

    final box = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        title: 'Share PhishNet scan',
        subject: 'Suspicious message from PhishNet',
        text: 'PhishNet flagged this message:\n\n$text',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Social'),
      drawer: const AppDrawer(currentPage: 'Family/Social'),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
          children: [
            _ScanCard(result: _selectedResult, message: _selectedMessage),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: _OutlineButton(
                label: 'Add Contact Favorites',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact favorites prototype opened.'),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            Align(
              alignment: Alignment.centerLeft,
              child: _OutlineButton(
                label: 'Switch Message',
                onPressed: _chooseMessage,
              ),
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: _OutlineButton(
                label: 'Share with Family',
                onPressed: () => _shareMessage(context, 'Family'),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Share this message with a trusted family member '
              'to help confirm PhishNet’s analysis.',
              style: TextStyle(
                fontSize: AppTypography.body,
                height: 1.35,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final ScanResult? result;
  final String message;

  const _ScanCard({this.result, this.message = ''});

  @override
  Widget build(BuildContext context) {
    final score = result?.scamPercentage ?? 85;

    final riskColor = switch (result?.riskLevel) {
      'low' => const Color(0xFF2E9E5B),
      'medium' => const Color(0xFFE08A1E),
      _ => const Color(0xFFD64545),
    };

    final riskLabel = switch (result?.riskLevel) {
      'low' => 'Low Risk',
      'medium' => 'Medium Risk',
      _ => 'High Risk',
    };
    final scanTitle = switch (result?.riskLevel) {
      'high' => 'This looks like a phishing attempt',
      'medium' => 'This message may be a scam',
      _ => 'No strong warning signs found',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 20, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.72),
        boxShadow: const [
          BoxShadow(
            color: Color(0x280B718E),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: score.clamp(0, 100) / 100,
                        strokeWidth: 9,
                        color: riskColor,
                        backgroundColor: riskColor.withValues(alpha: 0.2),
                      ),
                    ),
                    SizedBox(
                      width: 95,
                      height: 45,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$score/100',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 42),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: riskColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: AppTypography.label,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$score% likely scam',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 29, color: riskColor),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.52),
                    border: Border.all(color: const Color(0x337B9BA8)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scanTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          color: Color(0xFF159BD3),
                        ),
                      ),
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Received today, 12:52 PM',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: AppTypography.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF168BC2),
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        side: const BorderSide(color: Colors.white, width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      ),
      child: Text(label, style: const TextStyle(fontSize: AppTypography.body)),
    );
  }
}
