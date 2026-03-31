class DayModel {
  const DayModel({
    required this.dayId,
    required this.title,
    this.dayDate,
    this.updatedAt,
  });

  final String dayId;
  final String title;
  final DateTime? dayDate;
  final DateTime? updatedAt;

  factory DayModel.fromJson(Map<String, dynamic> json) {
    return DayModel(
      dayId: _normalizeDayId(
        json['DayId'] ?? json['dayId'] ?? json['id'] ?? json['index'],
      ),
      title: (json['Title'] ?? json['title'] ?? 'Dia').toString(),
      dayDate: _parseDateFlexible(
        json['DayDate'] ?? json['dayDate'] ?? json['date'] ?? json['day_date'],
      ),
      updatedAt: DateTime.tryParse(
        (json['UpdatedAt'] ?? json['updatedAt'] ?? '').toString(),
      ),
    );
  }

  factory DayModel.fromDb(Map<String, Object?> row) {
    return DayModel(
      dayId: (row['dayId'] ?? '').toString().padLeft(2, '0'),
      title: (row['title'] ?? 'Dia').toString(),
      dayDate: DateTime.tryParse((row['dayDate'] ?? '').toString()),
      updatedAt: DateTime.tryParse((row['updatedAt'] ?? '').toString()),
    );
  }

  Map<String, Object?> toDb({
    required String lang,
    required String quarterlyId,
    required String lessonId,
  }) {
    return <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'lessonId': lessonId,
      'dayId': dayId,
      'dayDate': dayDate?.toIso8601String(),
      'title': title,
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static String _normalizeDayId(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '00';
    final numeric = int.tryParse(text);
    if (numeric != null) return numeric.toString().padLeft(2, '0');
    return text.padLeft(2, '0');
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
}
