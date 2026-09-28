import 'package:nemo/core/notifications/notifications_api.dart';

/// Records what the app asked the platform to schedule or cancel.
class FakeApi implements NotificationsApi {
  final Map<
    int,
    ({
      String title,
      String body,
      int at,
      String channelId,
      List<String>? lines,
      String? payload,
    })
  >
  scheduled = {};
  final List<int> cancelled = [];
  bool initialized = false;
  bool permission = true;

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async =>
      initialized = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    List<String>? lines,
    String? payload,
  }) async => scheduled[id] = (
    title: title,
    body: body,
    at: epochMs,
    channelId: channelId,
    lines: lines,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<String?> launchPayload() async => null;
}
