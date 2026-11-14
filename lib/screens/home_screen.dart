import 'dart:async';

import 'package:flutter/material.dart';
import '../models/saved_scan.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../services/scan_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_widgets.dart';
import 'capture_screen.dart';

/// Counts derived from real scan history. Week stats use the last 7 days;
/// attention uses high-risk scans from the last 48 hours.
class _ScanSummary {
  _ScanSummary(List<SavedScan> scans, DateTime now) {
    final week = <SavedScan>[];
    final recent = <SavedScan>[];
    for (final s in scans) {
      final at = s.createdAt;
      if (at != null && (lastChecked == null || at.isAfter(lastChecked!))) {
        lastChecked = at;
      }
      final age = at == null ? null : now.difference(at);
      if (age != null && age <= const Duration(days: 7)) week.add(s);
      if (age != null &&
          age <= const Duration(hours: 48) &&
          s.result.riskLevel == 'high') {
        recent.add(s);
      }
    }
    total = week.length;
    flagged = week.where((s) => s.result.riskLevel == 'high').length;
    safe = week.where((s) => s.result.riskLevel == 'low').length;
    attention = recent;
  }

  int total = 0;
  int flagged = 0;
  int safe = 0;
  List<SavedScan> attention = const [];
  DateTime? lastChecked;

  int get scamRatePercent => total == 0 ? 0 : (flagged * 100 ~/ total);
}

String _timeAgo(DateTime? at, DateTime now) {
  if (at == null) return 'No checks yet';
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'Last checked: just now';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return 'Last checked: $m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (d.inHours < 24) {
    final h = d.inHours;
    return 'Last checked: $h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final days = d.inDays;
  return 'Last checked: $days ${days == 1 ? 'day' : 'days'} ago';
}

String _greetingForHour(int hour) {
  if (hour < 12) return 'Good morning, ';
  if (hour < 18) return 'Good afternoon, ';
  return 'Good evening, ';
}

class HomeScreen extends StatefulWidget {
  final AuthService? authService;
  final ScanService? scanService;

  const HomeScreen({super.key, this.authService, this.scanService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;
  List<SavedScan> _scans = [];

  // Inbox linking is not built yet: connecting is simulated in the demo.
  bool _inboxConnected = false;
  bool _monitoring = false;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {
    try {
      final service = widget.scanService ?? ScanService();
      final scans = await service.getScanHistory();
      if (!mounted) return;
      setState(() => _scans = scans);
    } catch (_) {
      // Keep zeros when history can't load; Home stays usable.
    }
  }

  void _toggleMonitoring() => setState(() => _monitoring = !_monitoring);

  void _connectInbox() {
    setState(() {
      _inboxConnected = true;
      _monitoring = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yahoo inbox connected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstName = (widget.authService ?? AuthService()).firstName;
    final summary = _ScanSummary(_scans, now);
    final hasScans = _scans.isNotEmpty;

    final String statusText;
    final IconData statusIcon;
    final Color statusColor;
    if (summary.attention.isNotEmpty) {
      final n = summary.attention.length;
      statusText = '$n ${n == 1 ? 'message needs' : 'messages need'} your attention';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = AppColors.dangerRed;
    } else if (!hasScans) {
      statusText = _inboxConnected
          ? 'Check a message to get started.'
          : 'Connect your inbox to start protection.';
      statusIcon = Icons.info_outline;
      statusColor = AppColors.cautionAmber;
    } else {
      statusText = 'Nothing needs your attention right now.';
      statusIcon = Icons.verified_user;
      statusColor = AppColors.accentGreen;
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: const FigmaAppBar(title: 'Home'),
      drawer: const AppDrawer(currentPage: 'Home'),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            _Reveal(
              animation: _enter,
              start: 0,
              child: _TypedGreeting(
                prefix: _greetingForHour(now.hour),
                name: firstName ?? 'there',
              ),
            ),
            const SizedBox(height: 8),
            _Reveal(
              animation: _enter,
              start: 0.1,
              child: Row(
                children: [
                  Icon(statusIcon, size: AppTypography.emphasis, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: AppTypography.label,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Reveal(
              animation: _enter,
              start: 0.2,
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(fadeRoute(const CaptureScreen())),
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Check a message',
                    style: TextStyle(fontSize: AppTypography.emphasis),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Reveal(
              animation: _enter,
              start: 0.3,
              child: _MonitoringCard(
                connected: _inboxConnected,
                monitoring: _monitoring,
                lastChecked: _timeAgo(summary.lastChecked, now),
                onToggle: _toggleMonitoring,
                onConnect: _connectInbox,
              ),
            ),
            const SizedBox(height: 16),
            if (!hasScans) ...[
              _Reveal(
                animation: _enter,
                start: 0.35,
                child: const _EmptyStateCard(),
              ),
              const SizedBox(height: 16),
            ],
            if (summary.attention.isNotEmpty) ...[
              _Reveal(
                animation: _enter,
                start: 0.35,
                child: _AttentionCard(scans: summary.attention),
              ),
              const SizedBox(height: 16),
            ],
            _Reveal(
              animation: _enter,
              start: 0.4,
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.mark_email_read,
                      value: '${summary.total}',
                      boldLabel: 'Emails',
                      restLabel: ' checked this week',
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.warning_amber_rounded,
                      value: '${summary.flagged}',
                      boldLabel: 'Possible scams',
                      restLabel: ' found',
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Reveal(
              animation: _enter,
              start: 0.5,
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      value: '${summary.safe}',
                      boldLabel: 'Safe',
                      restLabel: ' emails',
                      color: AppColors.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.shield,
                      value: '${summary.scamRatePercent}%',
                      boldLabel: 'Scam rate',
                      restLabel: ' of emails',
                      color: AppColors.cautionAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a section in. Each section gets its own slice of the
/// shared controller, so the page builds from top to bottom.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.start,
    required this.child,
  });
  final Animation<double> animation;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

/// Greeting that types itself out once, like the AI Chat welcome. The name
/// is bold; the typed text is always the full greeting.
class _TypedGreeting extends StatefulWidget {
  const _TypedGreeting({required this.prefix, required this.name});
  final String prefix;
  final String name;

  @override
  State<_TypedGreeting> createState() => _TypedGreetingState();
}

class _TypedGreetingState extends State<_TypedGreeting> {
  static const _tick = Duration(milliseconds: 45);
  Timer? _timer;
  int _shown = 0;
  bool _started = false;

  String get _full => '${widget.prefix}${widget.name}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _shown = _full.length;
    } else {
      _timer = Timer.periodic(_tick, (t) {
        setState(() => _shown++);
        if (_shown >= _full.length) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = _full;
    final shown = full.substring(0, _shown.clamp(0, full.length));
    final p = shown.length < widget.prefix.length
        ? shown
        : widget.prefix;
    final n = shown.length > widget.prefix.length
        ? shown.substring(widget.prefix.length)
        : '';
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: AppTypography.heading,
          color: AppColors.primaryBlue,
        ),
        children: [
          TextSpan(text: p),
          TextSpan(
            text: n,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(22),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300B718E),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: AppTypography.body, color: AppColors.text);
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return _SoftCard(
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates, size: 36, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: const [
                  TextSpan(text: 'Paste a message and tap '),
                  TextSpan(text: 'Check a message', style: bold),
                  TextSpan(text: ' to see if it is '),
                  TextSpan(text: 'safe', style: bold),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.connected,
    required this.monitoring,
    required this.lastChecked,
    required this.onToggle,
    required this.onConnect,
  });
  final bool connected;
  final bool monitoring;
  final String lastChecked;
  final VoidCallback onToggle;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    if (!connected) {
      title = 'Inbox not connected';
      subtitle = 'Yahoo inbox is not linked yet';
    } else if (monitoring) {
      title = 'Monitoring your inbox';
      subtitle = 'Yahoo inbox is connected';
    } else {
      title = 'Monitoring is paused';
      subtitle = 'Yahoo inbox is connected';
    }

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected && monitoring ? Icons.shield : Icons.shield_outlined,
                size: 44,
                color: connected && monitoring
                    ? AppColors.primaryBlue
                    : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppTypography.emphasis,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AppTypography.label,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (connected && monitoring) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                lastChecked,
                style: const TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: !connected
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    onPressed: onConnect,
                    icon: const Icon(Icons.link),
                    label: const Text(
                      'Connect inbox',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  )
                : monitoring
                ? OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text(
                      'Pause monitoring',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text(
                      'Resume monitoring',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.scans});
  final List<SavedScan> scans;

  @override
  Widget build(BuildContext context) {
    final shown = scans.take(3).toList();
    return _SoftCard(
      borderColor: AppColors.dangerRed.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread, color: AppColors.dangerRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${scans.length} ${scans.length == 1 ? 'message needs' : 'messages need'} your attention',
                  style: const TextStyle(
                    fontSize: AppTypography.emphasis,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in shown) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x80FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x330B718E)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${s.description}"',
                          style: const TextStyle(
                            fontSize: AppTypography.body,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.result.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTypography.caption,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Likely scam',
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.boldLabel,
    required this.restLabel,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String boldLabel;
  final String restLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.heading,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: AppTypography.label,
                color: AppColors.text,
              ),
              children: [
                TextSpan(
                  text: boldLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: restLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
