import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loading / error / data switcher for stream-backed screens.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({required this.value, required this.data, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnReload: true,
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$e', textAlign: TextAlign.center),
      ),
    ),
  );
}
