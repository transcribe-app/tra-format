// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'bound_multipart_stream.dart';
import 'char_code.dart' as char_code;
import 'mime_shared.dart';

Uint8List _getBoundary(String boundary, bool lfonly) {
  final charCodes = boundary.codeUnits;
  if(lfonly){
    final boundaryList = Uint8List(3 + charCodes.length);
    boundaryList[0] = char_code.lf;
    boundaryList[1] = char_code.dash;
    boundaryList[2] = char_code.dash;
    boundaryList.setRange(3, 3 + charCodes.length, charCodes);
    return boundaryList;
  }
  final boundaryList = Uint8List(4 + charCodes.length);
  // Set-up the matching boundary preceding it with CRLF and two
  // dashes.
  boundaryList[0] = char_code.cr;
  boundaryList[1] = char_code.lf;
  boundaryList[2] = char_code.dash;
  boundaryList[3] = char_code.dash;
  boundaryList.setRange(4, 4 + charCodes.length, charCodes);
  return boundaryList;
}

/// Parser for MIME multipart types of data as described in RFC 2046
/// section 5.1.1. The data is transformed into [MimeMultipart] objects, each
/// of them streaming the multipart data.
class MimeMultipartTransformer
    extends StreamTransformerBase<List<int>, MimeMultipart> {
  final List<int> _boundary;
  bool _lfonly = false;

  /// Construct a new MIME multipart parser with the boundary
  /// [boundary]. The boundary should be as specified in the content
  /// type parameter, that is without the -- prefix.
  /// [lfonly]. Parse '\n'-only files (without '\r')
  MimeMultipartTransformer(String boundary, bool lfonly)
      : _boundary = _getBoundary(boundary, lfonly), _lfonly = lfonly;

  @override
  Stream<MimeMultipart> bind(Stream<List<int>> stream) =>
      BoundMultipartStream(_boundary, stream, _lfonly).stream;

}
