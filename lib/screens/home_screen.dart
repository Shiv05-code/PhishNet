import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/home_stats.dart';
import '../models/saved_scan.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../services/home_stats_cache.dart';
import '../services/attention_state.dart';
import '../services/monitoring_service.dart';
import '../services/push_service.dart';
import '../services/scan_service.dart';
import '../services/subscription_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/plus_gate.dart';
import '../widgets/swimming_fish.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_widgets.dart';
import 'capture_screen.dart';
import 'results_screen.dart';

const _statsRetryDelays = [
  Duration(seconds: 3),
  Duration(seconds: 10),
  Duration(seconds: 30),
  Duration(minutes: 1),
];

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

class HomeScreen extends StatefulWidget {
  final AuthService? authService;
  final ScanService? scanService;

  /// Injected in tests. Defaults to the live subscription stream.
  final Stream<Map<String, dynamic>?>? subscriptionStream;

  const HomeScreen({
    super.key,
    this.authService,
    this.scanService,
    this.subscriptionStream,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AuthService _auth = widget.authService ?? AuthService();
  late final String _firstName = _auth.firstName ?? 'there';
  bool _started = false;
  bool _loadingStats = false;
  Timer? _autoRefresh;
  Timer? _retryTimer;
  Timer? _dwellTimer;
  int _statsFailures = 0;

  ScanService? _ownedService;
  HomeStats _stats = HomeStats.empty;

  // Live Monitoring state comes from the backend, never from local prefs.
  final MonitoringService _monitor = MonitoringService();
  MonitoringStatus _monitorStatus = MonitoringStatus.unknown;
  bool _monitorBusy = false;
  String? _monitorMessage;

  // Attention alerts are a Plus-only feature. Fails closed until confirmed.
  bool _isPlus = false;
  StreamSubscription<Map<String, dynamic>?>? _plusSub;
  StreamSubscription<void>? _alertSub;
  bool _reloadAfterLoad = false;

  @override
  void initState() {
    super.initState();
    final key = _cacheKey();
    if (key != null) _stats = HomeStatsCache.peek(key) ?? HomeStats.empty;
    unawaited(_restoreStatsAndRefresh(key));
    _autoRefresh = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _loadStats(force: true),
    );
    WidgetsBinding.instance.addObserver(this);
    _listenForPlus();
    _alertSub = PushService.alerts.listen((_) {
      if (mounted) _loadStats(force: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the Google consent page in the browser.
    if (state == AppLifecycleState.resumed) _refreshMonitoring();
  }

  /// Menu and Home counts. Only Plus users ever have a non-zero count.
  void _publishAttention() {
    attentionCount.value = _isPlus ? _stats.attention48h : 0;
  }

  void _listenForPlus() {
    try {
      final stream =
          widget.subscriptionStream ??
          SubscriptionService.instance.watchEffectiveSubscription();
      _plusSub = stream.listen(
        (data) {
          final isPlus = SubscriptionService.isActivePlus(data);
          if (mounted && isPlus != _isPlus) {
            setState(() => _isPlus = isPlus);
            if (isPlus) {
              _refreshMonitoring();
              unawaited(PushService.start(_monitor));
            }
            _publishAttention();
          }
        },
        onError: (_) {
          if (mounted && _isPlus) setState(() => _isPlus = false);
        },
      );
    } catch (_) {
      // Firebase not initialized: stay non-Plus.
    }
  }

  Future<void> _restoreStatsAndRefresh(String? key) async {
    if (key != null) {
      final cached = await HomeStatsCache.restore(key);
      if (!mounted) return;
      if (cached != null) {
        setState(() => _stats = cached);
        _publishAttention();
      }
    }
    if (mounted) await _loadStats(force: true);
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
    _dwellTimer?.cancel();
    _retryTimer?.cancel();
    _plusSub?.cancel();
    _alertSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
    // A forced refresh that arrives mid-load (for example, a new alert) runs once more after it.
    if (_loadingStats) {
      if (force) _reloadAfterLoad = true;
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    final key = _cacheKey();
    final now = DateTime.now();
    if (!force && key != null && HomeStatsCache.isFresh(key, now)) return;

    _loadingStats = true;
    try {
      final service = widget.scanService ?? (_ownedService ??= ScanService());
      final fresh = await service.getHomeStats();
      if (key != null) {
        unawaited(HomeStatsCache.put(key, fresh, DateTime.now()));
      }
      _statsFailures = 0;
      if (mounted) {
        setState(() => _stats = fresh);
        _publishAttention();
      }
    } catch (error) {
      // Keep the last known numbers.
      debugPrint('Home stats failed: $error');
      if (error is ScanException && error.retryable) _scheduleStatsRetry();
    } finally {
      _loadingStats = false;
      if (_reloadAfterLoad && mounted) {
        _reloadAfterLoad = false;
        unawaited(_loadStats(force: true));
      }
    }
  }

  void _scheduleStatsRetry() {
    if (!mounted) return;
    final delay =
        _statsRetryDelays[_statsFailures.clamp(
          0,
          _statsRetryDelays.length - 1,
        )];
    _statsFailures++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _loadStats(force: true);
    });
  }

  Future<void> _refreshMonitoring() async {
    if (!_isPlus || !_monitor.isConfigured || _monitorBusy) return;
    try {
      final status = await _monitor.status();
      if (mounted) {
        setState(() {
          _monitorStatus = status;
          _monitorMessage = null;
        });
      }
    } on MonitoringException catch (e) {
      if (mounted) setState(() => _monitorMessage = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _monitorMessage =
              "Couldn't check Live Monitoring. Please try again.",
        );
    }
  }

  /// Starts (or restarts) Google consent. The result is read on return to the app.
  Future<void> _connectInbox() async {
    if (_monitorBusy) return;
    setState(() {
      _monitorBusy = true;
      _monitorMessage = null;
    });
    try {
      final url = await _monitor.startConnect();
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(
          () => _monitorMessage = "Couldn't open Google. Please try again.",
        );
      }
    } on MonitoringException catch (e) {
      if (mounted) setState(() => _monitorMessage = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _monitorMessage = "Couldn't open Google. Please try again.",
        );
    } finally {
      if (mounted) setState(() => _monitorBusy = false);
    }
  }

  Future<void> _disconnectInbox() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off Live Monitoring?'),
        content: const Text(
          'PhishNet will stop checking your Gmail and remove its access. Past results stay in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true || _monitorBusy) return;
    setState(() {
      _monitorBusy = true;
      _monitorMessage = null;
    });
    try {
      final status = await _monitor.disconnect();
      if (mounted) setState(() => _monitorStatus = status);
    } on MonitoringException catch (e) {
      if (mounted) setState(() => _monitorMessage = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _monitorMessage =
              "Couldn't turn off Live Monitoring. Please try again.",
        );
    } finally {
      if (mounted) setState(() => _monitorBusy = false);
    }
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
    service.markScanReviewed(scan.id).catchError((Object error) {
      debugPrint('Mark reviewed failed: $error');
    });
    if (!mounted) return;
    // Clear the menu dot and the card after 5 seconds on Results, without
    // waiting for a server refresh. Returning clears them right away too.
    _dwellTimer?.cancel();
    _dwellTimer = Timer(
      const Duration(seconds: 5),
      () => _markLocallyReviewed(scan.id),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          result: scan.result,
          monitored: _isPlus ? scan.monitored : null,
        ),
      ),
    );
    _dwellTimer?.cancel();
    _markLocallyReviewed(scan.id);
    if (mounted) _loadStats(force: true);
  }

  void _markLocallyReviewed(String scanId) {
    if (!mounted) return;
    setState(() => _stats = _stats.withReviewed(scanId));
    _publishAttention();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stats = _stats;
    final hasAnyScans = stats.lastCheckedAt != null || stats.weekTotal > 0;
    // Attention alerts are Plus-only: non-Plus users never see the flagged count.
    final hasAttention = _isPlus && stats.attention48h > 0;

    final String statusText;
    final IconData statusIcon;
    final Color statusColor;
    if (hasAttention) {
      final n = stats.attention48h;
      statusText =
          'Review $n flagged ${n == 1 ? 'message' : 'messages'} below.';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = AppColors.dangerRed;
    } else if (!_isPlus && stats.attention48h > 0) {
      // Non-Plus: neutral pointer to their own check. No alert styling.
      statusText = 'You have a recent check to review in Results.';
      statusIcon = Icons.info_outline;
      statusColor = AppColors.cautionAmber;
    } else if (!hasAnyScans) {
      statusText = _monitorStatus == MonitoringStatus.connected
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
                child: PlusGate(
                  feature: 'Live Monitoring Inbox',
                  child: _MonitoringCard(
                    isPlus: _isPlus,
                    configured: _monitor.isConfigured,
                    status: _monitorStatus,
                    busy: _monitorBusy,
                    lastChecked: _timeAgo(stats.lastCheckedAt, now),
                    message: _monitorMessage,
                    onConnect: _connectInbox,
                    onDisconnect: _disconnectInbox,
                    onRefresh: _refreshMonitoring,
                  ),
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

/// Short, friendly phrases shown while the monitoring status loads.
class _RotatingPhrase extends StatefulWidget {
  const _RotatingPhrase();

  @override
  State<_RotatingPhrase> createState() => _RotatingPhraseState();
}

class _RotatingPhraseState extends State<_RotatingPhrase> {
  static const _phrases = [
    'Casting a line…',
    'Reeling in your inbox…',
    'Checking the waters…',
    'Scanning the depths…',
  ];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        _phrases[_index],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: AppColors.muted),
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.isPlus,
    required this.configured,
    required this.status,
    required this.busy,
    required this.lastChecked,
    required this.message,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRefresh,
  });

  final bool isPlus;
  final bool configured;
  final MonitoringStatus status;
  final bool busy;
  final String lastChecked;
  final String? message;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRefresh;

  static const _buttonHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    // Non-Plus users see generic copy only. Their status is never fetched.
    if (!isPlus) {
      return _body(
        icon: Icons.shield_outlined,
        iconColor: AppColors.muted,
        title: 'Live Monitoring Inbox',
        subtitle:
            'A PhishNet Plus feature. Upgrade to check your Gmail for scams automatically.',
        action: null,
      );
    }

    // A build without MONITOR_API_URL can never load a status, so don't spin.
    if (!configured) {
      return _body(
        icon: Icons.error_outline,
        iconColor: AppColors.muted,
        title: 'Live Monitoring unavailable',
        subtitle: 'Not set up in this build.',
        action: null,
      );
    }

    switch (status) {
      case MonitoringStatus.connected:
        return _body(
          icon: Icons.shield,
          iconColor: AppColors.primaryBlue,
          title: 'Monitoring your Gmail',
          // lastChecked already reads "Last checked: …" (see _timeAgo).
          subtitle: lastChecked == 'No checks yet'
              ? 'Waiting for the first check.'
              : lastChecked,
          action: _Action(
            label: 'Turn Off',
            onPressed: onDisconnect,
            destructive: true,
          ),
        );
      case MonitoringStatus.reauthNeeded:
        return _body(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.cautionAmber,
          title: 'Paused: reconnect needed',
          subtitle: 'Google needs you to sign in again to keep checking.',
          action: _Action(
            label: 'Reconnect Gmail',
            onPressed: onConnect,
            filled: true,
          ),
        );
      case MonitoringStatus.error:
      case MonitoringStatus.unavailable:
        return _body(
          icon: Icons.error_outline,
          iconColor: AppColors.dangerRed,
          title: 'Live Monitoring hit a problem',
          subtitle: 'Please try again in a moment.',
          action: _Action(
            label: 'Try again',
            onPressed: onRefresh,
            filled: true,
          ),
        );
      case MonitoringStatus.denied:
      case MonitoringStatus.disconnected:
        return _body(
          icon: Icons.shield_outlined,
          iconColor: AppColors.muted,
          title: 'Live Monitoring is off',
          subtitle: 'Connect your Gmail to check new emails for scams.',
          action: _Action(
            label: 'Connect Gmail',
            onPressed: onConnect,
            filled: true,
          ),
        );
      case MonitoringStatus.unknown:
        return const _SoftCard(
          child: Column(
            children: [
              SwimmingFish(size: 64),
              SizedBox(height: 12),
              _RotatingPhrase(),
            ],
          ),
        );
    }
  }

  Widget _body({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required _Action? action,
  }) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 44, color: iconColor),
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
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: const TextStyle(
                fontSize: AppTypography.label,
                color: AppColors.dangerRed,
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ] else if (action != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: _buttonHeight,
              child: action.filled
                  ? FilledButton(
                      onPressed: action.onPressed,
                      child: _actionText(action.label),
                    )
                  : OutlinedButton(
                      onPressed: action.onPressed,
                      style: action.destructive
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dangerRed,
                              side: const BorderSide(
                                color: AppColors.dangerRed,
                              ),
                            )
                          : null,
                      child: _actionText(action.label),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _actionText(String label) => Text(
  label,
  style: const TextStyle(
    fontSize: AppTypography.label,
    fontWeight: FontWeight.w700,
  ),
);

class _Action {
  const _Action({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  /// Outlined in danger red, for actions that turn something off.
  final bool destructive;
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
