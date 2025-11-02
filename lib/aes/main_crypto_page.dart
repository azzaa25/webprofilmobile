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
  
  // State to store encrypted data loaded from Firestore
  String? _loadedCiphertext;
  String? _loadedIvBase64;
  
  // UI State
  bool _isLoading = true;
  String _statusMessage = 'Memuat catatan terakhir...';

  // Gets the current user ID or defaults to 'guest' if not logged in
  String get userId => _auth.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _loadLastNote();
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
  
  // --- Firestore Function: Load Last Note ---
  Future<void> _loadLastNote() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Memuat catatan terakhir...';
    });

    try {
      // Data is stored per user ID
      final doc = await _firestore
          .collection('secure_notes')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _loadedCiphertext = data['ciphertext'] as String;
        _loadedIvBase64 = data['iv_base64'] as String;
        
        _statusMessage = 'Catatan terenkripsi dimuat. Siap didekripsi.';
      } else {
        _statusMessage = 'Belum ada catatan rahasia tersimpan di Firebase.';
        _loadedCiphertext = null;
        _loadedIvBase64 = null;
      }
    } catch (e) {
      _statusMessage = 'Error memuat dari Firebase: ${e.toString()}';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Encryption Logic & Save to Firestore ---
  void _encryptAndSave() async {
    final plainText = _plainTextController.text;
    final secretKey = _encryptKeyController.text;

    if (plainText.isEmpty || secretKey.isEmpty) {
      _showToast('Teks dan Kunci Rahasia wajib diisi!', isError: true);
      return;
    }

    final key = AESService.generateKey(secretKey);
    if (key == null) {
      _showToast('Kunci harus 16, 24, atau 32 karakter (byte).', isError: true);
      return;
    }

    // 1. Buat IV unik
    final iv = AESService.generateRandomIV();
    
    // 2. Initialize Encrypter & Encrypt
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final aesService = AESService(encrypter: encrypter, iv: iv);
    final ciphertext = aesService.encrypt(plainText);
    
    if (ciphertext.startsWith('ENCRYPT_ERROR')) {
      _showToast('Enkripsi Gagal.', isError: true);
      return;
    }
    
    // 3. Simpan Ciphertext dan IV ke Firestore
    try {
      await _firestore.collection('secure_notes').doc(userId).set({
        'ciphertext': ciphertext,
        'iv_base64': base64Encode(iv.bytes), // Store IV for decryption
        'encrypted_at': FieldValue.serverTimestamp(),
        'user_id': userId,
      });
      _showToast('Catatan terenkripsi berhasil disimpan ke Firestore!', isError: false);
      _loadLastNote(); // Reload the newly saved note
      // Copy Key to Decryption field for convenience
      _decryptKeyController.text = secretKey; 
    } catch (e) {
      _showToast('Gagal menyimpan ke Firestore: ${e.toString()}', isError: true);
    }
  }

  // --- Decryption Logic from Firestore ---
  void _decryptData() {
    final secretKey = _decryptKeyController.text;

    if (_loadedCiphertext == null || _loadedIvBase64 == null) {
      _showToast('Tidak ada catatan terenkripsi yang dimuat dari Firebase.', isError: true);
      return;
    }
    if (secretKey.isEmpty) {
      _showToast('Kunci Dekripsi wajib diisi!', isError: true);
      return;
    }

    // 1. Decrypt using Key and IV from Firestore
    final decryptedResult = AESService.decrypt(_loadedCiphertext!, secretKey, _loadedIvBase64!);

    if (decryptedResult.startsWith('DECRYPT_ERROR')) {
      _decryptedTextController.text = '';
      _showToast(decryptedResult.replaceAll('DECRYPT_ERROR: ', ''), isError: true);
    } else {
      _decryptedTextController.text = decryptedResult;
      _showToast('Dekripsi Berhasil!', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AES/CBC Secure Notes (Firestore)'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            if (_auth.currentUser == null)
              _buildAuthWarning(),
            
            _buildEncryptionCard(),
            const SizedBox(height: 20),
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
        leading: Icon(Icons.warning_amber, color: Colors.red),
        title: Text('Perhatian: Anda tidak login!'),
        subtitle: Text('Catatan akan disimpan menggunakan ID Tamu (guest). Login untuk menyimpan catatan pribadi.'),
      ),
    );
  }

  Widget _buildEncryptionCard() {
    return Card(
      color: Colors.yellow.shade100, // Yellow color like the module
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('ENCRYPT & SAVE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Divider(),
            TextField(
              controller: _plainTextController,
              decoration: const InputDecoration(
                labelText: 'Teks yang akan di enkripsi (Plaintext)',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _encryptKeyController,
              decoration: const InputDecoration(
                labelText: 'Secret Key (Wajib 16, 24, atau 32 karakter/byte)',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              obscureText: true, 
              maxLength: 32,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _encryptAndSave,
              icon: const Icon(Icons.save),
              label: const Text('ENCRYPT & SAVE TO FIREBASE', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecryptionCard() {
    return Card(
      color: Colors.cyan.shade100, // Cyan/light blue color like the module
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('LOAD & DECRYPT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Divider(),
            
            // Status of Encrypted Data
            Text('Status Data di Firebase:', style: TextStyle(fontWeight: FontWeight.bold)),
            _isLoading
                ? const LinearProgressIndicator()
                : Text(_statusMessage, style: TextStyle(color: _loadedCiphertext != null ? Colors.green : Colors.orange)),
            
            if (_loadedCiphertext != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SelectableText(
                  'Ciphertext Terakhir: ${_loadedCiphertext!.substring(0, 40)}...',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 2,
                ),
              ),
            
            const SizedBox(height: 12),
            TextField(
              controller: _decryptKeyController,
              decoration: const InputDecoration(
                labelText: 'Masukkan Secret Key untuk dekripsi',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              obscureText: true,
              maxLength: 32,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _decryptData,
              icon: const Icon(Icons.lock_open),
              label: const Text('DECRYPT', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _decryptedTextController,
              decoration: const InputDecoration(
                labelText: 'Teks terdekripsi (Plaintext)',
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              maxLines: 5,
              readOnly: true,
            ),
          ],
        ),
      ),
    );
  }
}
