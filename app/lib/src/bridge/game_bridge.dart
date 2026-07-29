import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class GameBridgeEnvelope {
  const GameBridgeEnvelope({
    required this.type,
    required this.requestId,
    this.payload = const <String, Object?>{},
  });

  static const int protocolVersion = 1;

  final String type;
  final String requestId;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocolVersion': protocolVersion,
    'type': type,
    'requestId': requestId,
    'payload': payload,
  };

  String encode() => jsonEncode(toJson());

  factory GameBridgeEnvelope.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid bridge JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Bridge envelope must be a JSON object.');
    }
    if (decoded['protocolVersion'] != protocolVersion) {
      throw FormatException(
        'Unsupported bridge protocol: ${decoded['protocolVersion']}',
      );
    }
    final Object? type = decoded['type'];
    final Object? requestId = decoded['requestId'];
    final Object? rawPayload = decoded['payload'];
    if (type is! String || type.isEmpty) {
      throw const FormatException('Bridge type must be a non-empty string.');
    }
    if (requestId is! String || requestId.isEmpty) {
      throw const FormatException(
        'Bridge requestId must be a non-empty string.',
      );
    }
    if (rawPayload is! Map<String, Object?>) {
      throw const FormatException('Bridge payload must be a JSON object.');
    }
    return GameBridgeEnvelope(
      type: type,
      requestId: requestId,
      payload: Map<String, Object?>.unmodifiable(rawPayload),
    );
  }
}

abstract final class GameBridgeTypes {
  static const String initialize = 'host.initialize';
  static const String applySettings = 'settings.apply';
  static const String saveChanged = 'save.changed';
  static const String ready = 'game.ready';
  static const String error = 'game.error';
}
