import 'dart:async';

import 'package:ashen_hollow_app/src/host/game_host_client.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';

final class FakeGameHostClient implements GameHostClient {
  final StreamController<WebHostEvent> _events =
      StreamController<WebHostEvent>.broadcast();

  final List<String> calls = <String>[];
  final List<String> bridgeMessages = <String>[];
  bool failLoad = false;

  @override
  Stream<WebHostEvent> get events => _events.stream;

  void emit(WebHostEvent event) => _events.add(event);

  @override
  Future<void> attachView(int viewId) async {
    calls.add('attach:$viewId');
  }

  @override
  Future<void> disposeHost() async {
    calls.add('dispose');
  }

  @override
  Future<void> load(String source) async {
    calls.add('load:$source');
    if (failLoad) {
      throw StateError('load failed');
    }
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> sendBridgeJson(String json) async {
    calls.add('bridge');
    bridgeMessages.add(json);
  }

  Future<void> close() => _events.close();
}
