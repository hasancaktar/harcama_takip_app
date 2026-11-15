import 'package:flutter/widgets.dart';

/// Boşluk, köşe yarıçapı ve kırılım noktası belirteçleri.
abstract class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  /// İçerik genişliği sınırları (geniş ekranlarda satırların aşırı uzamasını engeller).
  static const double maxContentWidth = 760;
  static const double maxFormWidth = 560;
  static const double maxAuthWidth = 440;

  /// Material 3 pencere boyutu sınıfları.
  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 1000;

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(md, md, md, xl);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
}
