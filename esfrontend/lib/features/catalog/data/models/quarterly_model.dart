class QuarterlyModel {
  const QuarterlyModel({
    required this.quarterlyId,
    required this.title,
    required this.coverUrl,
    this.splashUrl,
    this.startDate,
    this.endDate,
    this.updatedAt,
  });

  final String quarterlyId;
  final String title;
  final String coverUrl;
  final String? splashUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? updatedAt;

  factory QuarterlyModel.fromJson(Map<String, dynamic> json) {
    return QuarterlyModel(
      quarterlyId: (json['QuarterlyId'] ?? json['quarterlyId'] ?? '').toString(),
      title: (json['Title'] ?? json['title'] ?? 'Sin titulo').toString(),
      coverUrl: (json['CoverUrl'] ?? json['coverUrl'] ?? '').toString(),
      splashUrl: _normalizeUrl(
        json['splashUrl'] ?? json['SplashUrl'] ?? json['splash'] ?? json['hero'],
      ),
      startDate: _parseDateFlexible(json['StartDate'] ?? json['startDate'] ?? json['start_date']),
      endDate: _parseDateFlexible(json['EndDate'] ?? json['endDate'] ?? json['end_date']),
      updatedAt: DateTime.tryParse((json['UpdatedAt'] ?? '').toString()),
    );
  }

  factory QuarterlyModel.fromDb(Map<String, Object?> row) {
    return QuarterlyModel(
      quarterlyId: (row['quarterlyId'] ?? '').toString(),
      title: (row['title'] ?? 'Sin titulo').toString(),
      coverUrl: (row['coverUrl'] ?? '').toString(),
      splashUrl: _normalizeUrl(row['splashUrl']),
      startDate: DateTime.tryParse((row['startDate'] ?? '').toString()),
      endDate: DateTime.tryParse((row['endDate'] ?? '').toString()),
      updatedAt: DateTime.tryParse((row['updatedAt'] ?? '').toString()),
    );
  }

  Map<String, Object?> toDb({required String lang}) {
    return <String, Object?>{
      'lang': lang,
      'quarterlyId': quarterlyId,
      'title': title,
      'coverUrl': coverUrl,
      'splashUrl': splashUrl,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
    };
  }

  QuarterlyModel copyWith({
    String? quarterlyId,
    String? title,
    String? coverUrl,
    String? splashUrl,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return QuarterlyModel(
      quarterlyId: quarterlyId ?? this.quarterlyId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      splashUrl: splashUrl ?? this.splashUrl,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
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
}
