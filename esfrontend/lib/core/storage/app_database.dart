import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'esfrontend.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE quarterlies (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            title TEXT,
            coverUrl TEXT,
            splashUrl TEXT,
            startDate TEXT,
            endDate TEXT,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId)
          )
        ''');

        await db.execute('''
          CREATE TABLE lessons (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            title TEXT,
            startDate TEXT,
            endDate TEXT,
            coverUrl TEXT,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId, lessonId)
          )
        ''');

        await db.execute('''
          CREATE TABLE days (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            dayId TEXT NOT NULL,
            dayDate TEXT,
            title TEXT,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId, lessonId, dayId)
          )
        ''');

        await db.execute('''
          CREATE TABLE day_reads (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            dayId TEXT NOT NULL,
            readJson TEXT NOT NULL,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId, lessonId, dayId)
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_state (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lastSync TEXT,
            PRIMARY KEY (lang, quarterlyId)
          )
        ''');

        await db.execute('''
          CREATE TABLE app_meta (
            key TEXT NOT NULL PRIMARY KEY,
            value TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE question_answers (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            dayId TEXT NOT NULL,
            questionKey TEXT NOT NULL,
            answer TEXT,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId, lessonId, dayId, questionKey)
          )
        ''');

        await db.execute('''
          CREATE TABLE study_marks (
            lang TEXT NOT NULL,
            quarterlyId TEXT NOT NULL,
            lessonId TEXT NOT NULL,
            dayId TEXT NOT NULL,
            isStudied INTEGER NOT NULL DEFAULT 0,
            studiedAt TEXT,
            updatedAt TEXT,
            PRIMARY KEY (lang, quarterlyId, lessonId, dayId)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE quarterlies ADD COLUMN splashUrl TEXT");
          await db.execute("ALTER TABLE lessons ADD COLUMN coverUrl TEXT");
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_meta (
              key TEXT NOT NULL PRIMARY KEY,
              value TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS question_answers (
              lang TEXT NOT NULL,
              quarterlyId TEXT NOT NULL,
              lessonId TEXT NOT NULL,
              dayId TEXT NOT NULL,
              questionKey TEXT NOT NULL,
              answer TEXT,
              updatedAt TEXT,
              PRIMARY KEY (lang, quarterlyId, lessonId, dayId, questionKey)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS study_marks (
              lang TEXT NOT NULL,
              quarterlyId TEXT NOT NULL,
              lessonId TEXT NOT NULL,
              dayId TEXT NOT NULL,
              isStudied INTEGER NOT NULL DEFAULT 0,
              studiedAt TEXT,
              updatedAt TEXT,
              PRIMARY KEY (lang, quarterlyId, lessonId, dayId)
            )
          ''');
        }
      },
    );

    return _db!;
  }
}
