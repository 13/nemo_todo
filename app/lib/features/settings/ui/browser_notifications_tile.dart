import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// On the web: whether this browser lets nemo notify, and that it does so
/// only while a tab is open. Asks for permission from its own button, the
/// user gesture browsers want before they prompt.
class BrowserNotificationsTile extends ConsumerWidget {
  const BrowserNotificationsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final browser = ref.watch(browserNotificationsProvider);
    if (browser == null) {
      return ListTile(
        key: const Key('browser-notifications'),
        leading: const SettingsIcon(Icons.notifications_outlined),
        title: Text(l.browserNotificationsTitle),
        subtitle: Text(l.browserNotificationsUnsupported),
      );
    }
    return ValueListenableBuilder<BrowserPermission>(
      valueListenable: browser.permission,
      builder: (context, permission, _) => ListTile(
        key: const Key('browser-notifications'),
        leading: const SettingsIcon(Icons.notifications_outlined),
        title: Text(l.browserNotificationsTitle),
        subtitle: Text(switch (permission) {
          BrowserPermission.granted => l.browserNotificationsOn,
          BrowserPermission.ask => l.browserNotificationsAsk,
          BrowserPermission.denied => l.browserNotificationsBlocked,
        }),
        trailing: permission == BrowserPermission.ask
            ? TextButton(
                key: const Key('browser-notifications-allow'),
                onPressed: browser.requestPermission,
                child: Text(l.browserNotificationsAllow),
              )
            : null,
      ),
    );
  }
}
