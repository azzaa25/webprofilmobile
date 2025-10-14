import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webprofil/berita/tambah_berita_baru_page.dart';
import 'package:webprofil/berita/edit_berita_page.dart';
import 'package:webprofil/services/admin_log_service.dart'; // Sudah ada

class DashboardBeritaPage extends StatefulWidget {
  const DashboardBeritaPage({super.key});

  @override
  State<DashboardBeritaPage> createState() => _DashboardBeritaPageState();
}

class _DashboardBeritaPageState extends State<DashboardBeritaPage> {
  final Set<String> _selectedDocuments = {};
  bool _isMultiSelectionMode = false;
  bool _isLoading = false;

  // Instance AdminLogService
  final AdminLogService _logService = AdminLogService();

  // --- State untuk Search dan Filter ---
  String _searchQuery = '';
  String _selectedStatus = 'Semua';
  String _selectedCategory = 'Semua';
  bool _isSearching = false;

  final List<String> _statusList = ['Semua', 'Tayang', 'Draf'];
  final List<String> _kategoriList = ['Semua', 'Kegiatan Warga', 'Pengumuman', 'Lainnya'];

  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Fungsi Supabase Storage ---
  Future<void> _deleteImage(String? imageUrl) async {
    // ... (kode _deleteImage tidak berubah)
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final fullPath = pathSegments.sublist(pathSegments.indexOf('MediaSukorame') + 1).join('/');
        await _supabase.storage.from('MediaSukorame').remove([fullPath]);
      } catch (e) {
        print('Gagal menghapus gambar dari Supabase: $e');
      }
    }
  }

  // --- Fungsi Hapus Berita (Firestore + Storage) ---
  Future<void> _deleteBerita(BuildContext context, List<DocumentSnapshot> documentsToDelete) async {
    if (documentsToDelete.isEmpty) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(documentsToDelete.length > 1 ? 'Hapus ${documentsToDelete.length} Berita' : 'Hapus Berita'),
          content: SingleChildScrollView(
            child: Text(documentsToDelete.length > 1 
                ? 'Apakah Anda yakin ingin menghapus ${documentsToDelete.length} berita ini? Tindakan ini tidak dapat dibatalkan.'
                : 'Apakah Anda yakin ingin menghapus berita ini? Tindakan ini tidak dapat dibatalkan.'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                setState(() { _isLoading = true; });

                int successCount = 0;
                int failCount = 0;

                for (final doc in documentsToDelete) {
                  try {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data != null) {
                      // Hapus dari Supabase dan Firestore
                      await _deleteImage(data['imageUrl'] as String?);
                      await FirebaseFirestore.instance.collection('berita').doc(doc.id).delete();
                      
                      // === PENCATATAN LOG (DELETE) ===
                      final judul = data['judul'] ?? 'Tanpa Judul';
                      await _logService.logActivity('Menghapus Berita: "$judul"');
                      // ===============================

                      successCount++;
                    }
                  } catch (e) {
                    print('Gagal menghapus berita ${doc.id}: $e');
                    failCount++;
                  }
                }
                
                setState(() {
                  _selectedDocuments.clear();
                  _isMultiSelectionMode = false;
                  _isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Berhasil menghapus $successCount berita. Gagal: $failCount')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ... (sisa fungsi _showBeritaDetail, _toggleSelection, _filterData tetap) ...

  // --- Fungsi Tampilkan Detail (Pop-up) ---
  void _showBeritaDetail(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final Timestamp? timestamp = data['tanggal'] as Timestamp?;
        final String formattedDate = timestamp != null
            ? DateFormat('dd MMMM yyyy, HH:mm').format(timestamp.toDate())
            : 'Tanggal tidak tersedia';
        return AlertDialog(
          title: Text(data['judul'] ?? 'Tanpa Judul'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['imageUrl'] is String && data['imageUrl'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        data['imageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 200),
                      ),
                    ),
                  ),
                Text(
                  'Oleh: ${data['penulis'] ?? 'Admin'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Tanggal: $formattedDate'),
                Text('Kategori: ${data['kategori'] ?? 'Tidak diketahui'}'),
                const Divider(),
                Text(data['isi'] ?? 'Tidak ada isi berita'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
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

  // --- Fungsi Filter Logika Utama ---
  List<DocumentSnapshot> _filterData(List<DocumentSnapshot> listBerita) {
    // 1. Filter Kategori
    List<DocumentSnapshot> filteredList = listBerita.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final kategori = data['kategori'] as String? ?? 'Tidak diketahui';
      
      return _selectedCategory == 'Semua' || kategori == _selectedCategory;
    }).toList();
    
    // 2. Filter Status (Simulasi: Draf jika judul mengandung '[DRAFT]')
    filteredList = filteredList.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final judul = data['judul'] as String? ?? '';
      
      if (_selectedStatus == 'Semua') return true;
      if (_selectedStatus == 'Draf') return judul.toUpperCase().contains('[DRAFT]');
      if (_selectedStatus == 'Tayang') return !judul.toUpperCase().contains('[DRAFT]');
      
      return true;
    }).toList();

    // 3. Filter Pencarian
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredList = filteredList.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final judul = (data['judul'] as String? ?? '').toLowerCase();
        final isi = (data['isi'] as String? ?? '').toLowerCase();
        
        return judul.contains(query) || isi.contains(query);
      }).toList();
    }

    return filteredList;
  }


  // --- Widget Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Perbaikan: Text color di TextField diubah menjadi hitam
        title: _isSearching
            ? TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Cari Judul atau Isi...',
                  border: InputBorder.none,
                  // Teks hint hitam
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                // Teks input hitam
                style: const TextStyle(color: Colors.black),
              )
            : Text(
                _isMultiSelectionMode 
                ? '${_selectedDocuments.length} dipilih' 
                : 'Kelola Berita & Pengumuman',
                // Pastikan Title AppBar default juga hitam jika latar belakang putih
                style: TextStyle(color: Colors.black), 
              ),
        
        // Atur warna ikon AppBar menjadi hitam agar terlihat
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        
        leading: _isMultiSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black), // Ikon Close hitam
                onPressed: () {
                  setState(() {
                    _selectedDocuments.clear();
                    _isMultiSelectionMode = false;
                  });
                },
              )
            : null,
            
        actions: [
          // Tombol Search
          if (!_isMultiSelectionMode)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black), // Ikon Search hitam
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = ''; // Reset query saat menutup search
                  }
                });
              },
            ),

          // Tombol Hapus Massal
          if (_isMultiSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              onPressed: () {
                if (_selectedDocuments.isNotEmpty) {
                  FirebaseFirestore.instance
                      .collection('berita')
                      .where(FieldPath.documentId, whereIn: _selectedDocuments.toList())
                      .get()
                      .then((querySnapshot) {
                        _deleteBerita(context, querySnapshot.docs);
                      });
                }
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Penting agar Padding filter mengisi lebar
        children: [
          // Filter Row 1: Status Buttons
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0, 
                  children: _statusList.map((status) => _buildStatusChip(status)).toList(),
                ),
              ],
            ),
          ),
          
          // Filter Row 2: Category Dropdown (Di baris terpisah)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: _buildDropdownFilter(
              label: 'Kategori',
              value: _selectedCategory,
              items: _kategoriList,
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),
          ),
          
          // List Berita
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('berita').orderBy('tanggal', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Belum ada berita.'));
                }

                // Terapkan filter dan pencarian
                final listBerita = _filterData(snapshot.data!.docs);

                if (listBerita.isEmpty) {
                   return const Center(child: Text('Tidak ada berita yang cocok dengan filter/pencarian.'));
                }

                return ListView.builder(
                  itemCount: listBerita.length,
                  itemBuilder: (context, index) {
                    final DocumentSnapshot doc = listBerita[index];
                    final String documentId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;

                    final Timestamp? timestamp = data['tanggal'] as Timestamp?;
                    final String formattedDate = timestamp != null
                        ? DateFormat('dd MMMM yyyy').format(timestamp.toDate())
                        : 'Tanggal tidak tersedia';
                    
                    final bool isSelected = _selectedDocuments.contains(documentId);

                    return Card(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InkWell(
                        onTap: () {
                          if (_isMultiSelectionMode) {
                            _toggleSelection(documentId);
                          } else {
                            _showBeritaDetail(context, data);
                          }
                        },
                        onLongPress: () {
                          _toggleSelection(documentId);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isMultiSelectionMode)
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? value) => _toggleSelection(documentId),
                                ),
                              
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: (data['imageUrl'] is String && data['imageUrl'].isNotEmpty)
                                    ? Image.network(
                                        data['imageUrl'],
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                                      )
                                    : const Icon(Icons.image, size: 80, color: Colors.grey),
                              ),
                              const SizedBox(width: 16.0),
                              
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['judul'] ?? 'Tanpa Judul',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      '${data['penulis'] ?? 'Admin'} | $formattedDate',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    Text(
                                      'Kategori: ${data['kategori'] ?? 'Tidak diketahui'}',
                                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      data['isi'] ?? 'Tidak ada isi berita',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (!_isMultiSelectionMode)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditBeritaPage(
                                              documentId: documentId,
                                              initialData: data,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () {
                                        _deleteBerita(context, [doc]);
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
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
      // Floating Action Button untuk Tambah Berita Baru
      floatingActionButton: !_isMultiSelectionMode ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TambahBeritaBaruPage(),
            ),
          );
        },
        label: const Text('Tambah Berita'),
        icon: const Icon(Icons.add),
      ) : null,
    );
  }

  // --- Widget Pembantu untuk ActionChip Status Filter ---
  Widget _buildStatusChip(String label) {
    // ... (kode _buildStatusChip tetap)
    final isSelected = _selectedStatus == label;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onPressed: () {
        setState(() {
          _selectedStatus = label;
        });
      },
    );
  }

  // --- Widget Pembantu untuk Dropdown Category Filter ---
  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // ... (kode _buildDropdownFilter tetap)
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: Colors.grey),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        isDense: true,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}