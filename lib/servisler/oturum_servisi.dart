import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class OturumServisi {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> googleIleGirisYap() async {
    try {
      // ✅ KESİN ÇÖZÜM: Sadece çıkış yapmak yetmez, Google'ın bu cihazdaki
      // yetkilendirme hafızasını (cache) tamamen koparıyoruz.
      // isSignedIn() kontrolü yapıyoruz ki daha önce hiç girilmemişse hata fırlatmasın.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      } else {
        await _googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Kullanıcı hesap seçmeden iptal ederse

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Giriş Hatası: $e");
      return null;
    }
  }
}