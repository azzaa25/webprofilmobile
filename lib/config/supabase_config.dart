import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ganti dengan URL dan Anon Key proyek Supabase Anda
const SUPABASE_URL = 'https://vskmfjtwjfhictgfpnsh.supabase.co'; 
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZza21manR3amZoaWN0Z2ZwbnNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MDExMzksImV4cCI6MjA3NTM3NzEzOX0.xrOR5GCjzZciB1S3Lqs934L2EsTVJefM2BzTwIk0DWE';

// Inisialisasi Supabase Client
final supabase = Supabase.instance.client;

// Inisialisasi Firestore instance
final firestore = FirebaseFirestore.instance;

class SupabaseMediaService {
  final String bucketName = 'MediaSukorame';

  // Fungsi untuk mengunggah file ke Supabase Storage
  Future<String> uploadFile(File file, String storagePath, String fileName) async {
    try {
      final fileExtension = file.path.split('.').last;
      final fullPath = '$storagePath/$fileName.$fileExtension';
      
      // Melakukan upload file ke bucket MediaSukorame
      await supabase.storage.from(bucketName).upload(
        fullPath, 
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Mendapatkan URL publik dari file yang diunggah
      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(fullPath);
      return publicUrl;

    } on StorageException catch (e) {
      throw Exception('Gagal mengunggah media ke Supabase Storage: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan tidak terduga saat upload: $e');
    }
  }

  // Fungsi untuk menghapus file dari Supabase Storage (penting saat menghapus data galeri)
  Future<void> deleteFile(String fullPath) async {
    try {
      await supabase.storage.from(bucketName).remove([fullPath]);
    } on StorageException catch (e) {
      print('Gagal menghapus file dari Storage: ${e.message}');
    } catch (e) {
      print('Error menghapus file: $e');
    }
  }
}
