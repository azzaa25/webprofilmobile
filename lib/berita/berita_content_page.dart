// lib/berita/berita_content_page.dart (Diperbaiki)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import halaman detail yang baru
import 'package:webprofil/berita/detail_berita_page.dart'; 

class BeritaContentPage extends StatelessWidget {
  const BeritaContentPage({super.key});

  final Color primaryColor = const Color(0xFF673AB7);
  final Color backgroundColor = const Color(0xFFF7F4EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul (Ganti AppBar di shell)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Berita Sukorame',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          
          // Daftar Berita
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('berita').orderBy('tanggal', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada berita yang tersedia.'));

                final listBerita = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: listBerita.length,
                  itemBuilder: (context, index) {
                    // Ambil data dokumen sebagai Map
                    final data = listBerita[index].data() as Map<String, dynamic>;
                    
                    final imageUrl = data['imageUrl'] as String? ?? '';
                    final judul = data['judul'] as String? ?? 'Judul Berita';
                    final isi = data['isi'] as String? ?? 'Deskripsi Berita';
                    final timestamp = data['tanggal'] as Timestamp?;
                    final formattedDate = timestamp != null ? DateFormat('dd MMMM yyyy').format(timestamp.toDate()) : 'Tanggal tidak tersedia';

                    // MELEWATKAN SELURUH DATA DOKUMEN
                    return _buildBeritaItem(
                        context, 
                        data, // Melewatkan data lengkap
                        imageUrl, 
                        judul, 
                        isi, 
                        formattedDate
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Parameter diubah untuk menerima Map<String, dynamic> data lengkap
  Widget _buildBeritaItem(
    BuildContext context, 
    Map<String, dynamic> data, // Data lengkap yang dilewatkan
    String imageUrl, 
    String judul, 
    String deskripsi, 
    String tanggal
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          // NAVIGASI KE HALAMAN DETAIL DENGAN MENGIRIMKAN DATA
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailBeritaPage(beritaData: data),
            ),
          );
        },
        child: Card(
          elevation: 2,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 100, height: 100, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(height: 100, width: 100, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.red)),
                        )
                      : Container(height: 100, width: 100, color: Colors.grey[200], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(deskripsi, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(tanggal, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}