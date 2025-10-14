// lib/berita/detail_berita_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetailBeritaPage extends StatelessWidget {
  final Map<String, dynamic> beritaData;

  const DetailBeritaPage({super.key, required this.beritaData});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF673AB7);
    final Timestamp? timestamp = beritaData['tanggal'] as Timestamp?;
    final String formattedDate = timestamp != null
        ? DateFormat('dd MMMM yyyy, HH:mm').format(timestamp.toDate())
        : 'Tanggal tidak tersedia';
    final imageUrl = beritaData['imageUrl'] as String? ?? '';
    final judul = beritaData['judul'] as String? ?? 'Detail Berita';
    final isi = beritaData['isi'] as String? ?? 'Tidak ada isi lengkap.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EB),
      appBar: AppBar(
        title: const Text('Detail Berita'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Oleh: Admin | Kategori: ${beritaData['kategori'] ?? 'Umum'} | $formattedDate',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => 
                    Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.red)),
                ),
              ),
            const SizedBox(height: 20),
            
            // Isi Berita Lengkap
            Text(isi, style: const TextStyle(fontSize: 16, height: 1.5)),
          ],
        ),
      ),
    );
  }
}