import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../servisler/kasa_servisi.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

part 'gunluk_tasarim_modlari.dart';

class GunlukKayitEkrani extends StatelessWidget {
  final String ciftId;
  final String gunlukKayitId;
  final bool? gorevKabulEdildi;

  const GunlukKayitEkrani({super.key, required this.ciftId, required this.gunlukKayitId, this.gorevKabulEdildi});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => _GunlukKayitEkraniIcerik(
        ciftId: ciftId,
        gunlukKayitId: gunlukKayitId,
        gorevKabulEdildi: gorevKabulEdildi,
      ),
    );
  }
}

class _GunlukKayitEkraniIcerik extends StatefulWidget {
  final String ciftId;
  final String gunlukKayitId;
  final bool? gorevKabulEdildi;

  const _GunlukKayitEkraniIcerik({required this.ciftId, required this.gunlukKayitId, this.gorevKabulEdildi});

  @override
  State<_GunlukKayitEkraniIcerik> createState() => _GunlukKayitEkraniIcerikState();
}

class _GunlukKayitEkraniIcerikState extends State<_GunlukKayitEkraniIcerik> {
  int _tasarimIndex = 0;
  final _notController = TextEditingController();
  List<String> _secilenEmojiler = [];
  List<File> _yeniSecilenDosyalar = [];
  List<String> _mevcutUrller = [];
  List<String> _resimNotlari = [];
  int _kapakIndex = 0;
  bool _yukleniyor = false;

  double _notAlaniYuksekligi = 150.0;

  String? _tamamlananGorevIcerigi;

  bool _kabulEdildi = false;
  bool _tamamlandi = false;
  bool _duzenlemeModu = true;
  String _gunTuru = 'normal';
  bool _benimAnimMi = true;

  SharedPreferences? _prefs;
  String get _taslakAnahtari => 'taslak_${widget.gunlukKayitId}';

  bool _muhurlendi = false;
  bool _ilkKayitZamaniVarMi = true;
  DateTime? _bitisZamani;
  Timer? _zamanlayici;
  String _kalanSureMetni = "";

  final GlobalKey _kilitAnahtari = GlobalKey();
  final GlobalKey _gorevAnahtari = GlobalKey();

  // ✅ REKLAM DEĞİŞKENLERİ
  InterstitialAd? _gecisReklami;
  bool _reklamHazir = false;

  @override
  void initState() {
    super.initState();
    _sistemiBaslat();
    _reklamYukle();
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _notController.dispose();
    _gecisReklami?.dispose();
    super.dispose();
  }

  void _reklamYukle() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3503111294336294/3350352561',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _gecisReklami = ad;
          _reklamHazir = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Reklam yüklenemedi: $error');
          _reklamHazir = false;
        },
      ),
    );
  }

  // ✅ 30 DAKİKA KONTROLÜ (PLAY STORE İÇİN HAZIR)
  Future<void> _reklamKontrolVeGoster() async {
    Completer<void> reklamBitti = Completer<void>();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? sonGosterimZamani = prefs.getInt('son_reklam_zamani');
    int suAnkiZaman = DateTime.now().millisecondsSinceEpoch;

    // ✅ 30 Dakika = 1.800.000 Milisaniye (30 * 60 * 1000)
    int beklemeSuresi = 1800000;

    if (sonGosterimZamani != null && (suAnkiZaman - sonGosterimZamani) < beklemeSuresi) {
      reklamBitti.complete();
      return reklamBitti.future;
    }

    if (_reklamHazir && _gecisReklami != null) {
      _gecisReklami!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _gecisReklami = null;
          _reklamHazir = false;
          _reklamYukle();
          if (!reklamBitti.isCompleted) reklamBitti.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _gecisReklami = null;
          _reklamHazir = false;
          _reklamYukle();
          if (!reklamBitti.isCompleted) reklamBitti.complete();
        },
      );

      _reklamHazir = false;
      _gecisReklami!.show();
      await prefs.setInt('son_reklam_zamani', suAnkiZaman);
    } else {
      reklamBitti.complete();
    }

    return reklamBitti.future;
  }

  void _zamanGuncelle() {
    if (_bitisZamani == null || !mounted) return;
    Duration fark = _bitisZamani!.difference(DateTime.now());

    if (fark.isNegative) {
      setState(() {
        _muhurlendi = true;
        _duzenlemeModu = false;
        _kalanSureMetni = "";
      });
      _zamanlayici?.cancel();
    } else {
      int saat = fark.inHours;
      int dakika = fark.inMinutes.remainder(60);
      String yeniMetin = "${saat}s ${dakika}d";

      if (_kalanSureMetni != yeniMetin) {
        setState(() {
          _kalanSureMetni = yeniMetin;
        });
      }
    }
  }

  void _sayaciBaslat() {
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 10), (timer) {
      _zamanGuncelle();
    });
  }

  Future<void> _sistemiBaslat() async {
    _prefs = await SharedPreferences.getInstance();
    await _eskiVerileriGetir();

    String? kurtarilanTaslak = _prefs?.getString(_taslakAnahtari);
    if (kurtarilanTaslak != null && kurtarilanTaslak.isNotEmpty && kurtarilanTaslak != _notController.text) {
      setState(() {
        _notController.text = kurtarilanTaslak;
      });
    }

    _notController.addListener(() {
      if (_duzenlemeModu) {
        _prefs?.setString(_taslakAnahtari, _notController.text);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool egitimGosterildi = _prefs?.getBool('egitim_gunluk_ekrani') ?? false;

      if (!egitimGosterildi) {
        Future.delayed(const Duration(milliseconds: 600), () {
          ShowCaseWidget.of(context).startShowCase([_kilitAnahtari, _gorevAnahtari]);
        });
        await _prefs?.setBool('egitim_gunluk_ekrani', true);
      }
    });
  }

  Future<void> _eskiVerileriGetir() async {
    var doc = await FirebaseFirestore.instance.collection('GunlukKayitlar').doc(widget.gunlukKayitId).get();
    if (doc.exists) {
      var veri = doc.data() as Map<String, dynamic>;

      setState(() {
        _notController.text = veri['ani_notu'] ?? "";

        var moodVerisi = veri['mood_emoji'];
        if (moodVerisi is String) {
          _secilenEmojiler = [moodVerisi];
        } else if (moodVerisi is List) {
          _secilenEmojiler = List<String>.from(moodVerisi);
        }

        _mevcutUrller = List<String>.from(veri['resim_listesi'] ?? []);
        _resimNotlari = List<String>.from(veri['resim_notlari'] ?? []);
        while (_resimNotlari.length < _mevcutUrller.length) {
          _resimNotlari.add("Anı");
        }
        if (veri['resim_url'] != null && veri['resim_url'] != "") {
          _kapakIndex = _mevcutUrller.indexOf(veri['resim_url']);
          if (_kapakIndex == -1) _kapakIndex = 0;
        }

        _kabulEdildi = widget.gorevKabulEdildi ?? veri['gorev_kabul_edildi'] ?? false;
        _tamamlandi = veri['gorev_tamamlandi'] ?? false;
        _gunTuru = veri['gun_turu'] ?? 'normal';

        if (_tamamlandi && veri['gorev_id'] != null) {
          _gorevIceriginiGetir(veri['gorev_id']);
        }

        String anininYazari = veri['yazar_uid'] ?? FirebaseAuth.instance.currentUser!.uid;
        _benimAnimMi = (anininYazari == FirebaseAuth.instance.currentUser!.uid);

        if (veri['ilk_kayit_zamani'] != null) {
          DateTime kayitZamani = (veri['ilk_kayit_zamani'] as Timestamp).toDate();
          _bitisZamani = kayitZamani.add(const Duration(hours: 48));

          if (DateTime.now().isAfter(_bitisZamani!)) {
            _muhurlendi = true;
          } else {
            _zamanGuncelle();
            _sayaciBaslat();
          }
        } else {
          _ilkKayitZamaniVarMi = false;
        }

        if (veri['paylasildi_mi'] == true || !_benimAnimMi || _muhurlendi) {
          _duzenlemeModu = false;
        }
      });
    }
  }

  Future<void> _gorevIceriginiGetir(String gorevId) async {
    try {
      var gorevDoc = await FirebaseFirestore.instance.collection('GorevHavuzu').doc(gorevId).get();
      if (gorevDoc.exists && mounted) {
        setState(() {
          _tamamlananGorevIcerigi = gorevDoc.data()?['icerik'];
        });
      }
    } catch (e) {
      print("Görev içeriği çekilemedi: $e");
    }
  }

  Future<void> _cokluResimSec() async {
    int maksFoto = 5;
    int mevcutToplam = _mevcutUrller.length + _yeniSecilenDosyalar.length;

    if (mevcutToplam >= maksFoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bir anıya en fazla $maksFoto fotoğraf ekleyebilirsiniz! 📸"), backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    int secilebilirKalan = maksFoto - mevcutToplam;

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFiles.isNotEmpty) {
      List<XFile> eklenecekDosyalar = pickedFiles;

      if (pickedFiles.length > secilebilirKalan) {
        eklenecekDosyalar = pickedFiles.take(secilebilirKalan).toList();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Sınırı aştınız! Sadece ilk $secilebilirKalan fotoğraf eklendi. ⚠️"), backgroundColor: Colors.orange.shade800, behavior: SnackBarBehavior.floating),
          );
        }
      }

      setState(() {
        _yeniSecilenDosyalar.addAll(eklenecekDosyalar.map((e) => File(e.path)).toList());
        for (var i = 0; i < eklenecekDosyalar.length; i++) {
          _resimNotlari.add("Anı");
        }
      });
    }
  }

  void _tamEkranGoster(int index) {
    List<dynamic> tumResimler = [..._mevcutUrller, ..._yeniSecilenDosyalar];
    if (tumResimler.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TamEkranFotoGosterici(
          resimler: tumResimler,
          baslangicIndex: index,
        ),
      ),
    );
  }

  void _resimSecenekleriniGoster(int globalIndex) {
    if (!_duzenlemeModu) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDF5E6),
      elevation: 10,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.brown.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.blue)),
                title: const Text("Notu Düzenle", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                onTap: () {
                  Navigator.pop(context);
                  _notDuzenleDialog(globalIndex);
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.amber)),
                title: const Text("Kapak Fotoğrafı Yap", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                onTap: () {
                  setState(() => _kapakIndex = globalIndex);
                  Navigator.pop(context);
                },
              ),
              const Divider(indent: 20, endIndent: 20, color: Colors.black12),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline, color: Colors.red)),
                title: const Text("Fotoğrafı Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  setState(() {
                    if (globalIndex < _mevcutUrller.length) {
                      _mevcutUrller.removeAt(globalIndex);
                    } else {
                      _yeniSecilenDosyalar.removeAt(globalIndex - _mevcutUrller.length);
                    }
                    _resimNotlari.removeAt(globalIndex);
                    if (_kapakIndex >= (_mevcutUrller.length + _yeniSecilenDosyalar.length)) _kapakIndex = 0;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notDuzenleDialog(int index) {
    TextEditingController tempNotController = TextEditingController(text: _resimNotlari[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fotoğraf Notu"),
        content: TextField(
          controller: tempNotController,
          maxLength: 20,
          decoration: const InputDecoration(hintText: "Kısa bir not yazın..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              setState(() => _resimNotlari[index] = tempNotController.text);
              Navigator.pop(context);
            },
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  Future<void> _kaydetSorgusu() async {
    if (_notController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir not ekleyin!")));
      return;
    }

    if (_kabulEdildi && !_tamamlandi) {
      bool? gercektenYaptiMi = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 10),
              Text("Görevi Yaptın Mı?"),
            ],
          ),
          content: const Text("Meydan okumayı kabul etmiştin. Bu görevi partnerinle gerçekten yerine getirdiniz mi?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Hayır, Sadece Anı Yazıyorum", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Evet, Görevi Tamamladık! 🏆", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (gercektenYaptiMi == null) return;

      setState(() {
        _tamamlandi = gercektenYaptiMi;
      });
    }

    await _aniKaydetAsil();
  }

  Future<void> _aniKaydetAsil() async {
    setState(() => _yukleniyor = true);
    try {
      Future reklamGorevi = _reklamKontrolVeGoster();

      List<String> yuklenenUrller = List.from(_mevcutUrller);
      List<Future<String>> yuklemeGorevleri = [];

      for (int i = 0; i < _yeniSecilenDosyalar.length; i++) {
        yuklemeGorevleri.add((() async {
          String dosyaAdi = "${widget.ciftId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg";
          Reference ref = FirebaseStorage.instance.ref().child("anilar").child(dosyaAdi);
          await ref.putFile(_yeniSecilenDosyalar[i]);
          return await ref.getDownloadURL();
        })());
      }

      List<String> yeniUrller = await Future.wait(yuklemeGorevleri);
      yuklenenUrller.addAll(yeniUrller);

      String kapakUrl = yuklenenUrller.isNotEmpty ? yuklenenUrller[_kapakIndex.clamp(0, yuklenenUrller.length - 1)] : "";

      Map<String, dynamic> guncellenecekVeri = {
        'ani_notu': _notController.text.trim(),
        'resim_listesi': yuklenenUrller,
        'resim_notlari': _resimNotlari,
        'resim_url': kapakUrl,
        'mood_emoji': _secilenEmojiler,
        'paylasildi_mi': true,
        'gorev_kabul_edildi': _kabulEdildi,
        'gorev_tamamlandi': _tamamlandi,
        'gun_turu': _gunTuru,
        'yazar_uid': FirebaseAuth.instance.currentUser!.uid,
        'son_duzenleme': FieldValue.serverTimestamp(),
      };

      if (!_ilkKayitZamaniVarMi) {
        guncellenecekVeri['ilk_kayit_zamani'] = FieldValue.serverTimestamp();
        _ilkKayitZamaniVarMi = true;

        _bitisZamani = DateTime.now().add(const Duration(hours: 48));
        _zamanGuncelle();
        _sayaciBaslat();
      }

      await FirebaseFirestore.instance.collection('GunlukKayitlar').doc(widget.gunlukKayitId).update(guncellenecekVeri);
      await _prefs?.remove(_taslakAnahtari);

      await reklamGorevi;

      if (!mounted) return;

      setState(() {
        _duzenlemeModu = false;
        _mevcutUrller = List.from(yuklenenUrller);
        _yeniSecilenDosyalar.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anı başarıyla kaydedildi!")));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _tasarimDegistir() {
    setState(() {
      _tasarimIndex = (_tasarimIndex + 1) % 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tasarimIndex == 2 ? const Color(0xFFF5F5DC) : const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_getTasarimAdi(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 18)),
            ),
            if (_benimAnimMi && !_muhurlendi && _kalanSureMetni.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.brown),
                    const SizedBox(width: 4),
                    Text(
                      _kalanSureMetni,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_benimAnimMi)
            Showcase(
              key: _kilitAnahtari,
              title: 'Anını Düzenle / Kilitle 🔒',
              description: 'Buraya basarak anını düzenleyebilir veya 48 saat sonra mühürlendiğini görebilirsin.',
              targetShapeBorder: const CircleBorder(),
              child: IconButton(
                icon: Icon(
                    _muhurlendi ? Icons.edit_off_rounded : (_duzenlemeModu ? Icons.visibility : Icons.edit),
                    color: Colors.brown
                ),
                tooltip: _muhurlendi
                    ? "Bu anı mühürlendi (48 Saat Doldu)"
                    : (_duzenlemeModu ? "Okuma Moduna Geç" : "Anıyı Düzenle"),
                onPressed: () {
                  if (_muhurlendi) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Bu anı 48 saatten eski olduğu için zaman kapsülüne mühürlenmiştir. Değiştirilemez ⏳", style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.orange,
                    ));
                  } else {
                    setState(() => _duzenlemeModu = !_duzenlemeModu);
                  }
                },
              ),
            ),

          if (_kabulEdildi)
            Showcase(
              key: _gorevAnahtari,
              title: 'Görevi Tamamladın Mı? 🏆',
              description: 'Partnerinle bu sürpriz görevi yerine getirdiyseniz, kupa ikonuna dokunarak görevi tamamlayın!',
              targetShapeBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Tooltip(
                  message: _tamamlandi ? "Görev Tamamlandı!" : "Görev Bekliyor",
                  child: Icon(
                    _tamamlandi ? Icons.emoji_events : Icons.emoji_events_outlined,
                    color: _tamamlandi ? Colors.amber : Colors.grey.shade400,
                    size: 28,
                  ),
                ),
              ),
            ),

          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(_getTasarimIkonu(), key: ValueKey(_tasarimIndex), color: Colors.brown),
            ),
            onPressed: _tasarimDegistir,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _tasarimSecici(),
      ),
      bottomNavigationBar: _duzenlemeModu ? _kaydetButonu() : const SizedBox.shrink(),
    );
  }
}

class TamEkranFotoGosterici extends StatefulWidget {
  final List<dynamic> resimler;
  final int baslangicIndex;

  const TamEkranFotoGosterici({super.key, required this.resimler, required this.baslangicIndex});

  @override
  State<TamEkranFotoGosterici> createState() => _TamEkranFotoGostericiState();
}

class _TamEkranFotoGostericiState extends State<TamEkranFotoGosterici> {
  late PageController _pageController;
  late int _aktifIndex;

  @override
  void initState() {
    super.initState();
    _aktifIndex = widget.baslangicIndex;
    _pageController = PageController(initialPage: widget.baslangicIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_aktifIndex + 1} / ${widget.resimler.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.resimler.length,
        onPageChanged: (index) {
          setState(() {
            _aktifIndex = index;
          });
        },
        itemBuilder: (context, index) {
          var resim = widget.resimler[index];
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: resim is String
                  ? CachedNetworkImage(
                cacheManager: KasaServisi.gizliKasa,
                imageUrl: resim,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
              )
                  : Image.file(resim as File, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}