/// Arama icin metin normalizasyonu.
///
/// Turkce klavyeyle "ilkyardim" yazan biri "İlkyardım" kaydini bulabilmeli,
/// ama `toLowerCase()` tek basina yetmiyor: "İ" harfi Unicode'da iki kod
/// noktasina aciliyor ve "I" harfi de yanlis tarafa dusuyor. Once bu iki harf
/// elle esleniyor, sonra kucultuluyor.
String searchNormalize(String value) =>
    value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
