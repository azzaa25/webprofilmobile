// lib/models/kategori_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Kategori {
  final String id;
  final String name;

  Kategori({required this.id, required this.name});

  factory Kategori.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Dokumen Kategori tidak memiliki data.');
    }
    return Kategori(
      id: doc.id,
      name: data['name'] as String? ?? 'Tidak Ada Kategori',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name};
  }
}