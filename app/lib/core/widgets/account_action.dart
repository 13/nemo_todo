import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';

/// Says whether the app is signed in, and is the way in when it is not.
///
/// The account used to live only behind Settings, which meant a signed-out
/// app looked exactly like a signed-in one and there was nothing on screen
/// to sign in from. This sits in the app bar of every main screen, and in
/// the rail when the window is wide enough to show one.
class AccountAction extends ConsumerWidget {
  const AccountAction({this.inRail = false, super.key});

  /// The rail shows this itself, so the app bar leaves it out there.
  final bool inRail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!inRail &&
        MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final (icon, tooltip, destination) = switch (auth) {
      AuthState(connected: true, :final username?, :final serverUrl?) => (
        _Initial(username),
        l.settingsConnectedAs(username, serverUrl),
        Routes.settings,
      ),
      AuthState(sessionLost: true) => (
        Icon(Icons.cloud_off_rounded, color: scheme.error),
        l.settingsSignedOutRemotely,
        Routes.account,
      ),
      _ => (
        const Icon(Icons.account_circle_outlined),
        l.accountSignInAction,
        Routes.account,
      ),
    };
    return IconButton(
      key: const Key('account-action'),
      tooltip: tooltip,
      icon: icon,
      onPressed: () => context.push(destination),
    );
  }
}

/// The signed-in account as its first letter, the way an avatar would be
/// if the server held one.
class _Initial extends StatelessWidget {
  const _Initial(this.username);

  final String username;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 12,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        username.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
