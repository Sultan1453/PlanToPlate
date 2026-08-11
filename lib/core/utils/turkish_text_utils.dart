/// Kullanıcının yazdığı metni, Türkçe karakterlerden (ve büyük/küçük harf
/// farkından) bağımsız hale getirir. Böylece kullanıcı "Tavuk But", "tavuk
/// BUT" veya (Türkçe klavyesi olmayan biri) "tavuk but" yazsa da hepsi aynı
/// şekilde eşleşir.
///
/// NEDEN GEREKLİ? Dart'ın kendi `toLowerCase()` metodu Türkçe'ye özel
/// harfleri (özellikle noktalı/noktasız I-İ ikilisini) her zaman beklediğimiz
/// gibi çevirmez. Örn: `'İ'.toLowerCase()` normal İngilizce mantıkla "i"
/// vermeli ama Unicode kuralına göre "i" harfinin üstüne fazladan bir nokta
/// işareti ekleyerek verir. Bu da "İÇLİ KÖFTE" ile "içli köfte" karşılaştırıp
/// eşit bulmamıza engel olabilir. Bu yüzden Türkçe harfleri KENDİMİZ, sabit
/// bir tabloyla, düz (ASCII benzeri) karşılıklarına çeviriyoruz.
///
/// Bu fonksiyon Adım 2'de yazacağımız "Mock AI" eşleştirme sisteminde
/// kullanılacak: kullanıcının yazdığı yemek adını, elimizdeki örnek
/// tariflerin anahtar kelimeleriyle karşılaştırırken.
String normalizeTurkish(String input) {
  // Baştaki/sondaki boşlukları temizliyoruz (kullanıcı yanlışlıkla
  // "  tavuk but " gibi boşluklu yazmış olabilir).
  var result = input.trim();

  // Her Türkçe harfi, düz (Türkçe olmayan) karşılığına çeviren sabit bir
  // eşleştirme tablosu. Büyük ve küçük hallerinin İKİSİNİ de ayrı ayrı
  // eklemek zorundayız çünkü aşağıda `toLowerCase()`'i bu değişimden SONRA
  // çağıracağız.
  const charMap = <String, String>{
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ş': 's',
    'ş': 's',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
  };

  // `Map.forEach` ile tablodaki her (harf, karşılık) çiftini sırayla metin
  // üzerinde `replaceAll` ile değiştiriyoruz.
  charMap.forEach((turkishChar, plainChar) {
    result = result.replaceAll(turkishChar, plainChar);
  });

  // Artık metinde Türkçe'ye özel harf kalmadığı için standart
  // `toLowerCase()` güvenle kullanılabilir (kalan harfler zaten İngilizce
  // alfabesinde, yani Unicode'un "sorunlu" büyük/küçük dönüşümü devreye
  // girmez).
  return result.toLowerCase();
}
