import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/participant_models.dart';
import '../models/monitor_models.dart';
import '../models/supervisor_models.dart';
import '../models/violator_models.dart';
import '../models/notification_message.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'dim_buraxilish.db';
  static const int _databaseVersion = 9;

  // Table names
  static const String _participantsTable = 'participants';
  static const String _registeredParticipantsTable = 'registered_participants';
  static const String _registeredMonitorsTable = 'registered_monitors';
  static const String _allMonitorsTable = 'all_monitors';
  static const String _supervisorsTable = 'supervisors';
  static const String _registeredSupervisorsTable = 'registered_supervisors';
  static const String _participantViolationsTable = 'participant_violations';
  static const String _notificationsTable = 'emergency_notifications';

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    // Read the pre-9.2 active slot BEFORE opening the DB, so the v8->v9
    // upgrade (below) can backfill it onto migrated offline-queue rows that
    // never carried a slot/session id of their own. Safe/cheap even when no
    // upgrade will run (fresh install, or already on v9+).
    _pendingV8SlotKey = await _readSlotKeyForMigration();
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// `exam_details.slotKey` as it was stored by a pre-9.2 app, read once
  /// before `openDatabase()` so `_onUpgrade`'s v9 migration can stamp it onto
  /// migrated sync-queue rows. See the migration note on `_onUpgrade` below.
  static String? _pendingV8SlotKey;

  static Future<String?> _readSlotKeyForMigration() async {
    try {
      const storage = FlutterSecureStorage();
      final raw = await storage.read(key: 'exam_details');
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final slotKey = map['slotKey'];
      return (slotKey is String && slotKey.isNotEmpty) ? slotKey : null;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DDL — kept as getters in one place so _onCreate and _onUpgrade never
  // drift apart (established convention since the v8 migration).
  // ──────────────────────────────────────────────────────────────────────────

  /// Offline-downloaded participants (full re-download every time — see
  /// OfflineDatabaseProvider). Server `id`/`exam_session_id` replace the old
  /// legacy exam-date-string / `imt_Begin` / `ad_Bina` / `s_Nomer` plumbing
  /// (contract §1.2). `card_number` stays unique for QR-scan lookups.
  static String get _participantsTableDdl => '''
      CREATE TABLE $_participantsTable (
        id INTEGER PRIMARY KEY,
        card_number INTEGER UNIQUE,
        exam_session_id INTEGER,
        last_name TEXT,
        first_name TEXT,
        father_name TEXT,
        gender INTEGER,
        building_code TEXT,
        hall TEXT,
        floor TEXT,
        row TEXT,
        seat TEXT,
        photo BLOB,
        registered_at TEXT
      )
    ''';

  /// Sync queue (+ local statistics cache) for offline participant scans.
  /// `id` is the server `Participants.Id` once known (new 9.2 scans always
  /// have it, since the master table is downloaded with it); `slot_key` is
  /// only ever set for a v8 row migrated to v9 (see `_onUpgrade`) — the
  /// fallback sync branch matches those by `card_number`+`building_code`+
  /// `slot_key` (contract §1.3).
  static String get _registeredParticipantsTableDdl => '''
      CREATE TABLE $_registeredParticipantsTable (
        card_number INTEGER PRIMARY KEY,
        id INTEGER,
        slot_key TEXT,
        last_name TEXT,
        first_name TEXT,
        father_name TEXT,
        building_code TEXT,
        registered_at TEXT,
        online INTEGER DEFAULT 0,
        gender INTEGER,
        photo TEXT,
        hall TEXT,
        floor TEXT,
        row TEXT,
        seat TEXT
      )
    ''';

  /// Registered-monitor cache (monitors have no offline sync queue — scanning
  /// is always online, see mobile_inventory.md §2 — this is a local display
  /// cache only). `examDate` is kept as a display value (session time), never
  /// used as a lookup key (contract-adjacent decision, mobile spec §5).
  static String get _registeredMonitorsTableDdl => '''
      CREATE TABLE $_registeredMonitorsTable (
        workNumber INTEGER PRIMARY KEY,
        id INTEGER,
        exam_session_id INTEGER,
        firstName TEXT,
        lastName TEXT,
        middleName TEXT,
        idCardPin TEXT,
        buildingCode INTEGER,
        buildingName TEXT,
        roomId INTEGER,
        roomName TEXT,
        examDate TEXT,
        registerDate TEXT,
        image TEXT,
        online INTEGER DEFAULT 0
      )
    ''';

  /// Offline-downloaded supervisors. `examDate` kept as a display value only.
  static String get _supervisorsTableDdl => '''
      CREATE TABLE $_supervisorsTable (
        cardNumber TEXT PRIMARY KEY,
        id INTEGER,
        exam_session_id INTEGER,
        lastName TEXT,
        firstName TEXT,
        fatherName TEXT,
        buildingCode INTEGER,
        buildingName TEXT,
        districtCode INTEGER,
        examDate TEXT,
        image TEXT,
        pinCode TEXT,
        registerDate TEXT,
        supervisorAction INTEGER
      )
    ''';

  /// All-monitors offline download (admin). `examDate` kept as display value.
  static String get _allMonitorsTableDdl => '''
      CREATE TABLE $_allMonitorsTable (
        workNumber INTEGER PRIMARY KEY,
        id INTEGER,
        exam_session_id INTEGER,
        firstName TEXT,
        lastName TEXT,
        middleName TEXT,
        idCardPin TEXT,
        buildingCode INTEGER,
        buildingName TEXT,
        roomId INTEGER,
        roomName TEXT,
        examDate TEXT,
        registerDate TEXT,
        image TEXT,
        phone TEXT
      )
    ''';

  /// Sync queue for offline supervisor scans — see
  /// `_registeredParticipantsTableDdl` for the `id`/`slot_key` contract.
  static String get _registeredSupervisorsTableDdl => '''
      CREATE TABLE $_registeredSupervisorsTable (
        cardNumber TEXT PRIMARY KEY,
        id INTEGER,
        slot_key TEXT,
        lastName TEXT,
        firstName TEXT,
        fatherName TEXT,
        buildingCode INTEGER,
        buildingName TEXT,
        districtCode INTEGER,
        examDate TEXT,
        image TEXT,
        pinCode TEXT,
        registerDate TEXT,
        supervisorAction INTEGER,
        online INTEGER DEFAULT 0
      )
    ''';

  // Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(_participantsTableDdl);
    await db.execute(_registeredParticipantsTableDdl);
    await db.execute(_registeredMonitorsTableDdl);
    await db.execute(_supervisorsTableDdl);
    await db.execute(_allMonitorsTableDdl);
    await db.execute(_registeredSupervisorsTableDdl);

    await db.execute('''
      CREATE TABLE $_participantViolationsTable (
        is_N INTEGER PRIMARY KEY,
        altKatName TEXT,
        katName TEXT,
        qeyd TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $_notificationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id INTEGER UNIQUE,
        title TEXT,
        body TEXT,
        importance INTEGER DEFAULT 0,
        received_at TEXT,
        is_read INTEGER DEFAULT 0,
        read_at TEXT,
        building_code TEXT
      )
    ''');
  }

  // Handle database upgrades
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_registeredMonitorsTable (
          workNumber INTEGER PRIMARY KEY,
          firstName TEXT,
          lastName TEXT,
          middleName TEXT,
          idCardPin TEXT,
          buildingCode INTEGER,
          buildingName TEXT,
          roomId INTEGER,
          roomName TEXT,
          examDate TEXT,
          registerDate TEXT,
          image TEXT,
          online INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_allMonitorsTable (
          workNumber INTEGER PRIMARY KEY,
          firstName TEXT,
          lastName TEXT,
          middleName TEXT,
          idCardPin TEXT,
          buildingCode INTEGER,
          buildingName TEXT,
          roomId INTEGER,
          roomName TEXT,
          examDate TEXT,
          registerDate TEXT,
          image TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_participantViolationsTable (
          is_N INTEGER PRIMARY KEY,
          altKatName TEXT,
          katName TEXT,
          qeyd TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $_allMonitorsTable ADD COLUMN phone TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_notificationsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id INTEGER UNIQUE,
          title TEXT,
          body TEXT,
          importance INTEGER DEFAULT 0,
          received_at TEXT,
          is_read INTEGER DEFAULT 0,
          read_at TEXT,
          building_code TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      // Add read_at column if table already existed from v6
      try {
        await db.execute(
            'ALTER TABLE $_notificationsTable ADD COLUMN read_at TEXT');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // photo TEXT (base64) -> photo BLOB. The participants table is fully
      // repopulated on every offline download, so dropping it here loses
      // nothing — SQLite can't ALTER a column's type in place.
      await db.execute('DROP TABLE IF EXISTS $_participantsTable');
      await db.execute('''
        CREATE TABLE $_participantsTable (
          external_id INTEGER PRIMARY KEY,
          is_N INTEGER UNIQUE,
          soy TEXT,
          adi TEXT,
          baba TEXT,
          tev TEXT,
          gins INTEGER,
          sv_Seriya TEXT,
          s_Ves TEXT,
          bina TEXT,
          zal TEXT,
          mertebe TEXT,
          sira TEXT,
          yer TEXT,
          imt_Tarix TEXT,
          imt_Begin TEXT,
          photo BLOB,
          ad_Bina TEXT,
          qeydiyyat TEXT,
          s_Nomer INTEGER
        )
      ''');
    }
    if (oldVersion < 9) {
      // Full switch to server id + exam_session_id (contract §1.2/§1.3):
      // downloaded "master" tables (participants/supervisors/all_monitors/
      // registered_monitors) are always fully repopulated on the next
      // download, so they're safe to drop + recreate outright — same
      // precedent as v8. The offline sync QUEUE tables
      // (registered_participants/registered_supervisors) must never lose
      // rows: their v8 contents are read out, the table is recreated with
      // the new (id, slot_key) columns, then the old rows are re-inserted
      // with id=NULL and slot_key backfilled from the pre-9.2
      // `exam_details.slotKey` (read in `_initDatabase`, before the DB was
      // even opened). Those rows sync via the is_N/cardNumber+bina/
      // buildingCode+slotKey fallback branch (contract §1.3) the first time
      // SyncService runs after upgrade. Everything below runs in one
      // transaction so a crash mid-migration can't half-drop the queue.
      final fallbackSlotKey = _pendingV8SlotKey;

      await db.transaction((txn) async {
        // Preserve the v8 queues before touching anything.
        final oldQueuedParticipants =
            await txn.query(_registeredParticipantsTable);
        final oldQueuedSupervisors =
            await txn.query(_registeredSupervisorsTable);

        // Master/download-only tables: drop + recreate.
        await txn.execute('DROP TABLE IF EXISTS $_participantsTable');
        await txn.execute(_participantsTableDdl);

        await txn.execute('DROP TABLE IF EXISTS $_supervisorsTable');
        await txn.execute(_supervisorsTableDdl);

        await txn.execute('DROP TABLE IF EXISTS $_allMonitorsTable');
        await txn.execute(_allMonitorsTableDdl);

        await txn.execute('DROP TABLE IF EXISTS $_registeredMonitorsTable');
        await txn.execute(_registeredMonitorsTableDdl);

        // Queue tables: drop + recreate, then copy the v8 rows back in.
        await txn
            .execute('DROP TABLE IF EXISTS $_registeredParticipantsTable');
        await txn.execute(_registeredParticipantsTableDdl);
        // Read side uses the OLD v8 column names (is_N, soy, adi, baba, bina,
        // qeydiyyat, gins, zal, mertebe, sira, yer) — `row` here is a raw map
        // queried from the table before it was dropped/recreated above, so it
        // still has the pre-9.2 schema. Write side uses the NEW v9 names.
        for (final row in oldQueuedParticipants) {
          await txn.insert(
            _registeredParticipantsTable,
            {
              'card_number': row['is_N'],
              'id': null,
              'slot_key': fallbackSlotKey,
              'last_name': row['soy'],
              'first_name': row['adi'],
              'father_name': row['baba'],
              'building_code': row['bina'],
              'registered_at': row['qeydiyyat'],
              'online': row['online'] ?? 0,
              'gender': row['gins'],
              'photo': row['photo'],
              'hall': row['zal'],
              'floor': row['mertebe'],
              'row': row['sira'],
              'seat': row['yer'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn
            .execute('DROP TABLE IF EXISTS $_registeredSupervisorsTable');
        await txn.execute(_registeredSupervisorsTableDdl);
        for (final row in oldQueuedSupervisors) {
          await txn.insert(
            _registeredSupervisorsTable,
            {
              'cardNumber': row['cardNumber'],
              'id': null,
              'slot_key': fallbackSlotKey,
              'lastName': row['lastName'],
              'firstName': row['firstName'],
              'fatherName': row['fatherName'],
              'buildingCode': row['buildingCode'],
              'buildingName': row['buildingName'],
              'districtCode': row['districtCode'],
              'examDate': row['examDate'],
              'image': row['image'],
              'pinCode': row['pinCode'],
              'registerDate': row['registerDate'],
              'supervisorAction': row['supervisorAction'],
              'online': row['online'] ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    }
  }

  // PARTICIPANTS METHODS

  /// Save participants to offline storage
  static Future<void> saveParticipants(List<Participant> participants) async {
    final db = await database;
    final batch = db.batch();

    for (final participant in participants) {
      batch.insert(
        _participantsTable,
        _participantToMap(participant),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  /// Get participant from offline storage by work number
  static Future<Participant?> getParticipantByWorkNumber(int workNumber) async {
    final db = await database;
    final results = await db.query(
      _participantsTable,
      where: 'card_number = ?',
      whereArgs: [workNumber],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return _participantFromMap(results.first);
    }
    return null;
  }

  /// Register participant (save to registered table and update offline table)
  static Future<void> registerParticipant(
      Participant participant, String registrationDate) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        _participantsTable,
        {'registered_at': registrationDate},
        where: 'card_number = ?',
        whereArgs: [participant.cardNumber],
      );

      await txn.insert(
        _registeredParticipantsTable,
        {
          'card_number': participant.cardNumber,
          // New (9.2) scans always know the server id from the download —
          // no slot_key fallback needed for these rows (contract §1.3).
          'id': participant.id,
          'slot_key': null,
          'last_name': participant.lastName,
          'first_name': participant.firstName,
          'father_name': participant.fatherName,
          'building_code': participant.buildingCode,
          'registered_at': registrationDate,
          'online': 0,
          'gender': participant.gender,
          'photo': participant.photoBase64,
          'hall': participant.hall,
          'floor': participant.floor,
          'row': participant.row,
          'seat': participant.seat,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Get all registered participants
  static Future<List<Participant>> getRegisteredParticipants(
      {bool onlineOnly = false}) async {
    final db = await database;
    String whereClause = '';

    if (onlineOnly) {
      whereClause = 'WHERE online = 1';
    }

    final results = await db.rawQuery('''
      SELECT card_number, id, slot_key, last_name, first_name, father_name, gender, building_code, hall, floor, row, seat, photo, registered_at, online
      FROM $_registeredParticipantsTable $whereClause
      ORDER BY registered_at DESC
    ''');

    return results.map((map) => _registeredParticipantFromMap(map)).toList();
  }

  /// Get offline registered participants (not synced)
  static Future<List<Participant>> getOfflineRegisteredParticipants() async {
    return getRegisteredParticipants(onlineOnly: false);
  }

  /// Delete all participants
  static Future<void> deleteAllParticipants() async {
    final db = await database;
    await db.delete(_participantsTable);
    await db.delete(_registeredParticipantsTable);
  }

  // MONITORS METHODS

  /// Register monitor in local database for instant local statistics
  static Future<void> registerMonitor(
      Monitor monitor, String registrationDate) async {
    final db = await database;

    await db.insert(
      _registeredMonitorsTable,
      {
        'workNumber': monitor.workNumber,
        'id': monitor.id,
        'exam_session_id': monitor.examSessionId,
        'firstName': monitor.firstName,
        'lastName': monitor.lastName,
        'middleName': monitor.middleName,
        'idCardPin': monitor.idCardPin,
        'buildingCode': monitor.buildingCode,
        'buildingName': monitor.buildingName,
        'roomId': monitor.roomId,
        'roomName': monitor.roomName,
        'examDate': monitor.examDate,
        'registerDate': registrationDate,
        'image': monitor.image,
        'online': monitor.online == true ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove monitor from local registered table (after cancellation)
  static Future<void> unregisterMonitor(int workNumber) async {
    final db = await database;
    await db.delete(
      _registeredMonitorsTable,
      where: 'workNumber = ?',
      whereArgs: [workNumber],
    );
  }

  /// Remove participant from local registered table and clear registered_at (after cancellation)
  static Future<void> unregisterParticipant(int cardNumber) async {
    final db = await database;
    await db.delete(
      _registeredParticipantsTable,
      where: 'card_number = ?',
      whereArgs: [cardNumber],
    );
    await db.update(
      _participantsTable,
      {'registered_at': null},
      where: 'card_number = ?',
      whereArgs: [cardNumber],
    );
  }

  /// Remove supervisor from local registered table and clear registerDate (after cancellation)
  static Future<void> unregisterSupervisor(String cardNumber) async {
    final db = await database;
    await db.delete(
      _registeredSupervisorsTable,
      where: 'cardNumber = ?',
      whereArgs: [cardNumber],
    );
    await db.update(
      _supervisorsTable,
      {'registerDate': null},
      where: 'cardNumber = ?',
      whereArgs: [cardNumber],
    );
  }

  /// Get registered monitors from local database. `examDate` is no longer a
  /// filter key (contract-adjacent decision, mobile spec §5) — the table
  /// only ever holds one slot's worth of data at a time (cleared on every
  /// login/slot switch, see [clearAllDatabase]).
  static Future<List<Monitor>> getRegisteredMonitors() async {
    final db = await database;

    final results = await db.query(
      _registeredMonitorsTable,
      orderBy: 'registerDate DESC',
    );

    return results.map((map) => _registeredMonitorFromMap(map)).toList();
  }

  /// Get locally registered monitors for a specific room
  static Future<List<Monitor>> getRegisteredMonitorsByRoom(int roomId) async {
    final monitors = await getRegisteredMonitors();
    return monitors.where((monitor) => monitor.roomId == roomId).toList();
  }

  /// Clear all registered monitors
  static Future<void> clearAllRegisteredMonitors() async {
    final db = await database;
    await db.delete(_registeredMonitorsTable);
  }

  // SUPERVISORS METHODS

  /// Save supervisors to offline storage
  static Future<void> saveSupervisors(List<Supervisor> supervisors) async {
    final db = await database;
    final batch = db.batch();

    for (final supervisor in supervisors) {
      batch.insert(
        _supervisorsTable,
        _supervisorToMap(supervisor),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  /// Get supervisor from offline storage by card number
  static Future<Supervisor?> getSupervisorByCardNumber(
      String cardNumber) async {
    final db = await database;
    final results = await db.query(
      _supervisorsTable,
      where: 'cardNumber = ?',
      whereArgs: [cardNumber],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return _supervisorFromMap(results.first);
    }
    return null;
  }

  /// Register supervisor (save to registered table and update offline table)
  ///
  /// Both writes run inside a single transaction so the local statistics table
  /// (`supervisors.registerDate`) and the sync queue (`registered_supervisors`)
  /// can never diverge if the app is killed mid-registration.
  static Future<void> registerSupervisor(
      Supervisor supervisor, String registrationDate) async {
    final db = await database;

    await db.transaction((txn) async {
      // Update registration date in offline table
      await txn.update(
        _supervisorsTable,
        {'registerDate': registrationDate},
        where: 'cardNumber = ?',
        whereArgs: [supervisor.cardNumber],
      );

      // Insert/update in registered supervisors table
      await txn.insert(
        _registeredSupervisorsTable,
        {
          'cardNumber': supervisor.cardNumber,
          // New (9.2) scans always know the server id from the download —
          // no slot_key fallback needed for these rows (contract §1.3).
          'id': supervisor.id,
          'slot_key': null,
          'lastName': supervisor.lastName,
          'firstName': supervisor.firstName,
          'fatherName': supervisor.fatherName,
          'buildingCode': supervisor.buildingCode,
          'buildingName': supervisor.buildingName,
          'districtCode': supervisor.districtCode,
          'examDate': supervisor.examDate,
          'image': supervisor.image,
          'pinCode': supervisor.pinCode,
          'registerDate': registrationDate,
          'supervisorAction': supervisor.supervisorAction,
          'online': 0, // Offline registration
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Get all registered supervisors
  static Future<List<Supervisor>> getRegisteredSupervisors(
      {bool onlineOnly = false}) async {
    final db = await database;
    String whereClause = '';

    if (onlineOnly) {
      whereClause = 'WHERE online = 1';
    }

    final results = await db.rawQuery('''
      SELECT * FROM $_registeredSupervisorsTable $whereClause
      ORDER BY registerDate DESC
    ''');

    return results.map((map) => _registeredSupervisorFromMap(map)).toList();
  }

  /// Get offline registered supervisors (not synced)
  static Future<List<Supervisor>> getOfflineRegisteredSupervisors() async {
    return getRegisteredSupervisors(onlineOnly: false);
  }

  /// Delete all supervisors
  static Future<void> deleteAllSupervisors() async {
    final db = await database;
    await db.delete(_supervisorsTable);
    await db.delete(_registeredSupervisorsTable);
  }

  /// Check if supervisor is already registered
  static Future<bool> isSupervisorRegistered(String cardNumber) async {
    final db = await database;
    final results = await db.query(
      _registeredSupervisorsTable,
      where: 'cardNumber = ?',
      whereArgs: [cardNumber],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Check if participant is already registered
  static Future<bool> isParticipantRegistered(int workNumber) async {
    final db = await database;
    final results = await db.query(
      _registeredParticipantsTable,
      where: 'card_number = ?',
      whereArgs: [workNumber],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Check if database has offline data
  static Future<bool> hasOfflineData() async {
    final db = await database;
    final participantsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_participantsTable'),
        ) ??
        0;
    final supervisorsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_supervisorsTable'),
        ) ??
        0;

    return participantsCount > 0 || supervisorsCount > 0;
  }

  /// Get database statistics
  static Future<Map<String, int>> getDatabaseStatistics() async {
    final db = await database;

    final participantsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_participantsTable'),
        ) ??
        0;

    final registeredParticipantsCount = Sqflite.firstIntValue(
          await db
              .rawQuery('SELECT COUNT(*) FROM $_registeredParticipantsTable'),
        ) ??
        0;

    final registeredMonitorsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_registeredMonitorsTable'),
        ) ??
        0;

    final supervisorsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_supervisorsTable'),
        ) ??
        0;

    final registeredSupervisorsCount = Sqflite.firstIntValue(
          await db
              .rawQuery('SELECT COUNT(*) FROM $_registeredSupervisorsTable'),
        ) ??
        0;

    return {
      'participants': participantsCount,
      'registeredParticipants': registeredParticipantsCount,
      'registeredMonitors': registeredMonitorsCount,
      'supervisors': supervisorsCount,
      'registeredSupervisors': registeredSupervisorsCount,
    };
  }

  // Helper methods for mapping

  static Map<String, dynamic> _participantToMap(Participant participant) {
    return {
      'id': participant.id,
      'card_number': participant.cardNumber,
      'exam_session_id': participant.examSessionId,
      'last_name': participant.lastName,
      'first_name': participant.firstName,
      'father_name': participant.fatherName,
      'gender': participant.gender,
      'building_code': participant.buildingCode,
      'hall': participant.hall,
      'floor': participant.floor,
      'row': participant.row,
      'seat': participant.seat,
      'photo': participant.photoBytes,
      'registered_at': participant.registeredAt,
    };
  }

  static Participant _participantFromMap(Map<String, dynamic> map) {
    return Participant(
      cardNumber: map['card_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      fatherName: map['father_name'] as String,
      floor: map['floor'] as String,
      hall: map['hall'] as String,
      row: map['row'] as String,
      seat: map['seat'] as String,
      photoBytes: _photoBytesFromDb(map['photo']),
      registeredAt: map['registered_at'] as String?,
      buildingCode: map['building_code'] as String,
      gender: (map['gender'] as int?) ?? 0,
      id: map['id'] as int?,
      examSessionId: map['exam_session_id'] as int?,
    );
  }

  /// participants.photo is a BLOB (Uint8List) since v8. Tolerates a leftover
  /// base64 String too, in case a row somehow survived without going through
  /// the v8 migration's DROP TABLE.
  static Uint8List? _photoBytesFromDb(dynamic raw) {
    if (raw is Uint8List) return raw.isEmpty ? null : raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return base64Decode(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Merge a batch of downloaded photos into the participants table by
  /// card_number. One transaction per batch so a crash mid-download can't
  /// leave a partial batch half-applied.
  static Future<void> updateParticipantPhotos(
      List<MapEntry<int, Uint8List>> batch) async {
    if (batch.isEmpty) return;
    final db = await database;
    final dbBatch = db.batch();
    for (final entry in batch) {
      dbBatch.update(
        _participantsTable,
        {'photo': entry.value},
        where: 'card_number = ?',
        whereArgs: [entry.key],
      );
    }
    await dbBatch.commit(noResult: true);
  }

  static Participant _registeredParticipantFromMap(Map<String, dynamic> map) {
    return Participant(
      cardNumber: map['card_number'] as int,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      fatherName: map['father_name'] as String,
      floor: map['floor'] as String,
      hall: map['hall'] as String,
      row: map['row'] as String,
      seat: map['seat'] as String,
      photo: map['photo'] as String?,
      registeredAt: map['registered_at'] as String?,
      buildingCode: map['building_code'] as String,
      gender: (map['gender'] as int?) ?? 0,
      id: map['id'] as int?,
      slotKey: map['slot_key'] as String?,
    );
  }

  static Monitor _registeredMonitorFromMap(Map<String, dynamic> map) {
    return Monitor(
      workNumber: map['workNumber'] as int,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      middleName: map['middleName'] as String? ?? '',
      idCardPin: map['idCardPin'] as String? ?? '',
      buildingCode: map['buildingCode'] as int? ?? 0,
      buildingName: map['buildingName'] as String? ?? '',
      roomId: map['roomId'] as int? ?? 0,
      roomName: map['roomName'] as String? ?? '',
      examDate: map['examDate'] as String? ?? '',
      registerDate: map['registerDate'] as String? ?? '',
      image: map['image'] as String? ?? '',
      online: map['online'] == 1,
      id: map['id'] as int?,
      examSessionId: map['exam_session_id'] as int?,
    );
  }

  static Map<String, dynamic> _supervisorToMap(Supervisor supervisor) {
    return {
      'cardNumber': supervisor.cardNumber,
      'id': supervisor.id,
      'exam_session_id': supervisor.examSessionId,
      'lastName': supervisor.lastName,
      'firstName': supervisor.firstName,
      'fatherName': supervisor.fatherName,
      'buildingCode': supervisor.buildingCode,
      'buildingName': supervisor.buildingName,
      'districtCode': supervisor.districtCode,
      'examDate': supervisor.examDate,
      'image': supervisor.image,
      'pinCode': supervisor.pinCode,
      'registerDate': supervisor.registerDate,
      'supervisorAction': supervisor.supervisorAction,
    };
  }

  static Supervisor _supervisorFromMap(Map<String, dynamic> map) {
    return Supervisor(
      cardNumber: map['cardNumber'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      fatherName: map['fatherName'] as String? ?? '',
      buildingCode: map['buildingCode'] as int? ?? 0,
      buildingName: map['buildingName'] as String? ?? '',
      districtCode: map['districtCode'] as int? ?? 0,
      examDate: map['examDate'] as String? ?? '',
      image: map['image'] as String? ?? '',
      pinCode: map['pinCode'] as String? ?? '',
      registerDate: map['registerDate'] as String? ?? '',
      supervisorAction: map['supervisorAction'] as int? ?? 0,
      id: map['id'] as int?,
      examSessionId: map['exam_session_id'] as int?,
    );
  }

  static Supervisor _registeredSupervisorFromMap(Map<String, dynamic> map) {
    return Supervisor(
      cardNumber: map['cardNumber'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      fatherName: map['fatherName'] as String? ?? '',
      buildingCode: map['buildingCode'] as int? ?? 0,
      buildingName: map['buildingName'] as String? ?? '',
      districtCode: map['districtCode'] as int? ?? 0,
      examDate: map['examDate'] as String? ?? '',
      image: map['image'] as String? ?? '',
      pinCode: map['pinCode'] as String? ?? '',
      registerDate: map['registerDate'] as String? ?? '',
      supervisorAction: map['supervisorAction'] as int? ?? 0,
      online: map['online'] == 1,
      id: map['id'] as int?,
      slotKey: map['slot_key'] as String?,
    );
  }

  /// Simple gender detection by name (placeholder logic)
  /// Clear all participants from offline database
  static Future<void> clearAllParticipants() async {
    final db = await database;
    await db.delete(_participantsTable);
  }

  /// Clear all supervisors from offline database
  static Future<void> clearAllSupervisors() async {
    final db = await database;
    await db.delete(_supervisorsTable);
  }

  /// Clear all registered participants
  static Future<void> clearAllRegisteredParticipants() async {
    final db = await database;
    await db.delete(_registeredParticipantsTable);
  }

  /// Clear all registered supervisors
  static Future<void> clearAllRegisteredSupervisors() async {
    final db = await database;
    await db.delete(_registeredSupervisorsTable);
  }

  /// Clear entire database EXCEPT the sync queue.
  ///
  /// Called on login/logout to start with a clean slate for the master/offline
  /// download tables. The registered_* tables hold unsynced registrations
  /// (online = 0) and are intentionally PRESERVED so a re-login or token
  /// refresh can never wipe data that has not yet reached the server — the
  /// startup/login flush ([SyncService.kickstartIfPending]) sends them, and
  /// the server-side "skip" cleanup drains records whose master row is gone,
  /// so the queue cannot grow unbounded.
  static Future<void> clearAllDatabase() async {
    final db = await database;
    await db.delete(_participantsTable);
    await db.delete(_registeredMonitorsTable);
    await db.delete(_supervisorsTable);
    await db.delete(_allMonitorsTable);
    // NOTE: _registeredParticipantsTable / _registeredSupervisorsTable are NOT
    // cleared here — see doc comment above. Use clearUnSynced* / clearSynced*
    // only after a confirmed server sync.
  }

  /// Get all participants (for offline database management)
  static Future<List<Participant>> getAllParticipants() async {
    final db = await database;
    final results = await db.query(_participantsTable);
    return results.map((map) => _participantFromMap(map)).toList();
  }

  /// Get all supervisors (for offline database management)
  static Future<List<Supervisor>> getAllSupervisors() async {
    final db = await database;
    final results = await db.query(_supervisorsTable);
    return results.map((map) => _supervisorFromMap(map)).toList();
  }

  // ALL_MONITORS METHODS (offline download for admin)

  /// Save all monitors to offline storage (admin download)
  static Future<void> saveAllMonitors(List<Monitor> monitors) async {
    final db = await database;
    final batch = db.batch();
    for (final monitor in monitors) {
      batch.insert(
        _allMonitorsTable,
        {
          'workNumber': monitor.workNumber,
          'id': monitor.id,
          'exam_session_id': monitor.examSessionId,
          'firstName': monitor.firstName,
          'lastName': monitor.lastName,
          'middleName': monitor.middleName,
          'idCardPin': monitor.idCardPin,
          'buildingCode': monitor.buildingCode,
          'buildingName': monitor.buildingName,
          'roomId': monitor.roomId,
          'roomName': monitor.roomName,
          'examDate': monitor.examDate,
          'registerDate': monitor.registerDate,
          'image': monitor.image,
          'phone': monitor.phone,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// Get all monitors from offline storage (admin download)
  static Future<List<Monitor>> getAllMonitorsOffline() async {
    final db = await database;
    final results = await db.query(_allMonitorsTable);
    return results.map(_monitorFromAllMonitorsMap).toList();
  }

  /// Get all monitors for a specific room from offline storage (admin download)
  static Future<List<Monitor>> getAllMonitorsByRoomOffline(int roomId) async {
    final db = await database;
    final results = await db.query(
      _allMonitorsTable,
      where: 'roomId = ?',
      whereArgs: [roomId],
    );
    return results.map(_monitorFromAllMonitorsMap).toList();
  }

  static Monitor _monitorFromAllMonitorsMap(Map<String, dynamic> map) {
    return Monitor(
      workNumber: map['workNumber'] as int? ?? 0,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      middleName: map['middleName'] as String? ?? '',
      idCardPin: map['idCardPin'] as String? ?? '',
      buildingCode: map['buildingCode'] as int? ?? 0,
      buildingName: map['buildingName'] as String? ?? '',
      roomId: map['roomId'] as int? ?? 0,
      roomName: map['roomName'] as String? ?? '',
      examDate: map['examDate'] as String? ?? '',
      registerDate: map['registerDate'] as String? ?? '',
      image: map['image'] as String? ?? '',
      phone: map['phone'] as String?,
      id: map['id'] as int?,
      examSessionId: map['exam_session_id'] as int?,
    );
  }

  /// Clear all_monitors table
  static Future<void> clearAllMonitorsOffline() async {
    final db = await database;
    await db.delete(_allMonitorsTable);
  }

  /// Close database connection
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS METHODS
  // ──────────────────────────────────────────────────────────────────────────

  /// Save an emergency notification. Skips duplicates by message_id.
  static Future<void> saveNotification(NotificationMessage msg) async {
    final db = await database;
    await db.insert(
      _notificationsTable,
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Get all notifications sorted newest first.
  static Future<List<NotificationMessage>> getNotifications() async {
    final db = await database;
    final results = await db.query(
      _notificationsTable,
      orderBy: 'received_at DESC',
    );
    return results.map(NotificationMessage.fromMap).toList();
  }

  /// Count unread notifications.
  static Future<int> getUnreadNotificationCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $_notificationsTable WHERE is_read = 0',
          ),
        ) ??
        0;
  }

  /// Mark a single notification as read, recording the read timestamp.
  static Future<void> markNotificationRead(int id, String readAt) async {
    final db = await database;
    await db.update(
      _notificationsTable,
      {'is_read': 1, 'read_at': readAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark all unread notifications as read, recording the read timestamp.
  static Future<void> markAllNotificationsRead(String readAt) async {
    final db = await database;
    await db.update(
      _notificationsTable,
      {'is_read': 1, 'read_at': readAt},
      where: 'is_read = 0',
    );
  }

  // VIOLATIONS METHODS

  /// Save list of violators downloaded from server (replaces previous data).
  /// NOTE: the local `is_N` column is a purely internal persistence key —
  /// not part of the spec's sqflite rename list (participants/
  /// registered_participants only) — kept as-is to avoid a v9 migration for
  /// this always-fully-repopulated, non-queue table; the wire-level rename
  /// (`is_N`→`cardNumber`) is already reflected on [ViolatorInfo.cardNumber].
  static Future<void> saveViolations(List<ViolatorInfo> violators) async {
    final db = await database;
    await db.delete(_participantViolationsTable);
    final batch = db.batch();
    for (final v in violators) {
      batch.insert(
        _participantViolationsTable,
        {
          'is_N': v.cardNumber,
          'altKatName': v.altKatName,
          'katName': v.katName,
          'qeyd': v.qeyd,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// Returns all violations as a map keyed by card number
  static Future<Map<int, ViolatorInfo>> getAllViolations() async {
    final db = await database;
    final results = await db.query(_participantViolationsTable);
    final map = <int, ViolatorInfo>{};
    for (final row in results) {
      final cardNumber = row['is_N'] as int;
      map[cardNumber] = ViolatorInfo(
        cardNumber: cardNumber,
        altKatName: row['altKatName'] as String?,
        katName: row['katName'] as String?,
        qeyd: row['qeyd'] as String?,
      );
    }
    return map;
  }

  /// Returns violation info for a participant, or null if no violation exists
  static Future<ViolatorInfo?> getViolationForParticipant(
      int cardNumber) async {
    final db = await database;
    final results = await db.query(
      _participantViolationsTable,
      where: 'is_N = ?',
      whereArgs: [cardNumber],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return ViolatorInfo(
      cardNumber: row['is_N'] as int,
      altKatName: row['altKatName'] as String?,
      katName: row['katName'] as String?,
      qeyd: row['qeyd'] as String?,
    );
  }

  /// Clear all violations
  static Future<void> clearAllViolations() async {
    final db = await database;
    await db.delete(_participantViolationsTable);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SYNC QUEUE METHODS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get participants that have not yet been synced to the server (online = 0).
  static Future<List<Participant>> getUnSyncedParticipants() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT card_number, id, slot_key, last_name, first_name, father_name, gender, building_code, hall, floor, row, seat, photo, registered_at, online
      FROM $_registeredParticipantsTable
      WHERE online = 0
      ORDER BY registered_at ASC
    ''');
    return results.map((map) => _registeredParticipantFromMap(map)).toList();
  }

  /// Count of THIS device's not-yet-synced participant registrations, split by
  /// gender (gender=1 male, gender=2 female). Used to overlay the device's own
  /// pending scans on top of the server aggregate so the displayed count never
  /// drops below reality between syncs.
  static Future<Map<String, int>> getUnsyncedParticipantGenderCounts() async {
    final db = await database;
    final men = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $_registeredParticipantsTable WHERE online = 0 AND gender = 1',
        )) ??
        0;
    final women = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $_registeredParticipantsTable WHERE online = 0 AND gender = 2',
        )) ??
        0;
    return {'men': men, 'women': women};
  }

  /// Count of THIS device's not-yet-synced supervisor registrations.
  static Future<int> getUnsyncedSupervisorCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $_registeredSupervisorsTable WHERE online = 0',
        )) ??
        0;
  }

  /// Whether this participant still sits in the sync queue (registered offline
  /// and not yet sent to the server). Used so an offline cancel can drop the
  /// record locally without a server round-trip.
  static Future<bool> isParticipantQueued(int cardNumber) async {
    final db = await database;
    final results = await db.query(
      _registeredParticipantsTable,
      where: 'card_number = ? AND online = 0',
      whereArgs: [cardNumber],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Whether this supervisor still sits in the sync queue (not yet synced).
  static Future<bool> isSupervisorQueued(String cardNumber) async {
    final db = await database;
    final results = await db.query(
      _registeredSupervisorsTable,
      where: 'cardNumber = ? AND online = 0',
      whereArgs: [cardNumber],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Get supervisors that have not yet been synced to the server (online = 0).
  static Future<List<Supervisor>> getUnSyncedSupervisors() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT * FROM $_registeredSupervisorsTable
      WHERE online = 0
      ORDER BY registerDate ASC
    ''');
    return results.map((map) => _registeredSupervisorFromMap(map)).toList();
  }

  /// Delete unsynced participants from the queue after a successful server sync.
  /// NOTE: The `participants` table still holds `registered_at` for local statistics.
  static Future<void> clearUnSyncedParticipants() async {
    final db = await database;
    await db.delete(
      _registeredParticipantsTable,
      where: 'online = 0',
    );
  }

  /// Delete unsynced supervisors from the queue after a successful server sync.
  /// NOTE: The `supervisors` table still holds `registerDate` for local statistics.
  static Future<void> clearUnSyncedSupervisors() async {
    final db = await database;
    await db.delete(
      _registeredSupervisorsTable,
      where: 'online = 0',
    );
  }

  /// Delete only the specific participants (by card_number) that were
  /// successfully synced. Safe against race conditions: newly-scanned records
  /// with the same online=0 state but different IDs are NOT touched.
  static Future<void> clearSyncedParticipantsByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawDelete(
      'DELETE FROM $_registeredParticipantsTable WHERE card_number IN ($placeholders) AND online = 0',
      ids,
    );
  }

  /// Delete only the specific supervisors (by cardNumber) that were successfully synced.
  static Future<void> clearSyncedSupervisorsByCardNumbers(
      List<String> cardNumbers) async {
    if (cardNumbers.isEmpty) return;
    final db = await database;
    final placeholders = cardNumbers.map((_) => '?').join(',');
    await db.rawDelete(
      'DELETE FROM $_registeredSupervisorsTable WHERE cardNumber IN ($placeholders) AND online = 0',
      cardNumbers,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOCAL STATISTICS METHODS (read from offline tables — no network needed)
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns participant statistics computed entirely from the local SQLite DB.
  ///
  /// [buildingCode] – building code as stored in the participants table. The table
  /// only ever holds one slot's worth of data at a time (fully repopulated
  /// on every download, cleared on every login/slot switch — see
  /// [clearAllDatabase]), so no separate exam/session filter is needed here
  /// (contract-adjacent simplification: the old legacy exam-date-string
  /// column this used to filter on no longer exists at all — see the v9
  /// migration).
  ///
  /// Returns a map with keys:
  ///   allMen, allWomen, regMen, regWomen
  ///
  /// `gender = 1` → male;  `gender = 2` → female  (values from server).
  static Future<Map<String, int>> getLocalParticipantStats(
      String buildingCode) async {
    final db = await database;

    // Total by gender
    final allMenResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_participantsTable WHERE building_code = ? AND gender = 1',
      [buildingCode],
    );
    final allWomenResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_participantsTable WHERE building_code = ? AND gender = 2',
      [buildingCode],
    );

    // Registered by gender (registered_at IS NOT NULL and not empty)
    final regMenResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_participantsTable WHERE building_code = ? AND gender = 1 AND registered_at IS NOT NULL AND registered_at != ''",
      [buildingCode],
    );
    final regWomenResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_participantsTable WHERE building_code = ? AND gender = 2 AND registered_at IS NOT NULL AND registered_at != ''",
      [buildingCode],
    );

    return {
      'allMen': Sqflite.firstIntValue(allMenResult) ?? 0,
      'allWomen': Sqflite.firstIntValue(allWomenResult) ?? 0,
      'regMen': Sqflite.firstIntValue(regMenResult) ?? 0,
      'regWomen': Sqflite.firstIntValue(regWomenResult) ?? 0,
    };
  }

  /// Returns supervisor statistics computed entirely from the local SQLite DB.
  ///
  /// [buildingCode] – building code. Same single-slot-at-a-time reasoning as
  /// [getLocalParticipantStats] applies — no separate date/session filter.
  ///
  /// Returns a map with keys: allCount, regCount
  static Future<Map<String, int>> getLocalSupervisorStats(
      int buildingCode) async {
    final db = await database;

    final allResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_supervisorsTable WHERE buildingCode = ?',
      [buildingCode],
    );

    final regResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_supervisorsTable WHERE buildingCode = ? AND registerDate IS NOT NULL AND registerDate != ''",
      [buildingCode],
    );

    return {
      'allCount': Sqflite.firstIntValue(allResult) ?? 0,
      'regCount': Sqflite.firstIntValue(regResult) ?? 0,
    };
  }
}
