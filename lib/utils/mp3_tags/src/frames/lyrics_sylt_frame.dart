import 'dart:convert';

import 'frame.dart';
import '../raw_frame.dart';
import 'frame_parser.dart';


const String _frameName = 'SYLT';


class LyricsSYLT extends Frame {
  @override String get frameName => _frameName;

  final String language;
  final String lyrics;
  final int lastStamp;

  LyricsSYLT({required this.language, required this.lyrics, required this.lastStamp});

  @override
  Map<String, dynamic> toDictionary() {
    return {
      'frameName' : frameName,
      'language' : language,
      'lyrics' : lyrics,
    };
  }
}

class TranscriptionFrameParserSYLT extends FrameParser<LyricsSYLT> {
  @override
  List<String> get frameNames => [_frameName];

  @override
  LyricsSYLT? parseFrame(RawFrame rawFrame) {
    // Based on https://github.com/quodlibet/mutagen/blob/4394c43cb5e17812b93be2878e5def924caf858f/mutagen/id3/_frames.py#L1077
    // tagMinorVersion
    final frameContent = rawFrame.frameContent;
    frameContent.readEncoding();
    final language = latin1.decode(frameContent.readBytes(3));
    final tsformat = frameContent.readBytes(1);// Reading but ignoring
    final cotype = frameContent.readBytes(1);// Reading but ignoring
    final contentDescriptor = frameContent.readString(checkEncoding: false);// Reading but ignoring
    var lyrics = '';
    var lstamp_ms = 0;
    while (frameContent.remainingBytes > 0) {
      var lline = frameContent.readString(checkEncoding: false, terminatorMandatory: false);
      // Assuming milliseconds (MPEG frames require audio format inspection etc - not supported)
      // Editors contradictions: SYLT Editor and Kid3 imply different meaning for this timestamp
      // - SYLT Editor: timestamp of the END of the previous text chunk
      // - Kid3: timestamp of the START of the previous text chunk
      final lstamp_ms_next = frameContent.readIntRaw();
      lstamp_ms = lstamp_ms_next; // Kid3 mode
      final lstamp_s = (lstamp_ms/1000).floor().toInt();
      var minutes = (lstamp_s/60).floor().toInt();
      var seconds = (lstamp_s%60).toInt();
      var ms = ((lstamp_ms%1000) / 10).floor().toInt();
      var timeString = (minutes.toString()).padLeft(2,"0");
      timeString += ":"+(seconds.toString()).padLeft(2,"0");
      timeString += "."+(ms.toString()).padLeft(2,"0");
      lline = "[${timeString}]${lline}";
      lyrics = lyrics + lline;
      //lstamp_ms = lstamp_ms_next; // SYLT Editor mode, timestamp used as a start for NEXT chunk
      // debugPrint("-- SYLT ${lstamp_ms} '${lline}'");
    }
    return LyricsSYLT(language: language, lyrics: lyrics, lastStamp: lstamp_ms);
  }
}
