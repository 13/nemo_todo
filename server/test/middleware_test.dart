import 'package:nemo_server/nemo_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  Request request(String? forwarded) => Request(
    'GET',
    Uri.parse('http://localhost/x'),
    headers: forwarded == null ? {} : {'x-forwarded-for': forwarded},
  );

  test('the forwarding header is ignored unless a proxy is declared', () {
    // Nothing stops a client from sending this header itself, so it is
    // only worth reading when a proxy we run is known to rewrite it.
    expect(clientIp(request('1.2.3.4')), 'unknown');
    expect(clientIp(request('1.2.3.4'), trustedProxyHops: 1), '1.2.3.4');
  });

  test('only the entries our own proxies appended are trusted', () {
    // A client that prepends an address of its own choosing shifts the
    // list; counting from the right lands on what the proxy actually saw.
    expect(
      clientIp(request('9.9.9.9, 1.2.3.4'), trustedProxyHops: 1),
      '1.2.3.4',
    );
    expect(
      clientIp(request('9.9.9.9, 1.2.3.4, 5.6.7.8'), trustedProxyHops: 2),
      '1.2.3.4',
    );
  });

  test('more declared hops than entries falls back to the first', () {
    expect(clientIp(request('1.2.3.4'), trustedProxyHops: 5), '1.2.3.4');
    expect(clientIp(request(null), trustedProxyHops: 1), 'unknown');
  });
}
