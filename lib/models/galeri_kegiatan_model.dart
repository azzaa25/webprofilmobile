import 'package:cloud_firestore/cloud_firestore.dart';

// --- Model untuk Setiap Media (File) ---
class MediaItem {
  final String url; // URL Publik dari Supabase Storage
  final String storagePath; // Path di Supabase Storage
  final DateTime dateTaken; // Tanggal media diambil
  
  MediaItem({
    required this.url,
    required this.storagePath,
    required this.dateTaken,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'storage_path': storagePath,
      'date_taken': Timestamp.fromDate(dateTaken),
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    final Timestamp dateTakenTimestamp = map['date_taken'] as Timestamp;
    return MediaItem(
      url: map['url'] as String,
      storagePath: map['storage_path'] as String,
      dateTaken: dateTakenTimestamp.toDate(),
    );
  }
}

// --- Model untuk Kegiatan/Album Galeri (Cover) ---
class KegiatanGaleri {
  final String id; // ID Dokumen Firestore
  final String title; // Judul Kegiatan (misal: 'Kegiatan Agustus')
  final String description;
  final String coverUrl; // URL cover (URL media pertama)
  final List<MediaItem> media; // Daftar semua foto/video dalam kegiatan
  final Timestamp uploadedAt;
  final String categoryId; // BARU: ID Dokumen Kategori untuk relasi

  KegiatanGaleri({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.media,
    required this.uploadedAt,
    required this.categoryId, // BARU
  });

  // Digunakan saat membuat dokumen baru di Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'cover_url': coverUrl,
      'media': media.map((item) => item.toMap()).toList(),
      'uploaded_at': uploadedAt,
      'category_id': categoryId, // BARU
    };
  }

  // Digunakan saat membaca dokumen dari Firestore
  factory KegiatanGaleri.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw StateError('Dokumen Firestore dengan ID ${doc.id} tidak memiliki data.');
    }

    final uploadedAtTimestamp = data['uploaded_at'] as Timestamp?;
    final mediaListRaw = data['media'] as List<dynamic>?;

    final List<MediaItem> mediaItems = mediaListRaw != null
        ? mediaListRaw
            .map((itemMap) => MediaItem.fromMap(itemMap as Map<String, dynamic>))
            .toList()
        : [];

    return KegiatanGaleri(
      id: doc.id,
      title: data['title'] as String? ?? 'Tidak Ada Judul',
      description: data['description'] as String? ?? '',
      coverUrl: data['cover_url'] as String? ?? '',
      media: mediaItems,
      uploadedAt: uploadedAtTimestamp ?? Timestamp.now(),
      categoryId: data['category_id'] as String? ?? '', // BARU: Default ke string kosong jika tidak ada
    );
  }
}