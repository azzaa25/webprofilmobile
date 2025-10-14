import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago; // Tambahkan import timeago
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Tambahkan import Firestore
import 'package:webprofil/berita/dashboard_berita_page.dart';
import 'package:webprofil/auth/auth_service.dart';
import 'package:webprofil/home/home_shell_page.dart';
import 'package:webprofil/galeri/dashboard_galeri_page.dart'; 
import 'package:webprofil/galeri/manage_kategori_page.dart'; 
import 'package:webprofil/services/analytics_service.dart'; 

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isSigningOut = false;
  late Future<Map<String, int>> _statsFuture;
  
  // Ambil 5 aktivitas terbaru dari koleksi 'admin_logs'
  final Stream<QuerySnapshot> _activityStream = FirebaseFirestore.instance
      .collection('admin_logs')
      .orderBy('timestamp', descending: true)
      .limit(5)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  // Fungsi untuk memuat semua statistik (Asumsi AnalyticsService mengambil data dari Firestore/Realtime DB)
  Future<Map<String, int>> _fetchStats() async {
    // ... (Logika fetch stats tidak berubah)
    final visitors = await _analyticsService.getTotalVisitors();
    final newsCount = await _analyticsService.getActiveNewsCount();
    final galleryCount = await _analyticsService.getGalleryCount();
    
    return {
      'visitors': visitors,
      'news': newsCount,
      'gallery': galleryCount,
    };
  }

  // Fungsi untuk logout (tidak berubah)
  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await AuthService().signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeShellPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Logout: ${e.toString()}')),
        );
      }
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  void _showProfilePopup() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Tidak ada email';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informasi Akun'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Anda login sebagai:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Email: $email'),
              const SizedBox(height: 8),
              Text('Verifikasi Email: ${user?.emailVerified == true ? "Sudah" : "Belum"}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: Colors.blueAccent,
        actions: [
          TextButton.icon(
            onPressed: _showProfilePopup,
            icon: const Icon(Icons.person, color: Colors.white),
            label: const Text('Admin', style: TextStyle(color: Colors.white)),
          ),
          _isSigningOut
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
        ],
      ),
      // Drawer (Menghapus Kelola Profil Lurah)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu Admin', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard Utama'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.article), title: const Text('Kelola Berita & Pengumuman'), onTap: () {
              Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardBeritaPage()));
            }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Kelola Galeri Kegiatan'), onTap: () {
              Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardGaleriPage()));
            }),
            ListTile(leading: const Icon(Icons.category), title: const Text('Kelola Kategori Galeri'), onTap: () {
              Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageKategoriPage()));
            }),
          ],
        ),
      ),
      
      // BODY DENGAN FUTUREBUILDER UNTUK STATISTIK
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat data: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? {'visitors': 0, 'news': 0, 'gallery': 0};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- KARTU RINGKASAN (SUMMARY CARDS) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryCard(context, 'Total Kunjungan (App Open)', stats['visitors'].toString(), Icons.people, Colors.blue),
                    _buildSummaryCard(context, 'Berita Aktif', stats['news'].toString(), Icons.article, Colors.orange),
                    _buildSummaryCard(context, 'Galeri Kegiatan', stats['gallery'].toString(), Icons.photo_library, Colors.purple),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // --- LOG AKTIVITAS CRUD DINAMIS ---
                _buildRecentActivityCard(context),
                
                const SizedBox(height: 16),
                _buildMessageCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget _buildSummaryCard (Sudah dimodifikasi untuk estetika)
  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Icon(icon, color: color, size: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget Aktivitas Terkini (MENGGUNAKAN STREAM FIREBASE)
  Widget _buildRecentActivityCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktivitas CRUD Terkini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            
            StreamBuilder<QuerySnapshot>(
              stream: _activityStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error memuat log: ${snapshot.error}');
                }
                
                final activities = snapshot.data?.docs ?? [];
                
                if (activities.isEmpty) {
                  return const Text('Belum ada aktivitas CRUD tercatat.');
                }

                // Loop melalui data log yang diambil dari Firestore
                return Column(
                  children: activities.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final activity = data['activity'] as String? ?? 'Aktivitas tidak dikenal';
                    // Asumsi: 'username' atau 'email' disimpan dalam log
                    final user = data['user'] as String? ?? 'Admin'; 
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final timeAgo = timestamp != null 
                        ? timeago.format(timestamp) // Membutuhkan library timeago (diasumsikan)
                        : 'Baru saja'; 
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.edit_note, size: 18, color: Colors.green[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                Text(
                                  'Oleh $user - $timeAgo',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget Pesan Masuk (tidak berubah)
  Widget _buildMessageCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pesan Masuk Terbaru', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.red[100], child: const Text('B', style: TextStyle(color: Colors.red))),
              title: const Text('Budi Santato', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tanya tentang dokumen...', overflow: TextOverflow.ellipsis),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () {},
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[100], child: const Text('A', style: TextStyle(color: Colors.blue))),
              title: const Text('Andi Wijaya', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Permintaan perbaikan jalan...', overflow: TextOverflow.ellipsis),
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () {},
            ),
            const Divider(),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {},
                child: const Text('Lihat Semua Pesan', style: TextStyle(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}