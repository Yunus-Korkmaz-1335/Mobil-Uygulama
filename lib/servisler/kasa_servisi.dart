import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class KasaServisi {
  static const String kasaninAdi = 'sadecebiz_gizli_anilar';

  // ✅ YÖNTEM 3: İZOLE KASA (Sadece bize özel, sınırları belli bir hafıza alanı)
  static CacheManager gizliKasa = CacheManager(
    Config(
      kasaninAdi,
      stalePeriod: const Duration(days: 30), // 30 gün boyunca hiç bakılmayanları siler
      maxNrOfCacheObjects: 300, // Hafıza şişmesin diye en fazla 300 fotoğraf tutar
    ),
  );

  // ✅ YÖNTEM 1: .NOMEDIA BÜYÜSÜ (Galeriden gizleme)
  static Future<void> kasayiKilitle() async {
    try {
      // 1. Cihazın önbellek klasörüne gidiyoruz
      final tempDir = await getTemporaryDirectory();

      // 2. Kendi özel kasamızı oluşturuyoruz
      final kasaKlasoru = Directory('${tempDir.path}/$kasaninAdi');
      if (!await kasaKlasoru.exists()) {
        await kasaKlasoru.create(recursive: true);
      }

      // 3. Kasanın içine .nomedia dosyasını koyuyoruz (Burası taranmasın diyoruz)
      final nomediaDosyasi = File('${kasaKlasoru.path}/.nomedia');
      if (!await nomediaDosyasi.exists()) {
        await nomediaDosyasi.create();
      }

      // GARANTİ ÇÖZÜM: Bazı inatçı Android modelleri için ana klasöre de atıyoruz
      final anaNomedia = File('${tempDir.path}/.nomedia');
      if (!await anaNomedia.exists()) {
        await anaNomedia.create();
      }
    } catch (e) {
      print("Kasa kilitlenirken bir hata oluştu: $e");
    }
  }
}