// lib/home/home_content_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key});

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage>
    with WidgetsBindingObserver {
  final Color primaryColor = const Color(0xFF673AB7); // Ungu
  final Color backgroundColor = const Color(0xFFF7F4EB); // Krem
  final Color secondaryColor = const Color(0xFF388E3C); // Hijau

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Stream<QuerySnapshot> _beritaStream = FirebaseFirestore.instance
      .collection('berita')
      .orderBy('tanggal', descending: true)
      .limit(2)
      .snapshots();

  final Stream<QuerySnapshot> _galeriStream = FirebaseFirestore.instance
      .collection('kegiatan_galeri')
      .orderBy('uploaded_at', descending: true)
      .limit(4)
      .snapshots();

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _videoController =
        VideoPlayerController.asset('assets/videos/profil_sukorame.mp4')
          ..initialize().then((_) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController.setLooping(true);
            _videoController.play();
          });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    }
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoController.pause();
    }
  }
  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka $url')),
      );
    }
  }

  Future<String> _getCategoryName(String categoryId) async {
    if (categoryId.isEmpty || categoryId == 'Tidak diketahui') {
      return 'Tidak Dikategorikan';
    }
    try {
      final doc =
          await _firestore.collection('kategori_galeri').doc(categoryId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['nama'] as String? ??
            data?['name'] as String? ??
            'Nama Tidak Ditemukan';
      }
      return 'ID Tidak Valid';
    } catch (e) {
      return 'Error Lookup';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            _buildSectionTitle('Berita Sukorame'),
            _buildBeritaSectionRingkas(),
            _buildSectionTitle('Kegiatan di Sukorame'),
            _buildKegiatanSectionRingkas(context),
            _buildSectionTitle('Layanan Masyarakat'),
            _buildLayananSection(),
            _buildSectionTitle('Lokasi Kelurahan Sukorame'),
            _buildLokasiSection(),
            _buildFooterSection(),
          ],
        ),
      ),
    );
  }

  // --- HEADER dengan logo, teks, dan video profil ---
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.15),
            secondaryColor.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + Judul Kelurahan
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo_kediri.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelurahan Sukorame',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kecamatan Mojoroto, Kota Kediri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Video Profil Kelurahan
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            child: _isVideoInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: _videoController.value.aspectRatio,
                          child: VideoPlayer(_videoController),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoController.value.isPlaying) {
                              _videoController.pause();
                            } else {
                              _videoController.play();
                            }
                          });
                        },
                        child: AnimatedOpacity(
                          opacity: _videoController.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Icon(
                              _videoController.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          const SizedBox(height: 16),

          // Deskripsi Kelurahan
          Text(
            'Kelurahan Sukorame merupakan wilayah yang berada di Kecamatan Mojoroto, Kota Kediri. Awalnya berupa desa dan berubah status menjadi Kelurahan. Seiring perubahan tersebut, bentuk pemerintahan pun beralih dari pemerintah desa menjadi pemerintah kelurahan.\n\n'
            'Saat ini, Kelurahan Sukorame terbagi dalam 10 Rukun Warga (RW) dan 37 Rukun Tetangga (RT).',
            textAlign: TextAlign.justify,
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 15, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  // --- Berita Section ---
  Widget _buildBeritaSectionRingkas() {
    return StreamBuilder<QuerySnapshot>(
      stream: _beritaStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] as String? ?? '';
            final judul = data['judul'] as String? ?? 'Judul Berita';
            final isi = data['isi'] as String? ?? 'Deskripsi Berita';
            final timestamp = data['tanggal'] as Timestamp?;
            final formattedDate = timestamp != null
                ? DateFormat('dd MMMM yyyy').format(timestamp.toDate())
                : 'Tanggal tidak tersedia';
            return _buildBeritaItem(
                context, imageUrl, judul, isi, formattedDate);
          },
        );
      },
    );
  }

  Widget _buildBeritaItem(BuildContext context, String imageUrl, String judul,
      String deskripsi, String tanggal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () => print('Lihat Detail Berita: $judul'),
        child: Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 100,
                            width: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image,
                                size: 50, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 100,
                          width: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image,
                              size: 50, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(deskripsi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(tanggal,
                          style:
                              TextStyle(fontSize: 11, color: primaryColor)),
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

  // --- Kegiatan Section ---
  Widget _buildKegiatanSectionRingkas(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _galeriStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final imageUrl = data['cover_url'] as String? ?? '';
              final judul = data['title'] as String? ?? 'Judul Kegiatan';
              final categoryId =
                  data['category_id'] as String? ?? 'Tidak diketahui';
              final uploadedAtTimestamp = data['uploaded_at'] as Timestamp?;
              final formattedDate = uploadedAtTimestamp != null
                  ? DateFormat('dd MMMM yyyy')
                      .format(uploadedAtTimestamp.toDate())
                  : 'Tanggal Kegiatan';

              return FutureBuilder<String>(
                future: _getCategoryName(categoryId),
                builder: (context, categorySnapshot) {
                  final kategoriTampil =
                      categorySnapshot.data ?? 'Memuat...';
                  return _buildGaleriItem(
                      context, imageUrl, judul, kategoriTampil, formattedDate);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGaleriItem(BuildContext context, String imageUrl, String judul,
      String kategori, String tanggal) {
    return InkWell(
      onTap: () => print('Lihat Detail Kegiatan: $judul'),
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 140,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image,
                            size: 50, color: Colors.red),
                      ),
                    )
                  : Container(
                      height: 140,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image,
                          size: 50, color: Colors.grey),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Kategori: $kategori',
                      style: TextStyle(fontSize: 11, color: primaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(tanggal,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Layanan & Lokasi Section ---
  Widget _buildLayananSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLayananItem(
            'E-SUKET',
            'assets/icons/logo_kediri.png',
            () => _openUrl('https://esuket.kedirikota.go.id/'),
          ),
          _buildLayananItem(
            'Website Sukorame',
            'assets/icons/logo_kediri.png',
            () => _openUrl('https://kel-sukorame.kedirikota.go.id/index.php/'),
          ),
          _buildLayananItem(
            'SAKTI',
            'assets/icons/logo_kediri.png',
            () => _openUrl('https://disdukcapil.kedirikota.go.id/sakti/'),
          ),
        ],
      ),
    );
  }

  Widget _buildLayananItem(String label, String assetPath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(1),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLokasiSection() {
    const double latitude = -7.8276;
    const double longitude = 111.9780;

    // 🔗 Link otomatis ke Google Maps berdasarkan koordinat
    final String mapLink =
        "https://www.google.com/maps?q=$latitude,$longitude";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- PETA OPENSTREETMAP ---
          Expanded(
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.hardEdge,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(latitude, longitude),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.sukorame.webprofil',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80,
                        height: 80,
                        point: const LatLng(latitude, longitude),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // --- QR CODE OTOMATIS DARI LINK MAP ---
          Container(
            height: 200,
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Lokasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                Expanded(
                  child: Center(
                    child: QrImageView(
                      data: mapLink, // otomatis dari koordinat
                      version: QrVersions.auto,
                      size: 100.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFooterSection() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jl. KH. Ahmad Dahlan No. 54, Kelurahan Sukorame, Kecamatan Mojoroto, Kota Kediri, Jawa Timur',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                '(0354) 6022152',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.email, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Kelurahan.Sukorame@gmail.com',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.language, color: primaryColor),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openUrl('https://kel-sukorame.kedirikota.go.id'),
                child: const Text(
                  'https://kel-sukorame.kedirikota.go.id',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© 2025 Kelurahan Sukorame - Kota Kediri\nDikembangkan dengan ❤️ oleh Tim Web Profil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}