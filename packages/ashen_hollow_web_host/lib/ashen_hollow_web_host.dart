library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const String ashenHollowWebHostViewType = 'ashen_hollow/web_host';
const String ashenHollowWebHostMethodChannel = 'ashen_hollow/web_host/methods';
const String ashenHollowWebHostEventChannel = 'ashen_hollow/web_host/events';
const int ashenHollowWebHostProtocolVersion = 1;

@immutable
class WebHostEvent {
  const WebHostEvent({
    required this.type,
    required this.viewId,
    this.payload = const <String, Object?>{},
    this.bridgeJson,
  });

  factory WebHostEvent.fromObject(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Web host event must be a map.');
    }
    final Object? protocolVersion = value['protocolVersion'];
    if (protocolVersion != ashenHollowWebHostProtocolVersion) {
      throw FormatException(
        'Unsupported web host protocol version: $protocolVersion',
      );
    }
    final Object? type = value['event'];
    final Object? viewId = value['viewId'];
    if (type is! String || viewId is! int) {
      throw const FormatException(
        'Web host event requires string event and integer viewId.',
      );
    }
    final Object? rawPayload = value['payload'];
    final Map<String, Object?> payload = rawPayload is Map<Object?, Object?>
        ? rawPayload.map(
            (Object? key, Object? item) =>
                MapEntry<String, Object?>(key.toString(), item),
          )
        : const <String, Object?>{};
    return WebHostEvent(
      type: type,
      viewId: viewId,
      payload: payload,
      bridgeJson: value['bridgeJson'] as String?,
    );
  }

  final String type;
  final int viewId;
  final Map<String, Object?> payload;
  final String? bridgeJson;
}

class AshenHollowWebHostController {
  AshenHollowWebHostController({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel(ashenHollowWebHostMethodChannel),
       _eventChannel =
           eventChannel ?? const EventChannel(ashenHollowWebHostEventChannel);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  int? _viewId;
  Stream<WebHostEvent>? _events;

  int? get viewId => _viewId;

  Stream<WebHostEvent> get events {
    return _events ??= _eventChannel
        .receiveBroadcastStream(const <String, Object?>{
          'protocolVersion': ashenHollowWebHostProtocolVersion,
        })
        .map<WebHostEvent>(WebHostEvent.fromObject)
        .asBroadcastStream();
  }

  Future<void> attachView(int viewId) async {
    _viewId = viewId;
    await _invoke('attach', const <String, Object?>{});
  }

  Future<void> load(String source) =>
      _invoke('load', <String, Object?>{'source': source});

  Future<void> pause() => _invoke('pause', const <String, Object?>{});

  Future<void> resume() => _invoke('resume', const <String, Object?>{});

  Future<void> sendBridgeJson(String json) =>
      _invoke('sendBridgeJson', <String, Object?>{'json': json});

  Future<void> disposeHost() async {
    if (_viewId == null) {
      return;
    }
    await _invoke('dispose', const <String, Object?>{});
    _viewId = null;
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    final int? id = _viewId;
    if (id == null) {
      throw StateError('The OHOS platform view is not attached.');
    }
    await _methodChannel.invokeMethod<void>(method, <String, Object?>{
      'protocolVersion': ashenHollowWebHostProtocolVersion,
      'viewId': id,
      ...arguments,
    });
  }
}

class AshenHollowWebHost extends StatelessWidget {
  const AshenHollowWebHost({
    required this.controller,
    required this.onPlatformViewCreated,
    this.initialSource = 'resource://rawfile/game/index.html',
    super.key,
  });

  final AshenHollowWebHostController controller;
  final ValueChanged<int> onPlatformViewCreated;
  final String initialSource;

  @override
  Widget build(BuildContext context) {
    return OhosView(
      viewType: ashenHollowWebHostViewType,
      creationParams: <String, Object?>{
        'protocolVersion': ashenHollowWebHostProtocolVersion,
        'initialSource': initialSource,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
}
