/// What every synced row exposes: identity, its last-write stamp and an
/// optional tombstone. Both stamps are HLC strings (see `Hlc`).
abstract interface class SyncRow {
  String get id;
  String get updatedAt;
  String? get deletedAt;
}
