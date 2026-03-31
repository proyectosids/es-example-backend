import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/typography_preset.dart';
import '../../data/models/day_model.dart';
import '../../data/models/lesson_detail_meta.dart';
import '../../data/models/lesson_model.dart';
import '../providers/catalog_providers.dart';
import '../widgets/read_content_view.dart';

class WeekReaderScreen extends ConsumerStatefulWidget {
  const WeekReaderScreen({
    super.key,
    required this.quarterlyId,
    required this.lesson,
  });

  final String quarterlyId;
  final LessonModel lesson;

  @override
  ConsumerState<WeekReaderScreen> createState() => _WeekReaderScreenState();
}

class _WeekReaderScreenState extends ConsumerState<WeekReaderScreen> {
  PageController? _pageController;
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(
      daysProvider((
        quarterlyId: widget.quarterlyId,
        lessonId: widget.lesson.lessonId,
        lang: 'es',
      )),
    );
    final lessonMetaAsync = ref.watch(
      lessonDetailMetaProvider((
        quarterlyId: widget.quarterlyId,
        lessonId: widget.lesson.lessonId,
        lang: 'es',
      )),
    );
    final studyMarksAsync = ref.watch(
      lessonStudyMarksProvider((
        quarterlyId: widget.quarterlyId,
        lessonId: widget.lesson.lessonId,
        lang: 'es',
      )),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: daysAsync.when(
        data: (days) {
          final metaDays =
              lessonMetaAsync.valueOrNull?.days ?? const <LessonDayMeta>[];
          final mergedDays = _mergeDays(days, metaDays);

          if (mergedDays.isEmpty) {
            return const Center(
              child: Text(
                'No hay dias cargados para esta leccion.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          _ensureController(mergedDays);

          return PageView.builder(
            controller: _pageController,
            itemCount: mergedDays.length,
            onPageChanged: (index) {
              if (_currentPageIndex != index) {
                setState(() => _currentPageIndex = index);
              }
            },
            itemBuilder: (context, index) {
              final day = mergedDays[index];
              final studyMap =
                  studyMarksAsync.valueOrNull ?? const <String, bool>{};
              final isStudied = studyMap[day.dayId] ?? false;
              return _DayPage(
                quarterlyId: widget.quarterlyId,
                lessonId: widget.lesson.lessonId,
                day: day,
                lessonStartDate: widget.lesson.startDate,
                weekDays: mergedDays,
                currentIndex: _currentPageIndex,
                studiedByDayId: studyMap,
                weeklyCoverUrl:
                    lessonMetaAsync.valueOrNull?.coverUrl ??
                    widget.lesson.coverUrl,
                isStudied: isStudied,
                onGoToDay: (targetIndex) {
                  _pageController?.animateToPage(
                    targetIndex,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
                onToggleStudied: (value) async {
                  final repo = ref.read(catalogRepositoryProvider);
                  await repo.setDayStudied(
                    lang: 'es',
                    quarterlyId: widget.quarterlyId,
                    lessonId: widget.lesson.lessonId,
                    dayId: day.dayId,
                    isStudied: value,
                  );
                  if (!mounted) return;
                  ref.invalidate(
                    lessonStudyMarksProvider((
                      quarterlyId: widget.quarterlyId,
                      lessonId: widget.lesson.lessonId,
                      lang: 'es',
                    )),
                  );
                  ref.invalidate(
                    quarterlyStudyProgressProvider((
                      quarterlyId: widget.quarterlyId,
                      lang: 'es',
                    )),
                  );
                },
                onBack: () => Navigator.pop(context),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF9EA8FF)),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error al cargar dias:\n$error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _ensureController(List<DayModel> days) {
    if (_pageController != null) return;
    final initial = _resolveInitialDayIndex(days);
    _pageController = PageController(initialPage: initial);
    _currentPageIndex = initial;
  }

  int _resolveInitialDayIndex(List<DayModel> days) {
    if (!_isCurrentWeek(widget.lesson)) {
      return 0; // Sabado por defecto para semanas que no son la actual.
    }

    final today = _asDate(DateTime.now());

    for (var i = 0; i < days.length; i++) {
      final dayDate = days[i].dayDate;
      if (dayDate == null) continue;
      if (_sameDate(_asDate(dayDate), today)) return i;
    }

    var bestIndex = 0;
    DateTime? bestDate;
    for (var i = 0; i < days.length; i++) {
      final dayDate = days[i].dayDate;
      if (dayDate == null) continue;
      final date = _asDate(dayDate);
      if (date.isAfter(today)) continue;
      if (bestDate == null || date.isAfter(bestDate)) {
        bestDate = date;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  bool _isCurrentWeek(LessonModel lesson) {
    if (lesson.startDate == null || lesson.endDate == null) return false;
    final now = _asDate(DateTime.now());
    final start = _asDate(lesson.startDate!);
    final end = _asDate(lesson.endDate!);
    return !now.isBefore(start) && !now.isAfter(end);
  }

  DateTime _asDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DayModel> _mergeDays(
    List<DayModel> localDays,
    List<LessonDayMeta> metaDays,
  ) {
    if (metaDays.isEmpty) return localDays;

    final byId = <String, DayModel>{for (final d in localDays) d.dayId: d};
    for (final meta in metaDays) {
      final previous = byId[meta.dayId];
      byId[meta.dayId] = DayModel(
        dayId: meta.dayId,
        title: meta.title.isNotEmpty ? meta.title : (previous?.title ?? 'Dia'),
        dayDate: meta.dayDate ?? previous?.dayDate,
        updatedAt: previous?.updatedAt,
      );
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.dayId.compareTo(b.dayId));
    return merged;
  }
}

class _DayPage extends ConsumerWidget {
  const _DayPage({
    required this.quarterlyId,
    required this.lessonId,
    required this.day,
    required this.lessonStartDate,
    required this.weekDays,
    required this.currentIndex,
    required this.studiedByDayId,
    required this.weeklyCoverUrl,
    required this.isStudied,
    required this.onGoToDay,
    required this.onToggleStudied,
    required this.onBack,
  });

  final String quarterlyId;
  final String lessonId;
  final DayModel day;
  final DateTime? lessonStartDate;
  final List<DayModel> weekDays;
  final int currentIndex;
  final Map<String, bool> studiedByDayId;
  final String? weeklyCoverUrl;
  final bool isStudied;
  final ValueChanged<int> onGoToDay;
  final Future<void> Function(bool) onToggleStudied;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readAsync = ref.watch(
      dayReadProvider((
        quarterlyId: quarterlyId,
        lessonId: lessonId,
        dayId: day.dayId,
        lang: 'es',
      )),
    );

    return readAsync.when(
      data: (read) {
        final heroUrl = weeklyCoverUrl ?? _extractDayHeroImage(read);
        final dayDateTitle = _formatDayDate(
          day.dayDate,
          day.dayId,
          lessonStartDate,
        );

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 460,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (heroUrl != null && heroUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: heroUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _fallbackHero(),
                      )
                    else
                      _fallbackHero(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(0, 0, 0, 0.18),
                            Color.fromRGBO(0, 0, 0, 0.35),
                            Color.fromRGBO(0, 0, 0, 1),
                          ],
                          stops: [0.05, 0.6, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 42,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          _RoundIconButton(
                            icon: Icons.arrow_back,
                            onTap: onBack,
                          ),
                          const Spacer(),
                          _RoundIconButton(
                            icon: Icons.headset_rounded,
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          _RoundIconButton(
                            icon: Icons.ondemand_video_outlined,
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          _RoundIconButton(icon: Icons.more_vert, onTap: () {}),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 106,
                      right: 18,
                      child: _StudyToggleButton(
                        isStudied: isStudied,
                        onPressed: () async => onToggleStudied(!isStudied),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayDateTitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: EsTypePreset.readHeaderDate,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            day.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: EsTypePreset.readHeaderTitle,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _DailyNavigator(
                days: weekDays,
                currentIndex: currentIndex,
                studiedByDayId: studiedByDayId,
                onTapDay: onGoToDay,
              ),
            ),
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ReadContentView(
                    dayTitle: day.title,
                    data: read,
                    showDayTitle: false,
                    showRawJson: false,
                    hideHeaderFields: true,
                    textColor: Colors.white,
                    sectionColor: Colors.white,
                    subtleColor: const Color(0xFFB6BDCF),
                    answerScope: '$quarterlyId|$lessonId|${day.dayId}',
                    loadAnswer: (questionKey) {
                      final repo = ref.read(catalogRepositoryProvider);
                      return repo.getQuestionAnswer(
                        lang: 'es',
                        quarterlyId: quarterlyId,
                        lessonId: lessonId,
                        dayId: day.dayId,
                        questionKey: questionKey,
                      );
                    },
                    saveAnswer: (questionKey, answer) async {
                      final repo = ref.read(catalogRepositoryProvider);
                      await repo.saveQuestionAnswer(
                        lang: 'es',
                        quarterlyId: quarterlyId,
                        lessonId: lessonId,
                        dayId: day.dayId,
                        questionKey: questionKey,
                        answer: answer,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF9EA8FF)),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error al cargar el dia ${day.dayId}:\n$error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _formatDayDate(DateTime? date, String dayId, DateTime? lessonStart) {
    DateTime? resolved = date;

    if (resolved == null && lessonStart != null) {
      final offset = (int.tryParse(dayId) ?? 1) - 1;
      resolved = DateTime(
        lessonStart.year,
        lessonStart.month,
        lessonStart.day,
      ).add(Duration(days: offset < 0 ? 0 : offset));
    }

    if (resolved == null) {
      final weekday = _weekdayFromDayId(dayId);
      return weekday;
    }

    final dateValue = DateTime(resolved.year, resolved.month, resolved.day);
    final weekday = _weekdayFromDayId(
      dayId,
      fallbackFromDate: dateValue.weekday,
    );
    final month = _monthName(dateValue.month);
    return '$weekday, $month ${dateValue.day.toString().padLeft(2, '0')}';
  }

  String _weekdayFromDayId(String dayId, {int? fallbackFromDate}) {
    const byDayId = <String, String>{
      '01': 'SABADO',
      '02': 'DOMINGO',
      '03': 'LUNES',
      '04': 'MARTES',
      '05': 'MIERCOLES',
      '06': 'JUEVES',
      '07': 'VIERNES',
    };
    final normalized = dayId.padLeft(2, '0');
    if (byDayId.containsKey(normalized)) return byDayId[normalized]!;

    if (fallbackFromDate != null) {
      const byWeekday = <int, String>{
        DateTime.monday: 'LUNES',
        DateTime.tuesday: 'MARTES',
        DateTime.wednesday: 'MIERCOLES',
        DateTime.thursday: 'JUEVES',
        DateTime.friday: 'VIERNES',
        DateTime.saturday: 'SABADO',
        DateTime.sunday: 'DOMINGO',
      };
      return byWeekday[fallbackFromDate] ?? 'DIA';
    }
    return 'DIA';
  }

  String _monthName(int month) {
    const monthNames = <int, String>{
      1: 'ENERO',
      2: 'FEBRERO',
      3: 'MARZO',
      4: 'ABRIL',
      5: 'MAYO',
      6: 'JUNIO',
      7: 'JULIO',
      8: 'AGOSTO',
      9: 'SEPTIEMBRE',
      10: 'OCTUBRE',
      11: 'NOVIEMBRE',
      12: 'DICIEMBRE',
    };
    return monthNames[month] ?? '';
  }

  String? _extractDayHeroImage(Map<String, dynamic> read) {
    final resources = (read['resources'] is Map<String, dynamic>)
        ? read['resources'] as Map<String, dynamic>
        : null;
    final cover =
        (resources != null && resources['cover'] is Map<String, dynamic>)
        ? resources['cover'] as Map<String, dynamic>
        : null;
    final images = (read['images'] is Map<String, dynamic>)
        ? read['images'] as Map<String, dynamic>
        : null;

    final candidates = <Object?>[
      read['image'],
      read['hero'],
      read['cover'],
      read['background'],
      images?['hero'],
      images?['cover'],
      resources?['hero'],
      cover?['landscape'],
      cover?['portrait'],
    ];

    for (final item in candidates) {
      final value = (item ?? '').toString().trim();
      if (value.startsWith('http')) return value;
    }
    return null;
  }
}

Widget _fallbackHero() {
  return Container(
    color: const Color(0xFF111722),
    child: const Center(
      child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 58),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(0, 0, 0, 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _StudyToggleButton extends StatelessWidget {
  const _StudyToggleButton({required this.isStudied, required this.onPressed});

  final bool isStudied;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isStudied
                ? const Color.fromRGBO(16, 104, 70, 0.88)
                : const Color.fromRGBO(0, 0, 0, 0.52),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isStudied
                  ? const Color(0xFF56D49A)
                  : const Color(0xFF5A6072),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStudied ? Icons.check_circle : Icons.bookmark_border_rounded,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isStudied ? 'Estudiado' : 'Marcar estudiado',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyNavigator extends StatelessWidget {
  const _DailyNavigator({
    required this.days,
    required this.currentIndex,
    required this.studiedByDayId,
    required this.onTapDay,
  });

  final List<DayModel> days;
  final int currentIndex;
  final Map<String, bool> studiedByDayId;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(days.length, (index) {
            final day = days[index];
            final isCurrent = index == currentIndex;
            final isStudied = studiedByDayId[day.dayId] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTapDay(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFF1D2E53)
                        : const Color(0xFF111723),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF85A0F5)
                          : const Color(0xFF262E42),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.dayId,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isStudied
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: isStudied
                            ? const Color(0xFF56D49A)
                            : const Color(0xFF6B7284),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
