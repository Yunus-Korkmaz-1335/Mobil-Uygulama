// profil_duzenle.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilDuzenleEkrani extends StatefulWidget {
  final Map<String, dynamic> mevcutVeri;
  const ProfilDuzenleEkrani({super.key, required this.mevcutVeri});

  @override
  State<ProfilDuzenleEkrani> createState() => _ProfilDuzenleEkraniState();
}

class _ProfilDuzenleEkraniState extends State<ProfilDuzenleEkrani> {
  late TextEditingController _adController;
  late TextEditingController _nicknameController;
  File? _secilenFoto;
  bool _yukleniyor = false;
  String? _mevcutFotoUrl;

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.mevcutVeri['ad']);
    _nicknameController = TextEditingController(text: widget.mevcutVeri['nickname']);
    _mevcutFotoUrl = widget.mevcutVeri['profilFoto'];
  }

  // Fotoğraf Seçme Fonksiyonu
  Future<void> _fotoSec() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _secilenFoto = File(pickedFile.path));
    }
  }

  // Bilgileri ve Fotoğrafı Kaydetme
  Future<void> _guncelle() async {
    setState(() => _yukleniyor = true);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    String? fotoUrl = _mevcutFotoUrl;

    try {
      // Eğer yeni fotoğraf seçildiyse önce Storage'a yükle
      if (_secilenFoto != null) {
        var ref = FirebaseStorage.instance.ref().child('UserPhotos').child('$uid.jpg');
        await ref.putFile(_secilenFoto!);
        fotoUrl = await ref.getDownloadURL();
      }

      // Firestore güncelleme
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'ad': _adController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'profilFoto': fotoUrl,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profili Düzenle")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _fotoSec,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _secilenFoto != null
                    ? FileImage(_secilenFoto!)
                    : (_mevcutFotoUrl != null ? NetworkImage(_mevcutFotoUrl!) : null) as ImageProvider?,
                child: _secilenFoto == null && _mevcutFotoUrl == null ? const Icon(Icons.camera_alt, size: 40) : null,
              ),
            ),
            TextField(controller: _adController, decoration: const InputDecoration(labelText: "Ad")),
            TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: "Rumuz")),
            const SizedBox(height: 30),
            _yukleniyor
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _guncelle, child: const Text("Değişiklikleri Kaydet"))
          ],
        ),
      ),
    );
  }
}