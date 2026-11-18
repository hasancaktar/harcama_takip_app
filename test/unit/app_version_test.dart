import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';

void main() {
  test('uygulamadaki sürüm sabiti pubspec.yaml ile aynıdır', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(AppConstants.appVersion, version.group(1));
    expect(AppConstants.appBuildNumber, int.parse(version.group(2)!));
  });
}
