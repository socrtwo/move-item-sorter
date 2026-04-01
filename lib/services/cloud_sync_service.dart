import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/item.dart';

/// Interface for cloud sync. Currently implemented as a local JSON backup.
/// Replace with Firebase Firestore/Storage calls when Firebase is configured.
///
/// To enable Firebase:
/// 1. Add `firebase_core`, `cloud_firestore`, `firebase_storage` to pubspec.yaml
/// 2. Run `flutterfire configure` to generate firebase_options.dart
/// 3. Replace the stub methods below with Firestore read/write calls.
abstract class CloudSyncService {
  Future<bool> uploadItems(List<Item> items);
  Future<List<Item>?> downloadItems();
  Future<bool> isAvailable();
}

/// Local-file backup implementation (no network required).
/// Stores data as JSON in the app documents directory.
class LocalBackupSyncService implements CloudSyncService {
  static const _backupFilename = 'inventory_backup.json';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> uploadItems(List<Item> items) async {
    try {
      final file = await _backupFile();
      final json = jsonEncode({
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
      });
      await file.writeAsString(json);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Item>?> downloadItems() async {
    try {
      final file = await _backupFile();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final list = json['items'] as List;
      return list.map((e) => Item.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _backupFilename));
  }
}

/// Firebase stub — replace body with real Firestore calls.
class FirebaseSyncService implements CloudSyncService {
  @override
  Future<bool> isAvailable() async => false; // flip to true after configuring Firebase

  @override
  Future<bool> uploadItems(List<Item> items) async {
    // TODO: implement Firestore batch write
    // final db = FirebaseFirestore.instance;
    // final batch = db.batch();
    // for (final item in items) {
    //   batch.set(db.collection('inventories').doc(userEmail).collection('items').doc(item.id),
    //       item.toMap());
    // }
    // await batch.commit();
    throw UnimplementedError('Configure Firebase first — see cloud_sync_service.dart');
  }

  @override
  Future<List<Item>?> downloadItems() async {
    // TODO: implement Firestore read
    throw UnimplementedError('Configure Firebase first — see cloud_sync_service.dart');
  }
}
