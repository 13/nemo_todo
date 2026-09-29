import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/share/data/share_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelShareSource.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('decode', () {
    test('reads text, subject and pictures', () {
      final bytes = Uint8List.fromList([1, 2]);
      final content = ChannelShareSource.decode({
        'text': 'Hello',
        'subject': 'Hi',
        'images': [bytes, 'not bytes'],
      })!;
      expect(content.text, 'Hello');
      expect(content.subject, 'Hi');
      expect(content.images, [bytes]);
    });

    test('anything but a map, or an empty share, is nothing', () {
      expect(ChannelShareSource.decode(null), isNull);
      expect(ChannelShareSource.decode('text'), isNull);
      expect(
        ChannelShareSource.decode({'text': ' ', 'subject': null, 'images': 3}),
        isNull,
      );
    });
  });

  test('initial asks the activity for the launch share', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'text': 'From launch', 'images': <Uint8List>[]};
    });
    final source = ChannelShareSource();
    addTearDown(source.dispose);

    final content = await source.initial();

    expect(calls, ['initial']);
    expect(content?.text, 'From launch');
  });

  test('initial is nothing where the plugin is missing', () async {
    final source = ChannelShareSource();
    addTearDown(source.dispose);
    expect(await source.initial(), isNull);
  });

  test('a share pushed by the activity arrives on incoming', () async {
    final source = ChannelShareSource();
    addTearDown(source.dispose);
    final received = source.incoming.first;

    await messenger.handlePlatformMessage(
      ChannelShareSource.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('shared', {'text': 'While running'}),
      ),
      (_) {},
    );

    expect((await received).text, 'While running');
  });

  test('elsewhere nothing is ever shared', () async {
    const source = NoShareSource();
    expect(await source.initial(), isNull);
    expect(await source.incoming.isEmpty, isTrue);
  });

  test('the provider picks the channel on Android only', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final android = ProviderContainer();
    addTearDown(android.dispose);
    expect(android.read(shareSourceProvider), isA<ChannelShareSource>());

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final linux = ProviderContainer();
    addTearDown(linux.dispose);
    expect(linux.read(shareSourceProvider), isA<NoShareSource>());
  });
}
