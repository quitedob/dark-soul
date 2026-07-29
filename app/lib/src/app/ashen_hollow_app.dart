import 'dart:async';

import 'package:ashen_hollow_app/src/controller/game_host_controller.dart';
import 'package:ashen_hollow_app/src/l10n/app_strings.dart';
import 'package:ashen_hollow_app/src/model/game_settings_v1.dart';
import 'package:flutter/material.dart';

class AshenHollowApp extends StatefulWidget {
  const AshenHollowApp({
    required this.controller,
    required this.gameSurface,
    this.disposeController = true,
    super.key,
  });

  final GameHostController controller;
  final Widget gameSurface;
  final bool disposeController;

  @override
  State<AshenHollowApp> createState() => _AshenHollowAppState();
}

class _AshenHollowAppState extends State<AshenHollowApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.handleLifecycle(true));
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.controller.handleLifecycle(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.disposeController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ashen Hollow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC26D3C),
          brightness: Brightness.dark,
          surface: const Color(0xFF151719),
        ),
        scaffoldBackgroundColor: const Color(0xFF090B0D),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFD88A52),
          thumbColor: Color(0xFFF2C08C),
        ),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          return _GameShell(
            controller: widget.controller,
            gameSurface: widget.gameSurface,
          );
        },
      ),
    );
  }
}

class _GameShell extends StatelessWidget {
  const _GameShell({required this.controller, required this.gameSurface});

  final GameHostController controller;
  final Widget gameSurface;

  @override
  Widget build(BuildContext context) {
    final bool showSurface = controller.hasActiveGame;
    final AppStrings strings = AppStrings.forLocale(controller.settings.locale);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 1.25,
            colors: <Color>[
              Color(0xFF26201D),
              Color(0xFF101316),
              Color(0xFF07090A),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (showSurface)
                RepaintBoundary(
                  key: const Key('game-surface'),
                  child: gameSurface,
                ),
              switch (controller.state) {
                GameHostState.launcher => _LauncherView(
                  controller: controller,
                  strings: strings,
                ),
                GameHostState.loading => _LoadingView(strings: strings),
                GameHostState.game => _GameOverlay(
                  controller: controller,
                  strings: strings,
                ),
                GameHostState.settings => _SettingsView(
                  controller: controller,
                  strings: strings,
                ),
                GameHostState.error => _ErrorView(
                  controller: controller,
                  strings: strings,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherView extends StatelessWidget {
  const _LauncherView({required this.controller, required this.strings});

  final GameHostController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(
                Icons.local_fire_department_outlined,
                size: 58,
                color: Color(0xFFE7A56F),
              ),
              const SizedBox(height: 24),
              Text(
                strings.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  letterSpacing: 5,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFFF4E8D9),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.tagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 3,
                  color: const Color(0xFFB79E88),
                ),
              ),
              const SizedBox(height: 28),
              _LanguageChoice(
                strings: strings,
                locale: controller.settings.locale,
                onChanged: (String locale) => unawaited(
                  controller.updateSettings(
                    controller.settings.copyWith(locale: locale),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${strings.embers}: ${controller.save.embers}  •  '
                '${strings.checkpoint}: ${controller.save.checkpointId}',
                key: const Key('save-summary'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB79E88)),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const Key('start-game'),
                onPressed: controller.startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(strings.enter),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-settings'),
                onPressed: controller.openSettings,
                icon: const Icon(Icons.tune_rounded),
                label: Text(strings.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('loading-state'),
      color: const Color(0xE6090B0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 24),
            Text(
              strings.loading,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 3,
                color: const Color(0xFFDAB792),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverlay extends StatelessWidget {
  const _GameOverlay({required this.controller, required this.strings});

  final GameHostController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton.filledTonal(
              key: const Key('game-settings'),
              tooltip: strings.settingsTooltip,
              onPressed: controller.openSettings,
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('exit-game'),
              tooltip: strings.exitTooltip,
              onPressed: controller.backToLauncher,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.controller, required this.strings});

  final GameHostController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final GameSettingsV1 settings = controller.settings;
    return ColoredBox(
      key: const Key('settings-state'),
      color: const Color(0xE6101214),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            margin: const EdgeInsets.all(24),
            color: const Color(0xF21A1D20),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        strings.settings,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(letterSpacing: 3),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('close-settings'),
                        onPressed: controller.closeSettings,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LanguageChoice(
                    strings: strings,
                    locale: settings.locale,
                    onChanged: (String locale) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(locale: locale),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingSlider(
                    label: strings.masterVolume,
                    value: settings.masterVolume,
                    minimum: 0,
                    maximum: 1,
                    onChanged: (double value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(masterVolume: value),
                      ),
                    ),
                  ),
                  _SettingSlider(
                    label: strings.music,
                    value: settings.musicVolume,
                    minimum: 0,
                    maximum: 1,
                    onChanged: (double value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(musicVolume: value),
                      ),
                    ),
                  ),
                  _SettingSlider(
                    label: strings.effects,
                    value: settings.effectsVolume,
                    minimum: 0,
                    maximum: 1,
                    onChanged: (double value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(effectsVolume: value),
                      ),
                    ),
                  ),
                  _SettingSlider(
                    label: strings.cameraSensitivity,
                    value: settings.cameraSensitivity,
                    minimum: 0.25,
                    maximum: 2,
                    onChanged: (double value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(cameraSensitivity: value),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('subtitles-setting'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.subtitles),
                    value: settings.subtitlesEnabled,
                    onChanged: (bool value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(subtitlesEnabled: value),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('reduced-motion-setting'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.reducedMotion),
                    subtitle: Text(strings.reducedMotionHint),
                    value: settings.reducedMotion,
                    onChanged: (bool value) => unawaited(
                      controller.updateSettings(
                        settings.copyWith(reducedMotion: value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.strings,
    required this.locale,
    required this.onChanged,
  });

  final AppStrings strings;
  final String locale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: strings.language,
      child: Center(
        child: SegmentedButton<String>(
          key: const Key('language-choice'),
          segments: <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: GameSettingsV1.supportedLocaleEnglish,
              label: Text(strings.english),
            ),
            ButtonSegment<String>(
              value: GameSettingsV1.supportedLocaleSimplifiedChinese,
              label: Text(strings.chinese),
            ),
          ],
          selected: <String>{locale},
          onSelectionChanged: (Set<String> selection) {
            if (selection.isNotEmpty) {
              onChanged(selection.first);
            }
          },
        ),
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value.toStringAsFixed(2),
      child: Row(
        children: <Widget>[
          SizedBox(width: 152, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: minimum,
              max: maximum,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.controller, required this.strings});

  final GameHostController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('error-state'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 52,
                color: Color(0xFFE7A56F),
              ),
              const SizedBox(height: 20),
              Text(
                strings.errorTitle,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(letterSpacing: 3),
              ),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage ?? strings.unknownError,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  OutlinedButton(
                    key: const Key('error-back'),
                    onPressed: controller.backToLauncher,
                    child: Text(strings.back),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: const Key('error-retry'),
                    onPressed: controller.retry,
                    child: Text(strings.retry),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
