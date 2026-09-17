import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/core/constants/app_version.dart';

void main() {
  test('appVersion suit la version de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*([0-9.]+)\+\d+', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(appVersion, match!.group(1));
  });
}
