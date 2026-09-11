import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/auth/ui/certificate_dialog.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Connects the app to a nemo server, by signing in or creating an account.
///
/// [standalone] is the web app's front door: there is nothing behind it to
/// go back to, so it carries the mark instead of a back button and moves on
/// by itself once the session exists.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({this.standalone = false, super.key});

  final bool standalone;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    // The web app is served by the server it syncs with, so the address is
    // the one it was loaded from and there is nothing to type.
    _server.text = auth.serverUrl ?? (widget.standalone ? _origin() : '');
    _username.text = auth.username ?? '';
  }

  /// Where the web app is being served from, which is the server it talks
  /// to. Empty anywhere else, where the address has to be typed.
  String _origin() {
    final base = Uri.base;
    return base.scheme == 'http' || base.scheme == 'https' ? base.origin : '';
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(L l, ApiError e) => switch (e.code) {
    'invalid_credentials' => l.accountErrorInvalidCredentials,
    'signup_disabled' => l.accountErrorSignupDisabled,
    'username_taken' => l.accountErrorUsernameTaken,
    'invalid_username' => l.accountErrorInvalidUsername,
    'weak_password' => l.accountErrorWeakPassword,
    'too_many_requests' => l.accountErrorTooMany,
    'network' => l.accountErrorNetwork,
    _ => l.accountErrorGeneric(e.code),
  };

  Future<void> _submit({required bool signUp, bool retry = false}) async {
    final l = L.of(context);
    if (!SyncClient.isValidBaseUrl(_server.text)) {
      setState(() => _error = l.accountInvalidUrl);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            serverUrl: _server.text,
            username: _username.text,
            password: _password.text,
            signUp: signUp,
          );
      await ref.read(syncEngineProvider.notifier).onSignedIn();
      if (!mounted) return;
      // Standing on the front door, there is nothing to pop: the session
      // has changed, and the guard moves the router on to wherever this
      // visit was headed before it got stopped here.
      if (!widget.standalone) context.pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      // A handshake the device could not verify arrives as "could not
      // reach the server", which is true but unhelpful: the server is
      // there, and the certificate it offered is waiting to be looked at.
      final offered = retry ? null : _offeredCertificate();
      if (e.isOffline && offered != null) {
        setState(() => _busy = false);
        if (await askToTrustCertificate(context, ref, offered)) {
          await _submit(signUp: signUp, retry: true);
        } else if (mounted) {
          setState(() => _error = l.accountErrorCertificate);
        }
        return;
      }
      setState(() => _error = _messageFor(l, e));
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  ServerCertificate? _offeredCertificate() {
    final host = hostOf(SyncClient.normaliseBaseUrl(_server.text));
    if (host == null) return null;
    return ref.read(certificateTrustProvider).refusedFor(host);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.standalone,
        title: Text(widget.standalone ? l.accountSignIn : l.accountTitle),
      ),
      body: MaxWidth(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (widget.standalone) ...[
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 12),
                child: Center(child: NemoLogoTile(size: 64)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  auth.sessionLost
                      ? l.settingsSignedOutRemotely
                      : l.accountWebNotice,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: auth.sessionLost
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            TextField(
              key: const Key('account-server'),
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.accountServer,
                hintText: l.accountServerHint,
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account-username'),
              controller: _username,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.accountUsername,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.accountPassword,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onSubmitted: (_) => _busy ? null : _submit(signUp: false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('account-error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('account-sign-in'),
              onPressed: _busy ? null : () => _submit(signUp: false),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.accountSignIn),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('account-sign-up'),
              onPressed: _busy ? null : () => _submit(signUp: true),
              child: Text(l.accountSignUp),
            ),
            if (!widget.standalone) ...[
              const SizedBox(height: 16),
              Text(
                l.accountLocalNotice,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
