import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String _databaseName = 'connectx_tactical.db';
  static const int _databaseVersion = 1;

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // 1. Devices Table
    await db.execute('''
      CREATE TABLE devices (
        device_id TEXT PRIMARY KEY,
        hardware_callsign TEXT NOT NULL,
        display_name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        unit_team TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        sync_version INTEGER DEFAULT 1
      )
    ''');

    // 2. Rooms Table
    await db.execute('''
      CREATE TABLE rooms (
        room_id TEXT PRIMARY KEY,
        organization_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        visibility TEXT NOT NULL,
        creator_device_id TEXT NOT NULL,
        status TEXT NOT NULL,
        is_mesh_fallback INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'SYNCED'
      )
    ''');

    // 3. Room Members Table
    await db.execute('''
      CREATE TABLE room_members (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        is_muted INTEGER NOT NULL DEFAULT 0,
        is_speaking INTEGER NOT NULL DEFAULT 0,
        joined_at TEXT NOT NULL,
        last_active_at TEXT NOT NULL,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id) ON DELETE CASCADE
      )
    ''');

    // 4. Join Requests Table
    await db.execute('''
      CREATE TABLE join_requests (
        request_id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        callsign TEXT NOT NULL,
        status TEXT NOT NULL,
        reviewed_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id) ON DELETE CASCADE
      )
    ''');

    // 5. Raised Hands Speaking Queue Table
    await db.execute('''
      CREATE TABLE raised_hands (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        member_name TEXT NOT NULL,
        queue_position INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id) ON DELETE CASCADE
      )
    ''');

    // 6. Speaking Sessions (Transmission & Audit Ledger) Table
    await db.execute('''
      CREATE TABLE speaking_sessions (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        speaker_callsign TEXT NOT NULL,
        floor_token TEXT NOT NULL,
        transport TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_ms INTEGER DEFAULT 0,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id) ON DELETE CASCADE
      )
    ''');

    // 7. Sync Queue Table (Offline-First Delta Buffer)
    await db.execute('''
      CREATE TABLE sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT DEFAULT 'PENDING'
      )
    ''');

    // Indices for ultra-fast tactical queries
    await db.execute('CREATE INDEX idx_room_members_room ON room_members (room_id)');
    await db.execute('CREATE INDEX idx_raised_hands_room ON raised_hands (room_id, status)');
    await db.execute('CREATE INDEX idx_join_requests_room ON join_requests (room_id, status)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue (sync_status)');
  }
}
