import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:g_json/g_json.dart';
import '/utils/mp3_tags/id3tag.dart';
import '/components/traview_wi.dart' as TraViewWi;
import '/config.dart';
import '/utils/file_tra.dart';
import '/utils/app_log.dart';
import '/utils/sugar.dart' as sugar;

TraStatus fillTraFromLRC(TraData traData, String mp3_header, String lrc_tex) {
  // debugPrint("fillTraFromLRC:" + lrc_tex);
  lrc_tex = lrc_tex.replaceAll("\r\n", "\n");
  traData.deltaHeader = JSON.parse('{"doc":"json_v2","tm":"char"}');
  var lrc_lines = ['{"ph":1, "ts": -1, "he": ${jsonEncode(mp3_header)}}'];
  try {
    if(lrc_tex.isNotEmpty){
      int countF = lrc_tex.split("[").length;
      int countT = lrc_tex.split("]").length;
      if(countF == 0 || countF != countT){
        // Not LRC, adding content as is, single word
        lrc_lines.add('{"wr":${jsonEncode(lrc_tex)}}');
      }else{
        // Adding fake final stamp for parsing simplification, ignored
        lrc_tex = lrc_tex+"[-1:-1]";
        // Splitting by LRC timings
        var start = 0;
        var start_sec = -1.0;
        var lrc_rgx = RegExp(r'\[([\d.-]+):([\d.-]+?)\]');
        for (var match in lrc_rgx.allMatches(lrc_tex, start)) {
          if(start_sec >= 0){
            // From the end of previous match to current match
            var lrc_line_text = lrc_tex.substring(start, match.start);
            if(lrc_line_text.isNotEmpty){
              traData.duration = max(traData.duration,start_sec.toDouble());
              lrc_lines.add('{"wr":${jsonEncode(lrc_line_text)},"ts":${start_sec.toStringAsFixed(2)}}');
            }
            // debugPrint("fillTraFromLRC: < ${start_sec} | ${lrc_line_text}>");
          }
          var lrc_line_sec = ((int.tryParse(match[1]??"0")??0)*60 + (double.tryParse(match[2]??"0")??0)).toDouble();
          start = match.end;
          start_sec = lrc_line_sec;
        }
        // var lrc_line_text_last = lrc_tex.substring(start);
      }
    }else{
      // Something wrong
      lrc_lines.add('{"wr":"<empty>"}');
    }
  } catch(err){
    // Something wrong
    clog("- TRA: fillTraFromLRC: failed to parse LRC:"+[err,lrc_tex].toString());
    lrc_lines.add('{"wr":"<parsing error>"}');
  }
  // debugPrint("fillTraFromLRC: parsed <"+lrc_lines.join(",")+">");
  traData.deltaContent = JSON.parse('['+lrc_lines.join(",")+']').listValue;
  TraViewWi.prepareDocumentNodes(traData);
  return TraStatus.ok;
}

void parseMp3WithCallback(String fileName, Uint8List traBytes, TraParser onComplete) async {
  final tmpDirectory = (await getTemporaryDirectory()).path;
  var traData = TraData();
  traData.title = fileName;
  traData.audioPath = path.join(tmpDirectory,sugar.sanitizeFilename(kAppTag+"_"+sugar.unixstamp().toString()+"_"+fileName));
  final extractedFile = File(traData.audioPath);
  await extractedFile.create(recursive: true);
  await extractedFile.writeAsBytes(traBytes, mode: FileMode.writeOnlyAppend, flush: true);
  final mp3_parser = ID3TagReader.path(traData.audioPath);
  final mp3_tags = mp3_parser.readTagSync();
  var mp3_header = fileName;
  if(mp3_tags.title != null){
    mp3_header = mp3_tags.title!;
  }
  if(mp3_tags.album != null){
    mp3_header = mp3_tags.album! + " / " + mp3_header;
  }
  var tra_status = TraStatus.errorFormat;
  // debugPrint("MP3 frames:" + mp3_tags.tagVersion+":"+mp3_tags.frames.toString());
  if(tra_status != TraStatus.ok){
    // Place 1 - SYLT https://id3.org/id3v2.4.0-structure https://id3.org/d3v2.3.0
    var lyricsSYLT = mp3_tags.lyricsSYLT;
    if(lyricsSYLT.isNotEmpty){
      var lrc_tex = '';
      for(var fr in lyricsSYLT){
        lrc_tex = lrc_tex + (lrc_tex.isNotEmpty?"\n":"") + fr.lyrics;
        traData.duration = max(traData.duration,fr.lastStamp/1000.0);
      }
      tra_status = fillTraFromLRC(traData, mp3_header, lrc_tex);
    }
  }
  if(tra_status != TraStatus.ok){
    // Place 2 - USLT
    var lyricsUSLT = mp3_tags.lyricsUSLT;// Sometimes LRC is here
    if(lyricsUSLT.isNotEmpty){
      var lrc_tex = '';
      for(var fr in lyricsUSLT){
        lrc_tex = lrc_tex + (lrc_tex.isNotEmpty?"\n":"") + fr.lyrics;
      }
      tra_status = fillTraFromLRC(traData, mp3_header, lrc_tex);
    }
  }
  if(tra_status != TraStatus.ok){
    // Place 3 - https://id3.org/Lyrics3v2
    var lyrFrom = traBytes.indexOfSeq(ascii.encode("LYRICSBEGIN"));
    var lyrTo = traBytes.indexOfSeq(ascii.encode("LYRICS200"));
    if(lyrFrom >= 0 && lyrTo >= 0){
      var mp3LyrcFull = traBytes.sublist(lyrFrom, lyrTo);
      var lyrFrom2 = mp3LyrcFull.indexOfSeq(ascii.encode("LYR"));
      if(lyrFrom2 >= 0){
        mp3LyrcFull = mp3LyrcFull.sublist(lyrFrom2+6);
      }
      var lrc_tex = utf8.decode(mp3LyrcFull);
      tra_status = fillTraFromLRC(traData, mp3_header, lrc_tex);
    }
  }
  if(tra_status != TraStatus.ok){
    // Creating EMPTY text, just to play MP3
    clog("- TRA: parseMp3WithCallback: failed to detect LRC");
    tra_status = fillTraFromLRC(traData, mp3_header, "[00:00]<Lyrics not found>");
  }
  Future.delayed(Duration(seconds: 1), (){
      // onComplete(TraStatus.ok,traData);
      onComplete(tra_status,traData);
  });
}