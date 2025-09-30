import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'dim_buraxilish.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _participantsTable = 'participants';
  static const String _registeredParticipantsTable = 'registered_participants';
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
    // Handle schema migrations if needed
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
      cardNumber: map['cardNumber'] as String,
      lastName: map['lastName'] as String,
      firstName: map['firstName'] as String,
      fatherName: map['fatherName'] as String,
      buildingCode: map['buildingCode'] as int,
      buildingName: map['buildingName'] as String,
      districtCode: map['districtCode'] as int,
      examDate: map['examDate'] as String,
      image: map['image'] as String,
      pinCode: map['pinCode'] as String,
      registerDate: map['registerDate'] as String,
      supervisorAction: map['supervisorAction'] as int,
    );
  }

  static Supervisor _registeredSupervisorFromMap(Map<String, dynamic> map) {
    return Supervisor(
      cardNumber: map['cardNumber'] as String,
      lastName: map['lastName'] as String,
      firstName: map['firstName'] as String,
      fatherName: map['fatherName'] as String,
      buildingCode: map['buildingCode'] as int,
      buildingName: map['buildingName'] as String,
      districtCode: map['districtCode'] as int,
      examDate: map['examDate'] as String,
      image: map['image'] as String,
      pinCode: map['pinCode'] as String,
      registerDate: map['registerDate'] as String,
      supervisorAction: map['supervisorAction'] as int,
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

  /// Close database connection
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
