// lib/home/home_shell_page.dart

import 'package:flutter/material.dart';
import 'package:webprofil/auth/login_page.dart';
// Import Konten Halaman:
import 'package:webprofil/home/home_content_page.dart'; // Halaman 1: Home/Landing Page
import 'package:webprofil/berita/berita_content_page.dart'; // Halaman 2: Daftar Berita
import 'package:webprofil/galeri/galeri_content_page.dart'; // Halaman 3: Daftar Galeri

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _selectedIndex = 0;
  final Color primaryColor = const Color(0xFF673AB7);
  final Color secondaryColor = const Color(0xFF388E3C);
  
  // Daftar konten untuk Bottom Navigation Bar
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeContentPage(),
    const BeritaContentPage(),
    const GaleriContentPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Hilangkan tombol back default
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Image.asset(
              'assets/logo_kediri.png', 
              height: 30,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.apartment, size: 30, color: secondaryColor),
            ),
            const SizedBox(width: 10),
            Text(
              'KOTA KEDIRI MAPAN',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () {
              // Navigasi ke halaman Login (Admin)
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
            child: Text('Login', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),

      // Konten ditampilkan berdasarkan _selectedIndex
      body: _widgetOptions.elementAt(_selectedIndex),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Berita'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: 'Galeri'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped, 
      ),
    );
  }
}