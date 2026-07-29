import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebHostEvent validates and decodes native contract', () {
    final WebHostEvent event = WebHostEvent.fromObject(<String, Object?>{
      'protocolVersion': 1,
      'viewId': 12,
      'event': 'bridgeMessage',
      'bridgeJson': '{"protocolVersion":1}',
      'payload': <String, Object?>{'loaded': true},
    });

    expect(event.viewId, 12);
    expect(event.type, 'bridgeMessage');
    expect(event.payload['loaded'], isTrue);
  });

  test('WebHostEvent rejects unknown protocol versions', () {
    expect(
      () => WebHostEvent.fromObject(<String, Object?>{
        'protocolVersion': 9,
        'viewId': 1,
        'event': 'ready',
      }),
      throwsFormatException,
    );
  });
}
