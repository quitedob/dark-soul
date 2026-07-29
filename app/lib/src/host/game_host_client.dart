import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';

abstract interface class GameHostClient {
  Stream<WebHostEvent> get events;

  Future<void> attachView(int viewId);

  Future<void> load(String source);

  Future<void> pause();

  Future<void> resume();

  Future<void> sendBridgeJson(String json);

  Future<void> disposeHost();
}
