import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The currency the amounts on a task are written in.
///
/// A short list rather than every ISO code: a household spends in one,
/// and the code it already holds is always offered even when it is not
/// on the list.
const _offered = ['EUR', 'USD', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'PLN'];

class CurrencyTile extends ConsumerWidget {
  const CurrencyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(currencyCodeProvider);
    final codes = [if (!_offered.contains(current)) current, ..._offered];
    return ListTile(
      key: const Key('currency-tile'),
      leading: const Icon(Icons.payments_outlined),
      title: Text(l.settingsCurrency),
      subtitle: Text(current),
      onTap: () async {
        final chosen = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final code in codes)
                  ListTile(
                    title: Text(code),
                    selected: code == current,
                    onTap: () => Navigator.of(context).pop(code),
                  ),
              ],
            ),
          ),
        );
        if (chosen == null || chosen == current) return;
        await ref.read(currencyCodeProvider.notifier).set(chosen);
      },
    );
  }
}
