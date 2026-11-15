import 'package:flutter/material.dart';

abstract class ColorUtils {
  /// "#1E3A8A" veya "1E3A8A" biçimindeki rengi güvenle çözer; hatalı girdide [fallback] döner.
  static Color fromHex(
    String? hex, {
    Color fallback = const Color(0xFF1E3A8A),
  }) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  /// Arka plan rengine göre okunabilir metin rengini (beyaz/siyah) seçer.
  static Color onColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);
  }
}
