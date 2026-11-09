import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/app_colors.dart';
import '../services/monitoring_service.dart';
import '../theme/app_colors.dart' as theme_colors;
import '../theme/app_typography.dart';
import 'figma_glass_button.dart';

/// Connect / turn-off card shown at the top of History. Hidden entirely
/// when this build has no Yahoo monitoring endpoint configured.
class MonitoringCard extends StatefulWidget {
  final MonitoringService? service;

  const MonitoringCard({super.key, this.service});

  @override
  State<MonitoringCard> createState() => _MonitoringCardState();
}

class _MonitoringCardState extends State<MonitoringCard>
    with WidgetsBindingObserver {
  late final MonitoringService _service = widget.service ?? MonitoringService();

  MonitoringStatus? _status;
  String? _error;
  bool _busy = false;
  bool _waitingForConsent = false;

  @override
  void initState() {
    super.initState();
    if (_service.isConfigured) {
      WidgetsBinding.instance.addObserver(this);
      _refresh();
    }
  }

  @override
  void dispose() {
    if (_service.isConfigured) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  // Returning from Yahoo's consent page re-checks the real status.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForConsent) {
      _waitingForConsent = false;
      _refresh();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on MonitoringException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run(() async {
    final status = await _service.status();
    if (mounted) setState(() => _status = status);
  });

  Future<void> _connect() => _run(() async {
    final url = await _service.startConnect();
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const MonitoringException("Couldn't open Yahoo. Please try again.");
    }
    _waitingForConsent = true;
  });

  Future<void> _turnOff() => _run(() async {
    final status = await _service.disconnect();
    if (mounted) setState(() => _status = status);
  });

  @override
  Widget build(BuildContext context) {
    if (!_service.isConfigured) return const SizedBox.shrink();

    final connected = _status == MonitoringStatus.connected;
    final String headline;
    final String detail;
    final String buttonLabel;
    final VoidCallback onPressed;

    if (_status == null) {
      headline = _error == null ? 'Checking Yahoo email…' : 'Yahoo email';
      detail = _error ?? 'Checking your connection.';
      buttonLabel = 'Try again';
      onPressed = _refresh;
    } else if (connected) {
      headline = 'Yahoo email is connected';
      detail =
          _error ??
          'Connected. Automatic checks are not active yet, so new emails are not being scanned.';
      buttonLabel = 'Turn off';
      onPressed = _turnOff;
    } else {
      headline = _error == null
          ? 'Check my Yahoo email for scams'
          : 'Yahoo email is not connected';
      detail =
          _error ??
          'We read new emails only, and alert you only about risky ones.';
      buttonLabel = _error == null ? 'Connect Yahoo' : 'Try again';
      onPressed = _error == null ? _connect : _refresh;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme_colors.AppColors.highlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (connected)
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E9E5B),
                    shape: BoxShape.circle,
                  ),
                )
              else
                const Icon(
                  Icons.mail_outline,
                  color: AppColors.primaryBlue,
                  size: 26,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: AppTypography.emphasis,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              detail,
              style: TextStyle(
                fontSize: AppTypography.body,
                color: _error == null ? AppColors.muted : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 14),
          IgnorePointer(
            ignoring: _busy,
            child: Opacity(
              opacity: _busy ? 0.55 : 1,
              child: FigmaGlassButton(
                height: 52,
                semanticLabel: buttonLabel,
                onPressed: onPressed,
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: AppTypography.label,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
