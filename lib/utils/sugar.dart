// ignore_for_file: non_constant_identifier_names, prefer_conditional_assignment
import 'package:intl/intl.dart';
import 'dart:math';

int unixstamp() {
  var stamp_ms = unixstamp_ms();
  int stamp_sec = (stamp_ms/1000).floor();
  return stamp_sec;
}

int unixstamp_ms() {
  var unixTimeMilliseconds = DateTime.now().toUtc().millisecondsSinceEpoch;
  return unixTimeMilliseconds;
}

String dateAsYYYYMMDD(DateTime? date_today, {String frm = "yyyy-MM-dd"}){
  if(date_today == null){
    date_today = DateTime.now();
  }
  String datestr = DateFormat(frm).format(date_today);
  return datestr;
}

String strFromSec(int duration){
  var hours = (duration/3600).floor();
	var minutes = (duration%3600 / 60).floor();
	var seconds = (duration%60);
	var timeString = "";
	if (hours >= 1) {
		timeString += '${hours}:';
	}
	timeString += (minutes.toString()).padLeft(2,"0")+":";
	timeString += (seconds.toString()).padLeft(2,"0");
	return timeString;
}

String strFromDuration(Duration? timep){
  if(timep == null){
    return "00:00";
  }
	var duration = timep.inSeconds;
	return strFromSec(duration);
}

String strHeaderGet(String headersStr, String headerKey, String defaultValue) {
    final RegExp contentTypeRegex = RegExp(headerKey+r':\s*([^\n\r]+)[\n\r]', caseSensitive: false);
    final Match? contentTypeMatch = contentTypeRegex.firstMatch(headersStr);
    if (contentTypeMatch == null || contentTypeMatch.groupCount < 1) {
      return defaultValue;
    }
    var contentType = contentTypeMatch.group(1) as String;
    return contentType;
}

String strSubHeaderGet(String headersStr, String subHeaderKey, String defaultValue) {
  RegExp boundaryRegex = RegExp(subHeaderKey+r'="(.+)"', caseSensitive: false);
  final boundaryMatch = boundaryRegex.firstMatch(headersStr);
  if (boundaryMatch == null || boundaryMatch.groupCount != 1) {
    return defaultValue;
  }
  String boundary = boundaryMatch.group(1) as String;
  return boundary;
}

// Source - https://stackoverflow.com/questions/54898767/enumerate-or-map-through-a-list-with-index-and-value-in-dart
Iterable<(int, T)> enumerate<T>(Iterable<T> items) sync* {
  var index = 0;
  for (final item in items) {
    yield (index, item);
    index++;
  }
}

extension IndexOfListExtension<T> on List<T> {
  int indexOfSeq(List<T> needle, [int start = 0]) {
    if (needle.isEmpty) return start; // Empty needle is found at the start
    if (start < 0 || start >= length) {
      throw RangeError.range(start, 0, length - 1, 'start');
    }

    var first = needle[0];
    var end = length - needle.length;

    for (var i = start; i <= end; i++) {
      if (this[i] == first) {
        bool match = true;
        for (var j = 1; j < needle.length; j++) {
          if (this[i + j] != needle[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          return i;
        }
      }
    }
    return -1; // Not found
  }
}

int randomNumber(int min, int max) {
  return min + Random().nextInt(max - min);
}

String sanitizeFilename(String input, {String replacement = ''}) {
  final result = input
      // illegalRe
      .replaceAll(
        RegExp(r'[\/\?<>\\:\*\|"]'),
        replacement,
      )
      // controlRe
      .replaceAll(
        RegExp(
          r'[\x00-\x1f\x80-\x9f]',
        ),
        replacement,
      )
      // reservedRe
      .replaceFirst(
        RegExp(r'^\.+$'),
        replacement,
      )
      // windowsReservedRe
      .replaceFirst(
        RegExp(
          r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
          caseSensitive: false,
        ),
        replacement,
      )
      // windowsTrailingRe
      .replaceFirst(RegExp(r'[\. ]+$'), replacement);

  return result.length > 255 ? result.substring(0, 255) : result;
}

bool sameFloat(double x, double y, {double epsilon = 0.0001}){
  if ((x - y).abs() < epsilon){
    return true;
  }
  return false;
}