import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Class User yang digunakan di StreamBuilder: dari firebase_auth, diimpor langsung
import 'package:firebase_auth/firebase_auth.dart'; 
// Memberi prefix 'supabase_pkg' pada import Supabase
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_pkg; 

import 'package:webprofil/auth/login_page.dart';
import 'package:webprofil/dashboard/main_dashboard_page.dart';
import 'package:webprofil/config/firebase_options.dart';
import 'package:webprofil/config/supabase_config.dart'; 
// Menggunakan HomeShellPage yang merupakan Shell Navigasi
import 'package:webprofil/home/home_shell_page.dart'; 

// Variabel SUPABASE_URL dan SUPABASE_ANON_KEY diasumsikan diimpor dari config/supabase_config.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Variabel untuk menyimpan error
  String? initError;

  try {
    // Inisialisasi Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initError = 'Gagal inisialisasi Firebase: $e';
    debugPrint(initError);
  }

  try {
    // Inisialisasi Supabase
    await supabase_pkg.Supabase.initialize(
      url: SUPABASE_URL,
      anonKey: SUPABASE_ANON_KEY,
    );
  } catch (e) {
    initError = (initError != null ? '$initError\n' : '') + 'Gagal inisialisasi Supabase: $e';
    debugPrint('Gagal inisialisasi Supabase: $e');
  }

  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  final String? initError;
  const MyApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    // Jika ada error inisialisasi, tampilkan pesan error
    if (initError != null) {
      return MaterialApp(
        title: 'Web Profil Sukorame',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Error Inisialisasi')),
          body: Center(
            child: Text(
              initError!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Web Profil Sukorame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const MainDashboardPage();
          } else {
            return const HomeShellPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const MainDashboardPage(),
      },
    );
  }
}
