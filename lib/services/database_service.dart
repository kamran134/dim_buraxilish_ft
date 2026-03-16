import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/participant_models.dart';
import '../models/monitor_models.dart';
import '../models/supervisor_models.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'dim_buraxilish.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String _participantsTable = 'participants';
  static const String _registeredParticipantsTable = 'registered_participants';
  static const String _registeredMonitorsTable = 'registered_monitors';
  static const String _allMonitorsTable = 'all_monitors';
  static const String _supervisorsTable = 'supervisors';
  static const String _registeredSupervisorsTable = 'registered_supervisors';

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    // Create participants table (offline download)
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
        photo TEXT,
        ad_Bina TEXT,
        qeydiyyat TEXT,
        s_Nomer INTEGER
      )
    ''');

    // Create registered participants table
    await db.execute('''
      CREATE TABLE $_registeredParticipantsTable (
        is_N INTEGER PRIMARY KEY,
        soy TEXT,
        adi TEXT,
        baba TEXT,
        bina TEXT,
        imt_Tarix TEXT,
        qeydiyyat TEXT,
        online INTEGER DEFAULT 0,
        gins INTEGER,
        photo TEXT,
        zal TEXT,
        mertebe TEXT,
        sira TEXT,
        yer TEXT
      )
    ''');

    // Create registered monitors table
    await db.execute('''
      CREATE TABLE $_registeredMonitorsTable (
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

    // Create supervisors table (offline download)
    await db.execute('''
      CREATE TABLE $_supervisorsTable (
        cardNumber TEXT PRIMARY KEY,
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
    ''');

    // Create all_monitors table (offline download for admin)
    await db.execute('''
      CREATE TABLE $_allMonitorsTable (
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

    // Create registered supervisors table
    await db.execute('''
      CREATE TABLE $_registeredSupervisorsTable (
        cardNumber TEXT PRIMARY KEY,
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
      where: 'is_N = ?',
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

    // Update registration date in offline table
    await db.update(
      _participantsTable,
      {'qeydiyyat': registrationDate},
      where: 'is_N = ?',
      whereArgs: [participant.isN],
    );

    // Insert/update in registered participants table
    await db.insert(
      _registeredParticipantsTable,
      {
        'is_N': participant.isN,
        'soy': participant.soy,
        'adi': participant.adi,
        'baba': participant.baba,
        'bina': participant.bina,
        'imt_Tarix': participant.imtTarix,
        'qeydiyyat': registrationDate,
        'online': 0, // Offline registration
        'gins': _getGenderFromName(participant.adi), // Determine gender
        'photo': participant.photo,
        'zal': participant.zal,
        'mertebe': participant.mertebe,
        'sira': participant.sira,
        'yer': participant.yer,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      SELECT is_N, soy, adi, baba, gins, bina, zal, mertebe, sira, yer, imt_Tarix, photo, qeydiyyat, online
      FROM $_registeredParticipantsTable $whereClause
      ORDER BY qeydiyyat DESC
    ''');

    return results.map((map) => _registeredParticipantFromMap(map)).toList();
  }

  /// Get offline registered participants (not synced)
  static Future<List<Participant>> getOfflineRegisteredParticipants() async {
    return getRegisteredParticipants(onlineOnly: false);
  }

  /// Mark participants as synced
  static Future<void> markParticipantsAsSynced() async {
    final db = await database;
    await db.update(
      _registeredParticipantsTable,
      {'online': 1},
      where: 'online = 0',
    );
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

  /// Remove participant from local registered table and clear qeydiyyat (after cancellation)
  static Future<void> unregisterParticipant(int isN) async {
    final db = await database;
    await db.delete(
      _registeredParticipantsTable,
      where: 'is_N = ?',
      whereArgs: [isN],
    );
    await db.update(
      _participantsTable,
      {'qeydiyyat': null},
      where: 'is_N = ?',
      whereArgs: [isN],
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

  /// Get registered monitors from local database
  static Future<List<Monitor>> getRegisteredMonitors({String? examDate}) async {
    final db = await database;

    final results = await db.query(
      _registeredMonitorsTable,
      orderBy: 'registerDate DESC',
    );

    final monitors =
        results.map((map) => _registeredMonitorFromMap(map)).toList();

    if (examDate == null || examDate.trim().isEmpty) {
      return monitors;
    }

    final dateKey = _normalizeDateKey(examDate);
    if (dateKey.isEmpty) {
      return monitors;
    }

    return monitors
        .where((monitor) => _normalizeDateKey(monitor.examDate) == dateKey)
        .toList();
  }

  /// Get locally registered monitors for a specific room
  static Future<List<Monitor>> getRegisteredMonitorsByRoom(
    int roomId, {
    String? examDate,
  }) async {
    final monitors = await getRegisteredMonitors(examDate: examDate);
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
  static Future<void> registerSupervisor(
      Supervisor supervisor, String registrationDate) async {
    final db = await database;

    // Update registration date in offline table
    await db.update(
      _supervisorsTable,
      {'registerDate': registrationDate},
      where: 'cardNumber = ?',
      whereArgs: [supervisor.cardNumber],
    );

    // Insert/update in registered supervisors table
    await db.insert(
      _registeredSupervisorsTable,
      {
        'cardNumber': supervisor.cardNumber,
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

  /// Mark supervisors as synced
  static Future<void> markSupervisorsAsSynced() async {
    final db = await database;
    await db.update(
      _registeredSupervisorsTable,
      {'online': 1},
      where: 'online = 0',
    );
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
      where: 'is_N = ?',
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
      'external_id': participant.hashCode, // Use hashCode as external_id
      'is_N': participant.isN,
      'soy': participant.soy,
      'adi': participant.adi,
      'baba': participant.baba,
      'tev': '', // Not used in current model
      'gins': _getGenderFromName(participant.adi),
      'sv_Seriya': '', // Not used in current model
      's_Ves': '', // Not used in current model
      'bina': participant.bina,
      'zal': participant.zal,
      'mertebe': participant.mertebe,
      'sira': participant.sira,
      'yer': participant.yer,
      'imt_Tarix': participant.imtTarix,
      'imt_Begin': '', // Not used in current model
      'photo': participant.photo,
      'ad_Bina': '', // Not used in current model
      'qeydiyyat': participant.qeydiyyat,
      's_Nomer': 0, // Not used in current model
    };
  }

  static Participant _participantFromMap(Map<String, dynamic> map) {
    return Participant(
      isN: map['is_N'] as int,
      adi: map['adi'] as String,
      soy: map['soy'] as String,
      baba: map['baba'] as String,
      mertebe: map['mertebe'] as String,
      zal: map['zal'] as String,
      sira: map['sira'] as String,
      yer: map['yer'] as String,
      photo: map['photo'] as String?,
      qeydiyyat: map['qeydiyyat'] as String?,
      bina: map['bina'] as String,
      imtTarix: map['imt_Tarix'] as String,
    );
  }

  static Participant _registeredParticipantFromMap(Map<String, dynamic> map) {
    return Participant(
      isN: map['is_N'] as int,
      adi: map['adi'] as String,
      soy: map['soy'] as String,
      baba: map['baba'] as String,
      mertebe: map['mertebe'] as String,
      zal: map['zal'] as String,
      sira: map['sira'] as String,
      yer: map['yer'] as String,
      photo: map['photo'] as String?,
      qeydiyyat: map['qeydiyyat'] as String?,
      bina: map['bina'] as String,
      imtTarix: map['imt_Tarix'] as String,
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
    );
  }

  static String _normalizeDateKey(String rawDate) {
    final value = rawDate.trim();
    if (value.isEmpty) return '';

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }

    final mmddyyyy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
    if (mmddyyyy != null) {
      final month = mmddyyyy.group(1)!.padLeft(2, '0');
      final day = mmddyyyy.group(2)!.padLeft(2, '0');
      final year = mmddyyyy.group(3)!;
      return '$year-$month-$day';
    }

    final ddmmyyyy =
        RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(value);
    if (ddmmyyyy != null) {
      final day = ddmmyyyy.group(1)!.padLeft(2, '0');
      final month = ddmmyyyy.group(2)!.padLeft(2, '0');
      final year = ddmmyyyy.group(3)!;
      return '$year-$month-$day';
    }

    final parts = value.split(' ');
    if (parts.length >= 3) {
      final day = int.tryParse(parts[0]);
      final monthMap = {
        'yanvar': 1,
        'fevral': 2,
        'mart': 3,
        'aprel': 4,
        'may': 5,
        'iyun': 6,
        'iyul': 7,
        'avqust': 8,
        'sentyabr': 9,
        'oktyabr': 10,
        'noyabr': 11,
        'dekabr': 12,
      };
      final month = monthMap[parts[1].toLowerCase()];
      final year = int.tryParse(parts[2].replaceAll(RegExp(r'[^\d]'), ''));
      if (day != null && month != null && year != null) {
        return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }

    return '';
  }

  static Map<String, dynamic> _supervisorToMap(Supervisor supervisor) {
    return {
      'cardNumber': supervisor.cardNumber,
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
    );
  }

  /// Simple gender detection by name (placeholder logic)
  static int _getGenderFromName(String firstName) {
    // This is a simplified logic - in real app you might have a more sophisticated approach
    final femaleEndings = ['a', 'ə', 'e'];
    final lastChar = firstName.toLowerCase().substring(firstName.length - 1);
    return femaleEndings.contains(lastChar) ? 0 : 1; // 0 = female, 1 = male
  }

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

  /// Clear entire database (all tables)
  static Future<void> clearAllDatabase() async {
    final db = await database;
    await db.delete(_participantsTable);
    await db.delete(_registeredParticipantsTable);
    await db.delete(_registeredMonitorsTable);
    await db.delete(_supervisorsTable);
    await db.delete(_registeredSupervisorsTable);
    await db.delete(_allMonitorsTable);
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
    return results
        .map((map) => Monitor(
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
            ))
        .toList();
  }

  /// Get all monitors for a specific room from offline storage (admin download)
  static Future<List<Monitor>> getAllMonitorsByRoomOffline(int roomId) async {
    final db = await database;
    final results = await db.query(
      _allMonitorsTable,
      where: 'roomId = ?',
      whereArgs: [roomId],
    );
    return results
        .map((map) => Monitor(
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
            ))
        .toList();
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
  // SYNC QUEUE METHODS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get participants that have not yet been synced to the server (online = 0).
  static Future<List<Participant>> getUnSyncedParticipants() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT is_N, soy, adi, baba, gins, bina, zal, mertebe, sira, yer, imt_Tarix, photo, qeydiyyat, online
      FROM $_registeredParticipantsTable
      WHERE online = 0
      ORDER BY qeydiyyat ASC
    ''');
    return results.map((map) => _registeredParticipantFromMap(map)).toList();
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
  /// NOTE: The `participants` table still holds `qeydiyyat` for local statistics.
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

  // ──────────────────────────────────────────────────────────────────────────
  // LOCAL STATISTICS METHODS (read from offline tables — no network needed)
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns participant statistics computed entirely from the local SQLite DB.
  ///
  /// [bina] – building code as stored in the participants table.
  /// [examDate] – exam date string as stored in the participants table.
  ///
  /// Returns a map with keys:
  ///   allMen, allWomen, regMen, regWomen
  ///
  /// `gins = 1` → male;  `gins = 0 or 2` → female  (per `_getGenderFromName`).
  static Future<Map<String, int>> getLocalParticipantStats(
      String bina, String examDate) async {
    final db = await database;

    // Total by gender
    final allMenResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_participantsTable WHERE bina = ? AND imt_Tarix = ? AND gins = 1',
      [bina, examDate],
    );
    final allWomenResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_participantsTable WHERE bina = ? AND imt_Tarix = ? AND gins != 1',
      [bina, examDate],
    );

    // Registered by gender (qeydiyyat IS NOT NULL and not empty)
    final regMenResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_participantsTable WHERE bina = ? AND imt_Tarix = ? AND gins = 1 AND qeydiyyat IS NOT NULL AND qeydiyyat != ''",
      [bina, examDate],
    );
    final regWomenResult = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $_participantsTable WHERE bina = ? AND imt_Tarix = ? AND gins != 1 AND qeydiyyat IS NOT NULL AND qeydiyyat != ''",
      [bina, examDate],
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
  /// [buildingCode] – building code.
  /// [examDate] – exam date string as stored in the supervisors table.
  ///
  /// Returns a map with keys: allCount, regCount
  static Future<Map<String, int>> getLocalSupervisorStats(
      int buildingCode, String examDate) async {
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
