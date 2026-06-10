part of 'gunluk_kayit_ekrani.dart';

extension TasarimArayuzleri on _GunlukKayitEkraniIcerikState {

  Widget _tasarimSecici() {
    switch (_tasarimIndex) {
      case 0: return _klasikTasarim();
      case 1: return _modernKartTasarim();
      case 2: return _defterTasarim();
      case 3: return _hikayeTasarim();
      case 4: return _retroPolaroidTasarim();
      default: return _klasikTasarim();
    }
  }

  Widget _gunTuruSecici() {
    if (!_duzenlemeModu && _gunTuru == 'normal') return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_duzenlemeModu || _gunTuru == 'favori')
            _turButonu('favori', 'Favori', Icons.star, Colors.amber),

          if (_duzenlemeModu) const SizedBox(width: 15),

          if (_duzenlemeModu || _gunTuru == 'kotu')
            _turButonu('kotu', 'Kötü', Icons.cloud, Colors.blueGrey),
        ],
      ),
    );
  }

  Widget _turButonu(String deger, String etiket, IconData ikon, Color renk) {
    bool secili = _gunTuru == deger;
    return GestureDetector(
      onTap: _duzenlemeModu ? () => setState(() => _gunTuru = secili ? 'normal' : deger) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: secili ? renk.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: secili ? renk : Colors.grey.shade300, width: secili ? 2 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(ikon, color: secili ? renk : Colors.grey, size: 20),
            if (secili || _duzenlemeModu) ...[
              const SizedBox(width: 8),
              Text(etiket, style: TextStyle(color: secili ? renk : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }

  // ✅ Anı kutusundan bağımsız, çok şık "Günün Görevi" kartı
  Widget _tamamlananGorevKarti() {
    if (_tamamlananGorevIcerigi == null || _tamamlananGorevIcerigi!.isEmpty || _duzenlemeModu) return const SizedBox();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCA73A).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDCA73A).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFDCA73A), size: 20),
              const SizedBox(width: 8),
              Text(
                "O GÜNÜN GÖREVİ",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDCA73A).withOpacity(0.8),
                  letterSpacing: 1.2,
                  fontFamily: 'Serif',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _tamamlananGorevIcerigi!,
            style: const TextStyle(
              fontFamily: 'Serif',
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: Colors.brown,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Metin kutusunun içi tertemiz bırakıldı, sadece not var.
  Widget _okumaModuMetni() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFFD1BB87),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
        ),
        border: Border.all(color: Colors.brown.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.format_quote_rounded, color: Colors.brown.withOpacity(0.3), size: 36),
              Icon(Icons.auto_awesome, color: Colors.amber.withOpacity(0.5), size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _notController.text,
            style: TextStyle(
              fontSize: 16,
              height: 1.8,
              color: Colors.brown[800],
              fontFamily: _tasarimIndex == 2 || _tasarimIndex == 4 ? 'Serif' : null,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 50,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ SARILMA EMOJİSİ (🤗) EKLENDİ
  Widget _emojiPaneli({bool minimal = false}) {
    var tumEmojiler = ["❤️", "😊", "🥰", "🥺", "🤗", "🤩", "🍕", "🎬", "✨", "🔥", "☕", "🚗", "🧑‍🍳", "🤪", "🎉"];
    List<String> gosterilecekEmojiler = _duzenlemeModu ? tumEmojiler : _secilenEmojiler;
    if (gosterilecekEmojiler.isEmpty && !_duzenlemeModu) return const SizedBox();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: gosterilecekEmojiler.map((e) {
        bool secili = _secilenEmojiler.contains(e);
        return GestureDetector(
          onTap: () {
            if (!_duzenlemeModu) return;
            setState(() {
              if (secili) {
                _secilenEmojiler.remove(e);
              } else {
                _secilenEmojiler.add(e);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(minimal ? 6 : 10),
            decoration: BoxDecoration(
              color: secili ? Colors.brown.withOpacity(0.15) : (_duzenlemeModu ? Colors.white : Colors.transparent),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: secili ? Colors.brown.withOpacity(0.5) : Colors.transparent),
              boxShadow: _duzenlemeModu && !secili ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : null,
            ),
            child: Text(e, style: TextStyle(fontSize: minimal ? 18 : (_duzenlemeModu ? 24 : 28))),
          ),
        );
      }).toList(),
    );
  }

  Widget _klasikTasarim() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fotoGrid(crossCount: 3),
          const SizedBox(height: 25),
          Center(child: _gunTuruSecici()),
          Center(child: _emojiPaneli()),
          const SizedBox(height: 25),
          _tamamlananGorevKarti(),
          _notAlani(),
        ],
      ),
    );
  }

  Widget _modernKartTasarim() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _gunTuruSecici(),
        _emojiPaneli(),
        const SizedBox(height: 20),
        Card(
          elevation: 5,
          shadowColor: Colors.brown.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: _fotoGrid(crossCount: 2),
          ),
        ),
        const SizedBox(height: 20),
        _tamamlananGorevKarti(),
        _notAlani(decoration: "Bugünün hikayesini yaz..."),
      ],
    );
  }

  Widget _defterTasarim() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sevgili Günlük,", style: TextStyle(fontFamily: 'Serif', fontSize: 26, fontWeight: FontWeight.bold, color: Colors.brown)),
          const Divider(thickness: 2, color: Colors.brown),
          const SizedBox(height: 15),
          _tamamlananGorevKarti(),
          _notAlani(borderless: true, decoration: "Buraya her şeyi dökebilirsin..."),
          const SizedBox(height: 30),
          if (_mevcutUrller.isNotEmpty || _yeniSecilenDosyalar.isNotEmpty || _duzenlemeModu) ...[
            const Text("Anılarımız:", style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            _fotoGrid(crossCount: 3),
          ],
          const SizedBox(height: 20),
          Center(child: _gunTuruSecici()),
          Center(child: _emojiPaneli(minimal: true)),
        ],
      ),
    );
  }

  Widget _hikayeTasarim() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: PageView.builder(
              itemCount: _mevcutUrller.length + _yeniSecilenDosyalar.length + (_duzenlemeModu ? 1 : 0),
              itemBuilder: (context, index) {
                int toplam = _mevcutUrller.length + _yeniSecilenDosyalar.length;
                if (index == toplam) {
                  return Center(child: IconButton(icon: const Icon(Icons.add_a_photo, size: 50), onPressed: _cokluResimSec));
                }
                return GestureDetector(
                  onLongPress: () => _resimSecenekleriniGoster(index),
                  onTap: () => _tamEkranGoster(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: index < _mevcutUrller.length
                          ? CachedNetworkImage(
                        cacheManager: KasaServisi.gizliKasa,
                        imageUrl: _mevcutUrller[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.withOpacity(0.1)),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      )
                          : Image.file(_yeniSecilenDosyalar[index - _mevcutUrller.length], fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          _gunTuruSecici(),
          _emojiPaneli(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                _tamamlananGorevKarti(),
                _notAlani(decoration: "Bir şeyler yaz..."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _retroPolaroidTasarim() {
    int toplam = _mevcutUrller.length + _yeniSecilenDosyalar.length;
    int itemCount = toplam + (_duzenlemeModu ? 1 : 0);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.85,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == toplam) {
                return GestureDetector(
                  onTap: _cokluResimSec,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 40),
                  ),
                );
              }
              bool isKapak = _kapakIndex == index;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(2, 4))],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () => _resimSecenekleriniGoster(index),
                        onTap: () => _tamEkranGoster(index),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: isKapak ? Colors.amber : Colors.grey.shade200, width: isKapak ? 2 : 1)),
                          child: index < _mevcutUrller.length
                              ? CachedNetworkImage(
                            cacheManager: KasaServisi.gizliKasa,
                            imageUrl: _mevcutUrller[index],
                            fit: BoxFit.cover, width: double.infinity,
                            placeholder: (context, url) => Container(color: Colors.grey.withOpacity(0.1)),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          )
                              : Image.file(_yeniSecilenDosyalar[index - _mevcutUrller.length], fit: BoxFit.cover, width: double.infinity),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _duzenlemeModu ? () => _notDuzenleDialog(index) : null,
                      child: Text(
                        _resimNotlari[index] + (isKapak ? " ✨" : ""),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.brown, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          _gunTuruSecici(),
          _emojiPaneli(minimal: true),
          const SizedBox(height: 20),
          _tamamlananGorevKarti(),
          _notAlani(decoration: "Nostaljik bir not bırak..."),
        ],
      ),
    );
  }

  Widget _fotoGrid({required int crossCount}) {
    int toplam = _mevcutUrller.length + _yeniSecilenDosyalar.length;
    int itemCount = toplam + (_duzenlemeModu ? 1 : 0);
    if (toplam == 0 && !_duzenlemeModu) return const SizedBox();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == toplam) {
          return InkWell(
            onTap: _cokluResimSec,
            child: Container(
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.add_a_photo, color: Colors.black54),
            ),
          );
        }
        bool isKapak = _kapakIndex == index;
        return GestureDetector(
          onLongPress: () => _resimSecenekleriniGoster(index),
          onTap: () => _tamEkranGoster(index),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.brown, width: 2),
              boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: index < _mevcutUrller.length
                      ? CachedNetworkImage(
                    cacheManager: KasaServisi.gizliKasa,
                    imageUrl: _mevcutUrller[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.brown.withOpacity(0.05)),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                  )
                      : Image.file(_yeniSecilenDosyalar[index - _mevcutUrller.length], fit: BoxFit.cover),
                ),
                if (isKapak)
                  const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.star, color: Colors.amber, size: 22, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notAlani({int maxLines = 3, String decoration = "Bugün neler oldu?", bool borderless = false}) {
    if (!_duzenlemeModu) {
      if (_notController.text.trim().isEmpty) return const SizedBox();
      return _okumaModuMetni();
    }
    if (borderless) {
      return TextField(
        controller: _notController,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(fontFamily: _tasarimIndex == 2 || _tasarimIndex == 4 ? 'Serif' : null),
        decoration: InputDecoration(
          hintText: decoration,
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
        ),
      );
    }
    return Container(
      height: _notAlaniYuksekligi,
      decoration: BoxDecoration(
        color: Colors.brown.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.brown.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: TextField(
              controller: _notController,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontFamily: _tasarimIndex == 2 || _tasarimIndex == 4 ? 'Serif' : null),
              decoration: InputDecoration(
                hintText: decoration,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(15),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _notAlaniYuksekligi += details.delta.dy;
                  if (_notAlaniYuksekligi < 80) _notAlaniYuksekligi = 80;
                  if (_notAlaniYuksekligi > 400) _notAlaniYuksekligi = 400;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
                ),
                child: Icon(Icons.drag_indicator, size: 22, color: Colors.brown.withOpacity(0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kaydetButonu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.all(15),
        ),
        onPressed: _kaydetSorgusu,
        child: const Text("Değişiklikleri Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  String _getTasarimAdi() {
    return ["Klasik Görünüm", "Modern Kartlar", "Günlük Defteri", "Hikaye Modu", "Retro Polaroid"][_tasarimIndex];
  }

  IconData _getTasarimIkonu() {
    return [Icons.grid_view_rounded, Icons.layers_rounded, Icons.edit_note_rounded, Icons.amp_stories_rounded, Icons.camera_roll_rounded][_tasarimIndex];
  }
}