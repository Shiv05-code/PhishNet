import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scan_history_cache.dart';
import '../models/saved_scan.dart';
import '../screens/app_colors.dart';
import '../services/scan_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import 'results_screen.dart';
import 'dart:async';
import '../services/subscription_service.dart';

List<SavedScan> filterSavedScans(List<SavedScan> scans, String query) {
  final normalizedQuery = query.trim().toLowerCase();

  if (normalizedQuery.isEmpty) return scans;

  return scans.where((scan) {
    return scan.description.toLowerCase().contains(normalizedQuery) ||
        scan.result.summary.toLowerCase().contains(normalizedQuery) ||
        scan.result.riskLevel.toLowerCase().contains(normalizedQuery);
  }).toList();
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.scanService,
    this.onScanSelected,
    this.historyUserId,
  });

  final ScanService? scanService;
  final ValueChanged<SavedScan>? onScanSelected;
  final String? Function()? historyUserId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  StreamSubscription<User?>? _authSubscription;
  int _historyRequestGeneration = 0;
  final ScanHistoryCache _cache = ScanHistoryCache.instance;
  String? _historyUid;
  late final ScanService _service;
  late final bool _ownsService;
  final TextEditingController _search = TextEditingController();

  String? get _currentHistoryUid {
    if (widget.historyUserId != null) {
      return widget.historyUserId!();
    }

    return FirebaseAuth.instance.currentUser?.uid;
  }

  List<SavedScan> _scans = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();

    _ownsService = widget.scanService == null;
    _service = widget.scanService ?? ScanService();
    _listenForPlus();

    _loadHistory();

    if (widget.historyUserId == null) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (!mounted || user?.uid == _historyUid) return;

        ++_historyRequestGeneration;

        setState(() {
          _historyUid = user?.uid;
          _scans = [];
          _loading = true;
          _error = null;
        });

        if (user == null) {
          _cache.clearAll();

          setState(() {
            _loading = false;
            _error = 'Please sign in to view your scan history.';
          });

          return;
        }

        _loadHistory(expectedUid: user.uid);
      });
    }
  }

  Future<void> _loadHistory({
    bool forceRefresh = false,
    String? expectedUid,
    int retryCount = 0,
  }) async {
    final uid = expectedUid ?? _currentHistoryUid;
    final cacheRevision = uid == null ? null : _cache.revision(uid);
    final requestGeneration = ++_historyRequestGeneration;

    // Never reuse another account's visible history.
    if (_historyUid != uid) {
      _historyUid = uid;
      _scans = [];
    }

    final cached = uid == null ? null : _cache.get(uid);

    if (cached != null && _scans.isEmpty) {
      setState(() {
        _scans = cached;
        _loading = false;
        _error = null;
      });
    }

    // Fresh cached data can be displayed without another request.
    if (!forceRefresh && uid != null && cached != null && _cache.isFresh(uid)) {
      return;
    }

    final hadScans = _scans.isNotEmpty;

    setState(() {
      _loading = !hadScans;
      _error = null;
    });

    try {
      final scans = await _service.getScanHistory();

      if (!mounted ||
          requestGeneration != _historyRequestGeneration ||
          uid != _currentHistoryUid) {
        return;
      }

      if (uid != null && _cache.revision(uid) != cacheRevision) {
        // Do not restore outdated history after cache invalidation.
        if (retryCount < 1) {
          await _loadHistory(
            forceRefresh: true,
            expectedUid: uid,
            retryCount: retryCount + 1,
          );
        } else {
          setState(() {
            _loading = false;
            _error = _scans.isEmpty
                ? 'History changed while loading. Please try again.'
                : null;
          });
        }

        return;
      }

      if (uid != null) {
        _cache.save(uid, scans);
      }

      setState(() {
        _scans = scans;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted ||
          requestGeneration != _historyRequestGeneration ||
          uid != _currentHistoryUid) {
        return;
      }

      final message = error is ScanException
          ? error.message
          : 'Unable to load scan history.';

      setState(() {
        _loading = false;
        _error = hadScans ? null : message;
      });

      if (hadScans) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message Your previous scans are still available.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadHistory(forceRefresh: true),
            ),
          ),
        );
      }
    }
  }

  /// Source filter: all scans, Gmail live monitoring only, or in-app checks only.
  static const _sourceOptions = [
    ('all', 'All'),
    ('monitor', 'Live Monitor'),
    ('manual', 'In-app check'),
  ];
  String _source = 'all';
  // Live Monitor labels and the filter are Plus-only.
  bool _isPlus = false;
  StreamSubscription<dynamic>? _plusSub;

  List<SavedScan> get _filteredScans {
    final bySearch = filterSavedScans(_scans, _query);
    if (!_isPlus || _source == 'all') return bySearch;
    final wantMonitored = _source == 'monitor';
    return bySearch.where((s) => s.monitored == wantMonitored).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';

    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$month/$day/$year · $hour:$minute $period';
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':
        return AppColors.dangerRed;
      case 'medium':
        return AppColors.cautionAmber;
      default:
        return AppColors.accentGreen;
    }
  }

  void _openScan(SavedScan scan) {
    final callback = widget.onScanSelected;

    if (callback != null) {
      callback(scan);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(result: scan.result),
      ),
    );
  }

  /// Plus status decides whether Live Monitor labels and the filter show.
  /// Failing to read it (for example, no Firebase in tests) just keeps them hidden.
  void _listenForPlus() {
    try {
      _plusSub = SubscriptionService.instance.watchEffectiveSubscription().listen(
        (data) {
          final isPlus = SubscriptionService.isActivePlus(data);
          if (mounted && isPlus != _isPlus) setState(() => _isPlus = isPlus);
        },
        onError: (_) {},
      );
    } catch (_) {
      // Keep Plus-only UI hidden.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _plusSub?.cancel();
    _search.dispose();

    if (_ownsService) {
      _service.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredScans;

    return Scaffold(
      appBar: const FigmaAppBar(title: 'History'),
      drawer: const AppDrawer(currentPage: 'History'),
      body: FigmaGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 18, color: AppColors.text),
                  onChanged: (value) {
                    setState(() => _query = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search recent scans...',
                    hintStyle: const TextStyle(
                      fontSize: 18,
                      color: AppColors.muted,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_isPlus)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final option in _sourceOptions)
                      ChoiceChip(
                        label: Text(
                          option.$2,
                          style: const TextStyle(fontSize: 16),
                        ),
                        selected: _source == option.$1,
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _source == option.$1
                              ? Colors.white
                              : AppColors.text,
                        ),
                        onSelected: (_) => setState(() => _source = option.$1),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _messageState(_error!, retry: true)
                    : _scans.isEmpty
                    ? _messageState('No scans yet.')
                    : filtered.isEmpty
                    ? _messageState('No matching scans found.')
                    : RefreshIndicator(
                        onRefresh: () => _loadHistory(forceRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final scan = filtered[index];
                            final risk = scan.result.riskLevel;
                            final color = _riskColor(risk);

                            return Card(
                              color: AppColors.cardSurface,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                title: Text(
                                  scan.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(scan.createdAt),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_isPlus) ...[
                                        _SourceBadge(monitored: scan.monitored),
                                        const SizedBox(height: 10),
                                      ],
                                      Text(
                                        scan.result.summary,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          height: 1.4,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${risk.toUpperCase()} RISK',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.primaryBlue,
                                ),
                                onTap: () => _openScan(scan),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageState(String message, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text),
          ),
          if (retry) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Labels where a result came from: Gmail live monitoring or an in-app check.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.monitored});

  final bool monitored;

  @override
  Widget build(BuildContext context) {
    final color = monitored ? AppColors.primaryBlue : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        monitored ? 'Live Monitor' : 'In-app check',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
