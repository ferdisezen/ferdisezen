import 'package:flutter/material.dart';

/// Giriş ekranında kullanılan renk paleti.
///
/// Koyu grafit bir marka paneli ile sıcak kırık beyaz bir çalışma alanı,
/// vurgu rengi olarak da zümrüt/teal kullanılır.
abstract final class LoginColors {
  // Sol panel
  static const panel = Color(0xFF0F1715);
  static const panelRaised = Color(0xFF16211E);
  static const panelLine = Color(0x1FFFFFFF);
  static const panelText = Color(0xFFF1F5F3);
  static const panelMuted = Color(0xFF9DB0AA);
  static const panelDim = Color(0xFF6B7F79);

  // Vurgu
  static const accent = Color(0xFF0F9F83);
  static const accentStrong = Color(0xFF0B7F69);
  static const accentSoft = Color(0xFFE3F4EF);
  static const accentGlow = Color(0xFF34D3AE);

  // Sağ alan
  static const surface = Color(0xFFF4F3EF);
  static const card = Color(0xFFFFFFFF);
  static const cardLine = Color(0xFFE6E4DE);
  static const text = Color(0xFF16201D);
  static const textMuted = Color(0xFF6A716E);
  static const textDim = Color(0xFF9CA29F);

  // Tuş takımı
  static const key = Color(0xFFFAF9F6);
  static const keyHover = Color(0xFFF1EFEA);
  static const keyPressed = Color(0xFFE6E4DE);

  // Durum
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const dangerLine = Color(0xFFF7C5C5);
}
