import 'package:flutter/material.dart';
import '../services/galeri_services.dart'; 
import '../models/kategori_model.dart'; 
import 'package:webprofil/services/admin_log_service.dart'; // DITAMBAHKAN

class ManageKategoriPage extends StatefulWidget {
  const ManageKategoriPage({super.key});

  @override
  State<ManageKategoriPage> createState() => _ManageKategoriPageState();
}

class _ManageKategoriPageState extends State<ManageKategoriPage> {
  final GaleriService _galeriService = GaleriService();
  // Instance AdminLogService
  final AdminLogService _logService = AdminLogService();
  
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- Fungsi Tambah Kategori (CREATE) ---
  Future<void> _addKategori() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      final name = _nameController.text.trim();
      await _galeriService.addKategori(name); // Memanggil fungsi di GaleriService

      // === PENCATATAN LOG (CREATE) ===
      await _logService.logActivity('Menambah Kategori Galeri: "$name"');
      // ==============================

      _showSnackBar('Kategori "$name" berhasil ditambahkan!', Colors.green);
      _nameController.clear();
    } catch (e) {
      _showSnackBar('Gagal menambah kategori: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Fungsi Hapus Kategori (DELETE) ---
  Future<void> _deleteKategori(String kategoriId, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "$name"?'),
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
      try {
        // Hapus kategori dari Firestore
        await _galeriService.kategoriCollection.doc(kategoriId).delete();
        
        // === PENCATATAN LOG (DELETE) ===
        await _logService.logActivity('Menghapus Kategori Galeri: "$name" (ID: $kategoriId)');
        // ==============================

        _showSnackBar('Kategori "$name" berhasil dihapus!', Colors.green);
      } catch (e) {
        _showSnackBar('Gagal menghapus: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori Galeri'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- FORM TAMBAH KATEGORI ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Kategori Baru',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama kategori tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _isLoading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: CircularProgressIndicator()))
                      : ElevatedButton(
                          onPressed: _addKategori,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.add),
                        ),
                ],
              ),
            ),
          ),
          const Divider(),

          // --- DAFTAR KATEGORI ---
          Expanded(
            child: StreamBuilder<List<Kategori>>(
              stream: _galeriService.getKategori(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final kategoriList = snapshot.data ?? [];
                
                if (kategoriList.isEmpty) {
                  return const Center(child: Text('Belum ada kategori. Tambahkan satu di atas!'));
                }

                return ListView.builder(
                  itemCount: kategoriList.length,
                  itemBuilder: (context, index) {
                    final kategori = kategoriList[index];
                    return ListTile(
                      title: Text(kategori.name),
                      subtitle: Text('ID: ${kategori.id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteKategori(kategori.id, kategori.name),
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
}