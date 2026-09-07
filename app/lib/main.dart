import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  final boot = await AppBootstrap.load(db);
  // The Inbox exists before the first frame so every screen can rely on it.
  await ListsRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    const Uuid().v4,
  ).ensureInbox();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
      ],
      child: const NemoApp(),
    ),
  );
}
