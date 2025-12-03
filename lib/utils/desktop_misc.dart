// ignore_for_file: avoid_print

import 'dart:ui';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'app_prefs.dart';
import '/utils/app_log.dart';
import '/config.dart';

Future<String> getAppVersion() async {
  final package = await PackageInfo.fromPlatform();
  return package.version;
}

class WindowSize {
  final double height;
  final double width;
  final bool maximized;

  WindowSize({
    required this.height,
    required this.width,
    required this.maximized,
  });

  factory WindowSize.fromJson(Map<String, dynamic> json) => WindowSize(
        height: json["height"],
        width: json["width"],
        maximized: json["maximized"],
      );

  Map<String, dynamic> toJson() => {
        "height": height,
        "width": width,
        "maximized": maximized,
      };
}

class WindowManagerTools with WidgetsBindingObserver {
  // late final static AppLifecycleListener _listener;
  static WindowManagerTools? _instance;
  static WindowManagerTools get instance => _instance!;

  WindowManagerTools._();

  static Future<void> initialize() async {
    // _listener = AppLifecycleListener(
    //   onShow: () => _handleTransition('show'),
    //   onResume: () => _handleTransition('resume'),
    //   onHide: () => _handleTransition('hide'),
    //   onInactive: () => _handleTransition('inactive'),
    //   onPause: () => _handleTransition('pause'),
    //   onDetach: () => _handleTransition('detach'),
    //   onRestart: () => _handleTransition('restart'),
    //   // This fires for each state change. Callbacks above fire only for
    //   // specific state transitions.
    //   onStateChange: _handleStateChange,
    // );
    if (!kIsDesktop) {
      return;
    }
    await windowManager.ensureInitialized();
    // await windowManager.setPreventClose(true);
    // windowManager.addListener();
    _instance = WindowManagerTools._();
    WidgetsBinding.instance.addObserver(instance);
    var wndOpts = WindowOptions(
        title: kAppTag,// Non-localizable at this point
        backgroundColor: Colors.transparent,
        minimumSize: Size(700, 300),
        // titleBarStyle: TitleBarStyle.hidden,
        center: true,
      );
    await windowManager.waitUntilReadyToShow(wndOpts, () async {
        final savedSize = KVStoreService.windowSize;
        await windowManager.setResizable(true);
        if (savedSize?.maximized == true &&
            !(await windowManager.isMaximized())) {
          await windowManager.maximize();
        } else if (savedSize != null) {
          await windowManager.setSize(Size(savedSize.width, savedSize.height));
        }

        await windowManager.focus();
        await windowManager.show();
      },
    );
  }

  static Future<void> updateAppWindowTitle(String title) async {
    if (!kIsDesktop) {
      return;
    }
    await windowManager.setTitle(title);
  }

  Size? _prevSize;
  @override
  void didChangeMetrics() async {
    super.didChangeMetrics();
    if (kIsMobile) return;
    final size = await windowManager.getSize();
    final windowSameDimension =
        _prevSize?.width == size.width && _prevSize?.height == size.height;

    if (windowSameDimension || _prevSize == null) {
      _prevSize = size;
      return;
    }
    final isMaximized = await windowManager.isMaximized();
    await KVStoreService.windowSize_set(
      WindowSize(
        height: size.height,
        width: size.width,
        maximized: isMaximized,
      ),
    );
    _prevSize = size;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    clog(["State",state],isWarning:true);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    clog(["State","Exit"],isWarning:true);
    await AppLogger.deinitialize();
    return AppExitResponse.exit;
  }
}

void appShowAlert(BuildContext context, String alert_title, String alert_text) {
  if(!context.mounted){
    return;
  }
  // Standard Flutter API to present a dialog above the current route.
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(alert_title),
        content: Text(alert_text),
        actions: [
          // // Secondary action to cancel/dismiss.
          // OutlineButton(
          //   child: const Text('Cancel'),
          //   onPressed: () {
          //     // Close the dialog.
          //     Navigator.pop(context);
          //   },
          // ),
          // Primary action to accept/confirm.
          PrimaryButton(
            child: Text(context.tr('bt:OK')),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}