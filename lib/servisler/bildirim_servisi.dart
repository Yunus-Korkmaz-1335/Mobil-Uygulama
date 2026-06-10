import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BildirimServisi {
  static final BildirimServisi _instance = BildirimServisi._internal();
  factory BildirimServisi() => _instance;
  BildirimServisi._internal();

  // Firebase'in bildirim motoru
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. KULLANICIDAN AÇIKÇA BİLDİRİM İZNİ İSTE
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. İZİN VERİLDİYSE, CİHAZIN EŞSİZ KARGO ADRESİNİ (TOKEN) AL
      String? token = await _fcm.getToken();

      // 3. BU ADRESİ VERİTABANINA KAYDET
      _tokeniVeritabaninaKaydet(token);

      // (Ekstra Güvenlik): Google bazen bu token'ı güvenlik için günceller.
      // Eğer güncellenirse bizim veritabanında da otomatik güncellensin.
      _fcm.onTokenRefresh.listen((yeniToken) {
        _tokeniVeritabaninaKaydet(yeniToken);
      });
    }
  }

  // TOKEN'I USERS KOLEKSİYONUNA YAZAN FONKSİYON
  Future<void> _tokeniVeritabaninaKaydet(String? token) async {
    if (token == null) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
        'fcmToken': token, // Sunucu bu adresi kullanarak bildirim atacak!
      });
    }
  }
}