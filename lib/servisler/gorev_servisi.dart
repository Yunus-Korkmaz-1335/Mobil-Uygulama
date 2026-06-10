import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GorevServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Kullanıcı için günün BİREYSEL görevini getir veya yeni oluştur
  Future<DocumentSnapshot> gununGoreviniGetir(String ciftId) async {
    String bugun = DateTime.now().toString().substring(0, 10);
    String suankiUid = FirebaseAuth.instance.currentUser!.uid;

    var gunlukRef = _db.collection('GunlukKayitlar')
        .where('cift_id', isEqualTo: ciftId)
        .where('tarih_str', isEqualTo: bugun)
        .where('yazar_uid', isEqualTo: suankiUid);

    var sorguSonucu = await gunlukRef.get();

    if (sorguSonucu.docs.isNotEmpty) {
      var gunlukDoc = sorguSonucu.docs.first;

      // ✅ KENDİNİ ONARAN SİSTEM: Eski görev veritabanında hala duruyor mu?
      String gorevId = gunlukDoc['gorev_id'];
      var gorevKontrol = await _db.collection('GorevHavuzu').doc(gorevId).get();

      if (!gorevKontrol.exists) {
        // Veritabanı yenilendiği için görev silinmiş. Eski günlüğü çöpe atıp taze görev çekiyoruz.
        await gunlukDoc.reference.delete();
        return await _yeniGorevAta(ciftId, bugun, suankiUid);
      }

      return gunlukDoc;
    } else {
      return await _yeniGorevAta(ciftId, bugun, suankiUid);
    }
  }

  Future<DocumentSnapshot> _yeniGorevAta(String ciftId, String bugun, String suankiUid) async {
    var havuz = await _db.collection('GorevHavuzu').get();

    if (havuz.docs.isEmpty) {
      throw Exception("Görev havuzunda hiç görev bulunamadı! Lütfen görevleri yükleyin.");
    }

    var rastgeleIndex = Random().nextInt(havuz.docs.length);
    var secilenGorev = havuz.docs[rastgeleIndex];

    DocumentReference yeniKayit = await _db.collection('GunlukKayitlar').add({
      'cift_id': ciftId,
      'tarih_str': bugun,
      'gorev_id': secilenGorev.id,
      'kazindi_mi': false,
      'yazar_uid': suankiUid,
      'gorev_kabul_edildi': false,
      'gorev_tamamlandi': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return await yeniKayit.get();
  }
}