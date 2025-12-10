import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:solidart_hooks/solidart_hooks.dart';
import 'package:disco/disco.dart';
import '/utils/file_tra.dart';

final kAppTag = "tra_viewer";
final kIsDebug = !(kReleaseMode || kProfileMode);

final kIsDesktop = kIsLinux || kIsWindows || kIsMacOS;
final kIsMobile = kIsAndroid || kIsIOS;
final kIsBrowser = kIsWeb || kIsWasm;
final kIsFlatpak = kIsBrowser ? false : Platform.environment["FLATPAK_ID"] != null;
final kIsMacOS = kIsBrowser ? false : Platform.isMacOS;
final kIsLinux = kIsBrowser ? false : Platform.isLinux;
final kIsAndroid = kIsBrowser ? false : Platform.isAndroid;
final kIsIOS = kIsBrowser ? false : Platform.isIOS;
final kIsWindows = kIsBrowser ? false : Platform.isWindows;

class AppConfig {

  static final supportedLocales = [
    material.Locale('en', 'US'),// First is default
    material.Locale('it', 'IT'),
  ];
  static final supportedFontModes = [
    ["Default",'xLarge'],
    ["Large",'x2Large'],
    ["Small",'large']
  ];
  static final supportedThemes = [
    // https://sunarya-thito.github.io/shadcn_flutter/#/theme
    ["Light Blue",'lightBlue'],
    ["Dark Blue",'darkBlue'],
    ["Light Neutral",'lightDefaultColor'],
    ["Dark Neutral",'darkDefaultColor'],
    ["Light Orange",'lightOrange'],
    ["Dark Orange",'darkOrange']
  ];

}

class AppState {

    var stateChange = Signal(0);
    var stateChangeIsRestored = false;

    var uiLang = AppConfig.supportedLocales[0];
    var uiViewerFontMode = 0;// supportedFontModes
    var uiTheme = 0;// supportedThemes
    TraData? activeTra;
    var activeTraAutoplay = false;

    var globalAnimationEndExpectancy = 0;
}

final vAppStateProvider = Provider<AppState>(
  (context) => AppState(),
  dispose: (controller) => {},
);