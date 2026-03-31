import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/app_database.dart';
import '../models/day_model.dart';
import '../models/lesson_model.dart';
import '../models/quarterly_model.dart';

class CatalogLocalDataSource {
  Future<Database> get _db async => AppDatabase.instance.database;

  Future<List<QuarterlyModel>> getQuarterlies(String lang) async {
    final db = await _db;
    final rows = await db.query(
      'quarterlies',
      where: 'lang = ?',
      whereArgs: [lang],
      orderBy: 'startDate DESC',
    );
    return rows.map(QuarterlyModel.fromDb).toList();
  }

  Future<QuarterlyModel?> getQuarterlyById({
    required String lang,
    required String quarterlyId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'quarterlies',
      where: 'lang = ? AND quarterlyId = ?',
      whereArgs: [lang, quarterlyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return QuarterlyModel.fromDb(rows.first);
  }

  Future<List<LessonModel>> getLessons({
    required String lang,
    required String quarterlyId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'lessons',
      where: 'lang = ? AND quarterlyId = ?',
      whereArgs: [lang, quarterlyId],
      orderBy: 'lessonId ASC',
    );
    return rows.map(LessonModel.fromDb).toList();
  }

  Future<LessonModel?> getLessonById({
    required String lang,
    required String quarterlyId,
    required String lessonId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'lessons',
      where: 'lang = ? AND quarterlyId = ? AND lessonId = ?',
      whereArgs: [lang, quarterlyId, lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LessonModel.fromDb(rows.first);
  }

  Future<List<DayModel>> getDays({
    required String lang,
    required String quarterlyId,
    required String lessonId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'days',
      where: 'lang = ? AND quarterlyId = ? AND lessonId = ?',
      whereArgs: [lang, quarterlyId, lessonId],
      orderBy: 'dayId ASC',
    );
    return rows.map(DayModel.fromDb).toList();
  }

  Future<Map<String, dynamic>?> getDayRead({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'day_reads',
      where: 'lang = ? AND quarterlyId = ? AND lessonId = ? AND dayId = ?',
      whereArgs: [lang, quarterlyId, lessonId, dayId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['readJson'] as String) as Map<String, dynamic>;
  }

  Future<void> upsertQuarterlies({
    required String lang,
    required List<QuarterlyModel> quarterlies,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final quarterly in quarterlies) {
      batch.insert(
        'quarterlies',
        quarterly.toDb(lang: lang),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertLessons({
    required String lang,
    required String quarterlyId,
    required List<LessonModel> lessons,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert(
        'lessons',
        lesson.toDb(lang: lang, quarterlyId: quarterlyId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDays({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required List<DayModel> days,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final day in days) {
      batch.insert(
        'days',
        day.toDb(lang: lang, quarterlyId: quarterlyId, lessonId: lessonId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDayRead({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required Map<String, dynamic> readJson,
    DateTime? updatedAt,
  }) async {
    final db = await _db;
    await db.insert('day_reads', <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lessonId': lessonId,
      'dayId': dayId,
      'readJson': jsonEncode(readJson),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveBulkPayload({
    required String lang,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final quarterly = (payload['quarterly'] as Map<String, dynamic>?) ?? {};
      final quarterlyId = (quarterly['quarterlyId'] ?? '').toString();
      if (quarterlyId.isEmpty) return;

      final quarterlyModel = QuarterlyModel.fromJson(quarterly);
      await txn.insert(
        'quarterlies',
        quarterlyModel.toDb(lang: lang),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final lessons = (payload['lessons'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      for (final lessonMap in lessons) {
        final lesson = LessonModel.fromJson(lessonMap);
        await txn.insert(
          'lessons',
          lesson.toDb(lang: lang, quarterlyId: quarterlyId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final days = (lessonMap['days'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

        for (final dayMap in days) {
          final day = DayModel.fromJson(dayMap);
          await txn.insert(
            'days',
            day.toDb(
              lang: lang,
              quarterlyId: quarterlyId,
              lessonId: lesson.lessonId,
            ),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          final read =
              (dayMap['read'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          await txn.insert('day_reads', <String, Object?>{
            'lang': lang,
            'quarterlyId': quarterlyId,
            'lessonId': lesson.lessonId,
            'dayId': day.dayId,
            'readJson': jsonEncode(read),
            'updatedAt': DateTime.tryParse(
              (dayMap['updatedAt'] ?? '').toString(),
            )?.toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<List<String>> getDownloadedQuarterlyIds(String lang) async {
    final db = await _db;
    final rows = await db.query(
      'sync_state',
      columns: ['quarterlyId'],
      where: 'lang = ?',
      whereArgs: [lang],
    );
    return rows
        .map((e) => (e['quarterlyId'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<DateTime?> getLastSync({
    required String lang,
    required String quarterlyId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'sync_state',
      where: 'lang = ? AND quarterlyId = ?',
      whereArgs: [lang, quarterlyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse((rows.first['lastSync'] ?? '').toString());
  }

  Future<void> setLastSync({
    required String lang,
    required String quarterlyId,
    required DateTime value,
  }) async {
    final db = await _db;
    await db.insert('sync_state', <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lastSync': value.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String key) async {
    final db = await _db;
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['value'] ?? '').toString();
  }

  Future<void> setMeta({required String key, required String value}) async {
    final db = await _db;
    await db.insert('app_meta', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getQuestionAnswer({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required String questionKey,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'question_answers',
      where:
          'lang = ? AND quarterlyId = ? AND lessonId = ? AND dayId = ? AND questionKey = ?',
      whereArgs: [lang, quarterlyId, lessonId, dayId, questionKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['answer'] ?? '').toString();
  }

  Future<void> saveQuestionAnswer({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required String questionKey,
    required String answer,
  }) async {
    final db = await _db;
    await db.insert('question_answers', <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lessonId': lessonId,
      'dayId': dayId,
      'questionKey': questionKey,
      'answer': answer,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, bool>> getLessonStudyMarks({
    required String lang,
    required String quarterlyId,
    required String lessonId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'study_marks',
      columns: ['dayId', 'isStudied'],
      where: 'lang = ? AND quarterlyId = ? AND lessonId = ?',
      whereArgs: [lang, quarterlyId, lessonId],
    );

    final result = <String, bool>{};
    for (final row in rows) {
      final dayId = (row['dayId'] ?? '').toString().padLeft(2, '0');
      final isStudied = ((row['isStudied'] ?? 0) as int) == 1;
      if (dayId.isNotEmpty) {
        result[dayId] = isStudied;
      }
    }
    return result;
  }

  Future<void> setDayStudyMark({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required bool isStudied,
  }) async {
    final db = await _db;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.insert('study_marks', <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lessonId': lessonId.padLeft(2, '0'),
      'dayId': dayId.padLeft(2, '0'),
      'isStudied': isStudied ? 1 : 0,
      'studiedAt': isStudied ? nowIso : null,
      'updatedAt': nowIso,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> getQuarterlyStudyProgress({
    required String lang,
    required String quarterlyId,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT lessonId, COUNT(*) AS studiedCount
      FROM study_marks
      WHERE lang = ? AND quarterlyId = ? AND isStudied = 1
      GROUP BY lessonId
      ''',
      [lang, quarterlyId],
    );

    final progress = <String, int>{};
    for (final row in rows) {
      final lessonId = (row['lessonId'] ?? '').toString().padLeft(2, '0');
      final studied = row['studiedCount'];
      final count = studied is int
          ? studied
          : int.tryParse(studied.toString()) ?? 0;
      if (lessonId.isNotEmpty) {
        progress[lessonId] = count;
      }
    }
    return progress;
  }
}
