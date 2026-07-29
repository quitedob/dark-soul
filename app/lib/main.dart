import 'package:ashen_hollow_app/src/app/ashen_hollow_app.dart';
import 'package:ashen_hollow_app/src/controller/game_host_controller.dart';
import 'package:ashen_hollow_app/src/host/web_game_host_client.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final AshenHollowWebHostController platformController =
      AshenHollowWebHostController();
  final GameHostController gameController = GameHostController(
    host: WebGameHostClient(platformController),
  );
  runApp(
    AshenHollowApp(
      controller: gameController,
      gameSurface: AshenHollowWebHost(
        controller: platformController,
        onPlatformViewCreated: gameController.attachPlatformView,
      ),
    ),
  );
}
