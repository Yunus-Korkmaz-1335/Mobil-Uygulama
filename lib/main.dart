import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'ekranlar/giris_ekrani.dart';
import 'ekranlar/ana_sayfa.dart';
import 'ekranlar/profil_tamamlama.dart';
import 'ekranlar/eslesme_ekrani.dart';
import 'package:sadeceben/servisler/bildirim_servisi.dart';
import 'ekranlar/kilit_ekrani.dart';
import 'package:sadeceben/servisler/kasa_servisi.dart'; // ✅ KASA SERVİSİ EKLENDİ

// ✅ 1. ADMOB PAKETİ İÇERİ AKTARILDI
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ✅ TÜRKÇE DİL PAKETİ İÇERİ AKTARILDI
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 2. UYGULAMA AÇILIRKEN REKLAM MOTORU BAŞLATILDI
  await MobileAds.instance.initialize();

  await initializeDateFormatting('tr_TR', null);
  await BildirimServisi().init();

  // ✅ UYGULAMA AÇILIR AÇILMAZ GALERİ KORUMASINI (KASAYI) AKTİF ET
  await KasaServisi.kasayiKilitle();

  runApp(const AktiviteGunlugum());
}

class AktiviteGunlugum extends StatefulWidget {
  const AktiviteGunlugum({super.key});

  @override
  State<AktiviteGunlugum> createState() => _AktiviteGunlugumState();
}

class _AktiviteGunlugumState extends State<AktiviteGunlugum> {
  bool _internetYok = false;
  bool _yeniBaglandi = false;
  Timer? _zamanlayici;
  late StreamSubscription<List<ConnectivityResult>> _abonelik;

  @override
  void initState() {
    super.initState();
    _abonelik = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> sonuc) {
      bool suanYok = sonuc.contains(ConnectivityResult.none);

      if (_internetYok && !suanYok) {
        setState(() {
          _internetYok = false;
          _yeniBaglandi = true;
        });
        _zamanlayici?.cancel();
        _zamanlayici = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _yeniBaglandi = false);
          }
        });
      } else if (suanYok) {
        setState(() {
          _internetYok = true;
          _yeniBaglandi = false;
        });
        _zamanlayici?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _abonelik.cancel();
    _zamanlayici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SadeceBiz',
      debugShowCheckedModeBanner: false,

      // ✅ SİSTEM MENÜLERİNİ TÜRKÇE YAPMAK İÇİN GEREKEN AYARLAR EKLENDİ
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Ana dil Türkçe
        Locale('en', 'US'), // Yedek dil İngilizce
      ],

      theme: ThemeData(
        primarySwatch: Colors.brown,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF5E6),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (_internetYok || _yeniBaglandi)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _internetYok ? Colors.redAccent.shade400 : Colors.green.shade500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_internetYok ? Icons.wifi_off_rounded : Icons.wifi_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                            _internetYok ? "İnternet Bağlantısı Koptu" : "Tekrar Bağlandınız!",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) return const GirisEkrani();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const ProfilTamamlamaEkrani();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final String ciftId = (userData['ciftId'] ?? "").toString().trim();
            final bool kilitAktif = userData['kilit_aktif'] ?? false;

            if (ciftId.isEmpty) return const EslesmeEkrani();

            if (kilitAktif) {
              return KilitEkrani(ciftId: ciftId);
            } else {
              return AnaSayfa(ciftId: ciftId);
            }
          },
        );
      },
    );
  }
}