import 'package:ashen_hollow_app/src/app/ashen_hollow_app.dart';
import 'package:ashen_hollow_app/src/controller/game_host_controller.dart';
import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:ashen_hollow_web_host/ashen_hollow_web_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_game_host_client.dart';

void main() {
  testWidgets('launcher exposes start and settings flows', (
    WidgetTester tester,
  ) async {
    final FakeGameHostClient host = FakeGameHostClient();
    final GameHostController controller = GameHostController(host: host);
    await tester.pumpWidget(
      AshenHollowApp(
        controller: controller,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );

    expect(find.text('ASHEN HOLLOW'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pump();
    expect(find.byKey(const Key('settings-state')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('start-game')));
    await tester.pump();
    expect(find.byKey(const Key('loading-state')), findsOneWidget);
    expect(find.byKey(const Key('game-surface')), findsOneWidget);

    await host.close();
  });

  testWidgets('native ready reveals game controls and settings overlay', (
    WidgetTester tester,
  ) async {
    final FakeGameHostClient host = FakeGameHostClient();
    final GameHostController controller = GameHostController(host: host);
    controller.startGame();
    await controller.attachPlatformView(9);
    await tester.pumpWidget(
      AshenHollowApp(
        controller: controller,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );

    host.emit(const WebHostEvent(type: 'ready', viewId: 9));
    await tester.pump();
    expect(find.byKey(const Key('game-settings')), findsOneWidget);

    await tester.tap(find.byKey(const Key('game-settings')));
    await tester.pump();
    expect(find.byKey(const Key('settings-state')), findsOneWidget);
    expect(find.byKey(const Key('game-surface')), findsOneWidget);

    await host.close();
  });

  testWidgets('language choice switches launcher and persists into settings', (
    WidgetTester tester,
  ) async {
    final FakeGameHostClient host = FakeGameHostClient();
    final GameHostController controller = GameHostController(host: host);
    await tester.pumpWidget(
      AshenHollowApp(
        controller: controller,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );

    await tester.tap(find.text('简体中文'));
    await tester.pump();
    expect(find.text('灰烬幽谷'), findsOneWidget);
    expect(find.text('踏入幽谷'), findsOneWidget);
    expect(
      controller.settings.locale,
      GameSettingsV1.supportedLocaleSimplifiedChinese,
    );

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pump();
    expect(find.text('主音量'), findsOneWidget);
    expect(find.text('减少动态效果'), findsOneWidget);

    await host.close();
  });
}
