import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/celebrations/ui/achievement_banner.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';

/// Shows what a completion earned, above every screen.
///
/// Sits above the router, so it is handed the way to the achievements
/// screen rather than looking the router up.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({
    required this.onOpenAchievements,
    required this.child,
    super.key,
  });

  final VoidCallback onOpenAchievements;
  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 600),
  );
  StreamSubscription<CelebrationEvent>? _events;
  List<Achievement>? _banner;
  Timer? _hideBanner;
  Timer? _stopConfetti;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(celebrationControllerProvider);
    _events = controller.events.listen(_show);
    // Whatever is already reached at start was not a tap in this session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.backfill());
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _hideBanner?.cancel();
    _stopConfetti?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  void _show(CelebrationEvent event) {
    if (!mounted) return;
    final celebrate = ref.read(celebrationsEnabledProvider);
    final big = event is! TickCelebration;
    if (celebrate) {
      unawaited(
        big ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact(),
      );
    }
    if (!big) return;
    if (celebrate && !MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
      // The package only reports itself stopped once every particle has
      // finished falling, which runs on the real clock and can outlast a
      // test (or a user's patience); call time on it after its own burst
      // duration instead.
      _stopConfetti?.cancel();
      _stopConfetti = Timer(_confetti.duration, _confetti.stop);
    }
    if (celebrate && ref.read(celebrationSoundEnabledProvider)) {
      unawaited(ref.read(celebrationSoundProvider).play());
    }
    if (event is AchievementsUnlocked) {
      setState(() => _banner = event.achievements);
      _hideBanner?.cancel();
      _hideBanner = Timer(const Duration(seconds: 4), _closeBanner);
    }
  }

  void _closeBanner() {
    _hideBanner?.cancel();
    if (mounted) setState(() => _banner = null);
  }

  @override
  Widget build(BuildContext context) {
    // Rows a sync brought in are recorded quietly once it finishes, so the
    // next tap here does not celebrate another device's progress.
    ref.listen(syncEngineProvider, (previous, next) {
      if (previous?.status == SyncStatus.syncing &&
          next.status != SyncStatus.syncing) {
        unawaited(ref.read(celebrationControllerProvider).backfill());
      }
    });
    final scheme = Theme.of(context).colorScheme;
    final banner = _banner;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              emissionFrequency: 0.05,
              minBlastForce: 10,
              maxBlastForce: 30,
              gravity: 0.25,
              colors: [
                scheme.primary,
                scheme.secondary,
                scheme.tertiary,
                scheme.primaryContainer,
                scheme.tertiaryContainer,
              ],
            ),
          ),
        ),
        if (banner != null)
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AchievementBanner(
                      achievements: banner,
                      onClose: _closeBanner,
                      onOpen: () {
                        _closeBanner();
                        widget.onOpenAchievements();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
