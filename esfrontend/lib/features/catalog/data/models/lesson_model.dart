class LessonModel {
  const LessonModel({
    required this.lessonId,
    required this.title,
    this.startDate,
    this.endDate,
    this.coverUrl,
    this.updatedAt,
  });

  final String lessonId;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverUrl;
  final DateTime? updatedAt;

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    final rawLessonId =
        json['LessonId'] ??
        json['lessonId'] ??
        json['id'] ??
        json['number'] ??
        json['index'];

    return LessonModel(
      lessonId: _normalizeLessonId(rawLessonId),
      title: (json['Title'] ?? json['title'] ?? json['lesson'] ?? 'Leccion')
          .toString(),
      startDate: _parseDateFlexible(
        json['StartDate'] ??
            json['startDate'] ??
            json['start_date'] ??
            json['start'] ??
            json['date_start'],
      ),
      endDate: _parseDateFlexible(
        json['EndDate'] ??
            json['endDate'] ??
            json['end_date'] ??
            json['end'] ??
            json['date_end'],
      ),
      coverUrl: _normalizeUrl(
        json['cover'] ??
            json['Cover'] ??
            json['coverUrl'] ??
            json['CoverUrl'] ??
            json['image'] ??
            json['hero'],
      ),
      updatedAt: DateTime.tryParse(
        (json['UpdatedAt'] ?? json['updatedAt'] ?? '').toString(),
      ),
    );
  }

  factory LessonModel.fromDb(Map<String, Object?> row) {
    return LessonModel(
      lessonId: (row['lessonId'] ?? '').toString().padLeft(2, '0'),
      title: (row['title'] ?? 'Leccion').toString(),
      startDate: DateTime.tryParse((row['startDate'] ?? '').toString()),
      endDate: DateTime.tryParse((row['endDate'] ?? '').toString()),
      coverUrl: _normalizeUrl(row['coverUrl']),
      updatedAt: DateTime.tryParse((row['updatedAt'] ?? '').toString()),
    );
  }

  Map<String, Object?> toDb({
    required String lang,
    required String quarterlyId,
  }) {
    return <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lessonId': lessonId,
      'title': title,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'coverUrl': coverUrl,
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  LessonModel copyWith({
    String? lessonId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? coverUrl,
    DateTime? updatedAt,
  }) {
    return LessonModel(
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coverUrl: coverUrl ?? this.coverUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _normalizeUrl(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.startsWith('http')) return text;
    return null;
  }

  static DateTime? _parseDateFlexible(Object? value) {
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

  static String _normalizeLessonId(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '00';
    final numeric = int.tryParse(text);
    if (numeric != null) return numeric.toString().padLeft(2, '0');
    return text.padLeft(2, '0');
  }
}
