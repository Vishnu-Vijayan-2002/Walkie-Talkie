import 'dart:convert';
import '../app_database.dart';

class SyncQueueItem {
  final int? queueId;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String syncStatus;

  SyncQueueItem({
    this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.syncStatus = 'PENDING',
  });
}

class SyncQueueRepository {
  Future<void> enqueueDelta({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await AppDatabase.database;
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'PENDING',
    });
  }

  Future<List<SyncQueueItem>> getPendingDeltas() async {
    final db = await AppDatabase.database;
    final rows = await db.query(
      'sync_queue',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'queue_id ASC',
    );

    return rows.map((row) {
      return SyncQueueItem(
        queueId: row['queue_id'] as int?,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
        createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        syncStatus: row['sync_status'] as String,
      );
    }).toList();
  }

  Future<void> markSynced(int queueId) async {
    final db = await AppDatabase.database;
    await db.update(
      'sync_queue',
      {'sync_status': 'SYNCED'},
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
  }
}
