// lib/services/admin_log_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminLogService {
  final CollectionReference logs = FirebaseFirestore.instance.collection('admin_logs');
  final String userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin';

  Future<void> logActivity(String activityDescription) async {
    try {
      await logs.add({
        'activity': activityDescription,
        'user': userEmail,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Gagal mencatat aktivitas admin: $e');
    }
  }
}