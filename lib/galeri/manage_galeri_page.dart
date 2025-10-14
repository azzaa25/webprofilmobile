// lib/galeri/manage_galeri_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/galeri_services.dart'; 
import '../models/galeri_kegiatan_model.dart'; 
import '../models/kategori_model.dart'; 
import 'package:webprofil/services/admin_log_service.dart'; // DITAMBAHKAN

class ManageGaleriPage extends StatefulWidget {
  final KegiatanGaleri? kegiatan; // Null jika mode Tambah
  
  const ManageGaleriPage({super.key, this.kegiatan});

  @override
  State<ManageGaleriPage> createState() => _ManageGaleriPageState();
}

class _ManageGaleriPageState extends State<ManageGaleriPage> {
  final GaleriService _galeriService = GaleriService();
  final AdminLogService _logService = AdminLogService(); // Instance AdminLogService
  
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<File> _selectedNewFiles = []; 
  bool _isLoading = false;
  
  String? _selectedCategoryId; 
  List<Kategori> _kategoriList = []; 

  bool get isEditing => widget.kegiatan != null;
  
  List<MediaItem> _currentMediaItems = [];
  final ImagePicker _picker = ImagePicker(); // Tambahkan picker instance

  @override
  void initState() {
    super.initState();
    _loadKategori(); 
    
    if (isEditing) {
      _titleController.text = widget.kegiatan!.title;
      _descriptionController.text = widget.kegiatan!.description;
      _currentMediaItems = List.from(widget.kegiatan!.media);
      _selectedCategoryId = widget.kegiatan!.categoryId; 
    }
  }

  void _loadKategori() {
    _galeriService.getKategori().listen((kategori) {
      if (mounted) {
        setState(() {
          _kategoriList = kategori;
          if (isEditing && _selectedCategoryId == null && _kategoriList.isNotEmpty) {
             _selectedCategoryId = widget.kegiatan!.categoryId.isNotEmpty 
                 ? widget.kegiatan!.categoryId
                 : null;
          } 
          else if (!isEditing && _selectedCategoryId == null && _kategoriList.isNotEmpty) {
             _selectedCategoryId = _kategoriList.first.id;
          }
        });
      }
    });
  }


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Fungsi untuk memilih banyak gambar dari galeri
  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedNewFiles = pickedFiles.map((xfile) => File(xfile.path)).toList();
      });
    }
  }
  
  // Fungsi untuk memproses tambah/edit
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
        _showErrorSnackBar('Harap pilih Kategori Kegiatan.');
        return;
    }
    
    if (!isEditing && _selectedNewFiles.isEmpty) {
      _showErrorSnackBar('Harap pilih setidaknya satu gambar untuk diunggah.');
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      if (isEditing) {
        // --- Mode EDIT Metadata dan Tambah File Baru ---
        await _galeriService.updateKegiatanMetadata(
          kegiatanId: widget.kegiatan!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _selectedCategoryId, 
        );
        
        // PENCATATAN LOG: EDIT Metadata
        await _logService.logActivity('Mengedit Metadata Galeri: "${_titleController.text}"');

        // Jika ada file baru yang dipilih, tambahkan ke kegiatan yang sudah ada
        if (_selectedNewFiles.isNotEmpty) {
          await _galeriService.addMediaToKegiatan(
            kegiatanId: widget.kegiatan!.id,
            newFiles: _selectedNewFiles,
          );
          
          // PENCATATAN LOG: Tambah Media
          await _logService.logActivity('Menambah ${_selectedNewFiles.length} Media ke Album: "${_titleController.text}"');
          
          // Refresh media list
          final updatedDocSnapshot = await _galeriService.kegiatanCollection
              .doc(widget.kegiatan!.id)
              .get() as DocumentSnapshot<Map<String, dynamic>>;
              
          setState(() {
            _currentMediaItems = KegiatanGaleri.fromFirestore(updatedDocSnapshot).media;
            _selectedNewFiles.clear();
          });
        }
        _showSuccessSnackBar('Kegiatan berhasil diperbarui!');
        
      } else {
        // --- Mode TAMBAH Kegiatan Baru ---
        await _galeriService.addKegiatan(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          files: _selectedNewFiles,
          categoryId: _selectedCategoryId!, 
        );
        
        // PENCATATAN LOG: CREATE Kegiatan
        await _logService.logActivity('Menambah Kegiatan Galeri Baru: "${_titleController.text}"');

        _showSuccessSnackBar('Kegiatan baru berhasil diunggah!');
      }

      // Kembali ke halaman daftar setelah berhasil
      if (mounted && (_selectedNewFiles.isEmpty || !isEditing)) {
        Navigator.of(context).pop();
      }

    } catch (e) {
      _showErrorSnackBar('Gagal memproses data: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // Fungsi untuk menghapus media dari daftar yang sudah ada
  Future<void> _confirmDeleteMedia(BuildContext context, MediaItem mediaItem) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Media'),
        content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _galeriService.removeMediaFromKegiatan(
          kegiatanId: widget.kegiatan!.id,
          mediaToRemove: mediaItem,
        );
        
        // PENCATATAN LOG: Hapus Media
        await _logService.logActivity('Menghapus Media dari Album: "${widget.kegiatan!.title}"');

        setState(() {
          _currentMediaItems.removeWhere((m) => m.storagePath == mediaItem.storagePath);
        });
        _showSuccessSnackBar('Foto berhasil dihapus!');
      } catch (e) {
        _showErrorSnackBar('Gagal menghapus foto: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }


  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // BARU: Widget Dropdown untuk memilih Kategori
  Widget _buildCategoryDropdown() {
    if (_kategoriList.isEmpty) {
        return const Center(child: Text('Memuat kategori... (Pastikan ada data di Firestore)'));
    }
    
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Kategori Kegiatan',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      value: _selectedCategoryId,
      isExpanded: true,
      hint: const Text('Pilih Kategori'),
      items: _kategoriList.map((kategori) {
        return DropdownMenuItem(
          value: kategori.id,
          child: Text(kategori.name),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedCategoryId = newValue;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Kategori wajib dipilih';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Kegiatan: ${widget.kegiatan!.title}' : 'Tambah Kegiatan Baru'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Dropdown Kategori ---
              _buildCategoryDropdown(), 
              const SizedBox(height: 16),
              
              // --- Input Judul ---
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Judul Kegiatan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Judul tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // --- Input Deskripsi ---
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Kegiatan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              // --- Pemilih Gambar (Multi-File) ---
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text(
                  _selectedNewFiles.isEmpty 
                    ? (isEditing ? 'Tambah Foto Baru' : 'Pilih Foto Kegiatan')
                    : '${_selectedNewFiles.length} Foto Baru Dipilih',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              
              // Tampilan preview file yang baru dipilih
              if (_selectedNewFiles.isNotEmpty)
                Text(
                  '${_selectedNewFiles.length} file dipilih. File pertama akan menjadi cover jika ini kegiatan baru.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              
              const SizedBox(height: 30),

              // --- Tombol Submit ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isEditing ? 'Simpan Perubahan' : 'Unggah Kegiatan',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
              
              // Menampilkan media yang sudah ada (hanya di mode edit)
              if (isEditing && _currentMediaItems.isNotEmpty) ...[
                const Divider(height: 40),
                Text(
                  'Media Sudah Ada (${_currentMediaItems.length} file):', 
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 15),
                _buildExistingMediaGrid(context),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // Grid untuk menampilkan media yang sudah ada
  Widget _buildExistingMediaGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currentMediaItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final mediaItem = _currentMediaItems[index];
        return GridTile(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(mediaItem.url, fit: BoxFit.cover),
              ),
              // Tombol Hapus per Media
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: _isLoading ? null : () => _confirmDeleteMedia(context, mediaItem),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}