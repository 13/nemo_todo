import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the token the keystore holds', () async {
    FlutterSecureStorage.setMockInitialValues({'nemo_session_token': 'tok'});
    expect(await SecureAuthStorage().readToken(), 'tok');
  });

  test('writes a token and reads it back', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureAuthStorage();
    await storage.writeToken('fresh');
    expect(await storage.readToken(), 'fresh');
  });

  test('writing null forgets the token', () async {
    FlutterSecureStorage.setMockInitialValues({'nemo_session_token': 'tok'});
    final storage = SecureAuthStorage();
    await storage.writeToken(null);
    expect(await storage.readToken(), isNull);
  });
}
