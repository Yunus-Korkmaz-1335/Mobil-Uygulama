import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servisler/guvenlik_servisi.dart';
import 'ana_sayfa.dart';

class KilitEkrani extends StatefulWidget {
  final String ciftId;
  const KilitEkrani({super.key, required this.ciftId});

  @override
  State<KilitEkrani> createState() => _KilitEkraniState();
}

class _KilitEkraniState extends State<KilitEkrani> {
  String _girilenSifre = "";
  bool _yukleniyor = false;

  void _tusBas(String tus) {
    if (_girilenSifre.length < 4) {
      setState(() => _girilenSifre += tus);
      if (_girilenSifre.length == 4) _sifreKontrolEt();
    }
  }

  void _sil() {
    if (_girilenSifre.isNotEmpty) {
      setState(() => _girilenSifre = _girilenSifre.substring(0, _girilenSifre.length - 1));
    }
  }

  Future<void> _sifreKontrolEt() async {
    setState(() => _yukleniyor = true);
    String uid = FirebaseAuth.instance.currentUser!.uid;

    var doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    var data = doc.data() as Map<String, dynamic>;

    String gercek = data['gercek_sifre'] ?? "";
    String sahte = data['sahte_sifre'] ?? "";

    if (_girilenSifre == gercek) {
      GuvenlikServisi().sahteMod = false;
      _yonlendir();
    } else if (_girilenSifre == sahte) {
      GuvenlikServisi().sahteMod = true;
      _yonlendir();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!"), backgroundColor: Colors.red));
      setState(() {
        _girilenSifre = "";
        _yukleniyor = false;
      });
    }
  }

  // ŞİFRE KURTARMA SİSTEMİ
  Future<void> _sifremiUnuttum() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    var data = doc.data() as Map<String, dynamic>;

    String soru = data['guvenlik_sorusu'] ?? "";
    String asilCevap = data['guvenlik_cevabi'] ?? "";

    if (soru.isEmpty) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bunun için bir güvenlik sorusu ayarlanmamış. Lütfen uygulamayı yeniden yükleyin.")));
      return;
    }

    TextEditingController cevapController = TextEditingController();

    bool? basarili = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            scrollable: true, // ✅ ÇÖZÜM 1: Klavye açılınca pencere yukarı kayar
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Şifre Kurtarma", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Soru: $soru", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),
                TextField(
                  controller: cevapController,
                  decoration: InputDecoration(
                    labelText: "Cevabınız",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                onPressed: () {
                  if (cevapController.text.trim().toLowerCase() == asilCevap) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yanlış cevap!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Doğrula ve Kilidi Aç", style: TextStyle(color: Colors.white)),
              )
            ]
        )
    );

    if (basarili == true) {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({'kilit_aktif': false});
      GuvenlikServisi().sahteMod = false;
      _yonlendir();
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kilit kaldırıldı! Güvenliğiniz için profilinizden yeni bir şifre belirleyin.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    }
  }

  void _yonlendir() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa(ciftId: widget.ciftId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      resizeToAvoidBottomInset: false, // ✅ ÇÖZÜM 2: Arka plandaki sayfa klavye açılınca küçülmeye çalışmaz, sabit kalır!
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 70, color: Colors.brown),
            const SizedBox(height: 15),
            const Text("SadeceBiz", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown)),
            const SizedBox(height: 10),
            const Text("Lütfen parolanızı girin", style: TextStyle(color: Colors.brown, fontSize: 16)),
            const SizedBox(height: 40),

            // Şifre Noktaları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _girilenSifre.length ? Colors.brown : Colors.transparent,
                    border: Border.all(color: Colors.brown, width: 2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 50),

            // Numpad
            _yukleniyor
                ? const CircularProgressIndicator(color: Colors.brown)
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, childAspectRatio: 1.2, mainAxisSpacing: 10, crossAxisSpacing: 10
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) return const SizedBox();
                  if (index == 11) {
                    return IconButton(icon: const Icon(Icons.backspace, color: Colors.brown, size: 30), onPressed: _sil);
                  }
                  String rakam = index == 10 ? "0" : "${index + 1}";
                  return InkWell(
                    onTap: () => _tusBas(rakam),
                    borderRadius: BorderRadius.circular(40),
                    child: Center(child: Text(rakam, style: const TextStyle(fontSize: 28, color: Colors.brown, fontWeight: FontWeight.bold))),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            TextButton(
              onPressed: _sifremiUnuttum,
              child: const Text("Parolamı Unuttum", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}