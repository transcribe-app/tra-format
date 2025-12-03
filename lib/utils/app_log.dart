// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:easy_logger/easy_logger.dart';
import 'package:logger/logger.dart';
import '/utils/file_io.dart';
import '/utils/sugar.dart' as sugar;

// import 'package:logging/logging.dart' as logging;
// final _loggingToLoggerLevel = {
//   logging.Level.ALL: Level.all,
//   logging.Level.FINEST: Level.trace,
//   logging.Level.FINER: Level.debug,
//   logging.Level.FINE: Level.info,
//   logging.Level.CONFIG: Level.info,
//   logging.Level.INFO: Level.info,
//   logging.Level.WARNING: Level.warning,
//   logging.Level.SEVERE: Level.error,
//   logging.Level.SHOUT: Level.fatal,
//   logging.Level.OFF: Level.off,
// };

class AppLogger {
  static Logger? log;
  static LogOutput? logOutput;
  static String lastLogFolder = "";
  static bool isVerbose = false;

  static Future<void> initialize(bool verbose) async {
    isVerbose = verbose;
    WidgetsFlutterBinding.ensureInitialized();
    try{
      lastLogFolder = (await getPath("Logs", true))!;
      clog(lastLogFolder, tag: "Logger");
      logOutput = AdvancedFileOutput(path: lastLogFolder, writeImmediately: [Level.error,Level.warning,Level.fatal], maxFileSizeKB: 5000, maxRotatedFilesCount:10);
    }catch(err){
      // skipping file output on unsupported platforms
    }
    log = Logger(
      output: logOutput, // Console if null
      printer: PrettyPrinter(
        methodCount: 0, // Number of method calls to be displayed
        errorMethodCount: 8, // Number of method calls if stacktrace is provided
        lineLength: 120, // Width of the output
        colors: false, // Colorful log messages
        printEmojis: true, // Print an emoji for each log message
        // Should each log print contain a timestamp
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      level: Level.all,
    );
  }

  static Future<void> deinitialize() async {
    if(log == null){
      return;
    }
    var prevLog = log;
    log = null;
    logOutput = null;
    await prevLog!.close();
  }

  static R? runZoned<R>(R Function() body) {
    return runZonedGuarded<R>(
      () {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (details) {
          reportError(details.exception, details.stack ?? StackTrace.current);
        };

        PlatformDispatcher.instance.onError = (error, stackTrace) {
          reportError(error, stackTrace);
          return true;
        };

        if (!kIsWeb) {
          Isolate.current.addErrorListener(
            RawReceivePort((pair) async {
              final isolateError = pair as List<dynamic>;
              reportError(
                isolateError.first.toString(),
                isolateError.last,
              );
            }).sendPort,
          );
        }

        return body();
      },
      (error, stackTrace) {
        reportError(error, stackTrace);
      },
    );
  }

  static Future<void> reportError(
    dynamic error, [
    StackTrace? stackTrace,
    message = "",
  ]) async {
    print("// reportError: ${message} | ${error.toString()}");
    print(stackTrace.toString());
    if(AppLogger.log != null){
      AppLogger.log!.e(message, error: error, stackTrace: stackTrace);
    }
    // TBD: Send to Crashlitics, as https://pub.dev/packages/talker#crashlytics-integration
  }

  static void elLogPrinter(
    Object object, {
    String? name,
    StackTrace? stackTrace,
    LevelMessages? level,
  }) {
    if(stackTrace != null){
      reportError(object, stackTrace);
      return;
    }
    clog(object, tag: name??"");
  }

}

void clog(dynamic value, {String tag = '', bool isWarning = false}) {
  if(tag.isEmpty){
    tag = "App";
  }
  debugPrint("$tag: ${value.toString()}");
  if(AppLogger.log != null){
    AppLogger.log!.log(isWarning?Level.warning:Level.info, "$tag: ${value.toString()}");
  }
}

void dlog(dynamic value, {bool isDebug = true}) {
  var canLog = true;
  if(!kDebugMode){
    if(isDebug && !AppLogger.isVerbose){
      canLog = false;
    }
  }
  if(!canLog){// Ignoring
    return;
  }
  debugPrint("// ${value.toString()}");
  if(AppLogger.logOutput != null){
    // AppLogger.logFile?.writeAsString("// ${value.toString()}", mode: FileMode.writeOnlyAppend, flush: true);
    var msg = "[${DateTime.now()}] ${value.toString()}";
    final levent = OutputEvent(LogEvent(Level.info, ""), [msg]);
    AppLogger.logOutput?.output(levent);
  }
}

int _isSendingLogsActive = 0;
Future<int> sendLogsWithEmail() async {
  if(AppLogger.lastLogFolder.isEmpty){
    return 0;
  }
  if(_isSendingLogsActive > 0){
    return 0;
  }
  _isSendingLogsActive++;
  var namepostf = sugar.dateAsYYYYMMDD(null, frm: "yyyyMMdd") + "-" + sugar.unixstamp().toString();
  var trgzip = tempFilePath("AppLogs${namepostf}","zip");
  clog("Saving logs: ${AppLogger.lastLogFolder}", isWarning: true);
  await AppLogger.deinitialize();
  var zipfile = await zipFolderIntoFile(AppLogger.lastLogFolder, trgzip);
  if(zipfile == null){
    _isSendingLogsActive--;
    return -1;
  }
  dlog("zip finished: ${zipfile}");
  AppLogger.initialize(AppLogger.isVerbose);
  // TBD: Send by email iOS/Android: https://pub.dev/packages/open_mail_launcher
  final params = ShareParams(
    title: '[TRANSCRIBE] Feedback',
    text: '<describe the issue in details>',
    files: [XFile(zipfile)],
  );
  final result = await SharePlus.instance.share(params);
  _isSendingLogsActive--;
  if (result.status == ShareResultStatus.dismissed) {
    return -1;
  }
  return 1;
}