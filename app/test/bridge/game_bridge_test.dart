import 'package:ashen_hollow_app/src/bridge/game_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioned bridge envelope round-trips', () {
    const GameBridgeEnvelope envelope = GameBridgeEnvelope(
      type: GameBridgeTypes.initialize,
      requestId: 'flutter-1',
      payload: <String, Object?>{'answer': 42},
    );

    final GameBridgeEnvelope decoded = GameBridgeEnvelope.decode(
      envelope.encode(),
    );

    expect(decoded.type, envelope.type);
    expect(decoded.requestId, envelope.requestId);
    expect(decoded.payload, envelope.payload);
  });

  test('bridge rejects unsupported protocol version', () {
    expect(
      () => GameBridgeEnvelope.decode(
        '{"protocolVersion":2,"type":"game.ready",'
        '"requestId":"game-1","payload":{}}',
      ),
      throwsFormatException,
    );
  });
}
