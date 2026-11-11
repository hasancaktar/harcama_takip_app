import 'package:flutter/material.dart';

/// Sakin Zümrüt & Finans Güveni (Emerald & Slate Trust) Renk Paleti
abstract class AppColors {
  // Birincil Renkler (Zümrüt Yeşili)
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color primaryContainer = Color(0xFFD1E7DD);
  static const Color onPrimaryContainer = Color(0xFF08321E);

  // İkincil Renkler (Derin Gece / Finans Mavisi)
  static const Color secondary = Color(0xFF1E3A8A);
  static const Color secondaryLight = Color(0xFF60A5FA);
  static const Color secondaryContainer = Color(0xFFDBEAFE);

  // Arka Plan ve Yüzeyler (Açık Tema)
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F3F5);
  static const Color lightBorder = Color(0xFFE9ECEF);

  // Arka Plan ve Yüzeyler (Koyu Tema)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);

  // Durum Renkleri
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static const Color info = Color(0xFF0284C7);

  // Metin Renkleri
  static const Color textPrimaryLight = Color(0xFF1A1D20);
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Kategori Renkleri
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
}
