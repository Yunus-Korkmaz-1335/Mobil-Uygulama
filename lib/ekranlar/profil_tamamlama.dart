import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'giris_ekrani.dart';

class ProfilTamamlamaEkrani extends StatefulWidget {
  const ProfilTamamlamaEkrani({super.key});

  @override
  State<ProfilTamamlamaEkrani> createState() => _ProfilTamamlamaEkraniState();
}

class _ProfilTamamlamaEkraniState extends State<ProfilTamamlamaEkrani> {
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  bool _yukleniyor = false;

  Future<void> profiliKaydet() async {
    if (_adController.text.trim().isEmpty || _soyadController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen ad ve soyad alanlarını doldurun.", style: TextStyle(fontFamily: 'Serif'))));
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'ad': _adController.text.trim(),
        'soyad': _soyadController.text.trim(),
        'nickname': "", // ✅ Rumuz alanı kaldırıldı, veritabanına boş gidiyor
        'kayit_tarihi': FieldValue.serverTimestamp(),
        'profil_tamamlandi': true,
        'ciftId': "",
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e", style: const TextStyle(fontFamily: 'Serif'))));
    }
  }

  Widget _kagitGirisAlani({required TextEditingController controller, required String baslik, required String ipucu, required IconData ikon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: TextStyle(color: Colors.brown.shade400, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
            TextField(
              controller: controller,
              style: const TextStyle(fontFamily: 'Serif', fontSize: 16, color: Colors.brown),
              decoration: InputDecoration(
                hintText: ipucu,
                hintStyle: TextStyle(color: Colors.brown.shade200, fontSize: 15, fontFamily: 'Serif', fontStyle: FontStyle.italic),
                border: InputBorder.none,
                icon: Icon(ikon, color: Colors.brown.shade300, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: const Text("Seni Tanıyalım", style: TextStyle(fontFamily: 'Serif', color: Colors.brown, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.brown),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const GirisEkrani()),
                  (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // ✅ İkonografi Güncellemesi: Yanıltıcı kamera gitti, "Hikaye" hissi veren tüy kalem geldi
              Center(
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCA73A).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_edu_rounded, size: 60, color: Color(0xFFC07B54)),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Senin Hikayen Başlıyor...",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Serif', fontSize: 22, color: Colors.brown, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Bu günlüğün ilk sayfasına adını yazarak anıları biriktirmeye başla.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Serif', fontSize: 15, color: Colors.brown.shade400, height: 1.4),
              ),
              const SizedBox(height: 40),

              _kagitGirisAlani(controller: _adController, baslik: "ADINIZ", ipucu: "Örn. Yunus", ikon: Icons.person_outline),
              _kagitGirisAlani(controller: _soyadController, baslik: "SOYADINIZ", ipucu: "Örn. Korkmaz", ikon: Icons.badge_outlined),
              // ✅ Rumuz alanı silindi, ekran sadeleştirildi!

              const SizedBox(height: 30),

              _yukleniyor
                  ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                  : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC07B54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      shadowColor: const Color(0xFFC07B54).withOpacity(0.4)
                  ),
                  onPressed: profiliKaydet,
                  child: const Text("Birlikte Anı Biriktirelim", style: TextStyle(fontFamily: 'Serif', fontSize: 16, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ),
    );
  }
}