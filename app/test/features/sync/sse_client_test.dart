import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/sync/data/sse_client.dart';

void main() {
  test('reads event names out of a chunk of frames', () {
    expect(SseClient.eventsIn(': connected\n\n'), isEmpty);
    expect(SseClient.eventsIn('event: changed\ndata: {}\n\n'), ['changed']);
    expect(
      SseClient.eventsIn(
        'event: changed\ndata: {}\n\n: ping\n\nevent: changed\ndata: {}\n\n',
      ),
      ['changed', 'changed'],
    );
    expect(SseClient.eventsIn('data: partial'), isEmpty);
  });
}
