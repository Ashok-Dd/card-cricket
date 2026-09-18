import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';

/// Shown while the router is deciding where a returning user belongs
/// (checking a stored token) — see app_router.dart's redirect logic. Also
/// doubles as the "server is waking up" screen: the backend runs on
/// Render's free tier, whose container can take 30-50s to spin back up
/// after being idle, so the very first request (auth_controller.dart's
/// `/auth/me` check) can hang for a while. Rather than a bare spinner that
/// looks broken for up to a minute, this self-animates a progress bar from
/// its own elapsed on-screen time — it has no real progress to report (the
/// request is a single opaque HTTP call), but a slowly filling bar reads as
/// "working on it" far better than an indefinite spinner does, and costs
/// nothing when the backend is already warm (the screen is barely visible
/// for that fast path).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Cold starts on Render's free tier are typically well under a minute;
  // this is a display assumption, not a real deadline — nothing times out
  // or errors when it's exceeded, the bar just holds near-full until the
  // real response arrives.
  static const _assumedWakeUpDuration = Duration(seconds: 40);
  static const _slowThreshold = Duration(seconds: 2);

  late final Stopwatch _stopwatch;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  double get _progress {
    final fraction = _elapsed.inMilliseconds / _assumedWakeUpDuration.inMilliseconds;
    // Eases toward 92%, never a false 100% — the screen is simply replaced
    // once the real check actually finishes.
    return fraction.clamp(0.0, 1.0) * 0.92;
  }

  bool get _isSlow => _elapsed > _slowThreshold;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
                child: Text(
                  'CARD CRICKET',
                  style: AppTextStyles.hero.copyWith(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 350),
                crossFadeState: _isSlow ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
                secondChild: _WakeUpProgress(progress: _progress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WakeUpProgress extends StatelessWidget {
  const _WakeUpProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: progress, end: progress),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.glassFill,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Waking up the server…',
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'This can take up to a minute on the first launch',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
