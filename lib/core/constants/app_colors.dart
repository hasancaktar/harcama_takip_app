import 'package:flutter/material.dart';

/// "Zümrüt & Arduvaz" marka paleti. Bileşenler renkleri doğrudan buradan değil,
/// [ColorScheme] ve [AppSemanticColors] üzerinden almalıdır; böylece açık/koyu
/// tema tutarlı kalır.
abstract class AppColors {
  // Marka
  static const Color brand = Color(0xFF0F5132);
  static const Color brandLight = Color(0xFF34D399);

  // Açık tema
  static const Color lightPrimary = Color(0xFF0F6B47);
  static const Color lightPrimaryContainer = Color(0xFFD3F2E3);
  static const Color lightOnPrimaryContainer = Color(0xFF052E1F);
  static const Color lightSecondary = Color(0xFF1E3A8A);
  static const Color lightSecondaryContainer = Color(0xFFDDE6FF);
  static const Color lightBackground = Color(0xFFF5F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF0F3F2);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8EDEB);
  static const Color lightOnSurface = Color(0xFF111827);
  static const Color lightOnSurfaceVariant = Color(0xFF52606D);
  static const Color lightOutline = Color(0xFFCBD5D1);
  static const Color lightOutlineVariant = Color(0xFFE3E8E6);

  // Koyu tema
  static const Color darkPrimary = Color(0xFF4ADE9C);
  static const Color darkOnPrimary = Color(0xFF00391F);
  static const Color darkPrimaryContainer = Color(0xFF0B4F33);
  static const Color darkOnPrimaryContainer = Color(0xFFC9F5DE);
  static const Color darkSecondary = Color(0xFF93B4FF);
  static const Color darkSecondaryContainer = Color(0xFF243B73);
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF121A2A);
  static const Color darkSurfaceContainer = Color(0xFF1A2335);
  static const Color darkSurfaceContainerHigh = Color(0xFF232E43);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF9AA8BC);
  static const Color darkOutline = Color(0xFF3A4760);
  static const Color darkOutlineVariant = Color(0xFF263149);

  // Durum renkleri
  static const Color error = Color(0xFFC62828);
  static const Color errorDark = Color(0xFFFF8A80);
  static const Color warning = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color success = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color info = Color(0xFF0369A1);
  static const Color infoDark = Color(0xFF7DD3FC);

  // Kategori renkleri
  static const Color categoryMarket = Color(0xFF10B981);
  static const Color categoryRestaurant = Color(0xFFF97316);
  static const Color categoryTransport = Color(0xFF3B82F6);
  static const Color categoryBills = Color(0xFFEF4444);
  static const Color categoryRent = Color(0xFF8B5CF6);
  static const Color categoryHealth = Color(0xFF06B6D4);
  static const Color categoryEducation = Color(0xFF6366F1);
  static const Color categoryShopping = Color(0xFFF59E0B);
  static const Color categoryEntertainment = Color(0xFFEC4899);
  static const Color categoryTravel = Color(0xFF14B8A6);
  static const Color categorySubscription = Color(0xFF84CC16);
  static const Color categoryHome = Color(0xFFEAB308);
  static const Color categoryPersonalCare = Color(0xFFA855F7);
  static const Color categoryOther = Color(0xFF6B7280);

  /// Kart ve takım için seçilebilir renkler.
  static const List<String> pickerHexColors = [
    '#1E3A8A',
    '#0F5132',
    '#7C3AED',
    '#B91C1C',
    '#C2410C',
    '#0F766E',
    '#BE185D',
    '#0F172A',
  ];
}
