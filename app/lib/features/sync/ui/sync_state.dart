/// What the sync engine is doing right now.
enum SyncStatus {
  /// No account is connected; the app is purely local.
  local,

  /// Connected and idle.
  idle,
  syncing,

  /// The server could not be reached; changes are queued.
  offline,

  /// The last attempt failed for another reason.
  error,

  /// The session expired or was revoked; sign in again.
  signedOut,
}

class SyncState {
  const SyncState({
    this.status = SyncStatus.local,
    this.lastSyncAt,
    this.pending = 0,
    this.error,
    this.discarded = 0,
  });

  final SyncStatus status;
  final DateTime? lastSyncAt;

  /// Local changes not yet accepted by the server.
  final int pending;
  final String? error;

  /// Changes the server refused since the user last dismissed the notice.
  final int discarded;

  bool get connected => status != SyncStatus.local;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncAt,
    int? pending,
    String? error,
    bool clearError = false,
    int? discarded,
  }) => SyncState(
    status: status ?? this.status,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    pending: pending ?? this.pending,
    error: clearError ? null : error ?? this.error,
    discarded: discarded ?? this.discarded,
  );
}
