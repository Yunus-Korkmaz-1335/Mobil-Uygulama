import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class EslesmeEkrani extends StatefulWidget {
  const EslesmeEkrani({super.key});

  @override
  State<EslesmeEkrani> createState() => _EslesmeEkraniState();
}

class _EslesmeEkraniState extends State<EslesmeEkrani> {
  final _odaAdiController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _islemYapiliyor = false;

  Future<void> _eskiOdalardanCik(String uid) async {
    try {
      var p1Docs = await FirebaseFirestore.instance.collection('Ciftler').where('partner1', isEqualTo: uid).get();
      for (var doc in p1Docs.docs) {
        await doc.reference.update({'partner1': '', 'durum': 'bekliyor'});
      }

      var p2Docs = await FirebaseFirestore.instance.collection('Ciftler').where('partner2', isEqualTo: uid).get();
      for (var doc in p2Docs.docs) {
        await doc.reference.update({'partner2': '', 'durum': 'bekliyor'});
      }
    } catch (e) {
      print("Eski oda temizliği hatası: $e");
    }
  }

  Future<void> _userCiftIdGuncelle(String odaId) async {
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({'ciftId': odaId});
  }

  Future<void> odaOlustur() async {
    final odaAdi = _odaAdiController.text.trim();
    final sifre = _sifreController.text.trim();
    final suankiUid = FirebaseAuth.instance.currentUser!.uid;

    if (odaAdi.isEmpty || sifre.isEmpty) return;

    setState(() => _islemYapiliyor = true);

    final odaRef = FirebaseFirestore.instance.collection('Ciftler').doc(odaAdi);
    final doc = await odaRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      if (data['partner1'] == suankiUid || data['partner2'] == suankiUid) {
        await _userCiftIdGuncelle(odaAdi);
        _yonlendir();
      }
      else if ((data['partner1'] == '' || data['partner1'] == null) && (data['partner2'] == '' || data['partner2'] == null)) {
        await _eskiOdalardanCik(suankiUid);
        await odaRef.update({
          'sifre': sifre,
          'partner1': suankiUid,
          'durum': 'bekliyor',
        });
        await _userCiftIdGuncelle(odaAdi);
        _yonlendir();
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu oda adı zaten başkası tarafından alınmış!")));
        setState(() => _islemYapiliyor = false);
      }
    } else {
      await _eskiOdalardanCik(suankiUid);

      await odaRef.set({
        'sifre': sifre,
        'partner1': suankiUid,
        'partner2': '',
        'durum': 'bekliyor',
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
      });
      await _userCiftIdGuncelle(odaAdi);
      _yonlendir();
    }
  }

  Future<void> odayaKatil() async {
    final odaAdi = _odaAdiController.text.trim();
    final sifre = _sifreController.text.trim();
    final suankiUid = FirebaseAuth.instance.currentUser!.uid;

    if (odaAdi.isEmpty || sifre.isEmpty) return;

    setState(() => _islemYapiliyor = true);

    final odaRef = FirebaseFirestore.instance.collection('Ciftler').doc(odaAdi);
    final doc = await odaRef.get();

    if (doc.exists) {
      final data = doc.data()!;

      if (data['sifre'] != sifre) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı şifre!")));
        setState(() => _islemYapiliyor = false);
        return;
      }

      if (data['partner1'] == suankiUid || data['partner2'] == suankiUid) {
        await _userCiftIdGuncelle(odaAdi);
        _yonlendir();
        return;
      }

      if (data['partner1'] == '' || data['partner1'] == null) {
        await _eskiOdalardanCik(suankiUid);
        await odaRef.update({
          'partner1': suankiUid,
          'durum': (data['partner2'] == '' || data['partner2'] == null) ? 'bekliyor' : 'dolu',
        });
        await _userCiftIdGuncelle(odaAdi);
        _yonlendir();
      }
      else if (data['partner2'] == '' || data['partner2'] == null) {
        await _eskiOdalardanCik(suankiUid);
        await odaRef.update({
          'partner2': suankiUid,
          'durum': 'dolu',
        });
        await _userCiftIdGuncelle(odaAdi);
        _yonlendir();
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu oda zaten dolu!")));
        setState(() => _islemYapiliyor = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Böyle bir oda bulunamadı!")));
      setState(() => _islemYapiliyor = false);
    }
  }

  void _yonlendir() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false
    );
  }

  // ✅ TÜRKÇE KARAKTER HATASI BURADA DÜZELTİLDİ: _kagitGirisAlani yapıldı
  Widget _kagitGirisAlani({required TextEditingController controller, required String baslik, required String ipucu, required IconData ikon, bool gizli = false}) {
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
              obscureText: gizli,
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: const Text("Bizim Odamız", style: TextStyle(fontFamily: 'Serif', color: Colors.brown, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.brown),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.sensor_door_rounded, size: 70, color: Color(0xFFC07B54)),
              const SizedBox(height: 30),
              // ✅ BAŞLIK DAHA SICAK BİR METİNLE DEĞİŞTİRİLDİ
              const Text(
                "Sizin Küçük Dünyanız...",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Serif', fontSize: 24, color: Colors.brown, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Sadece ikinizin bildiği özel bir oda adı ve kilidi belirleyin. Eğer partnerin odayı çoktan kurduysa, anahtarı kullanarak odaya katıl.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Serif', fontSize: 15, color: Colors.brown.shade500, height: 1.5),
              ),
              const SizedBox(height: 40),

              _kagitGirisAlani(controller: _odaAdiController, baslik: "GİZLİ ODA ADI", ipucu: "Örn: bizim_kucuk_dunyalarimiz", ikon: Icons.meeting_room_rounded),
              _kagitGirisAlani(controller: _sifreController, baslik: "ODA ŞİFRESİ", ipucu: "Sadece ikinizin bileceği bir sır...", ikon: Icons.vpn_key_rounded, gizli: true),

              const SizedBox(height: 30),

              _islemYapiliyor
                  ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC07B54),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 4,
                      ),
                      onPressed: odaOlustur,
                      icon: const Icon(Icons.add_home_work_rounded),
                      label: const Text("Yeni Bir Oda Kur", style: TextStyle(fontFamily: 'Serif', fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: odayaKatil,
                    icon: Icon(Icons.door_front_door_outlined, color: Colors.brown.shade400),
                    label: Text("Zaten bir odamız var, Katıl", style: TextStyle(fontFamily: 'Serif', fontSize: 15, color: Colors.brown.shade400, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
}