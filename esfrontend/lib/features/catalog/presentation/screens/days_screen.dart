import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/lesson_model.dart';
import '../providers/catalog_providers.dart';
import 'day_read_screen.dart';

class DaysScreen extends ConsumerWidget {
  const DaysScreen({
    super.key,
    required this.quarterlyId,
    required this.lesson,
  });

  final String quarterlyId;
  final LessonModel lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(
      daysProvider((
        quarterlyId: quarterlyId,
        lessonId: lesson.lessonId,
        lang: 'es',
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Semana ${lesson.lessonId}'),
            Text(
              lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar cambios',
            icon: const Icon(Icons.sync_outlined),
            onPressed: () async {
              final container = ProviderScope.containerOf(
                context,
                listen: false,
              );
              final repo = ref.read(catalogRepositoryProvider);
              await repo.syncQuarterlyChanges(
                quarterlyId: quarterlyId,
                lang: 'es',
              );
              container.invalidate(
                daysProvider((
                  quarterlyId: quarterlyId,
                  lessonId: lesson.lessonId,
                  lang: 'es',
                )),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cambios sincronizados.')),
                );
              }
            },
          ),
        ],
      ),
      body: daysAsync.when(
        data: (days) {
          if (days.isEmpty) {
            return const Center(
              child: Text('No hay dias cargados para esta leccion.'),
            );
          }

          return ListView.separated(
            itemCount: days.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final day = days[index];
              return ListTile(
                leading: CircleAvatar(child: Text(day.dayId)),
                title: Text(day.title),
                subtitle: day.dayDate == null
                    ? null
                    : Text(day.dayDate!.toIso8601String()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DayReadScreen(
                        quarterlyId: quarterlyId,
                        lessonId: lesson.lessonId,
                        dayId: day.dayId,
                        dayTitle: day.title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error al cargar dias:\n$error')),
      ),
    );
  }
}
