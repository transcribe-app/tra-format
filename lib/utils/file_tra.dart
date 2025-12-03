import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:super_editor/super_editor.dart';
import 'package:g_json/g_json.dart';
import '/components/traview_wi.dart' as TraViewWi;
import '/utils/mime_relaxed/mime_relaxed.dart';
import '/config.dart';
import '/utils/app_log.dart';
import '/utils/sugar.dart' as sugar;

enum TraStatus {
  unknown(-1, 'Unknown'),
  ok(200, 'Ready'),
  errorFormat(500, 'Invalid format'),
  errorParsingMime(501, 'MIME Parsing failed');

  const TraStatus(this.code, this.description);
  final int code;
  final String description;

  @override
  String toString() => 'TraStatus($code, $description)';

  static TraStatus? fromCode(int code) {
    var value = TraStatus.values.firstOrNull;
    if(value == null){
      return null;
    }
    return value;
  }
}
class TraData {
  double duration = 0;
  int createdAt = 0;
  String title = "";
  String language = "";
  String audioPath = "";
  JSON deltaHeader = JSON({});
  List<JSON> deltaContent = [];

  // Editor nodes for async preparation
  List<DocumentNode>? enodes;

  @override
  String toString(){
    return "{title:'${title}', language:'${language}', duration:${duration}, audioPath:'${audioPath}'}";
  }
}
typedef TraParsingArgs = (RootIsolateToken, Uint8List);
typedef TraParsingResult = (TraStatus, TraData?);
typedef TraParser = void Function(TraStatus, TraData?);
void parseTraWithCallback(Uint8List traBytes, TraParser onComplete) async {
  // https://stackoverflow.com/questions/72294203/how-to-parse-an-http-multipart-mixed-response-in-dart-flutter
  if(traBytes.length < 3){
    onComplete(TraStatus.errorFormat,null);
    return;
  }
  RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
  Future<TraParsingResult> parseBytes(TraParsingArgs traArgs) async {
      Uint8List traBytes = traArgs.$2;
      RootIsolateToken isolateToken = traArgs.$1;
      BackgroundIsolateBinaryMessenger.ensureInitialized(isolateToken);
      var traFirstChunkLen = traBytes.indexOfSeq(ascii.encode("\n--"));
      if(traFirstChunkLen < 0){
        clog("- TRA parsing error: no multiparts found");
        return (TraStatus.errorFormat,null);
      }
      var traBytesHeader = traBytes.sublist(0, traFirstChunkLen);
      var traLfOnly = false;
      if(traBytesHeader.indexOfSeq(ascii.encode("\r\n")) < 0){
        traLfOnly = true;
      }
      String traFirstChunk = utf8.decode(traBytesHeader);
      // clog("- TRA header block: ${traFirstChunk}");
      var contentType = sugar.strHeaderGet(traFirstChunk,"Content-Type","");
      if (contentType.isEmpty) {
        clog("- TRA parsing error: no contentType");
        return (TraStatus.errorFormat,null);
      }
      final boundary = sugar.strSubHeaderGet(contentType,"boundary","");
      if (boundary.isEmpty) {
        clog("- TRA parsing error: no boundary");
        return (TraStatus.errorFormat,null);
      }
      clog("- TRA length: ${traBytes.length}; boundary: ${boundary} ${traLfOnly}");
      var traData = TraData();
      traData.title = sugar.strHeaderGet(traFirstChunk,"Transcription-Filename","");
      traData.language = sugar.strHeaderGet(traFirstChunk,"Transcription-Lang","");
      traData.duration = double.tryParse(sugar.strHeaderGet(traFirstChunk,"Transcription-Duration","")) ?? 0;
      traData.createdAt = int.tryParse(sugar.strHeaderGet(traFirstChunk,"Transcription-Created","")) ?? 0;
      try{
        var traDataJson = "";
        var tmpJsonName = "";
        var tmpAudioName = "";
        final transformer = MimeMultipartTransformer(boundary, traLfOnly);
        final traBytesList = List<int>.from(traBytes);
        final List<List<int>> traBytesListL = [traBytesList];
        final bodyStream = Stream.fromIterable(traBytesListL);
        List<MimeMultipart> parts = await transformer.bind(bodyStream).toList();
        for (MimeMultipart multipart in parts) {
          // List<String> bodystr = await multipart.single.asStream().map(((event) => utf8.decode(event, allowMalformed: true))).toList();
          // To avoid upper/lower case checks getting headers as string blob
          List<String> headers_kvp = multipart.headers.entries.map((entry) {
            return '${entry.key}:${entry.value}';
          }).toList();
          var headers_all = headers_kvp.join("\n")+"\n";
          var part_name = sugar.strSubHeaderGet(headers_all, "filename", "");
          var part_type = sugar.strHeaderGet(headers_all, "Content-Type", "");
          var body = await multipart.single;
          var xlen = body.length;
          clog("- TRA part: name=${part_name} type=${part_type} headers=${multipart.headers} len=${xlen}");
          // File ".json" or type "application/json", grouped/merged by file name = delta
          // - first json = main
          if(part_name.contains(".json") || part_type == "application/json"){
            if(tmpJsonName.isEmpty){
              tmpJsonName = part_name;
            }
            if(tmpJsonName == part_name){
              traDataJson = traDataJson + utf8.decode(body);
            }
          }
          // File ".mp3" or type "audio/..." or type "application/octet-stream", grouped/merged by file name = audio
          // - first audio = main
          if(part_name.contains(".mp3") || part_type.contains("audio/") || part_type == "application/octet-stream"){
            if(tmpAudioName.isEmpty){
              tmpAudioName = part_name;
              // Creating temporary file for appending audio data
              // var dir = Directory.systemTemp.createTempSync();
              // var temp = File("${dir.path}/$fileName").createSync();
              final tmpDirectory = (await getTemporaryDirectory()).path;
              traData.audioPath = path.join(tmpDirectory,sugar.sanitizeFilename(kAppTag+"_"+sugar.unixstamp().toString()+"_"+part_name));
            }
            if(tmpAudioName == part_name && traData.audioPath.isNotEmpty){
              final extractedFile = File(traData.audioPath);
              await extractedFile.create(recursive: true);
              await extractedFile.writeAsBytes(body, mode: FileMode.writeOnlyAppend, flush: true);
            }
          }
        }
        List<JSON> textDelta = JSON.parse(traDataJson).listValue;
        if(textDelta.isNotEmpty){
          traData.deltaHeader = textDelta[0];
          traData.deltaContent = textDelta.sublist(1);
        }
        clog("- parsing finished. TRA: ${traData.toString()}");
      }catch(e){
        clog("- TRA parsing error: mime parsing failed. Error: ${e}");
        return (TraStatus.errorParsingMime,null);
      }
      // TraViewWi.prepareDocumentNodes(traData);
      return (TraStatus.ok,traData);
  }
  final parseTuple = await compute<TraParsingArgs, TraParsingResult>(parseBytes, (rootIsolateToken,traBytes)); //await Isolate.run<TraParsingResult>(parseBytes);
  var parseResult = parseTuple.$1;
  var parseData = parseTuple.$2;
  // onComplete(parseResult,parseData);
  Future.delayed(Duration(seconds: 1), (){
      onComplete(parseResult,parseData);
  });
}