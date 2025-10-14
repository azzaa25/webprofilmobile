// lib/berita/tambah_berita_baru_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:webprofil/services/admin_log_service.dart'; // DITAMBAHKAN

class TambahBeritaBaruPage extends StatefulWidget {
  const TambahBeritaBaruPage({super.key});

  @override
  State<TambahBeritaBaruPage> createState() => _TambahBeritaBaruPageState();
}

class _TambahBeritaBaruPageState extends State<TambahBeritaBaruPage> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _isiController = TextEditingController();
  String _selectedKategori = 'Kegiatan Warga';
  bool _isLoading = false;

  XFile? _imageFile;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _kategoriList = ['Kegiatan Warga', 'Pengumuman', 'Lainnya'];
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  // Instance AdminLogService DITAMBAHKAN
  final AdminLogService _logService = AdminLogService();

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

  // --- Fungsi Upload Gambar ke Supabase (Sama) ---
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
        SnackBar(content: Text('Gagal upload gambar: ${e.message}')),
      );
      return null;
    } catch (e) {
      print('Error during image upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat upload gambar: $e')),
      );
      return null;
    }
  }

  // --- Fungsi Upload Berita (Sama) ---
  Future<void> _uploadBerita() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImageToSupabase();
        if (imageUrl == null) { // Hentikan jika upload gambar gagal
          setState(() { _isLoading = false; });
          return; 
        }
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
        await FirebaseFirestore.instance.collection('berita').add({
          'judul': _judulController.text,
          'isi': _isiController.text,
          'kategori': _selectedKategori,
          'imageUrl': imageUrl ?? '',
          'tanggal': Timestamp.fromDate(finalDateTime),
          'penulis': 'Admin',
        });

        // === PENCATATAN LOG (CREATE) ===
        await _logService.logActivity('Menambah Berita Baru: "${_judulController.text}"');
        // ===============================

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berita berhasil ditambahkan!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan berita: $e')),
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
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Berita Baru'),
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
                      title: const Text('Pilih Gambar (Opsional)'),
                      trailing: _imageFile == null
                          ? const Icon(Icons.add_a_photo)
                          : Image.file(File(_imageFile!.path), width: 50, height: 50, fit: BoxFit.cover),
                      onTap: () => _showImageSourceActionSheet(context), // Menggunakan action sheet
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    if (_imageFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton(
                          onPressed: () => setState(() { _imageFile = null; }),
                          child: const Text('Hapus Gambar'),
                        ),
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
                      onPressed: _uploadBerita,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Simpan Berita'),
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