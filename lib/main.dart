import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:disco/disco.dart';
import 'package:solidart_hooks/solidart_hooks.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/easy_logger.dart';
import '/utils/desktop_misc.dart';
import '/utils/shadcn_misc.dart';
import '/utils/app_prefs.dart';
import '/utils/app_log.dart';

import '/router.dart';
import '/config.dart';


Future<ArgResults> parseCLI(List<String> args) async {
  final parser = ArgParser();
  parser.addSeparator("TRA viewer. Supported formats:");
  parser.addSeparator("- TRA format");
  parser.addSeparator("- MP3 with SYLT Lyrics");
  parser.addSeparator("- MP3 with USLT Lyrics with LRC formatting");
  parser.addSeparator("- MP3 with Lyrics3v2 Lyrics");
  parser.addFlag("verbose",abbr: 'v', help: 'Verbose mode',defaultsTo: kIsDebug);
  parser.addFlag("version",help: "Print version and exit",negatable: false);
  parser.addFlag("help", abbr: "h", negatable: false);

  final arguments = parser.parse(args);
  if (arguments["help"] == true) {
    print(parser.usage);
    exit(0);
  }

  if (arguments["version"] == true) {
    var version = await getAppVersion();
    print("${kAppTag} v${version}");
    exit(0);
  }

  return arguments;
}

void main(List<String> rawArgs) async {
  final arguments = await parseCLI(rawArgs);
  AppLogger.runZoned(() async {
    // Important for EasyLocalization && Logger
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.initialize(arguments["verbose"]);
    await KVStoreService.initialize();
    EasyLocalization.logger.printer = AppLogger.elLogPrinter;
    EasyLocalization.logger.enableLevels = [LevelMessages.error, LevelMessages.warning];
    await EasyLocalization.ensureInitialized();

    var appVersion = await getAppVersion();
    var appLocale = AppConfig.supportedLocales[0]; // context.deviceLocale.toString();
    await WindowManagerTools.initialize();
    clog(["State","Start","${kAppTag} v${appVersion}"]);

    runApp(
      EasyLocalization(
        startLocale: appLocale,
        supportedLocales: AppConfig.supportedLocales,
        fallbackLocale: AppConfig.supportedLocales[0],
        useFallbackTranslations: true,
        useFallbackTranslationsForEmptyResources: true,
        useOnlyLangCode: true,
        saveLocale: false,
        path: 'assets/i18n',
        child: ProviderScope(
              providers: [
                vAppStateProvider,
              ],
              child:MainApp()
            )
      ),
    );
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = vAppStateProvider.of(context);//  = Data.of(context);
    restoreAppStateFromPrefs(appState);
    final stateChange = Computed(() => appState.stateChange.value);
    return  SignalBuilder( builder: (context, child) {
        stateChange();
        context.setLocale(appState.uiLang);
        var uiTypography = ShadTypography.withFontFamily('Roboto');
        var uiTheme = ThemeData(
            typography: uiTypography,
            colorScheme: resolveUiTheme(appState),
            surfaceOpacity: .8,
            surfaceBlur: 10,
            radius: 0.5,
          );
        return ShadcnApp.router(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          onGenerateTitle: (context) { 
            var title = context.tr('app:WindowTitle');
            WindowManagerTools.updateAppWindowTitle(title);
            return title;
          },
          scaling: const AdaptiveScaling(1),
          themeMode: ThemeMode.light,
          theme: uiTheme,
          darkTheme: uiTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false
        );
    });
  }
}
