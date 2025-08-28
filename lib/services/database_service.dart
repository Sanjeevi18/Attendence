import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/holiday_model.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../models/company_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'attendance_management.db';
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Companies table
    await db.execute('''
      CREATE TABLE companies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        logo TEXT,
        createdAt INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        settings TEXT
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        companyId TEXT NOT NULL,
        profileImage TEXT,
        createdAt INTEGER NOT NULL,
        lastLoginAt INTEGER,
        isActive INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (companyId) REFERENCES companies (id)
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        companyId TEXT NOT NULL,
        checkInTime INTEGER NOT NULL,
        checkOutTime INTEGER,
        checkInLocation TEXT,
        checkOutLocation TEXT,
        totalHours REAL,
        status TEXT NOT NULL,
        notes TEXT,
        date INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id),
        FOREIGN KEY (companyId) REFERENCES companies (id)
      )
    ''');

    // Holidays table - This is the key table for holiday management
    await db.execute('''
      CREATE TABLE holidays (
        id TEXT PRIMARY KEY,
        companyId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        type TEXT NOT NULL,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        createdBy TEXT NOT NULL,
        FOREIGN KEY (companyId) REFERENCES companies (id),
        FOREIGN KEY (createdBy) REFERENCES users (id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_users_company ON users (companyId)');
    await db.execute('CREATE INDEX idx_attendance_user ON attendance (userId)');
    await db.execute('CREATE INDEX idx_attendance_date ON attendance (date)');
    await db.execute(
      'CREATE INDEX idx_holidays_company ON holidays (companyId)',
    );
    await db.execute('CREATE INDEX idx_holidays_date ON holidays (date)');
  }

  // Holiday CRUD Operations
  Future<String> insertHoliday(Holiday holiday) async {
    final db = await database;
    await db.insert('holidays', holiday.toMap());
    return holiday.id;
  }

  Future<List<Holiday>> getHolidaysByCompany(String companyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'holidays',
      where: 'companyId = ?',
      whereArgs: [companyId],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => Holiday.fromMap(maps[i]));
  }

  Future<List<Holiday>> getHolidaysInDateRange(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'holidays',
      where: 'companyId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        companyId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => Holiday.fromMap(maps[i]));
  }

  Future<Holiday?> getHolidayByDate(String companyId, DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      'holidays',
      where: 'companyId = ? AND date >= ? AND date < ?',
      whereArgs: [
        companyId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Holiday.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateHoliday(Holiday holiday) async {
    final db = await database;
    await db.update(
      'holidays',
      holiday.toMap(),
      where: 'id = ?',
      whereArgs: [holiday.id],
    );
  }

  Future<void> deleteHoliday(String holidayId) async {
    final db = await database;
    await db.delete('holidays', where: 'id = ?', whereArgs: [holidayId]);
  }

  // Check if a date is a holiday
  Future<bool> isHoliday(String companyId, DateTime date) async {
    final holiday = await getHolidayByDate(companyId, date);
    return holiday != null;
  }

  // Get all holidays for calendar display
  Future<Map<DateTime, List<Holiday>>> getHolidaysForCalendar(
    String companyId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final holidays = await getHolidaysInDateRange(
      companyId,
      startDate,
      endDate,
    );
    Map<DateTime, List<Holiday>> holidayMap = {};

    for (Holiday holiday in holidays) {
      DateTime dateKey = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );
      if (holidayMap[dateKey] == null) {
        holidayMap[dateKey] = [];
      }
      holidayMap[dateKey]!.add(holiday);
    }

    return holidayMap;
  }

  // User CRUD Operations
  Future<String> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap());
    return user.id;
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Company CRUD Operations
  Future<String> insertCompany(Company company) async {
    final db = await database;
    await db.insert('companies', company.toMap());
    return company.id;
  }

  Future<Company?> getCompanyById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Company.fromMap(maps.first);
    }
    return null;
  }

  // Attendance CRUD Operations
  Future<String> insertAttendance(Attendance attendance) async {
    final db = await database;
    await db.insert('attendance', attendance.toMap());
    return attendance.id;
  }

  Future<List<Attendance>> getAttendanceByUser(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        userId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
