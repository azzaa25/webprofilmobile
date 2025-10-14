// lib/services/analytics_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Logika Menghitung Pembukaan Aplikasi (App Open) ---
  Future<int> getTotalVisitors() async {
    final prefs = await SharedPreferences.getInstance();
    // Ambil nilai saat ini, default ke 0
    int count = prefs.getInt('app_open_count') ?? 0;
    // Tambah 1 untuk sesi saat ini
    count++;
    // Simpan nilai baru
    await prefs.setInt('app_open_count', count);
    return count;
  }
  
  // --- Logika Mengambil Jumlah Berita Aktif ---
  Future<int> getActiveNewsCount() async {
    // Asumsi koleksi berita Anda bernama 'berita'
    final snapshot = await _firestore.collection('berita').get();
    return snapshot.docs.length;
  }

  // --- Logika Mengambil Jumlah Galeri Kegiatan ---
  Future<int> getGalleryCount() async {
    // Asumsi koleksi galeri Anda bernama 'kegiatan_galeri'
    final snapshot = await _firestore.collection('kegiatan_galeri').get();
    return snapshot.docs.length;
  }
}