import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CopKutusu extends StatefulWidget {
  final String ciftId;
  const CopKutusu({super.key, required this.ciftId});

  @override
  State<CopKutusu> createState() => _CopKutusuState();
}

class _CopKutusuState extends State<CopKutusu> {
  final String _suankiUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _aniGeriYukle(String docId) async {
    await FirebaseFirestore.instance.collection('GunlukKayitlar').doc(docId).update({'copte_mi': false});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anı başarıyla geri yüklendi! ♻️")));
  }

  Future<void> _aniKaliciSil(String docId) async {
    bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kalıcı Olarak Sil", style: TextStyle(color: Colors.red)),
        content: const Text("Bu anıyı tamamen silmek istediğinize emin misiniz? Bu işlem geri alınamaz!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Evet, Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay == true) {
      await FirebaseFirestore.instance.collection('GunlukKayitlar').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anı sonsuza dek silindi. 🗑️")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: const Text("Çöp Kutusu", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.brown),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Tekrar eski RAM Filtreleme yöntemine dönüyoruz. Hem en hızlısı, hem Firebase Index istemiyor.
        stream: FirebaseFirestore.instance
            .collection('GunlukKayitlar')
            .where('cift_id', isEqualTo: widget.ciftId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.brown));

          var coptekiAnilar = snapshot.data!.docs.where((doc) {
            var veri = doc.data() as Map<String, dynamic>;
            bool copte = veri['copte_mi'] ?? false;
            String yazar = veri['yazar_uid'] ?? "";
            return copte == true && yazar == _suankiUid;
          }).toList();

          if (coptekiAnilar.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 80, color: Colors.brown.withOpacity(0.3)),
                  const SizedBox(height: 15),
                  Text("Çöp kutusu tertemiz!", style: TextStyle(fontSize: 18, color: Colors.brown.withOpacity(0.6))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: coptekiAnilar.length,
            itemBuilder: (context, index) {
              var doc = coptekiAnilar[index];
              var veri = doc.data() as Map<String, dynamic>;
              DateTime tarih = DateTime.tryParse(veri['tarih_str'] ?? "") ?? DateTime.now();
              String formatliTarih = DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih);

              String gosterilecekEmoji = "❤️";
              if (veri['mood_emoji'] != null) {
                var moodData = veri['mood_emoji'];
                gosterilecekEmoji = moodData is List ? moodData.join("") : moodData.toString();
              }

              return Card(
                color: Colors.white70,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),

                  // ✅ ÇÖZÜM BURADA: Emojileri sabit bir kutuya koyduk (SizedBox) ve içine sığması için FittedBox kullandık. Asla taşmaz!
                  leading: SizedBox(
                    width: 50, // Kutunun maksimum genişliği
                    height: 50,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(gosterilecekEmoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),

                  title: Text(formatliTarih, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                  subtitle: Text(veri['ani_notu'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min, // Bu da butonların taşmasını engeller
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.green),
                        tooltip: "Geri Yükle",
                        onPressed: () => _aniGeriYukle(doc.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: "Kalıcı Sil",
                        onPressed: () => _aniKaliciSil(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}