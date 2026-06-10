import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../servisler/oturum_servisi.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _isLogin = true;
  bool _yukleniyor = false;

  Future<void> girisYap() async {
    if (_emailController.text.isEmpty || _sifreController.text.isEmpty) {
      _hataGoster("Lütfen tüm alanları doldurun.");
      return;
    }
    setState(() => _yukleniyor = true);

    try {
      String email = _emailController.text.trim();
      String sifre = _sifreController.text.trim();

      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: sifre,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: sifre,
        );
      }

      if (!mounted) return;
      _anaSayfayaGit();

    } on FirebaseAuthException catch (e) {
      String hataMesaji = "Bir hata oluştu, lütfen tekrar deneyin.";

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          hataMesaji = "E-posta adresiniz veya şifreniz hatalı.";
          break;
        case 'invalid-email':
          hataMesaji = "Lütfen geçerli bir e-posta adresi girin.";
          break;
        case 'email-already-in-use':
          hataMesaji = "Bu e-posta adresi zaten kullanımda.";
          break;
        case 'weak-password':
          hataMesaji = "Şifreniz çok zayıf.";
          break;
        case 'too-many-requests':
          hataMesaji = "Çok fazla başarısız deneme yaptınız.";
          break;
        default:
          hataMesaji = "Beklenmeyen bir hata oluştu.";
      }
      _hataGoster(hataMesaji);

    } catch (e) {
      _hataGoster("Beklenmeyen bir hata oluştu.");
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _anaSayfayaGit() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color anaRenk = Color(0xFF8D4B4B);

    return Scaffold(
      // ✅ UYGULAMANIN GENEL KREM RENGİ BURAYA EKLENDİ
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 80, color: Color(0xFFFF8A8A)),
              const SizedBox(height: 10),
              const Text(
                "SadeceBiz",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: anaRenk),
              ),
              const SizedBox(height: 50),

              _modernInput(_emailController, "E-posta", Icons.email_outlined, false),
              const SizedBox(height: 20),
              _modernInput(_sifreController, "Şifre", Icons.lock_outline, true),
              const SizedBox(height: 30),

              _yukleniyor
                  ? const CircularProgressIndicator(color: anaRenk)
                  : ElevatedButton(
                onPressed: girisYap,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: anaRenk,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(_isLogin ? "Giriş Yap" : "Kaydol",
                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 25),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text("veya", style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 25),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  User? user = await OturumServisi().googleIleGirisYap();
                  if (user != null) _anaSayfayaGit();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_Logo.png/48px-Google_Logo.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Text("Google ile Devam Et",
                        style: TextStyle(color: Colors.black87, fontSize: 16)),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Hesabın yok mu? Kaydol" : "Zaten üye misin? Giriş Yap",
                    style: const TextStyle(color: anaRenk, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernInput(TextEditingController controller, String label, IconData icon, bool obscure) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}