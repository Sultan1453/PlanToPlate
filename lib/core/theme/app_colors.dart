import 'package:flutter/material.dart';

/// Uygulamanın TEK renk kaynağı ("design tokens").
///
/// Ekranlarda ASLA doğrudan `Colors.green` gibi hazır Flutter renkleri
/// kullanmıyoruz; her zaman bu sınıftaki isimlendirilmiş renkleri
/// kullanıyoruz. Böylece ileride "biraz daha koyu bir yeşil olsun"
/// dendiğinde TEK bir satırı değiştirmek, uygulamanın HER yerini günceller.
class AppColors {
  AppColors._(); // Nesne oluşturulması gereksiz; her şey static sabit.

  /// Ana marka rengi: yumuşak adaçayı yeşili. Butonlar, seçili sekmeler,
  /// öne çıkan aksiyonlarda kullanılır.
  static const Color primaryGreen = Color(0xFF7FAE8E);

  /// `primaryGreen`in daha koyu tonu; metin/ikon kontrastı gerektiğinde
  /// kullanılır (örn. seçili sekme metni).
  static const Color primaryGreenDark = Color(0xFF4F7A61);

  /// Arka plan rengi: sıcak krem tonu. Saf beyaz yerine bunu kullanmak,
  /// mutfak/ev sıcaklığı hissi verir.
  static const Color cream = Color(0xFFFBF4E9);

  /// Kartların/yüzeylerin (surface) rengi.
  static const Color surface = Color(0xFFFFFFFF);

  /// Vurgu (accent) rengi: sıcak turuncu. "Premium'a Geç", "Reklam İzle"
  /// gibi dikkat çekmesi gereken aksiyonlarda kullanılır.
  static const Color accentOrange = Color(0xFFE8935B);

  /// Koyu vurgu tonu (basılı durum vb. için).
  static const Color accentOrangeDark = Color(0xFFC97540);

  /// Ana metin rengi (saf siyah değil, yumuşak bir kömür tonu).
  static const Color textDark = Color(0xFF3B372F);

  /// İkincil/soluk metin rengi (açıklama, yardımcı metinler için).
  static const Color textMuted = Color(0xFF8B8478);

  /// Kenarlık/ayırıcı çizgi rengi.
  static const Color divider = Color(0xFFE7DCC9);

  /// Hata/uyarı rengi (limit dolduğunda, form hatalarında).
  static const Color error = Color(0xFFD1554A);

  /// Başarı rengi (örn. "tarif başarıyla oluşturuldu" bildirimlerinde).
  static const Color success = Color(0xFF5E9A72);
}
