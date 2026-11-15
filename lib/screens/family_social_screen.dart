import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_glass_button.dart';
import '../widgets/figma_gradient_background.dart';
import '../models/scan_result.dart';
import '../services/trusted_contacts_store.dart';
import 'package:share_plus/share_plus.dart';
import 'history_screen.dart';
import '../models/saved_scan.dart';

class FamilySocialScreen extends StatefulWidget {
  final ScanResult? result;

  /// The original message text when it came from a live scan. Empty when the
  /// screen was opened from History, which stores only a summary.
  final String message;

  /// When the selected message was received. Null when unknown.
  final DateTime? receivedAt;

  /// Overrides the signed-in user. Used by tests.
  final String? userId;

  /// Overrides the favorites store. Used by tests.
  final TrustedContactsStore? contactsStore;

  /// Overrides the native contact picker. Used by tests. Returns a display
  /// name, or null if the user cancelled.
  final Future<String?> Function()? pickContact;

  const FamilySocialScreen({
    super.key,
    this.result,
    this.message = '',
    this.receivedAt,
    this.userId,
    this.contactsStore,
    this.pickContact,
  });

  @override
  State<FamilySocialScreen> createState() => _FamilySocialScreenState();
}

class _FamilySocialScreenState extends State<FamilySocialScreen> {
  ScanResult? _selectedResult;
  String _selectedMessage = '';
  bool _messageIsOriginal = false;
  DateTime? _receivedAt;

  late final TrustedContactsStore _store;
  late final String? _uid;
  List<TrustedContact> _contacts = const [];
  bool _contactsLoading = true;
  bool _contactsFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.result;
    _selectedMessage = widget.message;
    _messageIsOriginal = widget.message.trim().isNotEmpty;
    _receivedAt = widget.receivedAt;

    _store = widget.contactsStore ?? TrustedContactsRepository();
    _uid = widget.userId ?? _currentUserId();
    _loadContacts();
  }

  /// Returns the signed-in user's ID, or null if auth is unavailable.
  String? _currentUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadContacts() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _contactsLoading = false);
      return;
    }

    setState(() {
      _contactsLoading = true;
      _contactsFailed = false;
    });

    try {
      final contacts = await _store.load(uid);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _contactsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contactsLoading = false;
        _contactsFailed = true;
      });
    }
  }

  void _showSnack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  /// Saves [next] and shows it right away. Rolls back if the save fails.
  Future<void> _saveContacts(List<TrustedContact> next) async {
    final uid = _uid;
    if (uid == null) return;

    final previous = _contacts;
    setState(() => _contacts = next);

    try {
      await _store.save(uid, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _contacts = previous);
      _showSnack('Couldn’t save favorites. Please try again.');
    }
  }

  /// Opens the native iOS/Android contact sheet. Only the picked contact's
  /// name is returned, so no contacts permission is needed.
  Future<String?> _pickContactName() async {
    if (widget.pickContact != null) return widget.pickContact!();

    final contact = await FlutterContacts.native.showPicker();
    return contact?.displayName;
  }

  Future<void> _addContact() async {
    final String? picked;
    try {
      picked = await _pickContactName();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Contacts aren’t available on this device.');
      return;
    }
    if (!mounted || picked == null) return;

    final name = picked.trim();
    if (name.isEmpty) {
      _showSnack('That contact has no name to save.');
      return;
    }

    final shortName = name.length > trustedContactNameMaxLength
        ? name.substring(0, trustedContactNameMaxLength)
        : name;

    final duplicate = _contacts.any(
      (contact) => contact.name.toLowerCase() == shortName.toLowerCase(),
    );
    if (duplicate) {
      _showSnack('That person is already in favorites.');
      return;
    }

    final contact = TrustedContact(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: shortName,
    );
    await _saveContacts([..._contacts, contact]);
  }

  void _moveContact(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _contacts.length) return;

    final next = [..._contacts];
    final item = next.removeAt(index);
    next.insert(target, item);
    _saveContacts(next);
  }

  void _removeContact(int index) {
    final removed = _contacts[index];
    final next = [..._contacts]..removeAt(index);
    _saveContacts(next);

    _showSnack(
      'Removed ${removed.name}.',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          final restored = [..._contacts]
            ..insert(index.clamp(0, _contacts.length), removed);
          _saveContacts(restored);
        },
      ),
    );
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
      _messageIsOriginal = false;
      _receivedAt = selected.createdAt;
    });
  }

  Future<void> _shareMessage(BuildContext context) async {
    final text = buildFamilyShareText(
      result: _selectedResult,
      message: _selectedMessage,
      isOriginalText: _messageIsOriginal,
    );

    final box = context.findRenderObject() as RenderBox?;

    // Attach the logo when it loads. Text is still shared if it doesn't.
    final files = <XFile>[];
    try {
      final data = await rootBundle.load(
        'assets/images/phishnet_share_logo.png',
      );
      files.add(
        XFile.fromData(
          data.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'phishnet_share_logo.png',
        ),
      );
    } catch (_) {}

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: files,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage = _selectedMessage.trim().isNotEmpty;
    final favoritesFull = _contacts.length >= trustedContactsLimit;

    return Scaffold(
      appBar: const FigmaAppBar(title: 'Social'),
      drawer: const AppDrawer(currentPage: 'Family/Social'),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
          children: [
            _ScanCard(
              result: _selectedResult,
              message: _selectedMessage,
              receivedAt: _receivedAt,
            ),
            const SizedBox(height: 16),

            FigmaGlassButton(
              onPressed: _chooseMessage,
              child: const _GlassLabel(
                icon: Icons.swap_horiz_rounded,
                text: 'Switch Message',
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Trusted Contacts',
              style: TextStyle(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Up to $trustedContactsLimit favorites. Drag to reorder.',
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),

            _buildContacts(hasMessage),

            if (_uid != null && !_contactsLoading && !_contactsFailed) ...[
              const SizedBox(height: 12),
              if (favoritesFull)
                const Text(
                  'You’ve reached $trustedContactsLimit favorites. '
                  'Remove one to add another.',
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.muted,
                  ),
                )
              else
                FigmaGlassButton(
                  onPressed: _addContact,
                  child: const _GlassLabel(
                    icon: Icons.person_add_alt_1_rounded,
                    text: 'Add favorite',
                  ),
                ),
            ],

            const SizedBox(height: 28),

            _PrimaryButton(
              icon: Icons.ios_share_rounded,
              label: 'Share with Family',
              onPressed: () {
                if (!hasMessage) {
                  _showSnack('Select a scanned message to share.');
                  return;
                }
                _shareMessage(context);
              },
            ),

            const SizedBox(height: 14),

            const _InfoCard(
              text: TextSpan(
                children: [
                  TextSpan(text: 'Share this message with a '),
                  TextSpan(
                    text: 'trusted family member',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' to help '),
                  TextSpan(
                    text: 'confirm',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' PhishNet’s analysis.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContacts(bool hasMessage) {
    if (_uid == null) {
      return const _StatusCard(text: 'Sign in to save your favorites.');
    }

    if (_contactsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_contactsFailed) {
      return _StatusCard(
        text: 'Couldn’t load your favorites.',
        actionLabel: 'Try again',
        onAction: _loadContacts,
      );
    }

    if (_contacts.isEmpty) {
      return const _StatusCard(
        text: 'No favorites yet. Add people you trust to share scans with.',
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _contacts.length,
      onReorderItem: (oldIndex, newIndex) {
        final next = [..._contacts];
        final item = next.removeAt(oldIndex);
        next.insert(newIndex, item);
        _saveContacts(next);
      },
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return _ContactRow(
          key: ValueKey(contact.id),
          index: index,
          contact: contact,
          isFirst: index == 0,
          isLast: index == _contacts.length - 1,
          canMessage: hasMessage,
          onMessage: () => _shareMessage(context),
          onMoveUp: () => _moveContact(index, -1),
          onMoveDown: () => _moveContact(index, 1),
          onRemove: () => _removeContact(index),
        );
      },
    );
  }
}

/// Defangs web addresses so messaging apps don't turn them into tappable
/// links. "citibank-verification.com" becomes "citibank-verification[.]com".
String defangLinks(String text) {
  final pattern = RegExp(
    r'(https?://)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,24}(?:/[^\s]*)?',
  );
  return text.replaceAllMapped(pattern, (match) {
    var link = match.group(0)!;
    link = link.replaceAllMapped(
      RegExp(r'^https?', caseSensitive: false),
      (m) => m.group(0)!.toLowerCase().replaceFirst('http', 'hxxp'),
    );
    link = link.replaceAll('://', '[://]');
    final scheme = link.indexOf('[://]');
    final head = scheme == -1 ? '' : link.substring(0, scheme + 5);
    final rest = scheme == -1 ? link : link.substring(scheme + 5);
    return head + rest.replaceAll('.', '[.]');
  });
}

/// Converts ASCII letters to Unicode bold letters. Shared text can't carry
/// formatting, so this is the only way to get bold text into a message.
String boldUnicode(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x41 && rune <= 0x5A) {
      buffer.writeCharCode(0x1D400 + (rune - 0x41));
    } else if (rune >= 0x61 && rune <= 0x7A) {
      buffer.writeCharCode(0x1D41A + (rune - 0x61));
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Builds the text shared with family: a status icon, PhishNet's verdict and
/// details, then the message. Live scans show the original message; History
/// scans show a summary.
String buildFamilyShareText({
  ScanResult? result,
  required String message,
  required bool isOriginalText,
}) {
  final text = message.trim();
  final lines = <String>['🛡️ ${boldUnicode('PhishNet Scan Result')}', ''];

  if (result == null) {
    lines.add('❔ ${boldUnicode('NOT SCORED')}');
    lines.add('PhishNet has not scored this message.');
  } else {
    final (icon, headline) = switch (result.riskLevel) {
      'low' => ('✅', 'LOW RISK'),
      'medium' => ('⚠️', 'MEDIUM RISK'),
      'high' => ('🚨', 'HIGH RISK'),
      _ => ('❔', 'NOT RATED'),
    };
    final score = result.scamPercentage;
    lines.add(
      score == null
          ? '$icon ${boldUnicode(headline)}'
          : '$icon ${boldUnicode(headline)} · $score/100 likely scam',
    );

    final verdict = switch (result.riskLevel) {
      'low' => 'PhishNet found no strong warning signs in this message.',
      'medium' => 'PhishNet thinks this message may be a scam.',
      'high' => 'PhishNet thinks this looks like a phishing attempt.',
      _ => 'PhishNet could not rate this message.',
    };
    lines.add(verdict);

    final summary = result.summary.trim();
    if (summary.isNotEmpty) {
      lines.add('');
      lines.add(summary);
    }

    final flags = result.redFlags.where((f) => f.trim().isNotEmpty).toList();
    if (flags.isNotEmpty) {
      lines.add('');
      lines.add('⚠️ ${boldUnicode('Warning Signs:')}');
      lines.addAll(flags.map((f) => '• ${f.trim()}'));
    }
  }

  if (text.isNotEmpty) {
    lines.add('');
    if (isOriginalText) {
      lines.add('💬 ${boldUnicode('Message:')}');
      lines.add('"$text"');
    } else {
      lines.add('📝 ${boldUnicode('Summary:')}');
      lines.add(text);
    }
  }

  lines.add('');
  lines.add('Shared from PhishNet.');
  return defangLinks(lines.join('\n'));
}

String formatReceivedAt(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';

  return '$month/$day/${local.year} · $hour:$minute $period';
}

String contactInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

class _ScanCard extends StatelessWidget {
  final ScanResult? result;
  final String message;
  final DateTime? receivedAt;

  const _ScanCard({this.result, this.message = '', this.receivedAt});

  /// Up to three non-empty reason labels from the scan. Empty when unknown.
  List<String> get flagLabels => (result?.redFlagLabels ?? const <String>[])
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .take(3)
      .toList();

  @override
  Widget build(BuildContext context) {
    final hasMessage = message.trim().isNotEmpty;

    if (result == null && !hasMessage) {
      return const _StatusCard(
        text: 'No scan selected. Choose a message to see its risk score.',
      );
    }

    final score = result?.scamPercentage;
    final riskColor = switch (result?.riskLevel) {
      'low' => const Color(0xFF2E9E5B),
      'medium' => const Color(0xFFE08A1E),
      'high' => const Color(0xFFD64545),
      _ => AppColors.muted,
    };

    final riskLabel = switch (result?.riskLevel) {
      'low' => 'Low Risk',
      'medium' => 'Medium Risk',
      'high' => 'High Risk',
      _ => 'Not scored',
    };
    final scanTitle = switch (result?.riskLevel) {
      'high' => 'This looks like a phishing attempt',
      'medium' => 'This message may be a scam',
      'low' => 'No strong warning signs found',
      _ => 'Scan details unavailable',
    };

    final clampedScore = score?.clamp(0, 100);
    final headline = score == null
        ? 'Score unavailable'
        : '$score% likely scam';
    final dateLabel = receivedAt == null
        ? 'Date unavailable'
        : 'Received ${formatReceivedAt(receivedAt!)}';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Semantics(
                    label: score == null
                        ? 'Risk score unavailable'
                        : 'Risk score $score out of 100',
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: (clampedScore ?? 0) / 100,
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
                                score == null ? '--/100' : '$score/100',
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
                      headline,
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
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.2,
                              color: Color(0xFF159BD3),
                            ),
                          ),
                          if (hasMessage) ...[
                            const SizedBox(height: 10),
                            Text(
                              '“${message.trim()}”',
                              textAlign: TextAlign.center,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppTypography.caption,
                                height: 1.3,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              dateLabel,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: AppTypography.caption,
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
          if (flagLabels.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FlagReasons(labels: flagLabels),
          ],
        ],
      ),
    );
  }
}

/// "PhishNet has flagged this message:" with the top few reasons as chips.
class _FlagReasons extends StatelessWidget {
  const _FlagReasons({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PhishNet has flagged this message:',
          style: TextStyle(
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.w600,
            color: AppColors.cautionAmber,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in labels)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: AppColors.dangerRed.withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Prominent filled button for the main action on this screen.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: AppTypography.emphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Soft card with an icon and text, matching the Home tip card.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final InlineSpan text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.72),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tips_and_updates,
            size: 32,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: AppTypography.body,
                  height: 1.35,
                  color: AppColors.text,
                ),
                children: [text],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple card for empty, loading, and error states.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.72),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: AppTypography.body,
              height: 1.35,
              color: AppColors.text,
            ),
          ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
        ],
      ),
    );
  }
}

/// Label with an icon, used inside [FigmaGlassButton].
class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF168BC2)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
              color: Color(0xFF168BC2),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ContactMenuAction { moveUp, moveDown, remove }

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.index,
    required this.contact,
    required this.isFirst,
    required this.isLast,
    required this.canMessage,
    required this.onMessage,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final TrustedContact contact;
  final bool isFirst;
  final bool isLast;
  final bool canMessage;
  final VoidCallback onMessage;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.drag_indicator, color: AppColors.muted),
            ),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              contactInitials(contact.name),
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTypography.emphasis,
                color: AppColors.text,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: canMessage ? onMessage : null,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Message'),
          ),
          PopupMenuButton<_ContactMenuAction>(
            tooltip: 'More options for ${contact.name}',
            onSelected: (action) {
              switch (action) {
                case _ContactMenuAction.moveUp:
                  onMoveUp();
                case _ContactMenuAction.moveDown:
                  onMoveDown();
                case _ContactMenuAction.remove:
                  onRemove();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ContactMenuAction.moveUp,
                enabled: !isFirst,
                child: const Text('Move up'),
              ),
              PopupMenuItem(
                value: _ContactMenuAction.moveDown,
                enabled: !isLast,
                child: const Text('Move down'),
              ),
              const PopupMenuItem(
                value: _ContactMenuAction.remove,
                child: Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
