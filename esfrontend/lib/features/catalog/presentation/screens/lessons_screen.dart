import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/typography_preset.dart';
import '../../../auth/presentation/access/access_control.dart';
import '../../data/models/lesson_model.dart';
import '../../data/models/quarterly_model.dart';
import '../providers/catalog_providers.dart';
import 'week_reader_screen.dart';

class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key, required this.quarterly});

  final QuarterlyModel quarterly;

  List<LessonModel> _complete13Lessons(List<LessonModel> apiLessons) {
    final map = {for (final lesson in apiLessons) lesson.lessonId: lesson};
    return List.generate(13, (index) {
      final id = (index + 1).toString().padLeft(2, '0');
      return map[id] ??
          LessonModel(lessonId: id, title: 'Leccion $id (pendiente)');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canOpenReader = ref.watch(
      canOpenScreenProvider(AppScreenKey.mobileLessonReader),
    );
    final canSyncExecute = ref.watch(
      hasPermissionProvider(AppPermission.syncExecute),
    );
    final lessonsAsync = ref.watch(
      lessonsProvider((quarterlyId: quarterly.quarterlyId, lang: 'es')),
    );
    final heroImageAsync = ref.watch(
      quarterlyHeroImageProvider((
        quarterlyId: quarterly.quarterlyId,
        lang: 'es',
      )),
    );
    final descriptionAsync = ref.watch(
      quarterlyDescriptionProvider((
        quarterlyId: quarterly.quarterlyId,
        lang: 'es',
      )),
    );
    final authorAsync = ref.watch(
      quarterlyAuthorProvider((quarterlyId: quarterly.quarterlyId, lang: 'es')),
    );
    final progressAsync = ref.watch(
      quarterlyStudyProgressProvider((
        quarterlyId: quarterly.quarterlyId,
        lang: 'es',
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050916),
      body: lessonsAsync.when(
        data: (lessons) {
          final heroImageUrl = heroImageAsync.valueOrNull ?? quarterly.coverUrl;
          final normalized = _complete13Lessons(lessons);
          final hasAvailableLesson = lessons.isNotEmpty;
          final firstAvailable = normalized.firstWhere(
            (item) => lessons.any((l) => l.lessonId == item.lessonId),
            orElse: () => normalized.first,
          );

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                backgroundColor: const Color(0xFF090E1D),
                expandedHeight: 480,
                automaticallyImplyLeading: false,
                leadingWidth: 68,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                  child: _HeroActionIcon(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                actions: [
                  if (canSyncExecute)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 6,
                        top: 6,
                        bottom: 6,
                      ),
                      child: _HeroActionIcon(
                        icon: Icons.download_for_offline_outlined,
                        onTap: () async {
                          final container = ProviderScope.containerOf(
                            context,
                            listen: false,
                          );
                          final repo = ref.read(catalogRepositoryProvider);
                          await repo.syncQuarterlyBulk(
                            quarterlyId: quarterly.quarterlyId,
                            lang: 'es',
                          );
                          container.invalidate(
                            lessonsProvider((
                              quarterlyId: quarterly.quarterlyId,
                              lang: 'es',
                            )),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Trimestre descargado para modo offline.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (canSyncExecute)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 6,
                        top: 6,
                        bottom: 6,
                      ),
                      child: _HeroActionIcon(
                        icon: Icons.sync_outlined,
                        onTap: () async {
                          final container = ProviderScope.containerOf(
                            context,
                            listen: false,
                          );
                          final repo = ref.read(catalogRepositoryProvider);
                          await repo.syncQuarterlyChanges(
                            quarterlyId: quarterly.quarterlyId,
                            lang: 'es',
                          );
                          container.invalidate(
                            lessonsProvider((
                              quarterlyId: quarterly.quarterlyId,
                              lang: 'es',
                            )),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cambios sincronizados.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: 12,
                      top: 6,
                      bottom: 6,
                    ),
                    child: _HeroActionIcon(
                      icon: Icons.share_outlined,
                      onTap: () {},
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (heroImageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: heroImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _fallbackCover(),
                        )
                      else
                        _fallbackCover(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromRGBO(0, 0, 0, 0.18),
                              Color.fromRGBO(0, 0, 0, 0.28),
                              Color.fromRGBO(5, 9, 22, 1),
                            ],
                            stops: [0.1, 0.58, 1],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                quarterly.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: EsTypePreset.quarterHeroTitle,
                                  fontWeight: FontWeight.w700,
                                  height: 1.02,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _quarterRangeText(quarterly),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: EsTypePreset.quarterHeroRange,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: 260,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B3B39),
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed:
                                      !hasAvailableLesson || !canOpenReader
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => WeekReaderScreen(
                                                quarterlyId:
                                                    quarterly.quarterlyId,
                                                lesson: firstAvailable,
                                              ),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    'LEER',
                                    style: TextStyle(
                                      fontSize: EsTypePreset.quarterReadButton,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if ((descriptionAsync.valueOrNull ?? '')
                                  .isNotEmpty)
                                _QuarterlyDescriptionPreview(
                                  title: quarterly.title,
                                  description: descriptionAsync.valueOrNull!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: normalized.length,
                separatorBuilder: (_, index) => const Divider(
                  color: Color(0xFF1E2435),
                  height: 1,
                  thickness: 1,
                ),
                itemBuilder: (context, index) {
                  final lesson = normalized[index];
                  final isAvailable = lessons.any(
                    (l) => l.lessonId == lesson.lessonId,
                  );
                  final studiedByLesson =
                      progressAsync.valueOrNull ?? const <String, int>{};
                  final studiedCount = (studiedByLesson[lesson.lessonId] ?? 0)
                      .clamp(0, 7);
                  final weekNumber =
                      int.tryParse(lesson.lessonId) ?? (index + 1);

                  return InkWell(
                    onTap: !isAvailable || !canOpenReader
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => WeekReaderScreen(
                                  quarterlyId: quarterly.quarterlyId,
                                  lesson: lesson,
                                ),
                              ),
                            );
                          },
                    child: Container(
                      color: const Color(0xFF060A17),
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              '$weekNumber',
                              style: TextStyle(
                                color: isAvailable
                                    ? const Color(0xFF56607B)
                                    : const Color(0xFF31384B),
                                fontWeight: FontWeight.w700,
                                fontSize: EsTypePreset.quarterLessonIndex,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lesson.title,
                                        style: TextStyle(
                                          color: isAvailable
                                              ? Colors.white
                                              : Colors.white54,
                                          fontSize:
                                              EsTypePreset.quarterLessonTitle,
                                          fontWeight: FontWeight.w500,
                                          height: 1.18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StudyProgressChip(
                                      studiedCount: studiedCount,
                                      totalDays: 7,
                                      dimmed: !isAvailable,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lessonDateRange(lesson),
                                  style: const TextStyle(
                                    color: Color(0xFFB5BAC9),
                                    fontSize: EsTypePreset.quarterLessonDate,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isAvailable)
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF4C566F),
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFF0C1018),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _OptionItem(
                        icon: Icons.headset_rounded,
                        title: 'Audio',
                        description:
                            'Escuche la leccion sobre la marcha con la version de audio',
                      ),
                      const SizedBox(height: 18),
                      const _OptionItem(
                        icon: Icons.ondemand_video_outlined,
                        title: 'Video',
                        description:
                            'Vea la discusion semanal de la leccion para profundizar su estudio',
                      ),
                      const SizedBox(height: 18),
                      const _OptionItem(
                        icon: Icons.library_books_outlined,
                        title: 'Diseño original',
                        description:
                            'Mejore su estudio de la leccion utilizando el diseño de impresion original con numerosas herramientas de anotacion.',
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Autor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: EsTypePreset.quarterAuthorLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (authorAsync.valueOrNull ?? '').isNotEmpty
                            ? authorAsync.valueOrNull!
                            : 'Autor no disponible',
                        style: const TextStyle(
                          color: Color(0xFFC0C5D4),
                          fontSize: EsTypePreset.quarterAuthorValue,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '© Conferencia General de los Adventistas del Septimo Dia',
                        style: TextStyle(
                          color: Color(0xFF7E879C),
                          fontSize: EsTypePreset.quarterCopyright,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF9EA8FF)),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Error al cargar lecciones:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  String _quarterRangeText(QuarterlyModel quarterly) {
    final start = quarterly.startDate;
    final end = quarterly.endDate;
    if (start == null || end == null) {
      return quarterly.quarterlyId;
    }

    if (start.year == end.year) {
      return '${_monthName(start.month)} · ${_monthName(end.month)} ${start.year}';
    }
    return '${_monthName(start.month)} ${start.year} · ${_monthName(end.month)} ${end.year}';
  }

  String _lessonDateRange(LessonModel lesson) {
    final start = lesson.startDate;
    final end = lesson.endDate;
    if (start == null || end == null) return 'Fecha no disponible';
    return '${_monthAbbr(start.month)} ${_dd(start.day)} - ${_monthAbbr(end.month)} ${_dd(end.day)}';
  }

  String _dd(int day) => day.toString().padLeft(2, '0');

  String _monthAbbr(int month) {
    const months = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    if (month < 1 || month > 12) return '--';
    return months[month - 1];
  }

  String _monthName(int month) {
    const months = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    if (month < 1 || month > 12) return '--';
    return months[month - 1];
  }
}

Widget _fallbackCover() {
  return Container(
    color: const Color(0xFF13213F),
    child: const Center(
      child: Icon(Icons.menu_book_rounded, size: 64, color: Colors.white70),
    ),
  );
}

class _HeroActionIcon extends StatelessWidget {
  const _HeroActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(0, 0, 0, 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 30, color: const Color(0xFFDCE2F2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: EsTypePreset.quarterOptionTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFFBAC0D1),
                  fontSize: EsTypePreset.quarterOptionBody,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyProgressChip extends StatelessWidget {
  const _StudyProgressChip({
    required this.studiedCount,
    required this.totalDays,
    required this.dimmed,
  });

  final int studiedCount;
  final int totalDays;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final fg = dimmed ? const Color(0xFF9BA2B5) : Colors.white;
    final bg = dimmed
        ? const Color.fromRGBO(47, 55, 77, 0.55)
        : const Color.fromRGBO(21, 117, 90, 0.88);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dimmed ? const Color(0xFF49516A) : const Color(0xFF67E1B1),
        ),
      ),
      child: Text(
        '$studiedCount/$totalDays',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QuarterlyDescriptionPreview extends StatelessWidget {
  const _QuarterlyDescriptionPreview({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final normalized = description.replaceAll('\n', ' ').trim();
    final showMore = normalized.length > 140;
    final previewText = showMore
        ? '${normalized.substring(0, 140)}...'
        : normalized;

    return Column(
      children: [
        Text(
          previewText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: EsTypePreset.quarterDescription,
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
        if (showMore)
          TextButton(
            onPressed: () => _openDescriptionModal(context),
            child: const Text(
              'Más...',
              style: TextStyle(
                color: Color(0xFFC5D3FF),
                decoration: TextDecoration.underline,
                fontSize: EsTypePreset.quarterDescriptionMore,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _openDescriptionModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.84,
          minChildSize: 0.6,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111521),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 34),
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: EsTypePreset.quarterModalTitle,
                            fontWeight: FontWeight.w700,
                            height: 1.04,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: EsTypePreset.quarterModalBody,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
