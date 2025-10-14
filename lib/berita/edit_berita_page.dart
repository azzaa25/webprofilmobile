// lib/berita/edit_berita_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:webprofil/services/admin_log_service.dart'; // DITAMBAHKAN

class EditBeritaPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> initialData;

  const EditBeritaPage({
    super.key,
    required this.documentId,
    required this.initialData,
  });

  @override
  State<EditBeritaPage> createState() => _EditBeritaPageState();
}

class _EditBeritaPageState extends State<EditBeritaPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulController;
  late final TextEditingController _isiController;
  late String _selectedKategori;
  bool _isLoading = false;

  XFile? _imageFile;
  String? _currentImageUrl;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  final List<String> _kategoriList = ['Kegiatan Warga', 'Pengumuman', 'Lainnya'];
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  // Instance AdminLogService DITAMBAHKAN
  final AdminLogService _logService = AdminLogService();

  @override
  void initState() {
    super.initState();
    _judulController = TextEditingController(text: widget.initialData['judul'] ?? '');
    _isiController = TextEditingController(text: widget.initialData['isi'] ?? '');
    _selectedKategori = widget.initialData['kategori'] ?? 'Kegiatan Warga';
    _currentImageUrl = widget.initialData['imageUrl'];

    final Timestamp? timestamp = widget.initialData['tanggal'] as Timestamp?;
    final DateTime initialDateTime = timestamp?.toDate() ?? DateTime.now();
    _selectedDate = initialDateTime;
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  // --- Fungsi Image Picker DENGAN Pilihan Sumber ---
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  // --- Fungsi Menampilkan Pilihan Sumber Gambar ---
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi Date and Time Picker (Sama) ---
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  // --- Fungsi Hapus Gambar dari Supabase (Sama) ---
  Future<void> _deleteOldImage(String? imageUrl) async {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final fullPath = pathSegments.sublist(pathSegments.indexOf('MediaSukorame') + 1).join('/');
        await _supabase.storage.from('MediaSukorame').remove([fullPath]);
      } catch (e) {
        print('Gagal menghapus gambar lama dari Supabase: $e');
      }
    }
  }

  // --- Fungsi Upload Gambar ke Supabase (Sama, path disederhanakan) ---
  Future<String?> _uploadImageToSupabase() async {
    if (_imageFile == null) return null;

    final File file = File(_imageFile!.path);
    final fileExtension = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}';
    final storagePath = 'berita/$fileName$fileExtension';

    try {
      final response = await _supabase.storage.from('MediaSukorame').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: 'image/jpeg',
        ),
      );

      if (response.isNotEmpty) {
        final publicUrl = _supabase.storage.from('MediaSukorame').getPublicUrl(storagePath);
        return publicUrl;
      }
      return null;
    } on StorageException catch (e) {
      print('Supabase Storage Error: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload gambar baru: ${e.message}')),
      );
      return null;
    } catch (e) {
      print('Error during image upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat upload gambar baru: $e')),
      );
      return null;
    }
  }

  // --- Fungsi Update Berita (Sama) ---
  Future<void> _updateBerita() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String? newImageUrl = _currentImageUrl;

      // 1. Handle Gambar Baru (Upload baru dan hapus lama jika ada)
      if (_imageFile != null) {
        if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
          await _deleteOldImage(_currentImageUrl);
        }
        
        newImageUrl = await _uploadImageToSupabase();
        if (newImageUrl == null) {
          setState(() { _isLoading = false; });
          return; 
        }
      } else if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
        // Kasus: Gambar lama dihapus / memang tidak ada gambar
        newImageUrl = '';
      }

      // Gabungkan tanggal dan waktu
      final DateTime finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      try {
        final Map<String, dynamic> beritaData = {
          'judul': _judulController.text,
          'isi': _isiController.text,
          'kategori': _selectedKategori,
          'imageUrl': newImageUrl ?? '',
          'tanggal': Timestamp.fromDate(finalDateTime),
          'penulis': 'Admin',
        };

        // Perbarui data di Firestore
        await FirebaseFirestore.instance
            .collection('berita')
            .doc(widget.documentId)
            .update(beritaData);

        // === PENCATATAN LOG (UPDATE) ===
        await _logService.logActivity('Mengedit Berita: "${_judulController.text}"');
        // ===============================

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berita berhasil diperbarui!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui berita: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Berita'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _judulController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Berita',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Judul tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _isiController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Isi Berita Lengkap',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Isi berita tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedKategori,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: _kategoriList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedKategori = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // --- Image Picker Widget dengan Pilihan Sumber ---
                    ListTile(
                      title: const Text('Ganti Gambar (Opsional)'),
                      subtitle: (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) && _imageFile == null
                          ? const Text('Gambar saat ini terlampir')
                          : null,
                      trailing: _imageFile != null
                          ? Image.file(File(_imageFile!.path), width: 50, height: 50, fit: BoxFit.cover)
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                              ? Image.network(_currentImageUrl!, width: 50, height: 50, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image))
                              : const Icon(Icons.add_a_photo),
                      onTap: () => _showImageSourceActionSheet(context), // Menggunakan action sheet
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_imageFile != null)
                          TextButton(
                            onPressed: () => setState(() { 
                              _imageFile = null; 
                              // Jika ada URL gambar lama, kembalikan tampilannya
                              _currentImageUrl = widget.initialData['imageUrl'];
                            }),
                            child: const Text('Batalkan Gambar Baru'),
                          ),
                        if ((_currentImageUrl != null && _currentImageUrl!.isNotEmpty) || _imageFile != null)
                          TextButton(
                            onPressed: () => setState(() { 
                              _currentImageUrl = ''; 
                              _imageFile = null; // Pastikan gambar baru juga dibatalkan/dihapus
                            }),
                            child: const Text('Hapus Gambar'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // --- Date and Time Picker Widget ---
                    InkWell(
                      onTap: () => _selectDateTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal & Waktu Publikasi',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} ${_selectedTime.format(context)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updateBerita,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Update Berita'),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.close),
      ),
    );
  }
}