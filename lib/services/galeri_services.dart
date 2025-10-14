import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// Pastikan jalur impor ini benar sesuai struktur folder Anda
import '../config/supabase_config.dart'; 
import '../models/kategori_model.dart'; 
import '../models/galeri_kegiatan_model.dart'; 

class GaleriService {
  // Variabel private (diawali underscore)
  final CollectionReference _kegiatanCollection = firestore.collection('kegiatan_galeri');
  // Collection Reference untuk Kategori
  final CollectionReference _kategoriCollection = firestore.collection('kategori_galeri'); 
  final SupabaseMediaService _mediaService = SupabaseMediaService(); 

  // Getter publik untuk koleksi kegiatan
  CollectionReference get kegiatanCollection => _kegiatanCollection;
  // Getter untuk koleksi kategori
  CollectionReference get kategoriCollection => _kategoriCollection;

  // FUNGSI SLUG: Untuk mengubah string menjadi slug yang aman untuk URL/Path
  String _toSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') 
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
  
  // FUNGSI KATEGORI: TAMBAH KATEGORI (CREATE)
  Future<void> addKategori(String name) async {
    // Menambahkan dokumen baru ke koleksi kategori
    await _kategoriCollection.add({'name': name});
  }

  // --- 1. TAMBAH/UPLOAD KEGIATAN BARU (Multi-File) ---
  Future<void> addKegiatan({
    required String title,
    required String description,
    required List<File> files,
    required String categoryId, // BARU: Parameter categoryId
  }) async {
    if (files.isEmpty) {
      throw Exception('Harap pilih setidaknya satu file untuk diunggah.');
    }

    const uuid = Uuid();
    
    // BARU: Buat slug dari judul
    final folderSlug = _toSlug(title); 
    final kegiatanId = uuid.v4();
    
    // PERUBAHAN UTAMA: Gunakan slug dan ID unik sebagai nama folder
    final storageFolder = 'kegiatan/$folderSlug-$kegiatanId'; 

    List<MediaItem> uploadedMedia = [];
    String? coverUrl;

    try {
      // 1. Upload semua file ke Supabase
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final extension = p.extension(file.path);
        final fileNameWithoutExt = uuid.v4(); 
        final fullStoragePath = '$storageFolder/$fileNameWithoutExt$extension';
        
        final publicUrl = await _mediaService.uploadFile(
          file, 
          storageFolder, 
          fileNameWithoutExt
        );

        final mediaItem = MediaItem(
          url: publicUrl,
          storagePath: fullStoragePath,
          dateTaken: DateTime.now(),
        );
        uploadedMedia.add(mediaItem);

        if (i == 0) {
          coverUrl = publicUrl;
        }
      }

      // 2. Simpan Metadata Kegiatan ke Firestore
      if (coverUrl == null) throw Exception("Gagal mendapatkan URL cover.");

      final newKegiatan = KegiatanGaleri(
        id: kegiatanId,
        title: title,
        description: description,
        coverUrl: coverUrl,
        media: uploadedMedia,
        uploadedAt: Timestamp.now(),
        categoryId: categoryId, // BARU: Simpan categoryId ke model
      );

      await _kegiatanCollection.doc(kegiatanId).set(newKegiatan.toMap());
      
    } catch (e) {
      // *ROLLBACK*
      for (var item in uploadedMedia) {
        await _mediaService.deleteFile(item.storagePath);
      }
      rethrow;
    }
  }

  // --- FUNGSI BARU: AMBIL SEMUA KATEGORI (READ) ---
  Stream<List<Kategori>> getKategori() {
    return _kategoriCollection
        .orderBy('name', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Kategori.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }
  
  // --- 2. AMBIL SEMUA KEGIATAN (READ) ---
  Stream<List<KegiatanGaleri>> getKegiatan() {
    return _kegiatanCollection
        .orderBy('uploaded_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => KegiatanGaleri.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }
  
  // --- 3. EDIT KEGIATAN (UPDATE Metadata) ---
  Future<void> updateKegiatanMetadata({
    required String kegiatanId,
    required String title,
    required String description,
    String? categoryId, // Opsional untuk mengedit kategori
  }) async {
    final updateData = <String, dynamic>{
      'title': title,
      'description': description,
    };
    if (categoryId != null) {
      updateData['category_id'] = categoryId;
    }
    
    await _kegiatanCollection.doc(kegiatanId).update(updateData);
  }

  // --- 4. HAPUS KEGIATAN (DELETE Album) ---
  Future<void> deleteKegiatan(KegiatanGaleri kegiatan) async {
    final filesToDelete = kegiatan.media.map((m) => m.storagePath).toList();
    
    // Hapus semua file dari Supabase Storage
    await supabase.storage.from(_mediaService.bucketName).remove(filesToDelete);

    // Hapus dokumen dari Firestore
    await _kegiatanCollection.doc(kegiatan.id).delete();
  }
  
  // --- 5. TAMBAH MEDIA KE KEGIATAN YANG SUDAH ADA (UPDATE Media List) ---
  Future<void> addMediaToKegiatan({
    required String kegiatanId,
    required List<File> newFiles,
  }) async {
    if (newFiles.isEmpty) return;

    final docRef = _kegiatanCollection.doc(kegiatanId);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      throw Exception('Kegiatan tidak ditemukan.');
    }
    
    final currentKegiatan = KegiatanGaleri.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
    const uuid = Uuid();
    
    // PERUBAHAN: Dapatkan slug dari title kegiatan yang sudah ada
    final folderSlug = _toSlug(currentKegiatan.title);
    
    // PERUBAHAN: Rekonstruksi storageFolder menggunakan slug dan ID
    final storageFolder = 'kegiatan/$folderSlug-$kegiatanId';
    
    List<MediaItem> newlyUploadedMedia = [];

    // Upload file baru
    for (var file in newFiles) {
        final extension = p.extension(file.path);
        final fileNameWithoutExt = uuid.v4();
        final fullStoragePath = '$storageFolder/$fileNameWithoutExt$extension';

        final publicUrl = await _mediaService.uploadFile(
          file, 
          storageFolder, 
          fileNameWithoutExt
        );

        newlyUploadedMedia.add(MediaItem(
          url: publicUrl,
          storagePath: fullStoragePath,
          dateTaken: DateTime.now(),
        ));
    }

    // Gabungkan media lama dan media baru
    final updatedMediaList = currentKegiatan.media + newlyUploadedMedia;

    // Perbarui array 'media' di Firestore
    await docRef.update({
        'media': updatedMediaList.map((item) => item.toMap()).toList(),
    });
  }
  
  // --- 6. HAPUS SATU MEDIA DARI KEGIATAN (UPDATE Media List) ---
  Future<void> removeMediaFromKegiatan({
    required String kegiatanId,
    required MediaItem mediaToRemove,
  }) async {
    final docRef = _kegiatanCollection.doc(kegiatanId);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final currentKegiatan = KegiatanGaleri.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);

    // 1. Hapus file dari Supabase Storage
    await _mediaService.deleteFile(mediaToRemove.storagePath);
    
    // 2. Hapus metadata dari array 'media' di lokal
    final updatedMediaList = currentKegiatan.media
        .where((m) => m.storagePath != mediaToRemove.storagePath)
        .toList();

    // 3. Perbarui dokumen di Firestore
    await docRef.update({
        'media': updatedMediaList.map((item) => item.toMap()).toList(),
        // Perbarui coverUrl jika media yang dihapus adalah cover
        'cover_url': mediaToRemove.url == currentKegiatan.coverUrl 
            ? updatedMediaList.isNotEmpty ? updatedMediaList.first.url : null
            : currentKegiatan.coverUrl,
    });
  }
}