import 'package:shadcn_flutter/shadcn_flutter.dart';


extension ShadTypography on Typography {
  static Typography withFontFamily(String fontFamily) {
    var typg = Typography(
      sans: TextStyle(fontFamily: fontFamily), //fontFamily: 'GeistSans', package: 'shadcn_flutter',
      mono: TextStyle(fontFamily: fontFamily), //fontFamily: 'GeistMono', package: 'shadcn_flutter',
      xSmall: TextStyle(fontFamily: fontFamily, fontSize: 12),
      small: TextStyle(fontFamily: fontFamily, fontSize: 14),
      base: TextStyle(fontFamily: fontFamily, fontSize: 16),
      large: TextStyle(fontFamily: fontFamily, fontSize: 18),
      xLarge: TextStyle(fontFamily: fontFamily, fontSize: 20),
      x2Large: TextStyle(fontFamily: fontFamily, fontSize: 24),
      x3Large: TextStyle(fontFamily: fontFamily, fontSize: 30),
      x4Large: TextStyle(fontFamily: fontFamily, fontSize: 36),
      x5Large: TextStyle(fontFamily: fontFamily, fontSize: 48),
      x6Large: TextStyle(fontFamily: fontFamily, fontSize: 60),
      x7Large: TextStyle(fontFamily: fontFamily, fontSize: 72),
      x8Large: TextStyle(fontFamily: fontFamily, fontSize: 96),
      x9Large: TextStyle(fontFamily: fontFamily, fontSize: 144),
      thin: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w100),
      light: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w300),
      extraLight: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w200),
      normal: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
      medium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
      semiBold: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      bold: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      extraBold: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800),
      black: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w900),
      italic: TextStyle(fontFamily: fontFamily, fontStyle: FontStyle.italic),
      h1: TextStyle(fontFamily: fontFamily, fontSize: 36, fontWeight: FontWeight.w800),
      h2: TextStyle(fontFamily: fontFamily, fontSize: 30, fontWeight: FontWeight.w600),
      h3: TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w600),
      h4: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600),
      p: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400),
      blockQuote: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic),
      inlineCode: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600),
      lead: TextStyle(fontFamily: fontFamily, fontSize: 20),
      textLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600),
      textSmall: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
      textMuted: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400),
    );
    return typg;
  }
}