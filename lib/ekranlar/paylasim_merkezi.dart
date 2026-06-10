import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaylasimMerkezi extends StatefulWidget {
  final String ciftId;
  const PaylasimMerkezi({super.key, required this.ciftId});

  @override
  State<PaylasimMerkezi> createState() => _PaylasimMerkeziState();
}

class _PaylasimMerkeziState extends State<PaylasimMerkezi> {
  final String _suankiUid = FirebaseAuth.instance.currentUser!.uid;
  String? _partnerUid;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _partneriBul();
  }

  Future<void> _partneriBul() async {
    try {
      var odaDoc = await FirebaseFirestore.instance.collection('Ciftler').doc(widget.ciftId).get();
      if (odaDoc.exists) {
        var veri = odaDoc.data() as Map<String, dynamic>;
        String p1 = veri['partner1'] ?? "";
        String p2 = veri['partner2'] ?? "";

        setState(() {
          _partnerUid = (p1 == _suankiUid) ? p2 : p1;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _erisimVer() async {
    if (_partnerUid == null || _partnerUid!.isEmpty) return;
    await FirebaseFirestore.instance.collection('Users').doc(_suankiUid).set({
      'gunlugumu_gorebilenler': FieldValue.arrayUnion([_partnerUid]),
      'gelen_istekler': FieldValue.arrayRemove([_partnerUid]),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Günlüğünün anahtarını sevgiline verdin! 🗝️❤️")));
  }

  Future<void> _istegiReddet() async {
    if (_partnerUid == null || _partnerUid!.isEmpty) return;
    await FirebaseFirestore.instance.collection('Users').doc(_suankiUid).set({
      'gelen_istekler': FieldValue.arrayRemove([_partnerUid]),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Günlük okuma isteği reddedildi.")));
  }

  Future<void> _erisimiIptalEt() async {
    if (_partnerUid == null || _partnerUid!.isEmpty) return;
    await FirebaseFirestore.instance.collection('Users').doc(_suankiUid).set({
      'gunlugumu_gorebilenler': FieldValue.arrayRemove([_partnerUid])
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erişim durduruldu. Anıların artık sadece sana özel. 🔒")));
  }

  Future<void> _istekGonder() async {
    if (_partnerUid == null || _partnerUid!.isEmpty) return;
    await FirebaseFirestore.instance.collection('Users').doc(_partnerUid).set({
      'gelen_istekler': FieldValue.arrayUnion([_suankiUid])
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sevgiline günlük okuma isteği gönderildi! 📩")));
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDF5E6),
        body: Center(child: CircularProgressIndicator(color: Colors.brown)),
      );
    }

    if (_partnerUid == null || _partnerUid!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDF5E6),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text("Odanızda henüz bir partner yok.", style: TextStyle(color: Colors.brown))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: const Text("Mahremiyet ve Paylaşım", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.brown),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(_suankiUid).snapshots(),
        builder: (context, snapshotBen) {
          if (!snapshotBen.hasData) return const Center(child: CircularProgressIndicator());

          var benimVerim = snapshotBen.data!.data() as Map<String, dynamic>? ?? {};
          List benimIzinVerdiklerim = benimVerim['gunlugumu_gorebilenler'] ?? [];
          List banaGelenIstekler = benimVerim['gelen_istekler'] ?? [];

          bool benIzinVerdimMi = benimIzinVerdiklerim.contains(_partnerUid);
          bool partnerBendenIzinIstiyorMu = banaGelenIstekler.contains(_partnerUid);

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Users').doc(_partnerUid).snapshots(),
            builder: (context, snapshotPartner) {
              if (!snapshotPartner.hasData) return const Center(child: CircularProgressIndicator());

              var partnerVerim = snapshotPartner.data!.data() as Map<String, dynamic>? ?? {};
              List partnerinIzinVerdikleri = partnerVerim['gunlugumu_gorebilenler'] ?? [];
              List partnereGelenIstekler = partnerVerim['gelen_istekler'] ?? [];

              bool partnerBanaIzinVerdiMi = partnerinIzinVerdikleri.contains(_suankiUid);
              bool benPartnerdenIzinIstedimMi = partnereGelenIstekler.contains(_suankiUid);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.vpn_key_rounded, size: 60, color: Colors.brown),
                    const SizedBox(height: 20),
                    const Text(
                      "Günlük Anahtarları",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "SadeceBiz'de herkesin günlüğü kendine aittir. Karşılıklı izin vermediğiniz sürece kimse kimsenin anılarını göremez.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // --- 1. BENİM GÜNLÜĞÜM ---
                    _kartOlustur(
                      baslik: "Benim Günlüğüm",
                      ikon: Icons.menu_book_rounded,
                      durumIkon: benIzinVerdimMi ? Icons.lock_open : Icons.lock,
                      durumRenk: benIzinVerdimMi ? Colors.green : Colors.redAccent,
                      durumMetni: benIzinVerdimMi ? "Sevgilin günlüğünü okuyabilir" : "Günlüğün sevgiline gizli",

                      butonW: partnerBendenIzinIstiyorMu && !benIzinVerdimMi
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _erisimVer,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                              icon: const Icon(Icons.check, color: Colors.brown, size: 18),
                              label: const FittedBox(child: Text("Kabul Et", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _istegiReddet,
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                              label: const FittedBox(child: Text("Reddet", style: TextStyle(color: Colors.redAccent))),
                            ),
                          ),
                        ],
                      )
                          : benIzinVerdimMi
                      // ✅ DÜZELTME: Metin yerine şık bir Buton yapıldı
                          ? OutlinedButton.icon(
                        onPressed: _erisimiIptalEt,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        icon: const Icon(Icons.block, color: Colors.redAccent),
                        label: const Text("Erişimi Durdur", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      )
                          : ElevatedButton.icon(
                        onPressed: _erisimVer,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                        icon: const Icon(Icons.key, color: Colors.white),
                        label: const Text("Anahtarı Sevgilime Ver", style: TextStyle(color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- 2. SEVGİLİMİN GÜNLÜĞÜ ---
                    _kartOlustur(
                      baslik: "Sevgilimin Günlüğü",
                      ikon: Icons.favorite,
                      durumIkon: partnerBanaIzinVerdiMi ? Icons.lock_open : Icons.lock,
                      durumRenk: partnerBanaIzinVerdiMi ? Colors.green : Colors.redAccent,
                      durumMetni: partnerBanaIzinVerdiMi ? "Sevgilinin günlüğünü okuyabilirsin!" : "Sevgilinin günlüğü sana gizli",
                      butonW: partnerBanaIzinVerdiMi
                          ? const Text("Artık anılar sayfasını sola kaydırarak onun günlüğüne gizlice bakabilirsin! 🤫",
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                          : benPartnerdenIzinIstedimMi
                          ? const Text("İstek gönderildi, onay bekleniyor ⏳",
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
                          : ElevatedButton.icon(
                        onPressed: _istekGonder,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text("Okumak İçin İstek Gönder", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _kartOlustur({required String baslik, required IconData ikon, required IconData durumIkon, required Color durumRenk, required String durumMetni, required Widget butonW}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: Colors.brown),
              const SizedBox(width: 10),
              Text(baslik, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(durumIkon, color: durumRenk, size: 20),
              const SizedBox(width: 8),
              Text(durumMetni, style: TextStyle(color: durumRenk, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          butonW,
        ],
      ),
    );
  }
}