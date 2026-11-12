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

  static const contacts = [
    ('JF', 'Jack Feria'),
    ('DS', 'Dhara Shah'),
    ('SK', 'Shivansh Kanda'),
    ('PC', 'Payton Curry'),
    ('NC', 'Nicholas Chang'),
    ('Dr', 'Dr. Albinani'),
  ];

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
            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerLeft,
              child: _OutlineButton(
                label: 'Switch Message',
                onPressed: _chooseMessage,
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Trusted Contacts',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),

            const SizedBox(height: 12),

            for (final contact in contacts)
              _ContactRow(
                initials: contact.$1,
                name: contact.$2,
                onPressed: () => _shareMessage(context, contact.$2),
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
  @override
  Widget build(BuildContext context) {
    final score = result?.scamPercentage ?? 85;

    final riskLabel = switch (result?.riskLevel) {
      'low' => 'Low Risk',
      'medium' => 'Medium Risk',
      _ => 'High Risk',
    };

    final scanMessage = message.trim().isEmpty
    ? 'No message text is available for this saved scan.'
    : message.trim();

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
              Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF04444), width: 11),
                ),
                child: Text(
                  '$score/100',
                  style: TextStyle(fontSize: 24, color: Color(0xFFF04444)),
                ),
              ),
              const SizedBox(height: 42),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF6B6B)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: Color(0xFFFF4D4D),
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
                  style: TextStyle(fontSize: 29, color: Color(0xFFF04444)),
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
                        scanMessage,
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

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.initials,
    required this.name,
    required this.onPressed,
  });

  final String initials;
  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x66808080))),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.62),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 20, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 24, color: AppColors.text),
            ),
          ),
          _MessageButton(onPressed: onPressed),
        ],
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.chat_bubble_outline, size: 22),
      label: const Text(
        'Message',
        style: TextStyle(fontSize: AppTypography.body),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF168BC2),
        side: const BorderSide(color: Colors.white, width: 1.5),
        backgroundColor: Colors.white.withValues(alpha: 0.38),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
