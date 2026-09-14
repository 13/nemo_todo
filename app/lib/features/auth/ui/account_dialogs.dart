import 'package:flutter/material.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Asks for the current and a new password and changes it. True once the
/// server has taken the new one.
Future<bool> showChangePasswordDialog(
  BuildContext context,
  SyncClient client,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(client),
    ) ??
    false;

/// Explains what deleting the account does, asks for the password, and
/// deletes it. True once the server has.
Future<bool> showDeleteAccountDialog(
  BuildContext context,
  SyncClient client, {
  required String server,
  required bool wipesDevice,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(
        client,
        server: server,
        wipesDevice: wipesDevice,
      ),
    ) ??
    false;

String _errorText(L l, ApiError e) => switch (e.code) {
  'wrong_password' => l.accountErrorWrongPassword,
  'weak_password' => l.accountErrorWeakPassword,
  'network' => l.accountErrorNetwork,
  'too_many_requests' => l.accountErrorTooMany,
  _ => l.accountErrorGeneric(e.code),
};

/// Runs a request from a dialog: disables its buttons meanwhile, shows what
/// the server said on failure, and closes with true on success.
mixin _Submitting<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  Future<void> submit(Future<void> Function() request) async {
    final l = L.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await request();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) setState(() => error = _errorText(l, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog(this.client);

  final SyncClient client;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog>
    with _Submitting {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text(l.settingsChangePassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('change-password-current'),
            controller: _current,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: l.settingsCurrentPassword),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('change-password-new'),
            controller: _next,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: l.settingsNewPassword,
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('change-password-confirm'),
          onPressed: busy
              ? null
              : () => submit(
                  () => widget.client.changePassword(
                    current: _current.text,
                    next: _next.text,
                  ),
                ),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog(
    this.client, {
    required this.server,
    required this.wipesDevice,
  });

  final SyncClient client;
  final String server;
  final bool wipesDevice;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog>
    with _Submitting {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l.settingsDeleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.settingsDeleteAccountConfirm(widget.server)} '
            '${widget.wipesDevice ? l.settingsDeleteAccountWipes : l.settingsDeleteAccountKeeps}',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('delete-account-password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l.accountPassword,
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('delete-account-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: busy
              ? null
              : () => submit(() => widget.client.deleteAccount(_password.text)),
          child: Text(l.settingsDeleteAccount),
        ),
      ],
    );
  }
}
