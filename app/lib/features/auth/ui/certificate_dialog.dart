import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/format.dart';

/// The host of [serverUrl], or null when there is no address to speak of.
String? hostOf(String? serverUrl) {
  if (serverUrl == null) return null;
  final host = Uri.tryParse(serverUrl)?.host;
  return host == null || host.isEmpty ? null : host;
}

/// Shows what a server identified itself with and asks whether to believe
/// it, remembering the answer. True once it is trusted.
///
/// The fingerprint is the whole point of the dialog, so it is the part set
/// in a monospaced face and left selectable: it is there to be compared
/// against the server, character by character.
Future<bool> askToTrustCertificate(
  BuildContext context,
  WidgetRef ref,
  ServerCertificate certificate,
) async {
  final l = L.of(context);
  final locale = Localizations.localeOf(context).toString();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('trust-certificate'),
      title: Text(l.accountCertificateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.accountCertificateBody(certificate.host)),
          const SizedBox(height: 16),
          _Detail(label: l.accountCertificateIssuer, value: certificate.issuer),
          _Detail(
            label: l.accountCertificateExpires,
            value: dateLabel(
              locale,
              certificate.expires.millisecondsSinceEpoch,
            ),
          ),
          _Detail(
            label: l.accountCertificateFingerprint,
            value: certificate.fingerprint,
            monospaced: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('trust-certificate-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.accountCertificateTrust),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(certificateTrustProvider).trust(certificate);
  return true;
}

/// One labelled line of a certificate.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.monospaced = false,
  });

  final String label;
  final String value;
  final bool monospaced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(
            value,
            style: monospaced
                ? theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Courier'],
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
