import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Connects the app to a nemo server, by signing in or creating an account.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

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
    _server.text = auth.serverUrl ?? '';
    _username.text = auth.username ?? '';
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

  Future<void> _submit({required bool signUp}) async {
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
      if (mounted) context.pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = _messageFor(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: MaxWidth(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
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
            const SizedBox(height: 16),
            Text(
              l.accountLocalNotice,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
