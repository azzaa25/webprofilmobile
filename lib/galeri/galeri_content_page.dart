// lib/galeri/galeri_content_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:webprofil/galeri/detail_galeri_page.dart'; 

class GaleriContentPage extends StatefulWidget {
  const GaleriContentPage({super.key});

  @override
  State<GaleriContentPage> createState() => _GaleriContentPageState();
}

class _GaleriContentPageState extends State<GaleriContentPage> {
  final Color primaryColor = const Color(0xFF673AB7);
  final Color backgroundColor = const Color(0xFFF7F4EB);
  String _searchQuery = '';
  
  // Instance Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- FUNGSI ASINKRON UNTUK MENCARI NAMA KATEGORI ---
  Future<String> _getCategoryName(String categoryId) async {
    if (categoryId.isEmpty || categoryId == 'Tidak diketahui') {
      return 'Tidak Dikategorikan';
    }
    try {
      // Asumsi: Koleksi kategori Anda bernama 'kategori_galeri'
      final doc = await _firestore.collection('kategori_galeri').doc(categoryId).get();
      
      if (doc.exists) {
        final data = doc.data();
        // Asumsi: Nama kategori disimpan di field 'nama' atau 'name'
        return data?['nama'] as String? ?? data?['name'] as String? ?? 'Kategori Tidak Ditemukan';
      }
      return 'ID Tidak Valid';
    } catch (e) {
      print('Error fetching category name: $e');
      return 'Error Lookup';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (Header Judul dan Search Bar tidak berubah) ...
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Galeri Kegiatan',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Cari kategori...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () {}, child: Text('Cari', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          
          // Grid Galeri Kegiatan
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kegiatan_galeri').orderBy('uploaded_at', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada kegiatan yang tersedia.'));

                final listGaleri = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final judul = (data['title'] as String? ?? '').toLowerCase(); 
                  final categoryId = (data['category_id'] as String? ?? '').toLowerCase(); 
                  final query = _searchQuery.toLowerCase();
                  return judul.contains(query) || categoryId.contains(query);
                }).toList();

                if (listGaleri.isEmpty) return const Center(child: Text('Tidak ada kegiatan yang cocok dengan pencarian.'));

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.7,
                  ),
                  itemCount: listGaleri.length,
                  itemBuilder: (context, index) {
                    final DocumentSnapshot doc = listGaleri[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final imageUrl = data['cover_url'] as String? ?? ''; 
                    final judul = data['title'] as String? ?? 'Judul Kegiatan'; 
                    final categoryId = data['category_id'] as String? ?? 'Tidak diketahui'; 
                    final uploadedAtTimestamp = data['uploaded_at'] as Timestamp?;
                    final formattedDate = uploadedAtTimestamp != null ? DateFormat('dd MMMM yyyy').format(uploadedAtTimestamp.toDate()) : 'Tanggal Kegiatan';

                    // PENTING: Menggunakan FutureBuilder untuk mendapatkan nama kategori
                    return FutureBuilder<String>(
                      future: _getCategoryName(categoryId),
                      builder: (context, categorySnapshot) {
                        final kategoriTampil = categorySnapshot.data ?? 'Memuat...';
                        
                        return _buildGaleriItem(context, data, imageUrl, judul, kategoriTampil, formattedDate);
                      },
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

  // Parameter _buildGaleriItem diubah untuk menerima Map<String, dynamic> data lengkap
  Widget _buildGaleriItem(BuildContext context, Map<String, dynamic> data, String imageUrl, String judul, String kategori, String tanggal) {
    return InkWell(
      onTap: () {
        // NAVIGASI KE HALAMAN DETAIL DENGAN MENGIRIMKAN DATA LENGKAP
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailGaleriPage(kegiatanData: data),
          ),
        );
      },
      child: Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4.0)),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl, 
                      width: double.infinity, 
                      height: 140, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(height: 140, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.red));
                      },
                    )
                  : Container(height: 140, color: Colors.grey[200], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Menampilkan nama kategori yang sudah dicari
                  Text('Kategori: $kategori', style: TextStyle(fontSize: 11, color: primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(tanggal, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}