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
  final List<String> shared = [];
  final List<String> unshared = [];
  List<ListMember> memberList = const [];

  /// Membership the server reports back on every sync.
  Map<String, List<ListMember>> memberMap = const {};
  ApiError? failWith;
  int calls = 0;

  @override
  String get baseUrl => 'https://nemo.test';

  @override
  String get token => 'secret';

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    calls++;
    pushes.add(request.changes);
    cursors.add(request.cursor);
    final failure = failWith;
    if (failure != null) throw failure;
    return responses.isEmpty
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
  Future<void> unshare(String listId, String username) async {
    final failure = failWith;
    if (failure != null) throw failure;
    unshared.add('$listId:$username');
  }

  @override
  Future<void> logout() async {}

  @override
  Uri uri(String path) => Uri.parse('$baseUrl/api/v1$path');
}
