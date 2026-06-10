import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../servisler/guvenlik_servisi.dart';
import '../servisler/kasa_servisi.dart';
import 'gunluk_kayit_ekrani.dart';
import 'cop_kutusu.dart';

class AniGecidi extends StatelessWidget {
  final String ciftId;
  const AniGecidi({super.key, required this.ciftId});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => _AniGecidiIcerik(ciftId: ciftId),
    );
  }
}

class _AniGecidiIcerik extends StatefulWidget {
  final String ciftId;
  const _AniGecidiIcerik({required this.ciftId});

  @override
  State<_AniGecidiIcerik> createState() => _AniGecidiIcerikState();
}

class _AniGecidiIcerikState extends State<_AniGecidiIcerik> {
  final String _suankiUid = FirebaseAuth.instance.currentUser!.uid;
  String? _partnerUid;
  bool _partnerIzniVar = false;

  final PageController _sayfaKontrolcusu = PageController(initialPage: 0);
  int _aktifSayfa = 0;

  bool _takvimModu = false;
  DateTime _seciliAy = DateTime.now();
  bool _yeniyeGoreSirala = true;
  String _seciliFiltre = 'tümü';

  bool _secimModu = false;
  List<String> _secilenAnilar = [];

  bool _ilkSecilenGizliMi = false;
  bool _ilkSecilenKilitliMi = false;

  final GlobalKey _sekmeAnahtari = GlobalKey();
  final GlobalKey _takvimAnahtari = GlobalKey();
  final GlobalKey _gizleAnahtari = GlobalKey();
  final GlobalKey _kilitleAnahtari = GlobalKey();
  final GlobalKey _silAnahtari = GlobalKey();

  // ✅ İNTERAKTİF (YUMUŞATILMIŞ VE HIZLANDIRILMIŞ) KAYDIRMA DEĞİŞKENLERİ
  Offset? _baslangicNoktasi;
  double _kaydirmaX = 0.0;
  int? _baslangicSayfasi;

  @override
  void initState() {
    super.initState();
    _izinleriVePartneriGetir();
    _egitimiBaslat();
  }

  // ✅ ANA SAYFA İLE BİREBİR AYNI HAFİF VE HIZLI KAYDIRMA MANTIĞI
  void _pointerDown(PointerDownEvent event) {
    _baslangicNoktasi = event.position;
    _baslangicSayfasi = _aktifSayfa;
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_baslangicNoktasi != null && _baslangicSayfasi == 0) {
      double dx = event.position.dx - _baslangicNoktasi!.dx;
      double dy = event.position.dy - _baslangicNoktasi!.dy;

      // 1. Ölü bölge 20'ye düşürüldü (daha çabuk algılar)
      if (dx > 20 && dx > dy.abs() * 1.5) {
        setState(() {
          // 2. Direnç %85'e çıkarıldı (parmağı daha hızlı takip eder, hafifler)
          _kaydirmaX = (dx - 20) * 0.85;
        });
      }
    }
  }

  void _pointerUp(PointerUpEvent event) {
    // 3. Geçiş için gereken mesafe 80'e düşürüldü (daha kolay sayfa atlar)
    if (_kaydirmaX > 80 && _baslangicSayfasi == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _kaydirmaX = 0.0;
      });
    }
    _baslangicNoktasi = null;
    _baslangicSayfasi = null;
  }

  void _pointerCancel(PointerCancelEvent event) {
    setState(() {
      _kaydirmaX = 0.0;
      _baslangicNoktasi = null;
      _baslangicSayfasi = null;
    });
  }

  Future<void> _egitimiBaslat() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool egitimGosterildi = prefs.getBool('egitim_ani_gecidi') ?? false;

      if (!egitimGosterildi) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            ShowCaseWidget.of(context).startShowCase([_sekmeAnahtari, _takvimAnahtari]);
          }
        });
        await prefs.setBool('egitim_ani_gecidi', true);
      }
    });
  }

  Future<void> _secimEgitiminiBaslat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool egitimGosterildi = prefs.getBool('egitim_secim_modu') ?? false;

    if (!egitimGosterildi) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([_gizleAnahtari, _kilitleAnahtari, _silAnahtari]);
        }
      });
      await prefs.setBool('egitim_secim_modu', true);
    }
  }

  Future<void> _izinleriVePartneriGetir() async {
    try {
      var odaDoc = await FirebaseFirestore.instance.collection('Ciftler').doc(widget.ciftId).get();
      if (odaDoc.exists) {
        String p1 = odaDoc.data()?['partner1'] ?? "";
        String p2 = odaDoc.data()?['partner2'] ?? "";
        _partnerUid = (p1 == _suankiUid) ? p2 : p1;

        if (_partnerUid != null && _partnerUid!.isNotEmpty) {
          var partnerDoc = await FirebaseFirestore.instance.collection('Users').doc(_partnerUid).get();
          if (partnerDoc.exists) {
            List izinVerilenler = partnerDoc.data()?['gunlugumu_gorebilenler'] ?? [];
            if (mounted) {
              setState(() {
                _partnerIzniVar = izinVerilenler.contains(_suankiUid);
              });
            }
          }
        }
      }
    } catch (e) {
      print("İzinler alınamadı: $e");
    }
  }

  Future<void> _secilenleriGuncelle(String alan, bool deger) async {
    if (_secilenAnilar.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (String id in _secilenAnilar) {
      DocumentReference ref = FirebaseFirestore.instance.collection('GunlukKayitlar').doc(id);
      batch.update(ref, {alan: deger});
    }
    await batch.commit();

    setState(() {
      _secimModu = false;
      _secilenAnilar.clear();
    });

    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seçili anılar güncellendi!")));
  }

  void _kilitUyarisiGoster() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.brown),
            SizedBox(width: 10),
            Text("Özel Anı", style: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Sevgilin bu anıyı kilitlemiş. 🔒\nSadece o kilidi açtığında okuyabilirsin.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontFamily: 'Serif'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color get bgRenk => _aktifSayfa == 0 ? const Color(0xFFFDF5E6) : const Color(0xFF1E1E1E);
  Color get yaziRenk => _aktifSayfa == 0 ? Colors.brown : Colors.grey.shade300;
  Color get baslikRenk => _aktifSayfa == 0 ? Colors.brown : Colors.white;
  Color get kartRenk => _aktifSayfa == 0 ? Colors.white : const Color(0xFF2C2C2C);
  Color get ikonRenk => _aktifSayfa == 0 ? Colors.brown : Colors.grey.shade400;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgRenk,
      body: AnimatedContainer(
        duration: _baslangicNoktasi == null ? const Duration(milliseconds: 350) : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_kaydirmaX, 0, 0),
        decoration: BoxDecoration(
          color: bgRenk,
          boxShadow: _kaydirmaX > 0
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 0)]
              : [],
        ),
        child: SafeArea(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerUp,
            onPointerCancel: _pointerCancel,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _secimModu ? _secimAppBar() : _normalAppBar(),
              body: PageView(
                controller: _sayfaKontrolcusu,
                onPageChanged: (index) {
                  setState(() {
                    _aktifSayfa = index;
                    _secimModu = false;
                    _secilenAnilar.clear();
                  });
                },
                children: [
                  _aniSayfasiOlustur(benimki: true),
                  _partnerIzniVar ? _aniSayfasiOlustur(benimki: false) : _kilitliSayfa(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _secimAppBar() {
    return AppBar(
      backgroundColor: Colors.brown.shade800,
      title: Text("${_secilenAnilar.length} Anı Seçildi", style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Serif')),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => setState(() { _secimModu = false; _secilenAnilar.clear(); }),
      ),
      actions: [
        Showcase(
          key: _gizleAnahtari,
          title: _ilkSecilenGizliMi ? 'Tekrar Göster 👁️' : 'Partnerinden Gizle 👁️',
          description: _ilkSecilenGizliMi ? 'Bu anıyı tekrar görünür yap.' : 'Seçtiğin anıları sevgilinin görmesini istemiyorsan buradan gizleyebilirsin.',
          targetShapeBorder: const CircleBorder(),
          child: IconButton(
              icon: Icon(_ilkSecilenGizliMi ? Icons.visibility : Icons.visibility_off, color: Colors.white),
              tooltip: _ilkSecilenGizliMi ? "Göster" : "Gizle",
              onPressed: () => _secilenleriGuncelle('gizli_mi', !_ilkSecilenGizliMi)
          ),
        ),
        Showcase(
          key: _kilitleAnahtari,
          title: _ilkSecilenKilitliMi ? 'Kilidi Aç 🔓' : 'Erişimi Kısıtla 🔒',
          description: _ilkSecilenKilitliMi ? 'Bu anının kilidini açarak tekrar okunabilir yap.' : 'Çok özel anılarını kilitleyebilirsin. Sen kilidi açana kadar sevgilin bu anıyı okuyamaz.',
          targetShapeBorder: const CircleBorder(),
          child: IconButton(
              icon: Icon(_ilkSecilenKilitliMi ? Icons.lock_open : Icons.lock, color: Colors.amber),
              tooltip: _ilkSecilenKilitliMi ? "Kilidi Aç" : "Kilitle",
              onPressed: () => _secilenleriGuncelle('kilitli_mi', !_ilkSecilenKilitliMi)
          ),
        ),
        Showcase(
          key: _silAnahtari,
          title: 'Çöpe At 🗑️',
          description: 'Anılarını sildiğinde hemen kaybolmaz, 30 gün boyunca Çöp Kutusu\'nda bekler.',
          targetShapeBorder: const CircleBorder(),
          child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: "Çöpe At",
              onPressed: () => _secilenleriGuncelle('copte_mi', true)
          ),
        ),
      ],
    );
  }

  AppBar _normalAppBar() {
    return AppBar(
      title: Showcase(
        key: _sekmeAnahtari,
        title: 'Hikayeler Arası Geçiş 📖',
        description: 'Sevgilinin seninle paylaştığı anıları okumak için ekranı sağa veya sola kaydırabilirsin.',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
              _aktifSayfa == 0 ? "Benim Hikayem" : "Onun Hikayesi",
              style: TextStyle(color: baslikRenk, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Serif', letterSpacing: 0.5)
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: ikonRenk),
      actions: [
        Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: const Color(0xFFFDF5E6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              textStyle: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontFamily: 'Serif', fontSize: 15),
            ),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.filter_alt_outlined, color: ikonRenk),
            onSelected: (val) => setState(() => _seciliFiltre = val),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'tümü', child: Row(children: [Icon(Icons.all_inbox, color: Colors.brown.shade400, size: 22), const SizedBox(width: 12), const Text("Tüm Anılar")])),
              PopupMenuItem(value: 'favori', child: Row(children: [const Icon(Icons.star, color: Colors.amber, size: 22), const SizedBox(width: 12), const Text("Favori Günler")])),
              PopupMenuItem(value: 'kotu', child: Row(children: [Icon(Icons.cloud, color: Colors.blueGrey.shade400, size: 22), const SizedBox(width: 12), const Text("Kötü Günler")])),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_yeniyeGoreSirala ? Icons.swap_vert_rounded : Icons.sort_rounded, color: ikonRenk),
          onPressed: () => setState(() => _yeniyeGoreSirala = !_yeniyeGoreSirala),
        ),
        Showcase(
          key: _takvimAnahtari,
          title: 'Görünümü Değiştir 📅',
          description: 'Anılarını ister şık bir listede, istersen de takvim üzerinde görmek için buraya tıkla.',
          targetShapeBorder: const CircleBorder(),
          child: IconButton(
            icon: Icon(_takvimModu ? Icons.view_agenda : Icons.calendar_month, color: ikonRenk),
            onPressed: () => setState(() => _takvimModu = !_takvimModu),
          ),
        ),
      ],
    );
  }

  Widget _kilitliSayfa() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade600),
          const SizedBox(height: 20),
          Text("Bu Sayfa Kilitli", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400, fontFamily: 'Serif')),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Sevgilin henüz günlüğünün anahtarını seninle paylaşmadı. Ayarlar kısmından istek gönderebilirsin.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontFamily: 'Serif'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aniSayfasiOlustur({required bool benimki}) {
    if (GuvenlikServisi().sahteMod) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text("Burada henüz bir anı yok.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontFamily: 'Serif')),
          ],
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('GunlukKayitlar')
          .where('cift_id', isEqualTo: widget.ciftId)
          .where('paylasildi_mi', isEqualTo: true)
          .orderBy('tarih_str', descending: _yeniyeGoreSirala)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}", style: TextStyle(color: yaziRenk, fontFamily: 'Serif')));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: ikonRenk));

        var anilar = snapshot.data!.docs.where((doc) {
          var veri = doc.data() as Map<String, dynamic>;
          String yazar = veri['yazar_uid'] ?? "";
          bool copte = veri['copte_mi'] ?? false;
          bool gizli = veri['gizli_mi'] ?? false;
          String gunTuru = veri['gun_turu'] ?? 'normal';

          if (copte) return false;
          if (_seciliFiltre != 'tümü' && gunTuru != _seciliFiltre) return false;

          if (benimki) {
            return yazar == _suankiUid;
          } else {
            return (yazar == _partnerUid) && !gizli;
          }
        }).toList();

        if (anilar.isEmpty) {
          return Center(
            child: Text(
              benimki ? "Burada henüz bir anın yok." : "Sevgilin henüz seninle bir anı paylaşmamış.",
              style: TextStyle(color: yaziRenk, fontSize: 16, fontFamily: 'Serif'),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _takvimModu ? _gercekTakvimGorunumu(anilar, benimki) : _listeGorunumu(anilar, benimki),
        );
      },
    );
  }

  Widget _gercekTakvimGorunumu(List<DocumentSnapshot> anilar, bool benimki) {
    int gunSayisi = DateTime(_seciliAy.year, _seciliAy.month + 1, 0).day;
    int ilkGunHaftada = DateTime(_seciliAy.year, _seciliAy.month, 1).weekday - 1;

    Map<int, DocumentSnapshot> aniHaritasi = {};
    for (var ani in anilar) {
      var data = ani.data() as Map<String, dynamic>;
      if (data['tarih_str'] != null) {
        DateTime? tarih = DateTime.tryParse(data['tarih_str']);
        if (tarih != null && tarih.month == _seciliAy.month && tarih.year == _seciliAy.year) {
          aniHaritasi[tarih.day] = ani;
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.chevron_left, color: ikonRenk), onPressed: () => setState(() => _seciliAy = DateTime(_seciliAy.year, _seciliAy.month - 1))),
              Text(DateFormat('MMMM yyyy', 'tr_TR').format(_seciliAy).toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: baslikRenk, fontFamily: 'Serif', letterSpacing: 1.2)),
              IconButton(icon: Icon(Icons.chevron_right, color: ikonRenk), onPressed: () => setState(() => _seciliAy = DateTime(_seciliAy.year, _seciliAy.month + 1))),
            ],
          ),
        ),
        _takvimGunBasliklari(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.8),
            itemCount: gunSayisi + ilkGunHaftada,
            itemBuilder: (context, index) {
              if (index < ilkGunHaftada) return const SizedBox();
              int gunNo = index - ilkGunHaftada + 1;
              var ani = aniHaritasi[gunNo];
              return _takvimHucresi(gunNo, ani, benimki);
            },
          ),
        ),
      ],
    );
  }

  Widget _takvimGunBasliklari() {
    List<String> gunler = ["PZT", "SALI", "ÇAR", "PER", "CUM", "CMT", "PAZ"];
    return Row(
      children: gunler.map((g) => Expanded(
        child: Center(child: Text(g, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ikonRenk, fontFamily: 'Serif'))),
      )).toList(),
    );
  }

  Widget _takvimHucresi(int gunNo, DocumentSnapshot? ani, bool benimki) {
    Map<String, dynamic>? veri = ani?.data() as Map<String, dynamic>?;
    bool seciliMi = ani != null && _secilenAnilar.contains(ani.id);

    Color borderColor = seciliMi ? Colors.green : (benimki ? Colors.brown.withOpacity(0.3) : Colors.grey.shade800);
    double borderWidth = seciliMi ? 3.0 : 1.0;

    if (veri != null && !seciliMi) {
      if (veri['gun_turu'] == 'favori') { borderColor = Colors.amber; borderWidth = 2.5; }
      else if (veri['gun_turu'] == 'kotu') { borderColor = Colors.blueGrey; borderWidth = 2.0; }
    }

    String gosterilecekEmoji = "❤️";
    if (veri != null && veri['mood_emoji'] != null) {
      var moodData = veri['mood_emoji'];
      gosterilecekEmoji = moodData is List ? moodData.join("") : moodData.toString();
    }

    double ekranYuksekligi = MediaQuery.of(context).size.height;
    double dinamikUstBosluk = ekranYuksekligi * 0.022;

    return GestureDetector(
      onLongPress: () {
        if (ani != null && benimki) {
          setState(() {
            if (!_secimModu) {
              _secimModu = true;
              _ilkSecilenGizliMi = veri?['gizli_mi'] == true;
              _ilkSecilenKilitliMi = veri?['kilitli_mi'] == true;
              _secimEgitiminiBaslat();
            }
            if(!_secilenAnilar.contains(ani.id)) _secilenAnilar.add(ani.id);
          });
        }
      },
      onTap: () {
        if (ani == null) return;
        if (_secimModu && benimki) {
          setState(() {
            if (_secilenAnilar.contains(ani.id)) {
              _secilenAnilar.remove(ani.id);
            } else {
              if (_secilenAnilar.isEmpty) {
                _ilkSecilenGizliMi = veri?['gizli_mi'] == true;
                _ilkSecilenKilitliMi = veri?['kilitli_mi'] == true;
              }
              _secilenAnilar.add(ani.id);
            }
            if (_secilenAnilar.isEmpty) _secimModu = false;
          });
        } else {
          if (veri?['kilitli_mi'] == true && !benimki) {
            _kilitUyarisiGoster();
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => GunlukKayitEkrani(ciftId: widget.ciftId, gunlukKayitId: ani.id)));
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: seciliMi ? Colors.green.withOpacity(0.2) : (_aktifSayfa == 0 ? Colors.white : const Color(0xFF2C2C2C)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _aktifSayfa == 0 ? [BoxShadow(color: Colors.brown.withOpacity(0.1), blurRadius: 4, offset: const Offset(1, 2))] : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(top: dinamikUstBosluk, bottom: 4.0, left: 4.0, right: 4.0),
              child: veri != null
                  ? (veri['resim_url'] != null && veri['resim_url'].toString().isNotEmpty
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    cacheManager: KasaServisi.gizliKasa,
                    imageUrl: veri['resim_url'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.withOpacity(0.1)),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  )
              )
                  : Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      gosterilecekEmoji,
                      style: const TextStyle(fontSize: 28),
                      textAlign: TextAlign.center
                  ),
                ),
              ))
                  : const SizedBox(),
            ),
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                "$gunNo",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                    fontFamily: 'Serif'
                ),
              ),
            ),
            if (veri?['gizli_mi'] == true)
              const Positioned(bottom: 2, left: 2, child: Icon(Icons.visibility_off, color: Colors.grey, size: 14)),

            if (veri?['kilitli_mi'] == true)
              const Positioned(bottom: 2, left: 18, child: Icon(Icons.lock, color: Colors.redAccent, size: 14)),

            if (veri?['gorev_tamamlandi'] == true)
              const Positioned(bottom: -2, right: -2, child: Icon(Icons.emoji_events, color: Colors.amber, size: 16)),
          ],
        ),
      ),
    );
  }

  Widget _listeGorunumu(List<DocumentSnapshot> anilar, bool benimki) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: anilar.length,
      itemBuilder: (context, index) {
        var doc = anilar[index];
        var veri = doc.data() as Map<String, dynamic>;
        DateTime tarih = DateTime.tryParse(veri['tarih_str'] ?? "") ?? DateTime.now();
        String formatliTarih = DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih);

        bool seciliMi = _secilenAnilar.contains(doc.id);

        BorderSide cardBorder = BorderSide.none;
        Color cardBg = seciliMi ? Colors.green.withOpacity(0.1) : kartRenk;

        Color favoriRenk = const Color(0xFFDCA73A);

        if (seciliMi) {
          cardBorder = const BorderSide(color: Colors.green, width: 2.5);
        } else if (veri['gun_turu'] == 'favori') {
          cardBorder = BorderSide(color: favoriRenk, width: 1.5);
        } else if (veri['gun_turu'] == 'kotu') {
          cardBorder = BorderSide(color: Colors.blueGrey.shade300, width: 1.5);
          if(!benimki) cardBg = const Color(0xFF222831);
        }

        String gosterilecekEmoji = "❤️";
        if (veri['mood_emoji'] != null) {
          var moodData = veri['mood_emoji'];
          gosterilecekEmoji = moodData is List ? moodData.join("") : moodData.toString();
        }

        return GestureDetector(
          onLongPress: () {
            if (benimki) {
              setState(() {
                if (!_secimModu) {
                  _secimModu = true;
                  _ilkSecilenGizliMi = veri['gizli_mi'] == true;
                  _ilkSecilenKilitliMi = veri['kilitli_mi'] == true;
                  _secimEgitiminiBaslat();
                }
                if(!_secilenAnilar.contains(doc.id)) _secilenAnilar.add(doc.id);
              });
            }
          },
          onTap: () {
            if (_secimModu && benimki) {
              setState(() {
                if (_secilenAnilar.contains(doc.id)) {
                  _secilenAnilar.remove(doc.id);
                } else {
                  if (_secilenAnilar.isEmpty) {
                    _ilkSecilenGizliMi = veri['gizli_mi'] == true;
                    _ilkSecilenKilitliMi = veri['kilitli_mi'] == true;
                  }
                  _secilenAnilar.add(doc.id);
                }
                if (_secilenAnilar.isEmpty) _secimModu = false;
              });
            } else {
              if (veri['kilitli_mi'] == true && !benimki) {
                _kilitUyarisiGoster();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => GunlukKayitEkrani(ciftId: widget.ciftId, gunlukKayitId: doc.id)));
              }
            }
          },
          child: Card(
            color: cardBg,
            margin: const EdgeInsets.only(bottom: 25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: cardBorder),
            elevation: benimki ? 5 : 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (veri['resim_url'] != null && veri['resim_url'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      cacheManager: KasaServisi.gizliKasa,
                      imageUrl: veri['resim_url'],
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(height: 250, color: Colors.grey.withOpacity(0.1)),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(formatliTarih, style: TextStyle(color: yaziRenk.withOpacity(0.9), fontSize: 17, letterSpacing: 0.5, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
                              if (veri['gizli_mi'] == true) ...[const SizedBox(width: 8), const Icon(Icons.visibility_off, color: Colors.grey, size: 18)],
                              if (veri['kilitli_mi'] == true) ...[const SizedBox(width: 8), const Icon(Icons.lock, color: Colors.redAccent, size: 18)],
                              if (veri['gun_turu'] == 'favori') ...[const SizedBox(width: 8), Icon(Icons.star, color: favoriRenk, size: 20)],
                            ],
                          ),
                          Expanded(child: Text(gosterilecekEmoji, style: const TextStyle(fontSize: 24), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                        ],
                      ),

                      if (veri['gorev_tamamlandi'] == true && veri['gorev_id'] != null)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('GorevHavuzu').doc(veri['gorev_id']).get(),
                          builder: (context, gorevSnap) {
                            if (!gorevSnap.hasData || !gorevSnap.data!.exists) return const SizedBox();
                            String gorevIcerigi = gorevSnap.data!['icerik'] ?? "";

                            return Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: favoriRenk.withOpacity(0.5), width: 1.0),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.emoji_events, color: favoriRenk, size: 17),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      gorevIcerigi,
                                      style: TextStyle(
                                        fontFamily: 'Serif',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                        color: yaziRenk.withOpacity(0.75),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      SizedBox(height: (veri['gorev_tamamlandi'] == true) ? 12 : 16),
                      Text(veri['ani_notu'] ?? "", maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: yaziRenk, fontFamily: 'Serif', height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}