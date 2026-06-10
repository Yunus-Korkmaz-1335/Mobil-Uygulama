import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sadeceben/ekranlar/gunluk_kayit_ekrani.dart';
import 'package:sadeceben/ekranlar/ani_gecidi.dart';
import 'package:sadeceben/ekranlar/profil_sayfasi.dart';
import 'package:sadeceben/ekranlar/paylasim_merkezi.dart';
import 'package:scratcher/scratcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servisler/gorev_servisi.dart';
import '../servisler/guvenlik_servisi.dart';

class AnaSayfa extends StatefulWidget {
  final String ciftId;
  const AnaSayfa({super.key, required this.ciftId});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with TickerProviderStateMixin {
  final GorevServisi _gorevServisi = GorevServisi();
  bool _kazindi = false;
  final GlobalKey<ScratcherState> _scratchKey = GlobalKey<ScratcherState>();
  final TextEditingController _sahteNotController = TextEditingController();

  late Future<DocumentSnapshot> _gunlukGorevFuture;

  late AnimationController _blinkController;
  late Animation<Color?> _colorAnimation;

  late AnimationController _askBlinkController;
  late Animation<Color?> _askColorAnimation;

  // ✅ İNTERAKTİF VE YUMUŞATILMIŞ KAYDIRMA DEĞİŞKENLERİ
  Offset? _baslangicNoktasi;
  bool _kaziKazanKullaniliyor = false;
  double _kaydirmaX = 0.0;

  @override
  void initState() {
    super.initState();
    _gunlukGorevFuture = _gorevServisi.gununGoreviniGetir(widget.ciftId);

    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: Colors.transparent, end: Colors.redAccent.withOpacity(0.9)).animate(_blinkController);

    _askBlinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _askColorAnimation = ColorTween(begin: Colors.transparent, end: Colors.redAccent).animate(_askBlinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _askBlinkController.dispose();
    _sahteNotController.dispose();
    super.dispose();
  }

  Future<void> _gorevKarariVer(DocumentSnapshot gunlukKayit, bool kabulEdildi) async {
    await gunlukKayit.reference.update({'gorev_kabul_edildi': kabulEdildi});
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GunlukKayitEkrani(
          ciftId: widget.ciftId,
          gunlukKayitId: gunlukKayit.id,
          gorevKabulEdildi: kabulEdildi,
        ),
      ),
    );
  }

  // ✅ DAHA HAFİF VE HIZLI KAYDIRMA MANTIĞI
  void _pointerDown(PointerDownEvent event) {
    if (!_kaziKazanKullaniliyor) {
      _baslangicNoktasi = event.position;
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_kaziKazanKullaniliyor && _baslangicNoktasi != null) {
      double dx = event.position.dx - _baslangicNoktasi!.dx;
      double dy = event.position.dy - _baslangicNoktasi!.dy;

      // 1. Ölü bölge 30'dan 20'ye düşürüldü (daha çabuk algılar)
      if (dx < -20 && dx.abs() > dy.abs() * 1.5) {
        setState(() {
          // 2. Direnç %70'ten %85'e çıkarıldı (parmağı daha hızlı takip eder, hafifler)
          _kaydirmaX = (dx + 20) * 0.85;
        });
      }
    }
  }

  void _pointerUp(PointerUpEvent event) {
    // 3. Geçiş için gereken mesafe 120'den 80'e düşürüldü (daha kolay sayfa atlar)
    if (_kaydirmaX < -80) {
      setState(() {
        _kaydirmaX = 0.0;
      });
      _baslangicNoktasi = null;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AniGecidi(ciftId: widget.ciftId)),
      );
    } else {
      setState(() {
        _kaydirmaX = 0.0;
      });
      _baslangicNoktasi = null;
    }
  }

  void _pointerCancel(PointerCancelEvent event) {
    setState(() {
      _kaydirmaX = 0.0;
      _baslangicNoktasi = null;
    });
  }

  String _kategoriGuzellestir(String rawKategori) {
    switch (rawKategori.toLowerCase().trim()) {
      case 'ev_ici': return "🏠 Evin Tadını Çıkarma";
      case 'disarida_hayat': return "🌳 Açık Hava & Macera";
      case 'derin_mevzular': return "💭 Derin Mevzular & Sohbet";
      case 'komik_absurt': return "🤪 Komik & Absürt Anlar";
      case 'gelecek_hayaller': return "✨ Gelecek & Hayaller";
      default: return "💖 Birlikte Güzel Bir An";
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget anaIcerik;

    if (GuvenlikServisi().sahteMod) {
      anaIcerik = Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Günlüğüm", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_edu, color: Colors.brown, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AniGecidi(ciftId: widget.ciftId))),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sevgili Günlük,", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.brown, fontFamily: 'Serif')),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: TextField(
                    controller: _sahteNotController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(hintText: "Bugün neler yaşadın? Buraya dökülebilirsin...", border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Günlüğe başarıyla kaydedildi!")));
                    _sahteNotController.clear();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text("Kaydet", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } else {
      anaIcerik = Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Günün Aktivitesi", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('Ciftler').doc(widget.ciftId).snapshots(),
              builder: (context, ciftSnapshot) {
                bool kirmiziYan = false;

                if (ciftSnapshot.hasData && ciftSnapshot.data!.exists) {
                  var ciftData = ciftSnapshot.data!.data() as Map<String, dynamic>;
                  String istekYapan = ciftData['silme_istek_yapan'] ?? "";
                  String durum = ciftData['silme_istek_durum'] ?? "";
                  String suankiUid = FirebaseAuth.instance.currentUser!.uid;

                  if (istekYapan.isNotEmpty && istekYapan != suankiUid && durum == 'bekliyor') kirmiziYan = true;
                  if (istekYapan == suankiUid && durum == 'reddedildi') kirmiziYan = true;
                }

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('Users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                  builder: (context, userSnapshot) {
                    String? fotoUrl;
                    bool gunlukIstegiVar = false;

                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      fotoUrl = userData['profilFoto'];
                      List gelenIstekler = userData['gelen_istekler'] ?? [];
                      gunlukIstegiVar = gelenIstekler.isNotEmpty;
                    }

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.vpn_key_rounded, color: Colors.brown, size: 26),
                              tooltip: gunlukIstegiVar ? "Sevgilinden Günlük İsteği Var! 💌" : "Mahremiyet ve Paylaşım",
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PaylasimMerkezi(ciftId: widget.ciftId))),
                            ),
                            if (gunlukIstegiVar)
                              Positioned(
                                top: 10,
                                right: 12,
                                child: AnimatedBuilder(
                                  animation: _askColorAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _askColorAnimation.value,
                                        border: Border.all(color: const Color(0xFFFDF5E6), width: 1.5),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),

                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilSayfasi())),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
                            child: AnimatedBuilder(
                              animation: _colorAnimation,
                              builder: (context, child) {
                                return Container(
                                  padding: EdgeInsets.all(kirmiziYan ? 4 : 0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kirmiziYan ? _colorAnimation.value : Colors.transparent,
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.brown[100],
                                    backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                                    child: fotoUrl == null ? const Icon(Icons.person, color: Colors.brown, size: 20) : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            IconButton(
              icon: const Icon(Icons.history_edu, color: Colors.brown, size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AniGecidi(ciftId: widget.ciftId))),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: _gunlukGorevFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.brown));
            if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Bugün için görev bulunamadı."));

            var gunlukVeri = snapshot.data!.data() as Map<String, dynamic>;

            String gorevId = gunlukVeri['gorev_id'];
            if (!_kazindi && gunlukVeri['kazindi_mi'] == true) {
              _kazindi = true;
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('GorevHavuzu').doc(gorevId).get(),
              builder: (context, gorevSnapshot) {
                if (!gorevSnapshot.hasData || !gorevSnapshot.data!.exists) return const SizedBox();

                var gorev = gorevSnapshot.data!.data() as Map<String, dynamic>;

                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Günün Sürprizi\nSeni Bekliyor!", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.brown, height: 1.2)),
                        const SizedBox(height: 30),

                        Listener(
                          onPointerDown: (_) {
                            if (!_kazindi) _kaziKazanKullaniliyor = true;
                          },
                          onPointerUp: (_) => Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) _kaziKazanKullaniliyor = false;
                          }),
                          onPointerCancel: (_) => Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) _kaziKazanKullaniliyor = false;
                          }),
                          child: Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _kazindi
                                  ? _gorevIcerikWidget(gorev)
                                  : Scratcher(
                                key: _scratchKey, brushSize: 50, threshold: 50, color: Colors.grey[400]!,
                                onThreshold: () async {
                                  setState(() => _kazindi = true);
                                  await snapshot.data!.reference.update({'kazindi_mi': true});
                                },
                                child: _gorevIcerikWidget(gorev),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                        if (_kazindi)
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFD67D7D), Color(0xFF8D4B4B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [BoxShadow(color: const Color(0xFF8D4B4B).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () => _gorevKarariVer(snapshot.data!, true),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.volunteer_activism, color: Colors.white, size: 24), SizedBox(width: 10), Text("Görevi Kabul Et & Anı Yaz", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))]),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => _gorevKarariVer(snapshot.data!, false),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Colors.brown.withOpacity(0.06)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit_note, color: Colors.brown[400], size: 20), const SizedBox(width: 8), Text("Pas Geç, Sadece Günlük Yaz", style: TextStyle(fontSize: 14, color: Colors.brown[400], fontWeight: FontWeight.w600))]),
                              ),
                            ],
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

    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      body: AnimatedContainer(
        duration: _baslangicNoktasi == null ? const Duration(milliseconds: 350) : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(_kaydirmaX, 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF5E6),
          boxShadow: _kaydirmaX < 0
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 0)]
              : [],
        ),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerUp,
          onPointerCancel: _pointerCancel,
          child: anaIcerik,
        ),
      ),
    );
  }

  Widget _gorevIcerikWidget(Map<String, dynamic> gorev) {
    String rawKategori = gorev['kategori'] ?? "";
    String sikKategori = _kategoriGuzellestir(rawKategori);

    return Container(
      width: 320,
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, size: 55, color: Colors.redAccent),
          const SizedBox(height: 20),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                  gorev['icerik'] ?? "Görev bulunamadı",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown,
                      height: 1.3
                  )
              )
          ),
          const SizedBox(height: 20),

          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.brown.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
              child: Text(
                  sikKategori,
                  style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 13)
              )
          ),
        ],
      ),
    );
  }
}