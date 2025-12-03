import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '/utils/app_log.dart';
import '/utils/sugar.dart' as sugar;
import '/config.dart';

String _getXdgStateHome() {
  // path_provider seems does not support XDG_STATE_HOME,
  // which is the specification to store application logs on Linux.
  // See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  if (const bool.hasEnvironment("XDG_STATE_HOME")) {
    String xdgStateHomeRaw = Platform.environment["XDG_STATE_HOME"] ?? "";
    if (xdgStateHomeRaw.isNotEmpty) {
      return xdgStateHomeRaw;
    }
  }
  return path.join(Platform.environment["HOME"] ?? "", ".local", "state");
}

Future<String?> getPath(String subsection, bool ensureExist) async {
  if(!kIsDesktop){
    return null;
  }
  String dir = (await getApplicationDocumentsDirectory()).path;
  if (kIsAndroid) {
    dir = (await getExternalStorageDirectory())?.path ?? "";
  }
  if (kIsMacOS) {
    dir = (await getLibraryDirectory()).path;
  }
  if (kIsLinux) {
    dir = path.join(_getXdgStateHome(), kAppTag);
  }
  dir = path.join(dir, subsection);
  if(ensureExist){
    final Directory newDirectory = Directory(dir);
    if (!await newDirectory.exists()) {
      await newDirectory.create(recursive: true);
    }
  }
  return dir;
}

Future<String?> zipFolderIntoFile(String pathFolderToZip, String pathToFile) async {
  final directory = Directory(pathFolderToZip);
  if (!await directory.exists()) {
    clog('Source directory does not exist: $pathFolderToZip');
    return null;
  }
  final encoder = ZipFileEncoder();
  encoder.create(pathToFile);
  await for (final entity in directory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: pathFolderToZip);
      await encoder.addFile(entity, relativePath);
    }
  }
  await encoder.close();
  return pathToFile;
}

String tempFilePath(String namepref, String ext) {
  Directory tempDir = Directory.systemTemp;
  var tmppath = path.join(tempDir.absolute.path, "${namepref}.${ext}");
  return tmppath;
}