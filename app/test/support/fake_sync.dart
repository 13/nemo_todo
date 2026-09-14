import 'dart:typed_data';

import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo_core/nemo_core.dart';

/// Epoch milliseconds of the clock the tests run at.
final int testNowMs = DateTime(2026, 9, 7, 10).millisecondsSinceEpoch;

/// Stands in for the server: records pushes and replays scripted answers.
class FakeSyncClient implements SyncClient {
  FakeSyncClient(this.responses);

  final List<SyncResponse> responses;
  final List<List<SyncChange>> pushes = [];
  final List<int> cursors = [];
  final List<SyncRequest> requests = [];
  final List<String> shared = [];
  final List<String> unshared = [];
  final List<String> handedOver = [];
  List<ListMember> memberList = const [];

  /// Membership the server reports back on every sync.
  Map<String, List<ListMember>> memberMap = const {};
  ApiError? failWith;
  int calls = 0;

  /// What every answer says about taking photo changes, scripted ones
  /// included. False plays a server from before photos.
  bool photos = true;

  /// When set, `/sync` refuses a push carrying a photo change the way a
  /// server from before photos does: a 400 for the whole request.
  bool rejectPhotoChanges = false;

  /// Runs while a push is in flight, so a test can make the device edit a
  /// row after its changes were collected but before the answer arrives.
  Future<void> Function()? duringSync;

  @override
  String get baseUrl => 'https://nemo.test';

  @override
  String get token => 'secret';

  /// Bytes the fake server is holding, by hash.
  final Map<String, Uint8List> blobs = {};
  final List<String> uploaded = [];
  final List<String> downloaded = [];

  /// How many times `uploadBlob` was called, including ones that failed --
  /// so a test can tell whether bytes were ever sent at all.
  int uploadAttempts = 0;

  /// Failures for single blobs, by hash, so one picture can go wrong while
  /// the rest of the sync goes right.
  final Map<String, Exception> blobFailures = {};

  /// The most blob requests that were in flight at once.
  int maxBlobsInFlight = 0;
  int _blobsInFlight = 0;

  /// Hashes pushed as photo rows, in order, so a test can check that the
  /// bytes went first.
  final List<String> pushedPhotoHashes = [];

  bool uploadedBefore(String sha256) =>
      uploaded.contains(sha256) &&
      (!pushedPhotoHashes.contains(sha256) ||
          uploaded.indexOf(sha256) <= pushedPhotoHashes.indexOf(sha256));

  Future<T> _blobRequest<T>(String sha256, T Function() answer) async {
    _blobsInFlight++;
    if (_blobsInFlight > maxBlobsInFlight) maxBlobsInFlight = _blobsInFlight;
    try {
      // Yields, so concurrent requests really overlap.
      await Future<void>.delayed(Duration.zero);
      final failure = failWith ?? blobFailures[sha256];
      if (failure != null) throw failure;
      return answer();
    } finally {
      _blobsInFlight--;
    }
  }

  @override
  Future<void> uploadBlob(String sha256, Uint8List bytes) {
    uploadAttempts++;
    return _blobRequest(sha256, () {
      uploaded.add(sha256);
      blobs[sha256] = bytes;
    });
  }

  @override
  Future<Uint8List> downloadBlob(String sha256) => _blobRequest(sha256, () {
    downloaded.add(sha256);
    final bytes = blobs[sha256];
    if (bytes == null) throw const ApiError(404, 'not_found');
    return bytes;
  });

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    calls++;
    requests.add(request);
    pushes.add(request.changes);
    for (final change in request.changes) {
      if (change is SyncChangePhoto) pushedPhotoHashes.add(change.row.sha256);
    }
    cursors.add(request.cursor);
    await duringSync?.call();
    final failure = failWith;
    if (failure != null) throw failure;
    if (rejectPhotoChanges &&
        request.changes.any((c) => c.entity == SyncEntity.photo)) {
      throw const ApiError(400, 'bad_request');
    }
    final response = responses.isEmpty
        ? SyncResponse(
            cursor: request.cursor,
            members: memberMap,
            serverHlc: Hlc(
              millis: testNowMs,
              counter: 0,
              node: 'srv',
            ).toString(),
          )
        : responses.removeAt(0);
    return response.copyWith(photos: photos);
  }

  @override
  Future<List<ListMember>> members(String listId) async => memberList;

  @override
  Future<void> share(String listId, String username, MemberRole role) async {
    final failure = failWith;
    if (failure != null) throw failure;
    shared.add('$listId:$username:${role.name}');
  }

  @override
  Future<void> transferOwnership(String listId, String username) async {
    final failure = failWith;
    if (failure != null) throw failure;
    handedOver.add('$listId:$username');
  }

  @override
  Future<void> unshare(String listId, String username) async {
    final failure = failWith;
    if (failure != null) throw failure;
    unshared.add('$listId:$username');
  }

  /// Password changes asked for, as `current>next`.
  final List<String> passwordChanges = [];

  /// Passwords account deletions were confirmed with.
  final List<String> deletions = [];

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    passwordChanges.add('$current>$next');
  }

  @override
  Future<void> deleteAccount(String password) async {
    final failure = failWith;
    if (failure != null) throw failure;
    deletions.add(password);
  }

  @override
  Future<void> logout() async {}

  @override
  Uri uri(String path) => Uri.parse('$baseUrl/api/v1$path');
}
