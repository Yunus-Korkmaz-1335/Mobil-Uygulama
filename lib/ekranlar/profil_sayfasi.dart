import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:http/http.dart' as http;
import '../main.dart';
import 'cop_kutusu.dart';

class ProfilSayfasi extends StatelessWidget {
  const ProfilSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => const _ProfilSayfasiIcerik(),
    );
  }
}

class _ProfilSayfasiIcerik extends StatefulWidget {
  const _ProfilSayfasiIcerik();

  @override
  State<_ProfilSayfasiIcerik> createState() => _ProfilSayfasiIcerikState();
}

class _ProfilSayfasiIcerikState extends State<_ProfilSayfasiIcerik> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _yukleniyor = false;
  bool _bildirimGonderiliyor = false;

  bool _benOndeyim = true;

  final GlobalKey _odaAnahtari = GlobalKey();
  final GlobalKey _hayaletAnahtari = GlobalKey();
  final GlobalKey _copAnahtari = GlobalKey();
  final GlobalKey _ayrilmaAnahtari = GlobalKey();

  @override
  void initState() {
    super.initState();
    _egitimiBaslat();
  }

  Future<void> _egitimiBaslat() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool egitimGosterildi = prefs.getBool('egitim_profil_sayfasi') ?? false;

      if (!egitimGosterildi) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            ShowCaseWidget.of(context).startShowCase([_odaAnahtari, _hayaletAnahtari, _copAnahtari, _ayrilmaAnahtari]);
          }
        });
        await prefs.setBool('egitim_profil_sayfasi', true);
      }
    });
  }

  // --- ODADAN AYRILMA VE SİLME SİSTEMİ ---

  void _odadanAyrilOnay(BuildContext context, String ciftId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.meeting_room_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text("Odadan Ayrıl", style: TextStyle(color: Colors.redAccent, fontFamily: 'Serif')),
            ],
          ),
          content: const Text(
            "Nasıl ayrılmak istersin? İstersen sadece odadan çıkabilirsin, istersen de çıkarken buradaki tüm anıların silinmesi için partnerine onay isteği gönderebilirsin.",
            style: TextStyle(fontFamily: 'Serif'),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
              onPressed: () {
                Navigator.pop(dialogContext);
                _odadanSadeceAyril(context, ciftId);
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text("Sadece Odadan Ayrıl", style: TextStyle(color: Colors.white, fontFamily: 'Serif')),
            ),
            const SizedBox(height: 5),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(dialogContext);
                _silmeIstegiGonder(context, ciftId);
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              label: const Text("Ayrıl ve Tüm Anıları Sil", style: TextStyle(color: Colors.white, fontFamily: 'Serif')),
            ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontFamily: 'Serif'))
            ),
          ],
        );
      },
    );
  }

  Future<void> _odadanSadeceAyril(BuildContext context, String ciftId) async {
    final navigator = Navigator.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.brown)));

    try {
      String uid = user!.uid;
      var odaRef = FirebaseFirestore.instance.collection('Ciftler').doc(ciftId);
      var odaDoc = await odaRef.get();

      if (odaDoc.exists) {
        var data = odaDoc.data() as Map<String, dynamic>;
        if (data['partner1'] == uid) {
          await odaRef.update({'partner1': '', 'durum': 'bekliyor'});
        } else if (data['partner2'] == uid) {
          await odaRef.update({'partner2': '', 'durum': 'bekliyor'});
        }
      }
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'ciftId': '',
        'gunlugumu_gorebilenler': [],
        'gelen_istekler': [],
      });

      navigator.pop();
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
    } catch (e) {
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bir hata oluştu: $e")));
    }
  }

  Future<void> _silmeIstegiGonder(BuildContext context, String ciftId) async {
    try {
      await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).update({
        'silme_istek_yapan': user!.uid,
        'silme_istek_durum': 'bekliyor',
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silme isteği gönderildi. Partnerinin onayı bekleniyor."), backgroundColor: Colors.amber));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _istegiGeriCek(String ciftId) async {
    try {
      await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).update({
        'silme_istek_yapan': FieldValue.delete(),
        'silme_istek_durum': FieldValue.delete(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ayrılma ve silme isteği geri çekildi. Odada kalıyorsunuz."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _istegiReddet(String ciftId) async {
    await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).update({
      'silme_istek_durum': 'reddedildi',
    });
  }

  Future<void> _istegiKabulEtVeSil(String ciftId, String partnerUid) async {
    final navigator = Navigator.of(context);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5E6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.brown),
                SizedBox(height: 20),
                Text(
                  "Bir hikayenin sonu...\nAnılarınız usulca veda ediyor, lütfen bekleyin. 🍂",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.brown, fontStyle: FontStyle.italic, fontSize: 14, fontFamily: 'Serif'),
                ),
              ],
            ),
          ),
        )
    );

    try {
      var anilar = await FirebaseFirestore.instance.collection('GunlukKayitlar').where('cift_id', isEqualTo: ciftId).get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in anilar.docs) {
        var veri = doc.data();
        List<dynamic> resimListesi = veri['resim_listesi'] ?? [];

        for (String url in resimListesi) {
          try {
            if (url.isNotEmpty) {
              await FirebaseStorage.instance.refFromURL(url).delete();
            }
          } catch (e) {
            print("Dosya silinirken hata: $e");
          }
        }
        batch.delete(doc.reference);
      }

      await batch.commit();

      await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).update({
        'partner1': '',
        'partner2': '',
        'durum': 'bekliyor',
        'silme_istek_yapan': FieldValue.delete(),
        'silme_istek_durum': FieldValue.delete(),
      });

      if (partnerUid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('Users').doc(partnerUid).update({'ciftId': ''});
        } catch (e) {
          debugPrint("Partner ciftId güncellenemedi (Yetki hatası yoksayıldı): $e");
        }
      }

      await FirebaseFirestore.instance.collection('Users').doc(user!.uid).update({
        'ciftId': '',
        'gunlugumu_gorebilenler': [],
        'gelen_istekler': [],
      });

      navigator.pop();
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
    } catch(e) {
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  // --- DİĞER PROFİL METOTLARI ---

  Future<void> _fotoSecVeYukle() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      setState(() => _yukleniyor = true);
      try {
        var ref = FirebaseStorage.instance.ref().child('ProfilFotolari').child('${user!.uid}.jpg');
        await ref.putFile(File(image.path));
        String downloadUrl = await ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('Users').doc(user!.uid).update({'profilFoto': downloadUrl});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil fotoğrafı güncellendi!")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      } finally {
        if (mounted) setState(() => _yukleniyor = false);
      }
    }
  }

  // ✅ PREMİUM GİRİŞ ALANI (Yazı taşmalarını önler, çok şık durur)
  Widget _premiumTextField({
    required TextEditingController controller,
    required String baslik,
    required String ipucu,
    required IconData ikon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(baslik, style: TextStyle(color: Colors.brown.shade400, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Serif', letterSpacing: 0.8)),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: const TextStyle(fontFamily: 'Serif', color: Colors.brown, fontSize: 16),
          decoration: InputDecoration(
            counterText: "",
            hintText: ipucu,
            hintStyle: TextStyle(color: Colors.brown.shade200, fontFamily: 'Serif', fontSize: 14, fontStyle: FontStyle.italic),
            prefixIcon: Icon(ikon, color: Colors.brown.shade300, size: 20),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.brown.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFC07B54), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // ✅ PREMİUM BİLGİ DÜZENLEME PENCERESİ
  void _bilgileriDuzenle(String mevcutAd, String mevcutSoyad, String mevcutRumuz) {
    final adController = TextEditingController(text: mevcutAd);
    final soyadController = TextEditingController(text: mevcutSoyad);
    final rumuzController = TextEditingController(text: mevcutRumuz);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_accounts_rounded, size: 45, color: Color(0xFFC07B54)),
                const SizedBox(height: 15),
                const Text("Bilgilerini Güncelle", style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                const SizedBox(height: 25),

                _premiumTextField(controller: adController, baslik: "ADINIZ", ipucu: "Örn. Yunus", ikon: Icons.person_outline),
                const SizedBox(height: 15),
                _premiumTextField(controller: soyadController, baslik: "SOYADINIZ", ipucu: "Örn. Korkmaz", ikon: Icons.badge_outlined),
                const SizedBox(height: 15),
                _premiumTextField(controller: rumuzController, baslik: "SEVGİLİNE HİTAP ŞEKLİN", ipucu: "Örn. Aşkım, Bebeğim...", ikon: Icons.favorite_border_rounded, maxLength: 25,),

                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16))
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC07B54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('Users').doc(user!.uid).update({
                            'ad': adController.text.trim(), 'soyad': soyadController.text.trim(), 'nickname': rumuzController.text.trim(),
                          });
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ PREMİUM ODA BİLGİLERİ PENCERESİ
  Future<void> _odaBilgileriniGosterDialog(String ciftId) async {
    if (ciftId.isEmpty) return;
    var odaDoc = await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).get();
    if (!odaDoc.exists) return;
    String mevcutSifre = odaDoc.data()?['sifre'] ?? "";
    final sifreController = TextEditingController(text: mevcutSifre);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            bool guncelleniyor = false;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF5E6),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sensor_door_rounded, size: 45, color: Color(0xFFC07B54)),
                    const SizedBox(height: 15),
                    const Text("Oda Bilgilerimiz", style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                    const SizedBox(height: 25),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Text("ODA ADI (DAVET KODU)", style: TextStyle(color: Colors.brown.shade400, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Serif', letterSpacing: 0.8)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.brown.withOpacity(0.1))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(ciftId, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif'), overflow: TextOverflow.ellipsis)),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: ciftId));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oda adı panoya kopyalandı!"), backgroundColor: Colors.green));
                                },
                                child: const Icon(Icons.copy_rounded, color: Color(0xFFC07B54), size: 22),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _premiumTextField(controller: sifreController, baslik: "ODA ŞİFRESİ", ipucu: "Yeni şifre belirle", ikon: Icons.vpn_key_rounded),

                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat", style: TextStyle(color: Colors.grey, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16))),
                        ),
                        Expanded(
                          child: guncelleniyor
                              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC07B54))))
                              : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC07B54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              if (sifreController.text.trim().isEmpty) return;
                              setStateDialog(() => guncelleniyor = true);
                              await FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).update({'sifre': sifreController.text.trim()});
                              setStateDialog(() => guncelleniyor = false);
                              if (mounted) Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Oda şifreniz güncellendi!"), backgroundColor: Colors.green));
                            },
                            child: const Text("Güncelle", style: TextStyle(color: Colors.white, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }
      ),
    );
  }

  // ✅ PREMİUM HAYALET MOD KURULUMU
// ✅ PREMİUM HAYALET MOD KURULUMU (Metin taşmaları düzeltildi)
  void _kilitSifreleriniBelirleDialog() {
    final gercekController = TextEditingController();
    final sahteController = TextEditingController();
    final soruController = TextEditingController();
    final cevapController = TextEditingController();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 45, color: Colors.brown),
                const SizedBox(height: 15),
                const Text("Hayalet Mod", style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                const SizedBox(height: 10),
                const Text("Gerçek şifreniz anılara, sahte şifreniz bomboş bir sayfaya götürür.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Serif', height: 1.4)),
                const SizedBox(height: 25),

                _premiumTextField(controller: gercekController, baslik: "GERÇEK PAROLA", ipucu: "4 Haneli", ikon: Icons.key, keyboardType: TextInputType.number, maxLength: 4, isPassword: true),
                const SizedBox(height: 10),
                _premiumTextField(controller: sahteController, baslik: "SAHTE (YEM) PAROLA", ipucu: "4 Haneli", ikon: Icons.visibility_off, keyboardType: TextInputType.number, maxLength: 4, isPassword: true),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.black12),
                ),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_reset_rounded, color: Color(0xFFC07B54), size: 18),
                    SizedBox(width: 8),
                    Text("Şifre Kurtarma", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC07B54), fontFamily: 'Serif', fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 15),

                // ✅ UZUN METİNLER KISALTILDI VE ALANA TAM OTURTULDU
                _premiumTextField(controller: soruController, baslik: "GÜVENLİK SORUSU", ipucu: "Örn: Evcil hayvanım?", ikon: Icons.help_outline),
                const SizedBox(height: 10),
                _premiumTextField(controller: cevapController, baslik: "CEVAP", ipucu: "Sadece senin bildiğin...", ikon: Icons.check_circle_outline),

                const SizedBox(height: 35), // Alt tarafa biraz daha boşluk verildi
                Row(
                  children: [
                    Expanded(
                      child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal", style: TextStyle(color: Colors.grey, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          if (gercekController.text.length == 4 && sahteController.text.length == 4 && gercekController.text != sahteController.text && soruController.text.isNotEmpty && cevapController.text.isNotEmpty) {
                            await FirebaseFirestore.instance.collection('Users').doc(user!.uid).update({
                              'kilit_aktif': true, 'gercek_sifre': gercekController.text, 'sahte_sifre': sahteController.text, 'guvenlik_sorusu': soruController.text.trim(), 'guvenlik_cevabi': cevapController.text.trim().toLowerCase(),
                            });
                            if (mounted) Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hayalet Mod başarıyla aktif edildi!")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun (Şifreler 4 haneli ve farklı olmalı)")));
                          }
                        },
                        child: const Text("Aktifleştir", style: TextStyle(color: Colors.white, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cikisYapOnay(BuildContext context) {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF5E6),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, size: 45, color: Colors.brown),
              const SizedBox(height: 15),
              const Text("Oturumu Kapat", style: TextStyle(fontFamily: 'Serif', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
              const SizedBox(height: 10),
              const Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Serif', fontSize: 15, color: Colors.brown)),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16)))),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        navigator.pop();
                        navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
                      },
                      child: const Text("Çıkış Yap", style: TextStyle(color: Colors.white, fontFamily: 'Serif', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _partneriUyar(String? partnerToken, String hitap) async {
    if (partnerToken == null || partnerToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Partnerinizin cihazı bildirime kapalı.")));
      return;
    }

    setState(() => _bildirimGonderiliyor = true);

    try {
      String mesajBasligi = hitap.trim().isNotEmpty ? hitap.trim() : "Sevgilim";
      String ozelBildirimMesaji = "$mesajBasligi, günlüğünü kaydetmeyi unutma! 💌";

      await FirebaseFirestore.instance.collection('BildirimIstekleri').add({
        'partnerToken': partnerToken,
        'gonderenUid': user!.uid,
        'ozelMesaj': ozelBildirimMesaji,
        'olusturulma': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Sevgiline tatlı bir hatırlatma gönderildi! 💌"),
          backgroundColor: Colors.pinkAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _bildirimGonderiliyor = false);
    }
  }

  Widget _profilBileseniOlustur({
    required bool isFront,
    required String? fotoUrl,
    required bool isPartner,
    required bool partnerYazdiMi,
  }) {
    double size = isFront ? 120.0 : 90.0;
    double top = isFront ? 0.0 : 15.0;
    double left = isFront ? 50.0 : 0.0;

    return AnimatedPositioned(
      key: ValueKey(isPartner ? 'partner' : 'ben'),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          if (isPartner) {
            setState(() => _benOndeyim = !_benOndeyim);
          } else {
            if (isFront) {
              _fotoSecVeYukle();
            } else {
              setState(() => _benOndeyim = true);
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.brown.shade100,
            border: Border.all(color: const Color(0xFFFDF5E6), width: isFront ? 4 : 2),
            boxShadow: isFront ? [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))] : [],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(
                child: fotoUrl != null
                    ? Image.network(fotoUrl, fit: BoxFit.cover)
                    : Icon(Icons.person, color: Colors.brown, size: size / 2),
              ),
              if (!isPartner && isFront)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.brown,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDF5E6), width: 2),
                    ),
                    child: const Icon(Icons.add_a_photo, size: 14, color: Colors.white),
                  ),
                ),
              if (isPartner)
                Positioned(
                  bottom: isFront ? 8 : 0,
                  left: isFront ? 8 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDF5E6), width: 2),
                    ),
                    child: Icon(
                      partnerYazdiMi ? Icons.check_circle_rounded : Icons.edit_calendar_rounded,
                      color: partnerYazdiMi ? Colors.green : Colors.orange,
                      size: isFront ? 24 : 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
          title: const Text(
              "Profilim",
              style: TextStyle(
                  color: Colors.brown,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  fontFamily: 'Serif'
              )
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.brown)
      ),
      body: user == null
          ? const Center(child: Text("Oturum kapatılıyor..."))
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator(color: Colors.brown));

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String ciftId = data['ciftId'] ?? "";

          if (ciftId.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                );
              }
            });
            return const Center(child: CircularProgressIndicator(color: Colors.brown));
          }

          String ad = data['ad'] ?? "";
          String soyad = data['soyad'] ?? "";
          String nickname = data['nickname'] ?? "";
          String? fotoUrl = data['profilFoto'];
          bool kilitAktif = data['kilit_aktif'] ?? false;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Ciftler').doc(ciftId).snapshots(),
            builder: (context, ciftSnapshot) {

              Widget istekKarti = const SizedBox.shrink();
              String partnerUid = "";

              if (ciftSnapshot.hasData && ciftSnapshot.data!.exists) {
                var ciftData = ciftSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                String istekYapan = ciftData['silme_istek_yapan'] ?? "";
                String durum = ciftData['silme_istek_durum'] ?? "";
                String p1 = ciftData['partner1'] ?? "";
                String p2 = ciftData['partner2'] ?? "";
                partnerUid = (p1 == user!.uid) ? p2 : p1;

                if (istekYapan == user!.uid && durum == 'bekliyor') {
                  istekKarti = Card(color: Colors.amber.shade50, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade300, width: 1.5)), child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [const Icon(Icons.access_time_filled_rounded, color: Colors.orange, size: 40), const SizedBox(height: 10), const Text("Tüm anıları silmek için partnerinize istek gönderildi. Onay bekleniyor...", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif')), const SizedBox(height: 15), Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ElevatedButton(onPressed: () => _istegiGeriCek(ciftId), style: ElevatedButton.styleFrom(backgroundColor: Colors.brown), child: const Text("İsteği Geri Çek (Odada Kal)", style: TextStyle(color: Colors.white, fontFamily: 'Serif'))), OutlinedButton(onPressed: () => _odadanSadeceAyril(context, ciftId), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)), child: const Text("Beklemekten Vazgeç ve Silmeden Ayrıl", style: TextStyle(color: Colors.redAccent, fontFamily: 'Serif')))])])));
                } else if (istekYapan == partnerUid && durum == 'bekliyor') {
                  istekKarti = Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent, width: 1.5)),
                      child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                              children: [
                                const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 40),
                                const SizedBox(height: 10),
                                const Text(
                                  "Zor bir karar zamanı... 🥀",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16, fontFamily: 'Serif'),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Partnerin odadan ayrılmak ve aranızdaki bu günlüğü tamamen kapatmak istiyor. Eğer bunu kabul edersen; bugüne kadar biriktirdiğiniz tüm fotoğraflar, görevler ve yazılar hem senin hem de onun telefonundan kalıcı olarak silinecek.\n\nEmin misin?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.brown, fontSize: 13, height: 1.4, fontFamily: 'Serif'),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                    children: [
                                      Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => _istegiKabulEtVeSil(ciftId, partnerUid), child: const Text("Kabul Et ve Sil", style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Serif')))),
                                      const SizedBox(width: 10),
                                      Expanded(child: OutlinedButton(onPressed: () => _istegiReddet(ciftId), child: const Text("Reddet", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontFamily: 'Serif')))),
                                    ]
                                )
                              ]
                          )
                      )
                  );
                } else if (istekYapan == user!.uid && durum == 'reddedildi') {
                  istekKarti = Card(color: Colors.red.shade50, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent, width: 2)), child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [const Icon(Icons.block_flipped, color: Colors.redAccent, size: 40), const SizedBox(height: 10), const Text("Partneriniz anıların silinmesini KABUL ETMEDİ.", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16, fontFamily: 'Serif')), const SizedBox(height: 15), Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () => _silmeIstegiGonder(context, ciftId), child: const Text("İsteği Tekrar Gönder", style: TextStyle(color: Colors.white, fontFamily: 'Serif'))), const SizedBox(height: 5), OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)), onPressed: () => _odadanSadeceAyril(context, ciftId), child: const Text("Silmeden Ayrıl", style: TextStyle(color: Colors.redAccent, fontFamily: 'Serif'))), TextButton(onPressed: () => _istegiGeriCek(ciftId), child: const Text("Vazgeç (Odada Kalmaya Devam Et)", style: TextStyle(color: Colors.brown, fontFamily: 'Serif')))])])));
                }
              }

              Widget profilFotograflariAlani;

              if (partnerUid.isEmpty) {
                profilFotograflariAlani = Center(
                  child: _profilBileseniOlustur(isFront: true, fotoUrl: fotoUrl, isPartner: false, partnerYazdiMi: false),
                );
              } else {
                profilFotograflariAlani = StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('Users').doc(partnerUid).snapshots(),
                    builder: (context, partnerSnap) {
                      String? pFotoUrl;
                      String? pFcmToken;

                      if (partnerSnap.hasData && partnerSnap.data!.exists) {
                        var pData = partnerSnap.data!.data() as Map<String, dynamic>;
                        pFotoUrl = pData['profilFoto'];
                        pFcmToken = pData['fcmToken'];
                      }

                      String bugun = DateTime.now().toString().substring(0, 10);
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('GunlukKayitlar')
                            .where('cift_id', isEqualTo: ciftId)
                            .where('yazar_uid', isEqualTo: partnerUid)
                            .where('tarih_str', isEqualTo: bugun)
                            .snapshots(),
                        builder: (context, gunlukSnap) {

                          bool partnerYazdiMi = false;
                          if (gunlukSnap.hasData && gunlukSnap.data!.docs.isNotEmpty) {
                            for (var doc in gunlukSnap.data!.docs) {
                              var d = doc.data() as Map<String, dynamic>;
                              if (d['paylasildi_mi'] == true && d['copte_mi'] != true) {
                                partnerYazdiMi = true;
                                break;
                              }
                            }
                          }

                          return Column(
                            children: [
                              GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  setState(() => _benOndeyim = !_benOndeyim);
                                },
                                child: SizedBox(
                                  width: 170,
                                  height: 130,
                                  child: Stack(
                                    children: [
                                      if (_benOndeyim) _profilBileseniOlustur(isFront: false, fotoUrl: pFotoUrl, isPartner: true, partnerYazdiMi: partnerYazdiMi),
                                      if (!_benOndeyim) _profilBileseniOlustur(isFront: false, fotoUrl: fotoUrl, isPartner: false, partnerYazdiMi: false),

                                      if (_benOndeyim) _profilBileseniOlustur(isFront: true, fotoUrl: fotoUrl, isPartner: false, partnerYazdiMi: false),
                                      if (!_benOndeyim) _profilBileseniOlustur(isFront: true, fotoUrl: pFotoUrl, isPartner: true, partnerYazdiMi: partnerYazdiMi),
                                    ],
                                  ),
                                ),
                              ),

                              if (!partnerYazdiMi) ...[
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: _bildirimGonderiliyor ? null : () => _partneriUyar(pFcmToken, nickname),
                                  icon: _bildirimGonderiliyor
                                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent))
                                      : const Icon(Icons.notifications_active_rounded, color: Colors.pinkAccent, size: 18),
                                  label: const Text("Sevgiline Günlüğü Hatırlat 💌", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
                                  style: TextButton.styleFrom(
                                      backgroundColor: Colors.pinkAccent.withOpacity(0.1),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                )
                              ]
                            ],
                          );
                        },
                      );
                    }
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    istekKarti,
                    profilFotograflariAlani,
                    const SizedBox(height: 30),

                    // ✅ KİŞİSEL BİLGİLER BLOĞU
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 10, top: 12, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("KİŞİSEL BİLGİLER", style: TextStyle(color: Colors.brown.shade300, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Serif', letterSpacing: 1.2)),
                                TextButton.icon(
                                  onPressed: () => _bilgileriDuzenle(ad, soyad, nickname),
                                  icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFC07B54)),
                                  label: const Text("Düzenle", style: TextStyle(color: Color(0xFFC07B54), fontFamily: 'Serif', fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap
                                  ),
                                )
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                          ListTile(
                              leading: const Icon(Icons.person, color: Colors.brown),
                              title: const Text("Ad Soyad", style: TextStyle(fontFamily: 'Serif')),
                              subtitle: Text("$ad $soyad", style: const TextStyle(fontFamily: 'Serif'))
                          ),
                          const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                          ListTile(
                            leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                            title: const Text("Hitap Şeklin", style: TextStyle(fontFamily: 'Serif')),
                            subtitle: Text(nickname.isEmpty ? "Belirlenmedi (Varsayılan: Sevgilim)" : nickname, style: TextStyle(fontFamily: 'Serif', fontStyle: FontStyle.italic, color: Colors.brown.shade400)),
                          ),
                          const SizedBox(height: 5),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Showcase(key: _odaAnahtari, title: 'Ortak Odanızın Anahtarı 🔑', description: 'Sevgilinle aynı odaya bağlanmak için gereken Oda adı ve kilitli anıları açan oda şifreniz tam olarak burada.', child: ListTile(leading: const Icon(Icons.sensor_door_rounded, color: Colors.brown), title: const Text("Oda Bilgilerimiz", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif')), subtitle: const Text("Oda kodunu kopyala veya şifreyi değiştir", style: TextStyle(fontFamily: 'Serif')), trailing: const Icon(Icons.chevron_right, color: Colors.brown), onTap: () => _odaBilgileriniGosterDialog(ciftId))),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Showcase(key: _hayaletAnahtari, title: 'Hayalet Mod 👻', description: 'Telefonun başkasının eline geçerse diye uygulamaya Hem geçek hemde sahte bir şifre tanımlayabilirsin.', child: SwitchListTile(activeColor: Colors.brown, title: const Text("Hayalet Mod Kilidi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif')), subtitle: const Text("Girişte parola sorar. Sahte parolayla sahte bir günlük açılır.", style: TextStyle(fontFamily: 'Serif', fontSize: 13)), value: kilitAktif, onChanged: (bool deger) { if (deger) { _kilitSifreleriniBelirleDialog(); } else { FirebaseFirestore.instance.collection('Users').doc(user!.uid).update({'kilit_aktif': false}); } })),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Showcase(key: _copAnahtari, title: 'Çöp Kutusu 🗑️', description: 'Sildiğin anılar 30 gün boyunca burada saklanır. Fikrini değiştirirsen geri yükleyebilirsin.', child: ListTile(leading: const Icon(Icons.delete_outline, color: Colors.brown), title: const Text("Çöp Kutusu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif')), subtitle: const Text("Silinen anıları gör veya kurtar", style: TextStyle(fontFamily: 'Serif')), trailing: const Icon(Icons.chevron_right, color: Colors.brown), onTap: () { if (ciftId.isNotEmpty) { Navigator.push(context, MaterialPageRoute(builder: (context) => CopKutusu(ciftId: ciftId))); } })),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
                          boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: Showcase(
                        key: _ayrilmaAnahtari,
                        title: 'Odadan Ayrıl 🚪',
                        description: 'Başka bir odaya geçmek veya partnerinle bağlantıyı koparmak istersen, buradan kendi eşyalarını toplayıp odadan çıkabilirsin.',
                        child: ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.meeting_room_rounded, color: Colors.redAccent)
                          ),
                          title: const Text("Odadan Ayrıl", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontFamily: 'Serif', fontSize: 16)),
                          subtitle: Text("Mevcut odadan ve partnerinden ayrıl", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Serif')),
                          trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                          onTap: () => _odadanAyrilOnay(context, ciftId),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    Center(
                      child: OutlinedButton.icon(
                          onPressed: () => _cikisYapOnay(context),
                          icon: Icon(Icons.logout, color: Colors.brown.shade500, size: 19),
                          label: Text("Hesaptan Çıkış Yap", style: TextStyle(color: Colors.brown.shade500, fontWeight: FontWeight.bold, fontFamily: 'Serif', fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.brown.withOpacity(0.04),
                            side: BorderSide(color: Colors.brown.withOpacity(0.25), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          )
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}