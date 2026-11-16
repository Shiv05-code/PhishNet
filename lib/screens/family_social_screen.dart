import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_dialog.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_glass_button.dart';
import '../widgets/figma_gradient_background.dart';
import '../models/scan_result.dart';
import '../services/message_composer.dart';
import '../services/phone_number.dart';
import '../services/trusted_contacts_store.dart';
import 'package:share_plus/share_plus.dart';
import 'history_screen.dart';
import '../models/saved_scan.dart';
import '../services/auth_service.dart';

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
  final Future<({String name, String? phone})?> Function()? pickContact;

  /// Overrides how Messages is opened. Used by tests.
  final MessageComposer? messageComposer;

  const FamilySocialScreen({
    super.key,
    this.result,
    this.message = '',
    this.receivedAt,
    this.userId,
    this.contactsStore,
    this.pickContact,
    this.messageComposer,
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
  String? _sharedContactId;
  late final MessageComposer _composer;
  Set<String> _swapIds = {};

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.result;
    _selectedMessage = widget.message;
    _messageIsOriginal = widget.message.trim().isNotEmpty;
    _receivedAt = widget.receivedAt;

    _store = widget.contactsStore ?? TrustedContactsRepository();
    _composer = widget.messageComposer ?? ChannelMessageComposer();
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

  /// The signed-in user's first name for the share text, or null.
  String? _senderName() {
    try {
      return AuthService().firstName;
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
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(fontSize: AppTypography.emphasis),
          ),
          action: action,
        ),
      );
  }

  /// Saves [next] and shows it right away. Rolls back if the save fails.
  Future<void> _saveContacts(
    List<TrustedContact> next, {
    String? successText,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final previous = _contacts;
    setState(() => _contacts = next);

    try {
      await _store.save(uid, next);
      if (mounted && successText != null) _showSnack(successText);
    } catch (_) {
      if (!mounted) return;
      setState(() => _contacts = previous);
      _showSnack('Couldn’t save favorites. Please try again.');
    }
  }

  /// Opens the native contact sheet. Returns the picked name and first phone
  /// number. No contacts permission is needed on iOS.
  Future<({String name, String? phone})?> _pickContact() async {
    if (widget.pickContact != null) return widget.pickContact!();

    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    if (contact == null) return null;

    return (
      name: contact.displayName ?? '',
      phone: contact.phones.isEmpty ? null : contact.phones.first.number,
    );
  }

  Future<void> _addContact() async {
    ({String name, String? phone})? picked;
    try {
      picked = await _pickContact();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Contacts aren’t available on this device.');
      return;
    }
    if (!mounted || picked == null) return;

    final name = picked.name.trim();
    if (name.isEmpty) {
      _showSnack('That contact has no name to save.');
      return;
    }

    final phone = normalizePhoneNumber(picked.phone);
    if (phone == null) {
      _showSnack('That contact needs a valid phone number to message.');
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
      phone: phone,
    );
    await _saveContacts([
      ..._contacts,
      contact,
    ], successText: 'Added $shortName to favorites.');
  }

  void _moveContact(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _contacts.length) return;

    final next = [..._contacts];
    final item = next.removeAt(index);
    _swapIds = {item.id, _contacts[target].id};
    next.insert(target, item);
    _saveContacts(next);
  }

  void _removeContact(int index) {
    _swapIds = {};
    final name = _contacts[index].name;
    final next = [..._contacts]..removeAt(index);
    _saveContacts(next, successText: 'Removed $name from favorites.');
  }

  /// Asks before removing a swiped contact. Always returns false so the
  /// row is removed by the list state, not by the swipe animation.
  Future<bool> _confirmRemove(String id) async {
    final contact = _contacts.firstWhere((c) => c.id == id);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(contact.name),
        content: const Text('Would you like to remove this Contact?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final index = _contacts.indexWhere((c) => c.id == id);
      if (index != -1) _removeContact(index);
    }
    return false;
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
      _sharedContactId = null;
    });
  }

  /// Opens Messages to the contact's number with the scan filled in. The
  /// row shows as sent after the user taps Send, until the scan changes.
  Future<void> _messageContact(TrustedContact contact) async {
    final phone = contact.phone;
    if (phone == null) return;

    final body = buildFamilyShareText(
      result: _selectedResult,
      message: _selectedMessage,
      isOriginalText: _messageIsOriginal,
      senderName: _senderName(),
    );
    final result = await _composer.compose(recipient: phone, body: body);
    if (!mounted) return;

    switch (result) {
      case MessageComposeResult.sent:
        setState(() => _sharedContactId = contact.id);
        _showShareDialog('Shared with ${contact.name}.');
      case MessageComposeResult.unavailable:
        _showSnack('Messages isn’t available on this device.');
      case MessageComposeResult.failed:
        _showSnack('Couldn’t open Messages. Please try again.');
      case MessageComposeResult.cancelled:
        break;
    }
  }

  /// Centered confirmation, styled like the Delete Account dialog.
  void _showShareDialog(String text) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        icon: Icons.check_circle,
        iconColor: AppColors.accentGreen,
        title: text,
        message: 'Your scan has been shared.',
        actions: [
          AppDialogButton(
            label: 'OK',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  /// Returns true when the user picked an action in the share sheet.
  Future<bool> _shareMessage(BuildContext context) async {
    final text = buildFamilyShareText(
      result: _selectedResult,
      message: _selectedMessage,
      isOriginalText: _messageIsOriginal,
      senderName: _senderName(),
    );

    // The context may belong to a list sliver rather than a box, so check the type.
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox && renderObject.hasSize
        ? renderObject
        : null;

    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    return result.status == ShareResultStatus.success;
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
              'Up to $trustedContactsLimit favorites. Hold and drag to reorder.',
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
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: AppTypography.caption,
                      color: AppColors.muted,
                    ),
                    children: [
                      const TextSpan(text: 'You’ve reached '),
                      TextSpan(
                        text: '$trustedContactsLimit favorites',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '. Remove '),
                      const TextSpan(
                        text: 'one',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' to add another.'),
                    ],
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
                _shareMessage(context).then((shared) {
                  if (shared && mounted)
                    _showShareDialog('Shared with Family.');
                });
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

  /// Wraps the row being moved with a blue outline and a pulsing glow.
  Widget _liftDecorator(Widget child, int index, Animation<double> animation) {
    return _LiftGlow(animation: animation, child: child);
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
      proxyDecorator: _liftDecorator,
      itemCount: _contacts.length,
      onReorderItem: (oldIndex, newIndex) {
        _swapIds = {};
        final next = [..._contacts];
        final item = next.removeAt(oldIndex);
        next.insert(newIndex, item);
        _saveContacts(next);
      },
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ReorderableDelayedDragStartListener(
          key: ValueKey(contact.id),
          index: index,
          child: _SwapSlide(
            index: index,
            animate: _swapIds.contains(contact.id),
            child: Dismissible(
              key: ValueKey('dismiss-${contact.id}'),
              direction: DismissDirection.endToStart,
              background: const _DeleteBackground(),
              confirmDismiss: (_) => _confirmRemove(contact.id),
              child: _ContactRow(
                contact: contact,
                isFirst: index == 0,
                isLast: index == _contacts.length - 1,
                canMessage: hasMessage && contact.phone != null,
                showSent: _sharedContactId == contact.id,
                onMessage: () => _messageContact(contact),
                onMoveUp: () => _moveContact(index, -1),
                onMoveDown: () => _moveContact(index, 1),
              ),
            ),
          ),
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
  String? senderName,
}) {
  final text = message.trim();
  final name = senderName?.trim() ?? '';
  final lines = <String>[
    name.isEmpty
        ? 'Id like a second opinion on this message.'
        : '$name wants a second opinion on this message.',
    'Does it look safe to you? PhishNet\'s analysis is below',
    '',
    '🛡️ ${boldUnicode('PhishNet Scan Result')}',
    '',
  ];

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

const _actionBlue = Color(0xFF168BC2);

/// Slides a row from its old slot to its new slot after an arrow move.
class _SwapSlide extends StatefulWidget {
  const _SwapSlide({
    required this.index,
    required this.animate,
    required this.child,
  });

  final int index;
  final bool animate;
  final Widget child;

  @override
  State<_SwapSlide> createState() => _SwapSlideState();
}

class _SwapSlideState extends State<_SwapSlide>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  Animation<double> _dy = const AlwaysStoppedAnimation<double>(0);
  double? _top;

  double? _measure() {
    final box = _key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _top = _measure();
    });
  }

  @override
  void didUpdateWidget(_SwapSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate || oldWidget.index == widget.index) return;
    final from = _top;
    if (from == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final to = _measure();
      if (to == null) return;
      _top = to;
      final delta = from - to;
      if (delta.abs() < 0.5) return;
      _dy = Tween<double>(begin: delta, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      );
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, _dy.value), child: child),
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}

/// Blue outline with a soft pulsing glow, shown while a row is being moved.
class _LiftGlow extends StatefulWidget {
  const _LiftGlow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_LiftGlow> createState() => _LiftGlowState();
}

class _LiftGlowState extends State<_LiftGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _pulse]),
      builder: (context, child) {
        final lift = Curves.easeOut.transform(widget.animation.value);
        final pulse = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1 + 0.03 * lift,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: lift),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(
                    alpha: 0.45 * lift * (0.35 + 0.65 * pulse),
                  ),
                  blurRadius: 12 + 10 * pulse,
                  spreadRadius: 1 + 2 * pulse,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Red trash background revealed when a favorite is swiped left.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.dangerRed,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(CupertinoIcons.delete, color: Colors.white),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.isFirst,
    required this.isLast,
    required this.canMessage,
    required this.showSent,
    required this.onMessage,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final TrustedContact contact;
  final bool isFirst;
  final bool isLast;
  final bool canMessage;
  final bool showSent;
  final VoidCallback onMessage;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
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
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: canMessage ? onMessage : null,
            icon: Icon(
              showSent ? Icons.check : Icons.chat_bubble_outline,
              size: 18,
              color: showSent ? const Color(0xFF2E9E5B) : null,
            ),
            label: Text(showSent ? 'Resend' : 'Message'),
          ),
          IconButton(
            tooltip: 'Move ${contact.name} up',
            onPressed: isFirst ? null : onMoveUp,
            icon: const Icon(CupertinoIcons.chevron_up, color: _actionBlue),
          ),
          IconButton(
            tooltip: 'Move ${contact.name} down',
            onPressed: isLast ? null : onMoveDown,
            icon: const Icon(CupertinoIcons.chevron_down, color: _actionBlue),
          ),
        ],
      ),
    );
  }
}
