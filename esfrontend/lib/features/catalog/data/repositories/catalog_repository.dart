import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../local/catalog_local_data_source.dart';
import '../models/day_model.dart';
import '../models/lesson_detail_meta.dart';
import '../models/lesson_model.dart';
import '../models/quarterly_model.dart';

class CatalogRepository {
  CatalogRepository(this._apiClient, this._local);

  final ApiClient _apiClient;
  final CatalogLocalDataSource _local;
  static const _quarterliesRefreshKeyPrefix = 'quarterlies_last_refresh_';
  static const _quarterlyDescriptionKeyPrefix = 'quarterly_intro_';
  static const _quarterlyAuthorKeyPrefix = 'quarterly_author_';
  static const _refreshInterval = Duration(hours: 24);

  Future<List<QuarterlyModel>> fetchQuarterlies({String lang = 'es'}) async {
    final local = await _local.getQuarterlies(lang);
    final shouldRefresh = await _shouldRefreshQuarterlies(lang);

    if (local.isNotEmpty && !shouldRefresh) {
      return local;
    }

    try {
      final remote = await _fetchQuarterliesRemote(lang: lang);
      if (remote.isNotEmpty) {
        await _local.upsertQuarterlies(lang: lang, quarterlies: remote);
      }
      await _local.setMeta(
        key: '$_quarterliesRefreshKeyPrefix$lang',
        value: DateTime.now().toUtc().toIso8601String(),
      );
      return remote.isNotEmpty ? remote : local;
    } on DioException {
      return local;
    }
  }

  Future<String?> fetchQuarterlyHeroImage({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    final localQuarterly = await _local.getQuarterlyById(
      lang: lang,
      quarterlyId: quarterlyId,
    );
    if ((localQuarterly?.splashUrl ?? '').isNotEmpty) {
      return localQuarterly!.splashUrl;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/quarterlies/$quarterlyId',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final heroUrl = _extractQuarterlyHeroImage(data);
      if (heroUrl != null) {
        final fallback =
            localQuarterly ??
            QuarterlyModel(
              quarterlyId: quarterlyId,
              title: quarterlyId,
              coverUrl: '',
              splashUrl: heroUrl,
            );
        await _local.upsertQuarterlies(
          lang: lang,
          quarterlies: [fallback.copyWith(splashUrl: heroUrl)],
        );
      }
      return heroUrl;
    } on DioException {
      return null;
    }
  }

  Future<String?> fetchQuarterlyDescription({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    final key = '$_quarterlyDescriptionKeyPrefix${lang}_$quarterlyId';
    final cached = await _local.getMeta(key);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/quarterlies/$quarterlyId',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final description = _extractQuarterlyDescription(data);
      if (description != null && description.isNotEmpty) {
        await _local.setMeta(key: key, value: description);
      }
      return description;
    } on DioException {
      return null;
    }
  }

  Future<String?> getQuestionAnswer({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required String questionKey,
  }) {
    return _local.getQuestionAnswer(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
      questionKey: questionKey,
    );
  }

  Future<void> saveQuestionAnswer({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required String questionKey,
    required String answer,
  }) {
    return _local.saveQuestionAnswer(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
      questionKey: questionKey,
      answer: answer,
    );
  }

  Future<Map<String, bool>> getLessonStudyMarks({
    required String lang,
    required String quarterlyId,
    required String lessonId,
  }) {
    return _local.getLessonStudyMarks(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId.padLeft(2, '0'),
    );
  }

  Future<void> setDayStudied({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required bool isStudied,
  }) {
    return _local.setDayStudyMark(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId.padLeft(2, '0'),
      dayId: dayId.padLeft(2, '0'),
      isStudied: isStudied,
    );
  }

  Future<Map<String, int>> getQuarterlyStudyProgress({
    required String lang,
    required String quarterlyId,
  }) {
    return _local.getQuarterlyStudyProgress(
      lang: lang,
      quarterlyId: quarterlyId,
    );
  }

  Future<String?> fetchQuarterlyAuthor({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    final key = '$_quarterlyAuthorKeyPrefix${lang}_$quarterlyId';
    final cached = await _local.getMeta(key);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/quarterlies/$quarterlyId',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      final author = _extractQuarterlyAuthor(data);
      if (author != null && author.isNotEmpty) {
        await _local.setMeta(key: key, value: author);
      }
      return author;
    } on DioException {
      return null;
    }
  }

  Future<String?> fetchLessonCoverImage({
    required String quarterlyId,
    required String lessonId,
    String lang = 'es',
  }) async {
    final localLesson = await _local.getLessonById(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
    );
    if ((localLesson?.coverUrl ?? '').isNotEmpty) {
      return localLesson!.coverUrl;
    }

    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/quarterlies/$quarterlyId/lessons/$lessonId',
        queryParameters: {'lang': lang},
      );
      final data = response.data ?? <String, dynamic>{};
      return _extractLessonCoverImage(data);
    } on DioException {
      return null;
    }
  }

  Future<LessonDetailMeta?> fetchLessonDetailMeta({
    required String quarterlyId,
    required String lessonId,
    String lang = 'es',
  }) async {
    final normalizedLessonId = lessonId.padLeft(2, '0');
    final localLesson = await _local.getLessonById(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: normalizedLessonId,
    );
    final localDays = await _local.getDays(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: normalizedLessonId,
    );
    final localMeta = LessonDetailMeta(
      coverUrl: localLesson?.coverUrl,
      days: localDays
          .map(
            (d) => LessonDayMeta(
              dayId: d.dayId,
              title: d.title,
              dayDate: d.dayDate,
            ),
          )
          .toList(),
    );

    if ((localMeta.coverUrl ?? '').isNotEmpty && localMeta.days.isNotEmpty) {
      return localMeta;
    }

    try {
      final meta = await _fetchLessonMetaRemote(
        quarterlyId: quarterlyId,
        lessonId: normalizedLessonId,
        lang: lang,
      );
      await _persistLessonMeta(
        lang: lang,
        quarterlyId: quarterlyId,
        lessonId: normalizedLessonId,
        meta: meta,
      );
      return meta;
    } on DioException {
      return localMeta.days.isNotEmpty || (localMeta.coverUrl ?? '').isNotEmpty
          ? localMeta
          : null;
    }
  }

  Future<List<LessonModel>> fetchLessons({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    final localLessons = await _local.getLessons(
      lang: lang,
      quarterlyId: quarterlyId,
    );
    final hasMissingDate = localLessons.any(
      (l) => l.startDate == null || l.endDate == null,
    );
    final hasInvalidIds = localLessons.any((l) {
      final n = int.tryParse(l.lessonId);
      return n == null || n < 1 || n > 13;
    });

    if (localLessons.isNotEmpty) {
      // Offline-first real: return local immediately and refresh in background only if needed.
      if (hasMissingDate || hasInvalidIds) {
        unawaited(syncQuarterlyChanges(quarterlyId: quarterlyId, lang: lang));
      }
      return localLessons;
    }

    try {
      final remoteList = await _fetchLessonsRemote(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      final detailLessons = await _fetchLessonsFromQuarterlyDetail(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      final merged = _mergeLessons(
        primary: detailLessons,
        fallback: remoteList,
      );
      if (merged.isNotEmpty) {
        await _local.upsertLessons(
          lang: lang,
          quarterlyId: quarterlyId,
          lessons: merged,
        );
        return merged;
      }
    } on DioException {
      // Offline, keep local lessons.
    }

    return localLessons;
  }

  Future<List<DayModel>> fetchDays({
    required String quarterlyId,
    required String lessonId,
    String lang = 'es',
  }) async {
    final localDays = await _local.getDays(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
    );
    if (localDays.isNotEmpty) {
      return localDays;
    }

    try {
      final remote = await _fetchDaysRemote(
        quarterlyId: quarterlyId,
        lessonId: lessonId,
        lang: lang,
      );
      if (remote.isNotEmpty) {
        await _local.upsertDays(
          lang: lang,
          quarterlyId: quarterlyId,
          lessonId: lessonId,
          days: remote,
        );
      }
      return remote;
    } on DioException {
      return <DayModel>[];
    }
  }

  Future<Map<String, dynamic>> fetchDayRead({
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    String lang = 'es',
  }) async {
    var local = await _local.getDayRead(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
    );

    if (local != null) return local;

    final remote = await _fetchDayReadRemote(
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
      lang: lang,
    );
    await _local.upsertDayRead(
      lang: lang,
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
      readJson: remote,
      updatedAt: DateTime.now().toUtc(),
    );
    return remote;
  }

  Future<void> syncAllDownloadedQuarterliesChanges({
    String lang = 'es',
  }) async {}

  Future<int> syncAllQuarterliesCatalog({String lang = 'es'}) async {
    try {
      final quarterlies = await _fetchQuarterliesRemote(lang: lang);
      if (quarterlies.isNotEmpty) {
        await _local.upsertQuarterlies(lang: lang, quarterlies: quarterlies);
      }

      await _local.setMeta(
        key: '$_quarterliesRefreshKeyPrefix$lang',
        value: DateTime.now().toUtc().toIso8601String(),
      );

      return quarterlies.length;
    } on DioException {
      return 0;
    }
  }

  Future<void> syncQuarterlyBulk({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    try {
      final lessons = await _fetchLessonsFromQuarterlyDetail(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      if (lessons.isNotEmpty) {
        await _local.upsertLessons(
          lang: lang,
          quarterlyId: quarterlyId,
          lessons: lessons,
        );
      }

      final splash = await fetchQuarterlyHeroImage(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      if (splash != null) {
        final localQuarterly = await _local.getQuarterlyById(
          lang: lang,
          quarterlyId: quarterlyId,
        );
        if (localQuarterly != null) {
          await _local.upsertQuarterlies(
            lang: lang,
            quarterlies: [localQuarterly.copyWith(splashUrl: splash)],
          );
        }
      }

      for (final lesson in lessons) {
        final meta = await _tryFetchLessonMetaRemote(
          quarterlyId: quarterlyId,
          lessonId: lesson.lessonId,
          lang: lang,
        );
        if (meta != null) {
          await _persistLessonMeta(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            meta: meta,
          );
        }
        final days = (meta?.days ?? const <LessonDayMeta>[])
            .map(
              (d) =>
                  DayModel(dayId: d.dayId, title: d.title, dayDate: d.dayDate),
            )
            .toList();
        final resolvedDays = days.isNotEmpty
            ? days
            : await _fetchDaysRemote(
                quarterlyId: quarterlyId,
                lessonId: lesson.lessonId,
                lang: lang,
              );
        if (resolvedDays.isNotEmpty) {
          await _local.upsertDays(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            days: resolvedDays,
          );
        }

        for (final day in resolvedDays) {
          final read = await _fetchDayReadRemote(
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            dayId: day.dayId,
            lang: lang,
          );
          await _local.upsertDayRead(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            dayId: day.dayId,
            readJson: read,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      }

      await _local.setLastSync(
        lang: lang,
        quarterlyId: quarterlyId,
        value: DateTime.now().toUtc(),
      );
    } on DioException {
      // Offline: use local cache only.
    }
  }

  Future<void> syncQuarterlyChanges({
    required String quarterlyId,
    String lang = 'es',
  }) async {
    try {
      final remoteList = await _fetchLessonsRemote(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      final detailLessons = await _fetchLessonsFromQuarterlyDetail(
        quarterlyId: quarterlyId,
        lang: lang,
      );
      final remoteLessons = _mergeLessons(
        primary: detailLessons,
        fallback: remoteList,
      );

      if (remoteLessons.isEmpty) return;

      final localLessons = await _local.getLessons(
        lang: lang,
        quarterlyId: quarterlyId,
      );
      final localLessonById = <String, LessonModel>{
        for (final lesson in localLessons) lesson.lessonId: lesson,
      };

      final changedLessonIds = <String>{};
      for (final remote in remoteLessons) {
        final local = localLessonById[remote.lessonId];
        if (_lessonNeedsSync(local, remote)) {
          changedLessonIds.add(remote.lessonId);
        }
      }

      if (changedLessonIds.isNotEmpty ||
          localLessons.length != remoteLessons.length) {
        await _local.upsertLessons(
          lang: lang,
          quarterlyId: quarterlyId,
          lessons: remoteLessons,
        );
      }

      for (final lesson in remoteLessons) {
        final meta = await _tryFetchLessonMetaRemote(
          quarterlyId: quarterlyId,
          lessonId: lesson.lessonId,
          lang: lang,
        );
        if (meta != null) {
          await _persistLessonMeta(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            meta: meta,
          );
        }

        final localDays = await _local.getDays(
          lang: lang,
          quarterlyId: quarterlyId,
          lessonId: lesson.lessonId,
        );
        final localDayById = <String, DayModel>{
          for (final d in localDays) d.dayId: d,
        };

        final remoteDays = (meta?.days ?? const <LessonDayMeta>[])
            .map(
              (d) =>
                  DayModel(dayId: d.dayId, title: d.title, dayDate: d.dayDate),
            )
            .toList();
        final resolvedRemoteDays = remoteDays.isNotEmpty
            ? remoteDays
            : await _fetchDaysRemote(
                quarterlyId: quarterlyId,
                lessonId: lesson.lessonId,
                lang: lang,
              );
        if (resolvedRemoteDays.isEmpty) continue;

        final daysChanged = _daysNeedSync(
          localDays: localDays,
          remoteDays: resolvedRemoteDays,
        );
        if (daysChanged) {
          await _local.upsertDays(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            days: resolvedRemoteDays,
          );
        }

        for (final day in resolvedRemoteDays) {
          final localRead = await _local.getDayRead(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            dayId: day.dayId,
          );
          final localDay = localDayById[day.dayId];
          final dayLooksUpdated = _dayLooksUpdated(
            localDay: localDay,
            remoteDay: day,
          );
          final shouldRefreshRead =
              localRead == null ||
              changedLessonIds.contains(lesson.lessonId) ||
              dayLooksUpdated;

          if (!shouldRefreshRead) continue;

          final read = await _fetchDayReadRemote(
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            dayId: day.dayId,
            lang: lang,
          );
          await _local.upsertDayRead(
            lang: lang,
            quarterlyId: quarterlyId,
            lessonId: lesson.lessonId,
            dayId: day.dayId,
            readJson: read,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      }

      await _local.setLastSync(
        lang: lang,
        quarterlyId: quarterlyId,
        value: DateTime.now().toUtc(),
      );
    } on DioException {
      // Offline: keep cached data.
    }
  }

  bool _lessonNeedsSync(LessonModel? local, LessonModel remote) {
    if (local == null) return true;
    final sameTitle = local.title.trim() == remote.title.trim();
    final sameStart = _sameDate(local.startDate, remote.startDate);
    final sameEnd = _sameDate(local.endDate, remote.endDate);
    final sameCover =
        (local.coverUrl ?? '').trim() == (remote.coverUrl ?? '').trim();
    final remoteUpdated = remote.updatedAt;
    final localUpdated = local.updatedAt;
    final updatedChanged =
        remoteUpdated != null &&
        (localUpdated == null || remoteUpdated.isAfter(localUpdated));
    return !(sameTitle && sameStart && sameEnd && sameCover) || updatedChanged;
  }

  bool _daysNeedSync({
    required List<DayModel> localDays,
    required List<DayModel> remoteDays,
  }) {
    if (localDays.length != remoteDays.length) return true;
    final localById = <String, DayModel>{for (final d in localDays) d.dayId: d};
    for (final remote in remoteDays) {
      final local = localById[remote.dayId];
      if (_dayLooksUpdated(localDay: local, remoteDay: remote)) return true;
    }
    return false;
  }

  bool _dayLooksUpdated({
    required DayModel? localDay,
    required DayModel remoteDay,
  }) {
    if (localDay == null) return true;
    final sameTitle = localDay.title.trim() == remoteDay.title.trim();
    final sameDate = _sameDate(localDay.dayDate, remoteDay.dayDate);
    final remoteUpdated = remoteDay.updatedAt;
    final localUpdated = localDay.updatedAt;
    final updatedChanged =
        remoteUpdated != null &&
        (localUpdated == null || remoteUpdated.isAfter(localUpdated));
    return !(sameTitle && sameDate) || updatedChanged;
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<QuarterlyModel>> _fetchQuarterliesRemote({
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/quarterlies',
      queryParameters: {'lang': lang},
    );

    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => QuarterlyModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<LessonModel>> _fetchLessonsRemote({
    required String quarterlyId,
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/quarterlies/$quarterlyId/lessons',
      queryParameters: {'lang': lang},
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => LessonModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DayModel>> _fetchDaysRemote({
    required String quarterlyId,
    required String lessonId,
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/quarterlies/$quarterlyId/lessons/$lessonId/days',
      queryParameters: {'lang': lang},
    );
    final data = response.data ?? <dynamic>[];
    return data
        .map((item) => DayModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _fetchDayReadRemote({
    required String quarterlyId,
    required String lessonId,
    required String dayId,
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/quarterlies/$quarterlyId/lessons/$lessonId/days/$dayId/read',
      queryParameters: {'lang': lang},
    );
    return response.data ?? <String, dynamic>{};
  }

  String? _extractQuarterlyHeroImage(Map<String, dynamic> data) {
    final raw = (data['raw'] is Map<String, dynamic>)
        ? data['raw'] as Map<String, dynamic>
        : null;
    final quarterly = (raw != null && raw['quarterly'] is Map<String, dynamic>)
        ? raw['quarterly'] as Map<String, dynamic>
        : null;

    final candidates = <Object?>[quarterly?['splash'], quarterly?['cover']];

    for (final item in candidates) {
      final url = (item ?? '').toString().trim();
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  String? _extractQuarterlyDescription(Map<String, dynamic> data) {
    final raw = (data['raw'] is Map<String, dynamic>)
        ? data['raw'] as Map<String, dynamic>
        : null;
    final quarterly = (raw != null && raw['quarterly'] is Map<String, dynamic>)
        ? raw['quarterly'] as Map<String, dynamic>
        : null;
    final introduction = (quarterly?['introduction'] ?? '').toString().trim();
    final description = (quarterly?['description'] ?? '').toString().trim();
    final text = introduction.isNotEmpty ? introduction : description;
    if (text.isEmpty) return null;
    return _cleanupIntroduction(text);
  }

  String? _extractQuarterlyAuthor(Map<String, dynamic> data) {
    final raw = (data['raw'] is Map<String, dynamic>)
        ? data['raw'] as Map<String, dynamic>
        : null;
    final quarterly = (raw != null && raw['quarterly'] is Map<String, dynamic>)
        ? raw['quarterly'] as Map<String, dynamic>
        : null;
    final credits = (quarterly != null && quarterly['credits'] is List)
        ? (quarterly['credits'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
        : <Map<String, dynamic>>[];

    if (credits.isEmpty) return null;

    for (final item in credits) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final value = (item['value'] ?? '').toString().trim();
      if (value.isEmpty) continue;
      if (name.contains('autor') || name.contains('author')) return value;
    }

    for (final item in credits) {
      final value = (item['value'] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  String _cleanupIntroduction(String input) {
    var out = input.trim();
    out = out.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    out = out.replaceAll('_', '');
    return out.trim();
  }

  String? _extractLessonCoverImage(Map<String, dynamic> data) {
    final raw = _extractRawMap(data);
    final lesson = (raw != null && raw['lesson'] is Map<String, dynamic>)
        ? raw['lesson'] as Map<String, dynamic>
        : null;

    final candidates = <Object?>[
      lesson?['cover'],
      lesson?['image'],
      lesson?['hero'],
      raw?['cover'],
      raw?['image'],
      data['CoverUrl'],
      data['coverUrl'],
    ];

    for (final item in candidates) {
      final url = (item ?? '').toString().trim();
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  LessonDetailMeta _extractLessonDetailMeta(Map<String, dynamic> data) {
    final raw = _extractRawMap(data);
    final lesson = (raw != null && raw['lesson'] is Map<String, dynamic>)
        ? raw['lesson'] as Map<String, dynamic>
        : null;
    final daysRaw = (raw != null && raw['days'] is List)
        ? (raw['days'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final days = daysRaw.map((item) {
      return LessonDayMeta(
        dayId: (item['id'] ?? '').toString().padLeft(2, '0'),
        title: (item['title'] ?? 'Dia').toString(),
        dayDate: _parseDateFlexible(item['date']),
        path: (item['path'] ?? '').toString(),
        readPath: (item['read_path'] ?? '').toString(),
      );
    }).toList()..sort((a, b) => a.dayId.compareTo(b.dayId));

    return LessonDetailMeta(
      coverUrl: _normalizeUrl(lesson?['cover']),
      days: days,
    );
  }

  Map<String, dynamic>? _extractRawMap(Map<String, dynamic> data) {
    if (data['raw'] is Map<String, dynamic>) {
      return data['raw'] as Map<String, dynamic>;
    }

    final rawJsonText = (data['RawJson'] ?? data['rawJson'] ?? '')
        .toString()
        .trim();
    if (rawJsonText.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawJsonText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed raw json payload.
    }
    return null;
  }

  DateTime? _parseDateFlexible(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String? _normalizeUrl(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.startsWith('http')) return text;
    return null;
  }

  Future<LessonDetailMeta> _fetchLessonMetaRemote({
    required String quarterlyId,
    required String lessonId,
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/quarterlies/$quarterlyId/lessons/$lessonId',
      queryParameters: {'lang': lang},
    );
    final data = response.data ?? <String, dynamic>{};
    return _extractLessonDetailMeta(data);
  }

  Future<LessonDetailMeta?> _tryFetchLessonMetaRemote({
    required String quarterlyId,
    required String lessonId,
    required String lang,
  }) async {
    try {
      return await _fetchLessonMetaRemote(
        quarterlyId: quarterlyId,
        lessonId: lessonId,
        lang: lang,
      );
    } on DioException {
      return null;
    }
  }

  Future<void> _persistLessonMeta({
    required String lang,
    required String quarterlyId,
    required String lessonId,
    required LessonDetailMeta meta,
  }) async {
    final normalizedLessonId = lessonId.padLeft(2, '0');
    if ((meta.coverUrl ?? '').isNotEmpty) {
      final localLesson = await _local.getLessonById(
        lang: lang,
        quarterlyId: quarterlyId,
        lessonId: normalizedLessonId,
      );
      if (localLesson != null && localLesson.coverUrl != meta.coverUrl) {
        await _local.upsertLessons(
          lang: lang,
          quarterlyId: quarterlyId,
          lessons: [localLesson.copyWith(coverUrl: meta.coverUrl)],
        );
      }
    }

    if (meta.days.isNotEmpty) {
      final dayModels = meta.days
          .map(
            (d) => DayModel(dayId: d.dayId, title: d.title, dayDate: d.dayDate),
          )
          .toList();
      await _local.upsertDays(
        lang: lang,
        quarterlyId: quarterlyId,
        lessonId: normalizedLessonId,
        days: dayModels,
      );
    }
  }

  Future<List<LessonModel>> _fetchLessonsFromQuarterlyDetail({
    required String quarterlyId,
    required String lang,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/quarterlies/$quarterlyId',
      queryParameters: {'lang': lang},
    );
    final data = response.data ?? <String, dynamic>{};
    final raw = (data['raw'] is Map<String, dynamic>)
        ? data['raw'] as Map<String, dynamic>
        : null;
    final lessons = (raw != null && raw['lessons'] is List)
        ? (raw['lessons'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final parsed = lessons.map(LessonModel.fromJson).toList();
    parsed.sort((a, b) => a.lessonId.compareTo(b.lessonId));
    return parsed;
  }

  List<LessonModel> _mergeLessons({
    required List<LessonModel> primary,
    required List<LessonModel> fallback,
  }) {
    final merged = <String, LessonModel>{
      for (final item in fallback) item.lessonId: item,
    };
    for (final item in primary) {
      final previous = merged[item.lessonId];
      merged[item.lessonId] = (previous ?? item).copyWith(
        title: item.title,
        startDate: item.startDate ?? previous?.startDate,
        endDate: item.endDate ?? previous?.endDate,
        coverUrl: item.coverUrl ?? previous?.coverUrl,
      );
    }
    final output = merged.values.toList();
    output.sort((a, b) => a.lessonId.compareTo(b.lessonId));
    return output;
  }

  Future<bool> _shouldRefreshQuarterlies(String lang) async {
    final value = await _local.getMeta('$_quarterliesRefreshKeyPrefix$lang');
    if (value == null || value.isEmpty) return true;
    final last = DateTime.tryParse(value);
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last.toUtc()) > _refreshInterval;
  }
}
