import 'dart:async';
import 'dart:convert';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import 'package:shared_preferences/shared_preferences.dart';
import '/config.dart';
import '/utils/desktop_misc.dart';
import '/utils/sugar.dart' as sugar;

abstract class KVStoreService {
  static SharedPreferences? _sharedPreferences;
  static SharedPreferences get sharedPreferences => _sharedPreferences!;

  static Future<void> initialize() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  static material.Locale get uiLang {
    final languageCode = sharedPreferences.getString('uiLang');
    if (languageCode == null) {
      return AppConfig.supportedLocales[0];
    }
    return material.Locale(languageCode);
  }
  static Future<void> uiLang_set(material.Locale value) async {
      await sharedPreferences.setString('uiLang',value.languageCode);
  }

  static int get uiViewerFontMode =>
      sharedPreferences.getInt('uiViewerFontMode') ?? 0;
  static Future<void> uiViewerFontMode_set(int value) async =>
      await sharedPreferences.setInt('uiViewerFontMode', value);

  static int get uiTheme =>
      sharedPreferences.getInt('uiTheme') ?? 0;
  static Future<void> uiTheme_set(int value) async =>
      await sharedPreferences.setInt('uiTheme', value);

  static WindowSize? get windowSize {
    final raw = sharedPreferences.getString('windowSize');
    if (raw == null) {return null;}
    return WindowSize.fromJson(jsonDecode(raw));
  }
  static Future<void> windowSize_set(WindowSize value) async {
      await sharedPreferences.setString('windowSize',jsonEncode(value.toJson()));
  }
}

void restoreAppStateFromPrefs(AppState appState) {
  if(appState.stateChangeIsRestored){
    // Nothing changed
    return;
  }
  // material.debugPrint("// restoreAppStateFromPrefs");

  // ui lang
  var prefUiLang = KVStoreService.uiLang;
  for (var item in AppConfig.supportedLocales){
    if(prefUiLang.languageCode == item.languageCode){
      appState.uiLang = item;
      break;
    }
  }

  // Viewer Font Size
  appState.uiViewerFontMode = KVStoreService.uiViewerFontMode;
  if(appState.uiViewerFontMode < 0 || appState.uiViewerFontMode >= AppConfig.supportedFontModes.length){
    appState.uiViewerFontMode = 0;
  }

  // ui theme
  appState.uiTheme = KVStoreService.uiTheme;
  if(appState.uiTheme < 0 || appState.uiTheme >= AppConfig.supportedThemes.length){
    appState.uiTheme = 0;
  }

  appState.stateChangeIsRestored = true;
}

Future<void> saveAppStateToPrefs(AppState appState) async {
  // material.debugPrint("// saveAppStateToPrefs");
  // ui lang
  await KVStoreService.uiLang_set(appState.uiLang);
  // Viewer Font Size
  await KVStoreService.uiViewerFontMode_set(appState.uiViewerFontMode);
  // ui theme
  await KVStoreService.uiTheme_set(appState.uiTheme);
}

void bumpAppState(AppState appState, bool isPrimary, {int expectAnimMs = 0}) {
  // Triggering UI rebuilds
  appState.stateChange.value = appState.stateChange.value+1;
  appState.globalAnimationEndExpectancy = sugar.unixstamp_ms()+expectAnimMs;
  if(isPrimary){
    // Saving to prefs
    unawaited(saveAppStateToPrefs(appState));
  }
}

TextStyle resolveUiViewerFontMode(BuildContext context) {
  final appState = vAppStateProvider.of(context);
  final uiTheme = Theme.of(context);
  final uiTypography = uiTheme.typography;
  var uiTextStyle = switch (AppConfig.supportedFontModes[appState.uiViewerFontMode][1])
    {
      'large' => uiTypography.large,
      'xLarge' => uiTypography.xLarge,
      'x2Large' => uiTypography.x2Large,
      _ => uiTypography.large
    };
  uiTextStyle = uiTextStyle.copyWith(color: uiTheme.colorScheme.foreground);//accentForeground
  return uiTextStyle;
}

ColorScheme resolveUiTheme(AppState appState) {
  var uiColorTheme = switch (AppConfig.supportedThemes[appState.uiTheme][1])
    {
      'lightBlue' => LegacyColorSchemes.lightBlue(),
      'darkBlue' => LegacyColorSchemes.darkBlue(),
      'lightDefaultColor' => LegacyColorSchemes.lightNeutral(),
      'darkDefaultColor' => LegacyColorSchemes.darkNeutral(),
      'lightOrange' => LegacyColorSchemes.lightOrange(),
      'darkOrange' => LegacyColorSchemes.darkOrange(),
      _ => LegacyColorSchemes.lightBlue()
    };
  return uiColorTheme;
}