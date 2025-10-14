import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../services/galeri_services.dart'; 
import '../models/galeri_kegiatan_model.dart'; 
import '../models/kategori_model.dart'; 
import 'manage_galeri_page.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:webprofil/services/admin_log_service.dart';

class DashboardGaleriPage extends StatefulWidget {
  DashboardGaleriPage({super.key});

  @override
  State<DashboardGaleriPage> createState() => _DashboardGaleriPageState();
}

class _DashboardGaleriPageState extends State<DashboardGaleriPage> {
  final GaleriService _galeriService = GaleriService();
  final AdminLogService _logService = AdminLogService();
  
  // === STATE MULTI-SELEKSI ===
  final Set<String> _selectedDocuments = {};
  bool _isMultiSelectionMode = false;
  
  String? _selectedCategoryId; 
  List<Kategori> _kategoriList = []; 
  bool _isLoadingKategori = true;

  @override
  void initState() {
    super.initState();
    _loadKategori();
  }

  // --- Fungsi Load Kategori ---
  void _loadKategori() {
    _galeriService.getKategori().listen((kategori) {
      if (mounted) {
        setState(() {
          _kategoriList = kategori;
          _isLoadingKategori = false;
        });
      }
    });
  }

  // --- Fungsi Toggle Seleksi ---
  void _toggleSelection(String documentId) {
    setState(() {
      if (_selectedDocuments.contains(documentId)) {
        _selectedDocuments.remove(documentId);
      } else {
        _selectedDocuments.add(documentId);
      }
      
      if (_selectedDocuments.isEmpty) {
        _isMultiSelectionMode = false;
      } else {
        _isMultiSelectionMode = true;
      }
    });
  }

  // --- Fungsi Mendapatkan Stream Galeri ---
  Stream<List<KegiatanGaleri>> _getFilteredKegiatanStream() {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return _galeriService.getKegiatan();
    }
    
    return _galeriService.kegiatanCollection
        .where('category_id', isEqualTo: _selectedCategoryId)
        .orderBy('uploaded_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => KegiatanGaleri.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  // FUNGSI HAPUS MASSAL (Tidak diubah, hanya dipanggil dari AppBar)
  Future<void> _deleteSelectedKegiatan(BuildContext context) async {
    if (_selectedDocuments.isEmpty) return;

    final count = _selectedDocuments.length;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus Massal'),
        content: Text('Anda yakin ingin menghapus $count kegiatan yang dipilih? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Logic penghapusan massal (disini hanya mencontohkan log dan reset state)
      // Perlu dipastikan logika aslinya ada di service.
      int successCount = 0;
      
      for (final docId in _selectedDocuments.toList()) {
        try {
          final doc = await _galeriService.kegiatanCollection.doc(docId).get();
          if (doc.exists) {
            final kegiatan = KegiatanGaleri.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
            await _galeriService.deleteKegiatan(kegiatan);
            await _logService.logActivity('Menghapus Massal Galeri: "${kegiatan.title}"');
            successCount++;
          }
        } catch (e) {
          print('Gagal menghapus kegiatan $docId: $e');
        }
      }
      
      setState(() {
        _selectedDocuments.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menghapus $successCount dari $count kegiatan.'), backgroundColor: Colors.green),
      );
    }
  }


  // BARU: Widget Dropdown untuk Filter Kategori (Tetap Sama)
  Widget _buildCategoryFilter() {
    if (_isLoadingKategori) {
      return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    
    final List<DropdownMenuItem<String?>> dropdownItems = [
      const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
      ..._kategoriList.map((kategori) {
        return DropdownMenuItem(
          value: kategori.id,
          child: Text(kategori.name),
        );
      }).toList(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: DropdownButtonFormField<String?>(
        decoration: InputDecoration(
          labelText: 'Filter Kategori',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        value: _selectedCategoryId,
        items: dropdownItems,
        onChanged: (newValue) {
          setState(() {
            _selectedCategoryId = newValue; 
            _selectedDocuments.clear();
            _isMultiSelectionMode = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMultiSelectionMode ? '${_selectedDocuments.length} Dipilih' : 'Admin Galeri Kegiatan'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: _isMultiSelectionMode ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _selectedDocuments.clear();
              _isMultiSelectionMode = false;
            });
          },
        ) : null,
        actions: [
          if (_isMultiSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _deleteSelectedKegiatan(context),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Implementasi pencarian dalam GridView
              },
            ),
        ],
      ),
      // Tombol FAB untuk menambah kegiatan baru
      floatingActionButton: !_isMultiSelectionMode ? FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_a_photo),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ManageGaleriPage(),
            ),
          );
        },
      ) : null,
      body: Column(
        children: [
          _buildCategoryFilter(), 
          
          Expanded(
            child: StreamBuilder<List<KegiatanGaleri>>(
              stream: _getFilteredKegiatanStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Tidak ada kegiatan yang sesuai dengan filter.'));
                }

                final kegiatanList = snapshot.data!;

                return ListView.builder(
                  itemCount: kegiatanList.length,
                  itemBuilder: (context, index) {
                    final kegiatan = kegiatanList[index];
                    final isSelected = _selectedDocuments.contains(kegiatan.id);
                    
                    final categoryName = _kategoriList
                        .firstWhere(
                          (k) => k.id == kegiatan.categoryId,
                          orElse: () => Kategori(id: '', name: 'Kategori Tidak Dikenal'),
                        )
                        .name;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      elevation: 4,
                      // HAPUS COLOR HIGHLIGHT: Warna latar belakang Card tetap putih (default)
                      // color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        onTap: () {
                          if (_isMultiSelectionMode) {
                            _toggleSelection(kegiatan.id);
                          } else {
                            _showMediaDetailDialog(context, kegiatan);
                          }
                        },
                        onLongPress: () {
                          _toggleSelection(kegiatan.id);
                        },
                        contentPadding: const EdgeInsets.all(10),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // CHECKBOX DITAMPILKAN JIKA MULTI-SELEKSI AKTIF
                            if (_isMultiSelectionMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) => _toggleSelection(kegiatan.id),
                                activeColor: Colors.deepPurple, // Gunakan warna aksen
                              ),
                            
                            // Kotak Gambar
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  kegiatan.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          kegiatan.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$categoryName | ${kegiatan.media.length} Foto | Diunggah: ${DateFormat('dd MMM yyyy').format(kegiatan.uploadedAt.toDate())}', 
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tombol Edit Metadata & Tambah Media
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit Kegiatan',
                              onPressed: () {
                                if (!_isMultiSelectionMode) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ManageGaleriPage(kegiatan: kegiatan),
                                    ),
                                  );
                                }
                              },
                            ),
                            // Tombol Hapus Kegiatan (Tunggal)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Hapus Kegiatan',
                              onPressed: () {
                                if (!_isMultiSelectionMode) {
                                  _confirmDelete(context, kegiatan);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
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

  // Dialog Konfirmasi Hapus (Tunggal)
  void _confirmDelete(BuildContext context, KegiatanGaleri kegiatan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
            'Apakah Anda yakin ingin menghapus kegiatan "${kegiatan.title}" dan SEMUA ${kegiatan.media.length} file medianya? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop(); 
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menghapus kegiatan...'), duration: Duration(seconds: 2)),
                );
                
                // Panggil service untuk menghapus
                await _galeriService.deleteKegiatan(kegiatan);
                
                // PENCATATAN LOG (DELETE GALERI)
                await _logService.logActivity('Menghapus Kegiatan Galeri: "${kegiatan.title}"');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kegiatan berhasil dihapus!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menghapus: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
  
  // Dialog untuk menampilkan semua media dalam kegiatan (tetap sama)
  void _showMediaDetailDialog(BuildContext context, KegiatanGaleri kegiatan) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Media di ${kegiatan.title}'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: kegiatan.media.length,
              itemBuilder: (context, index) {
                final mediaItem = kegiatan.media[index];
                return GestureDetector(
                  onTap: () {
                    // Opsional: Tampilkan gambar dalam mode fullscreen
                    // Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: mediaItem.url)));
                  },
                  child: Hero( 
                    tag: mediaItem.url,
                    child: Image.network(
                      mediaItem.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }
}