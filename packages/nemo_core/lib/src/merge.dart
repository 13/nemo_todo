import 'package:nemo_core/src/model/sync_row.dart';

/// Last-write-wins: the incoming row replaces [local] only when its HLC is
/// strictly greater. Equal stamps are the same event replayed, so the local
/// row is kept and the operation stays idempotent.
bool incomingWins(SyncRow? local, SyncRow incoming) =>
    local == null || incoming.updatedAt.compareTo(local.updatedAt) > 0;
