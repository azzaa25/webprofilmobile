// lib/auth/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream untuk memantau perubahan status login (login/logout)
  Stream<User?> get authState => _auth.authStateChanges();

  // Dapatkan user aktif saat ini
  User? get currentUser => _auth.currentUser;

  // Daftar akun baru + kirim email verifikasi
  Future<void> signUp(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
  }

  // Login dengan email & password
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
