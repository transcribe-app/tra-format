import 'package:test/test.dart';
import 'package:tra_viewer/config.dart';

void main() {
  group('Basic tests', () {
    test('App Config initialization', () {
      final appState = AppState();
      expect(appState.uiTheme, 0);
      print("appState init ok");
    });
  });
}