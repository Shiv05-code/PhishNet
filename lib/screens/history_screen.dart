import 'package:flutter/material.dart';

import '../models/saved_scan.dart';
import '../screens/app_colors.dart';
import '../services/scan_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import 'results_screen.dart';

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
  const HistoryScreen({super.key, this.scanService});

  final ScanService? scanService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final ScanService _service;
  late final bool _ownsService;
  final TextEditingController _search = TextEditingController();

  List<SavedScan> _scans = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ownsService = widget.scanService == null;
    _service = widget.scanService ?? ScanService();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final hadScans = _scans.isNotEmpty;

    setState(() {
      _loading = !hadScans;
      _error = null;
    });

    try {
      final scans = await _service.getScanHistory();

      if (!mounted) return;

      setState(() {
        _scans = scans;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

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
            action: SnackBarAction(label: 'Retry', onPressed: _loadHistory),
          ),
        );
      }
    }
  }

  List<SavedScan> get _filteredScans => filterSavedScans(_scans, _query);

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(result: scan.result),
      ),
    );
  }

  @override
  void dispose() {
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
                        onRefresh: _loadHistory,
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
                                      const SizedBox(height: 10),
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
