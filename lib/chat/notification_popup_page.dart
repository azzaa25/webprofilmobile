import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationPopupPage extends StatelessWidget {
  final RemoteMessage message;

  const NotificationPopupPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // Ambil data dari FCM
    final String title = message.notification?.title ?? 'Notifikasi';
    final String body = message.notification?.body ?? 'Tidak ada konten';

    // Tampilkan pop-up setelah halaman dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    });

    // Halaman kosong / background
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
      ),
      body: const Center(
        child: Text('Isi notifikasi muncul di pop-up.'),
      ),
    );
  }
}
