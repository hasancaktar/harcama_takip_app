import 'dart:io';

import 'package:flutter/services.dart';

/// Flutter SDK ile gelen Roboto ve Material Icons yazı tiplerini yükler.
///
/// Test ortamının varsayılan yazı tipinde her harf kare genişliğindedir;
/// metnin sığıp sığmadığını ölçen testler ve mağaza ekran görüntüleri için
/// Android'deki gerçek yazı tipi gerekir.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}
