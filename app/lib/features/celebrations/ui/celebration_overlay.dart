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

  /// The confetti and the banner, in an [Overlay] of their own: this sits
  /// outside the navigator's overlay, and the banner's close button shows a
  /// tooltip. Created once; it reads the state whenever it builds.
  late final OverlayEntry _layer = OverlayEntry(builder: _buildLayer);

  @override
  void initState() {
    super.initState();
    final controller = ref.read(celebrationControllerProvider);
    _subscribe(controller);
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
    // The Overlay below has already unmounted, so the entry no longer
    // reports itself mounted, but it still has to be removed before it
    // can be disposed; removing from an unmounted Overlay is a no-op.
    _layer
      ..remove()
      ..dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _subscribe(CelebrationController controller) {
    unawaited(_events?.cancel());
    _events = controller.events.listen(_show);
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
      _banner = event.achievements;
      _layer.markNeedsBuild();
      _hideBanner?.cancel();
      // Reaching the banner with a screen reader or switch access takes
      // longer than a glance, so there it stays until it is closed.
      if (!MediaQuery.accessibleNavigationOf(context)) {
        _hideBanner = Timer(const Duration(seconds: 4), _closeBanner);
      }
    }
  }

  void _closeBanner() {
    _hideBanner?.cancel();
    if (!mounted) return;
    _banner = null;
    _layer.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    // Rows a sync brought in are recorded quietly once it finishes, so the
    // next tap here does not celebrate another device's progress.
    ref
      ..listen(syncEngineProvider, (previous, next) {
        if (previous?.status == SyncStatus.syncing &&
            next.status != SyncStatus.syncing) {
          unawaited(ref.read(celebrationControllerProvider).backfill());
        }
      })
      ..listen(celebrationControllerProvider, (previous, next) {
        if (!identical(previous, next)) _subscribe(next);
      });
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Overlay(initialEntries: [_layer]),
      ],
    );
  }

  Widget _buildLayer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final banner = _banner;
    return Stack(
      fit: StackFit.expand,
      children: [
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
              // By default the package emits nothing on any frame slower
              // than 1/60 s. The frame after play() always is (and every
              // frame on a busy phone or a throttled browser), so the short
              // burst never got a single particle out.
              pauseEmissionOnLowFrameRate: false,
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
