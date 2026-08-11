/// Belirli bir tarihin ait olduğu haftanın Pazartesi gününü (saat 00:00
/// olarak) hesaplayan ORTAK yardımcı fonksiyon.
///
/// `DateTime.weekday` Pazartesi için 1, Pazar için 7 döner; bu yüzden
/// `weekday - 1` gün geriye gideriz. Saat/dakika/saniye bilgisini de
/// SIFIRLARIZ (sadece yıl-ay-gün kalır) ki iki farklı `DateTime` "aynı
/// hafta mı?" diye saat farkından etkilenmeden karşılaştırılabilsin.
///
/// Bu fonksiyon hem `User` (haftalık AI/foto hak sayaçları) hem de
/// `WeeklyPlan` (haftalık yemek planı) tarafında AYNI hafta hesaplamasını
/// yapmak için tek bir yerden kullanılır; mantığı iki yerde ayrı ayrı
/// yazmak, ileride birinin güncellenip diğerinin unutulması riskini
/// taşırdı.
DateTime startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// İki tarihin takvimde AYNI güne denk gelip gelmediğini (saat farkını
/// yok sayarak) kontrol eder.
bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
