import 'package:flutter/material.dart';
import 'package:webprofil/services/aes_service.dart';
import 'package:encrypt/encrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For base64Encode

class MainCryptoPage extends StatefulWidget {
  const MainCryptoPage({super.key});

  @override
  State<MainCryptoPage> createState() => _MainCryptoPageState();
}

class _MainCryptoPageState extends State<MainCryptoPage> {
  final TextEditingController _plainTextController = TextEditingController();
  final TextEditingController _encryptKeyController = TextEditingController();
  final TextEditingController _decryptedTextController = TextEditingController();
  final TextEditingController _decryptKeyController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Data
  List<Map<String, dynamic>> _notes = [];
  Map<String, dynamic>? _selectedNote;
  bool _isLoading = true;
  String _statusMessage = 'Memuat catatan...';

  String get userId => _auth.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _loadAllNotes();
  }

  void _showToast(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// Load all encrypted notes from Firestore
  Future<void> _loadAllNotes() async {
    setState(() {
      _isLoading = true;
      _notes.clear();
    });

    try {
      final snapshot = await _firestore
          .collection('secure_notes')
          .doc(userId)
          .collection('notes')
          .orderBy('encrypted_at', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        _statusMessage = 'Belum ada catatan terenkripsi.';
      } else {
        _notes = snapshot.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _selectedNote = _notes.first;
        _statusMessage = 'Catatan ditemukan: ${_notes.length} data.';
      }
    } catch (e) {
      _statusMessage = 'Gagal memuat data: $e';
    }

    setState(() => _isLoading = false);
  }

  /// Encrypt text and save new note to Firestore
  Future<void> _encryptAndSave() async {
    final plainText = _plainTextController.text.trim();
    final secretKey = _encryptKeyController.text.trim();

    if (plainText.isEmpty || secretKey.isEmpty) {
      _showToast('Teks dan Secret Key wajib diisi.', isError: true);
      return;
    }

    final key = AESService.generateKey(secretKey);
    if (key == null) {
      _showToast('Secret Key harus 16, 24, atau 32 karakter.', isError: true);
      return;
    }

    final iv = AESService.generateRandomIV();
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final aesService = AESService(encrypter: encrypter, iv: iv);

    String ciphertext;
    try {
      ciphertext = aesService.encrypt(plainText);
    } catch (e) {
      _showToast('Gagal mengenkripsi data: $e', isError: true);
      return;
    }

    try {
      await _firestore
          .collection('secure_notes')
          .doc(userId)
          .collection('notes')
          .add({
        'ciphertext': ciphertext,
        'iv_base64': base64Encode(iv.bytes),
        'encrypted_at': FieldValue.serverTimestamp(),
      });

      _showToast('Catatan berhasil dienkripsi dan disimpan!');
      _plainTextController.clear();
      _encryptKeyController.clear();
      _decryptKeyController.text = secretKey;
      _loadAllNotes();
    } catch (e) {
      _showToast('Gagal menyimpan ke Firestore: $e', isError: true);
    }
  }

  /// Decrypt selected ciphertext
  void _decryptSelected() {
    if (_selectedNote == null) {
      _showToast('Pilih catatan terlebih dahulu.', isError: true);
      return;
    }

    final secretKey = _decryptKeyController.text.trim();
    if (secretKey.isEmpty) {
      _showToast('Masukkan Secret Key untuk dekripsi.', isError: true);
      return;
    }

    final ciphertext = _selectedNote!['ciphertext'];
    final ivBase64 = _selectedNote!['iv_base64'];

    try {
      final decrypted = AESService.decrypt(ciphertext, secretKey, ivBase64);
      if (decrypted.startsWith('DECRYPT_ERROR')) {
        throw Exception(decrypted.replaceAll('DECRYPT_ERROR: ', ''));
      }
      _decryptedTextController.text = decrypted;
      _showToast('Dekripsi berhasil!');
    } catch (e) {
      _decryptedTextController.clear();
      _showToast('Dekripsi gagal: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AES Secure Notes'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_auth.currentUser == null) _buildAuthWarning(),
                  _buildEncryptionCard(),
                  const SizedBox(height: 16),
                  _buildDecryptionCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildAuthWarning() {
    return Card(
      color: Colors.red.shade100,
      margin: const EdgeInsets.only(bottom: 20),
      child: const ListTile(
        leading: Icon(Icons.warning, color: Colors.red),
        title: Text('Anda belum login'),
        subtitle:
            Text('Data akan disimpan sebagai "guest". Login untuk menyimpan pribadi.'),
      ),
    );
  }

  Widget _buildEncryptionCard() {
    return Card(
      color: Colors.yellow.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ENCRYPT & SAVE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            TextField(
              controller: _plainTextController,
              decoration: const InputDecoration(
                labelText: 'Plaintext',
                border: OutlineInputBorder(),
                filled: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _encryptKeyController,
              decoration: const InputDecoration(
                labelText: 'Secret Key (16/24/32 karakter)',
                border: OutlineInputBorder(),
                filled: true,
              ),
              obscureText: true,
              maxLength: 32,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _encryptAndSave,
              icon: const Icon(Icons.lock),
              label: const Text('Encrypt & Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecryptionCard() {
    return Card(
      color: Colors.cyan.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('LOAD & DECRYPT',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text(_statusMessage),
            const SizedBox(height: 8),
            if (_notes.isNotEmpty)
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedNote,
                decoration: const InputDecoration(
                  labelText: 'Pilih Catatan',
                  border: OutlineInputBorder(),
                ),
                items: _notes
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text(
                            (n['ciphertext'] as String).length > 25
                                ? (n['ciphertext'] as String).substring(0, 25) + '...'
                                : (n['ciphertext'] as String),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedNote = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _decryptKeyController,
              decoration: const InputDecoration(
                labelText: 'Secret Key untuk Dekripsi',
                border: OutlineInputBorder(),
                filled: true,
              ),
              obscureText: true,
              maxLength: 32,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _decryptSelected,
              icon: const Icon(Icons.lock_open),
              label: const Text('Decrypt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _decryptedTextController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Hasil Dekripsi',
                border: OutlineInputBorder(),
                filled: true,
              ),
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }
}
