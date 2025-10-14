// lib/galeri/detail_galeri_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetailGaleriPage extends StatelessWidget {
  final Map<String, dynamic> kegiatanData;

  const DetailGaleriPage({super.key, required this.kegiatanData});

  // Fungsi untuk mendapatkan nama kategori dari ID, jika diperlukan
  Future<String> _getCategoryName(String categoryId) async {
    if (categoryId.isEmpty || categoryId == 'Tidak diketahui') {
      return 'Tidak Dikategorikan';
    }
    // Asumsi: Koleksi kategori Anda bernama 'kategori_galeri'
    final doc = await FirebaseFirestore.instance.collection('kategori_galeri').doc(categoryId).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['nama'] as String? ?? data?['name'] as String? ?? categoryId;
    }
    return categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF673AB7);
    final uploadedAtTimestamp = kegiatanData['uploaded_at'] as Timestamp?;
    
    final String formattedDate = uploadedAtTimestamp != null
        ? DateFormat('dd MMMM yyyy, HH:mm').format(uploadedAtTimestamp.toDate())
        : 'Tanggal tidak tersedia';
        
    final String judul = kegiatanData['title'] as String? ?? 'Detail Kegiatan';
    final String deskripsi = kegiatanData['description'] as String? ?? 'Tidak ada deskripsi.';
    final String categoryId = kegiatanData['category_id'] as String? ?? 'Umum';
    
    // Mengambil array media (List of Maps, di mana setiap Map memiliki field 'url')
    final List<dynamic> mediaRaw = kegiatanData['media'] is List ? kegiatanData['media'] as List<dynamic> : [];
    final List<String> imageUrls = mediaRaw
        .map((item) => (item as Map<String, dynamic>)['url'] as String?)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EB),
      appBar: AppBar(
        title: const Text('Detail Kegiatan Galeri'),
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
            
            // FUTURE BUILDER UNTUK MENAMPILKAN NAMA KATEGORI
            FutureBuilder<String>(
              future: _getCategoryName(categoryId),
              builder: (context, snapshot) {
                final kategoriTampil = snapshot.data ?? 'Memuat Kategori...';
                return Text('Kategori: $kategoriTampil | $formattedDate',
                    style: const TextStyle(fontSize: 14, color: Colors.grey));
              },
            ),
            
            const SizedBox(height: 16),
            
            // Deskripsi
            Text(deskripsi, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 20),
            
            // Galeri Foto (Grid dari semua media yang ada)
            Text('Galeri Foto (${imageUrls.length})', 
                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 10),

            if (imageUrls.isEmpty)
              const Text('Tidak ada foto yang tersedia untuk kegiatan ini.'),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    // Tampilkan viewer foto fullscreen untuk semua foto
                    _showFullscreenViewer(context, imageUrls, index);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan Fullscreen Viewer (Carousel)
  void _showFullscreenViewer(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => FullscreenImageGallery(imageUrls: urls, initialIndex: initialIndex),
    ));
  }
}

// Widget untuk Fullscreen Carousel (Wajib ada di file ini atau diimpor)
class FullscreenImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageGallery({super.key, required this.imageUrls, required this.initialIndex});

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${_currentIndex + 1} of ${widget.imageUrls.length}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: Image.network(
              widget.imageUrls[index],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => 
                const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.red)),
            ),
          );
        },
      ),
    );
  }
}