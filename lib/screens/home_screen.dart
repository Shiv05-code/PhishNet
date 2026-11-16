import 'dart:async';

import 'package:flutter/material.dart';
import '../models/home_stats.dart';
import '../models/saved_scan.dart';
import '../models/scan_result.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../services/home_stats_cache.dart';
import '../services/monitoring_prefs.dart';
import '../services/scan_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_widgets.dart';
import 'capture_screen.dart';
import 'results_screen.dart';

const bool kHomeDemo = true;

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

String _scanTime(DateTime? at) {
  if (at == null) return 'Time unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = at.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day} · $hour12:$minute $period';
}

String _greetingForHour(int hour) {
  if (hour < 12) return 'Good morning, ';
  if (hour < 18) return 'Good afternoon, ';
  return 'Good evening, ';
}

HomeStats _demoStats(Set<String> reviewed) {
  final now = DateTime.now();
  final items = [
    SavedScan(
      id: 'demo-1',
      description: 'Account Suspended - Action Required',
      createdAt: now.subtract(const Duration(hours: 3)),
      result: const ScanResult(
        riskLevel: 'high',
        scamPercentage: 81,
        summary:
            'Fake account warning from a look-alike address (yah00-support.com).',
        redFlags: ['The sender address imitates Yahoo.'],
        nextSteps: ['Do not click any links.'],
      ),
    ),
    SavedScan(
      id: 'demo-2',
      description: "Congrats! You've won the giveaway",
      createdAt: now.subtract(const Duration(hours: 9)),
      result: const ScanResult(
        riskLevel: 'high',
        scamPercentage: 97,
        summary: 'Prize scam that pushes you to act quickly.',
        redFlags: ['Unexpected prize offer.'],
        nextSteps: ['Delete the email.'],
      ),
    ),
  ].where((s) => !reviewed.contains(s.id)).toList();

  return HomeStats(
    weekTotal: 148,
    weekHigh: 36,
    weekMedium: 0,
    weekLow: 112,
    scamRate: 24,
    attention48h: items.length,
    recentHigh: items,
    lastCheckedAt: now.subtract(const Duration(minutes: 5)),
    mockAnalysis: true,
  );
}
/// Only true when launched with `--dart-define=YAHOO_DEMO=true`. Shows the
/// "sample data" note for Yahoo demo analysis runs.
const bool yahooDemoMode = bool.fromEnvironment('YAHOO_DEMO');

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
  late final AuthService _auth = widget.authService ?? AuthService();
  late final String _firstName = _auth.firstName ?? 'there';
  bool _started = false;
  bool _loadingStats = false;
  Timer? _autoRefresh;

  ScanService? _ownedService;
  HomeStats _stats = HomeStats.empty;

  // Inbox linking is not built yet: connecting is simulated in the demo.
  bool _inboxConnected = false;
  bool _monitoring = false;

  static final Set<String> _reviewedDemo = {};

  @override
  void initState() {
    super.initState();
    // Paint the last known numbers at once, then refresh in the background.
    final key = _cacheKey();
    if (key != null) _stats = HomeStatsCache.peek(key) ?? HomeStats.empty;
    _loadStats(force: true);
    _autoRefresh = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _loadStats(force: true),
    );
    _restoreMonitoring();
  }

  Future<void> _restoreMonitoring() async {
    final key = _cacheKey();
    if (key == null) return;
    final saved = await MonitoringPrefs.load(key);
    if (!mounted) return;
    setState(() {
      _inboxConnected = saved.connected;
      _monitoring = saved.monitoring;
    });
  }

  void _saveMonitoring() {
    final key = _cacheKey();
    if (key == null) return;
    MonitoringPrefs.save(
      key,
      MonitoringState(connected: _inboxConnected, monitoring: _monitoring),
    );
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
    _autoRefresh?.cancel();
    _enter.dispose();
    _ownedService?.dispose();
    super.dispose();
  }

  String? _cacheKey() {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the summary unless a fresh copy is cached. Failures keep the
  /// numbers already on screen, so Home never breaks when offline.
  Future<void> _loadStats({bool force = false}) async {
    if (_loadingStats) return;
    final key = _cacheKey();
    final now = DateTime.now();
    if (!force && key != null && HomeStatsCache.isFresh(key, now)) return;

    _loadingStats = true;
    try {
      final service = widget.scanService ?? (_ownedService ??= ScanService());
      final fresh = await service.getHomeStats();
      if (key != null) HomeStatsCache.put(key, fresh, DateTime.now());
      if (mounted) setState(() => _stats = fresh);
    } catch (error) {
      // Keep the last known numbers.
      debugPrint('Home stats failed: $error');
    } finally {
      _loadingStats = false;
    }
  }

  void _toggleMonitoring() {
    setState(() => _monitoring = !_monitoring);
    _saveMonitoring();
  }

  void _connectInbox() {
    setState(() {
      _inboxConnected = true;
      _monitoring = true;
    });
    _saveMonitoring();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Yahoo inbox connected.')));
  }

  Future<void> _openCapture() async {
    await Navigator.of(context).push(fadeRoute(const CaptureScreen()));
    // A scan may have been saved while on the capture screen.
    if (mounted) _loadStats(force: true);
  }

  /// Opening a flagged scan counts as reviewing it: it leaves the attention
  /// list. Results opens right away; the refresh runs on return.
  Future<void> _openAttention(SavedScan scan) async {
    final service = widget.scanService ?? (_ownedService ??= ScanService());
    if (scan.id.startsWith('demo-')) {
      setState(() => _reviewedDemo.add(scan.id));
    } else {
      service.markScanReviewed(scan.id).catchError((Object error) {
        debugPrint('Mark reviewed failed: $error');
      });
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(result: scan.result),
      ),
    );
    if (mounted) _loadStats(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final showDemo =
        yahooDemoMode && kHomeDemo && _inboxConnected && _monitoring;
    final stats = showDemo ? _demoStats(_reviewedDemo) : _stats;
    final hasAnyScans = stats.lastCheckedAt != null || stats.weekTotal > 0;
    final hasAttention = stats.attention48h > 0;

    final String statusText;
    final IconData statusIcon;
    final Color statusColor;
    if (hasAttention) {
      final n = stats.attention48h;
      statusText =
          'Review $n flagged ${n == 1 ? 'message' : 'messages'} below.';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = AppColors.dangerRed;
    } else if (!hasAnyScans) {
      statusText = _inboxConnected
          ? 'Check a message to get started.'
          : 'Connect your inbox to start protection.';
      statusIcon = Icons.info_outline;
      statusColor = AppColors.cautionAmber;
    } else {
      statusText = 'Hooray! No messages need your attention.';
      statusIcon = Icons.celebration;
      statusColor = AppColors.accentGreen;
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: const FigmaAppBar(title: 'Home'),
      drawer: const AppDrawer(currentPage: 'Home'),
      body: FigmaGradientBackground(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () => _loadStats(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              _Reveal(
                animation: _enter,
                start: 0,
                child: _TypedGreeting(
                  prefix: _greetingForHour(now.hour),
                  name: _firstName,
                ),
              ),
              const SizedBox(height: 8),
              _Reveal(
                animation: _enter,
                start: 0.1,
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: AppTypography.emphasis,
                      color: statusColor,
                    ),
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
                    onPressed: _openCapture,
                    icon: const Icon(Icons.search),
                    label: const Text(
                      'Check a message',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Reveal(
                animation: _enter,
                start: 0.25,
                child: const _EmptyStateCard(),
              ),
              const SizedBox(height: 16),
              _Reveal(
                animation: _enter,
                start: 0.3,
                child: _MonitoringCard(
                  connected: _inboxConnected,
                  monitoring: _monitoring,
                  lastChecked: _timeAgo(stats.lastCheckedAt, now),
                  onToggle: _toggleMonitoring,
                  onConnect: _connectInbox,
                ),
              ),
              const SizedBox(height: 16),
              if (hasAttention) ...[
                _Reveal(
                  animation: _enter,
                  start: 0.35,
                  child: _AttentionCard(
                    count: stats.attention48h,
                    items: stats.recentHigh,
                    onOpen: _openAttention,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _Reveal(
                animation: _enter,
                start: 0.4,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.mark_email_read,
                          value: '${stats.weekTotal}',
                          boldLabel: 'Emails',
                          restLabel: ' checked this week',
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.warning_amber_rounded,
                          value: '${stats.weekHigh}',
                          boldLabel: 'Possible scams',
                          restLabel: ' found',
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Reveal(
                animation: _enter,
                start: 0.5,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle,
                          value: '${stats.weekLow}',
                          boldLabel: 'Safe',
                          restLabel: ' emails',
                          color: AppColors.accentGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.shield,
                          value: '${stats.scamRate}%',
                          boldLabel: 'Scam rate',
                          restLabel: ' of emails',
                          color: AppColors.cautionAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (yahooDemoMode && stats.mockAnalysis) ...[
                const SizedBox(height: 10),
                const Text(
                  'Demo analysis: results are sample data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
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
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
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
    final p = shown.length < widget.prefix.length ? shown : widget.prefix;
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
          const Icon(
            Icons.tips_and_updates,
            size: 36,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: const [
                  TextSpan(text: 'Tap '),
                  TextSpan(text: 'Check a message', style: bold),
                  TextSpan(text: ', then enter a message to see if it is '),
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
  const _AttentionCard({
    required this.count,
    required this.items,
    required this.onOpen,
  });
  final int count;
  final List<SavedScan> items;
  final ValueChanged<SavedScan> onOpen;

  @override
  Widget build(BuildContext context) {
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
                  '$count ${count == 1 ? 'message needs' : 'messages need'} your attention',
                  style: const TextStyle(
                    fontSize: AppTypography.emphasis,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in items) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onOpen(s),
              child: Container(
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
                          const SizedBox(height: 4),
                          Text(
                            _scanTime(s.createdAt),
                            style: const TextStyle(
                              fontSize: AppTypography.caption,
                              color: AppColors.muted,
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
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
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
          Row(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: AppTypography.heading,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
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
