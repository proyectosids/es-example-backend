class LessonDetailMeta {
  const LessonDetailMeta({
    required this.coverUrl,
    required this.days,
  });

  final String? coverUrl;
  final List<LessonDayMeta> days;
}

class LessonDayMeta {
  const LessonDayMeta({
    required this.dayId,
    required this.title,
    required this.dayDate,
    this.path,
    this.readPath,
  });

  final String dayId;
  final String title;
  final DateTime? dayDate;
  final String? path;
  final String? readPath;
}
