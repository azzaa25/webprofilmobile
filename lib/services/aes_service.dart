import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'dart:typed_data';

// Class untuk mengimplementasikan AES-256 dalam mode CBC
class AESService {
  // Ukuran kunci yang didukung oleh AES (16, 24, atau 32 bytes)
  static const List<int> validKeyLengths = [16, 24, 32];
  
  final Encrypter encrypter;
  final IV iv;

  AESService({required this.encrypter, required this.iv});

  // --- Metode Statis untuk Pembuatan Kunci dan IV ---

  // 1. Memvalidasi dan Menghasilkan Kunci (Key) dari Secret String
  static Key? generateKey(String secretKey) {
    final keyBytes = utf8.encode(secretKey);
    
    // Periksa apakah panjang kunci valid (16, 24, atau 32)
    if (validKeyLengths.contains(keyBytes.length)) {
      return Key(Uint8List.fromList(keyBytes));
    }

    // Jika panjang tidak valid, kita lakukan padding/truncation (Default ke 32)
    int targetLength = 32; 
    
    if (keyBytes.length < targetLength) {
      final padding = List<int>.filled(targetLength - keyBytes.length, 0);
      final paddedKey = [...keyBytes, ...padding];
      return Key(Uint8List.fromList(paddedKey));
    } else if (keyBytes.length > targetLength) {
      final truncatedKey = keyBytes.sublist(0, targetLength);
      return Key(Uint8List.fromList(truncatedKey));
    }
    
    return null; // Harusnya tidak tercapai
  }

  // 2. Menghasilkan Initialization Vector (IV) secara Acak
  static IV generateRandomIV() {
    final secureRandom = Random.secure();
    // IV harus 16 bytes (128 bits)
    final ivBytes = Uint8List.fromList(List<int>.generate(16, (i) => secureRandom.nextInt(256)));
    return IV(ivBytes);
  }

  // --- Metode Enkripsi/Dekripsi ---

  // Menggabungkan IV dan Ciphertext, lalu mengencode ke Base64
  String encrypt(String plainText) {
    try {
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      // Format: [IV_BASE64]:[CIPHERTEXT_BASE64]
      // Kita hanya akan mengembalikan bagian ciphertext Base64, dan menyimpan IV di Firestore secara terpisah 
      // untuk memudahkan struktur data.
      return encrypted.base64;
    } catch (e) {
      // debugPrint('Encryption Error: $e');
      return 'ENCRYPT_ERROR';
    }
  }

  // Memisahkan IV dan Ciphertext dari string Base64, lalu mendekripsi
  static String decrypt(String ciphertextBase64, String secretKey, String ivBase64) {
    try {
      final ivBytes = base64Decode(ivBase64);
      final key = generateKey(secretKey);
      
      if (key == null) throw Exception("Panjang Kunci Tidak Valid.");

      // Re-initialize service dengan key dan IV yang diekstrak
      final extractedIV = IV(Uint8List.fromList(ivBytes));
      final derivedEncrypter = Encrypter(
        AES(key, mode: AESMode.cbc, padding: 'PKCS7'),
      );

      final decrypted = derivedEncrypter.decrypt64(ciphertextBase64, iv: extractedIV);
      return decrypted;

    } catch (e) {
      // Mengembalikan pesan yang lebih spesifik jika dekripsi gagal (misalnya karena kunci salah)
      if (e.toString().contains('Invalid key') || e.toString().contains('Bad padding')) {
        return 'DECRYPT_ERROR: Kunci Rahasia Salah';
      }
      return 'DECRYPT_ERROR: Kesalahan Dekripsi Umum: ${e.toString()}';
    }
  }
}
