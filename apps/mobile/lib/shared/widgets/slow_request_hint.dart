import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

/// A small "this is normal, not broken" hint that fades in once a loading
/// state has been active for a while — used anywhere a request could hit
/// the backend's Render free-tier cold start (30-50s+ to spin back up after
/// being idle), which otherwise just looks like a stuck spinner with no
/// explanation. Cheap enough to drop under any button that shows
/// `PremiumButton(isLoading: ...)`.
class SlowRequestHint extends StatefulWidget {
  const SlowRequestHint({required this.isLoading, this.delay = const Duration(seconds: 3), super.key});

  final bool isLoading;
  final Duration delay;

  @override
  State<SlowRequestHint> createState() => _SlowRequestHintState();
}

class _SlowRequestHintState extends State<SlowRequestHint> {
  Timer? _timer;
  bool _show = false;

  @override
  void didUpdateWidget(covariant SlowRequestHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _timer?.cancel();
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _show = true);
      });
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _timer?.cancel();
      setState(() => _show = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show && widget.isLoading ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Waking up the server — this can take up to a minute…',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}
