import 'package:ashen_hollow_app/src/host/game_host_client.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';

final class WebGameHostClient implements GameHostClient {
  WebGameHostClient(this._controller);

  final AshenHollowWebHostController _controller;

  @override
  Stream<WebHostEvent> get events => _controller.events;

  @override
  Future<void> attachView(int viewId) => _controller.attachView(viewId);

  @override
  Future<void> disposeHost() => _controller.disposeHost();

  @override
  Future<void> load(String source) => _controller.load(source);

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> resume() => _controller.resume();

  @override
  Future<void> sendBridgeJson(String json) => _controller.sendBridgeJson(json);
}
