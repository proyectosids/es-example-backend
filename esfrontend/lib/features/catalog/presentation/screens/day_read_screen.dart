import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_providers.dart';
import '../widgets/read_content_view.dart';

class DayReadScreen extends ConsumerWidget {
  const DayReadScreen({
    super.key,
    required this.quarterlyId,
    required this.lessonId,
    required this.dayId,
    required this.dayTitle,
  });

  final String quarterlyId;
  final String lessonId;
  final String dayId;
  final String dayTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      quarterlyId: quarterlyId,
      lessonId: lessonId,
      dayId: dayId,
      lang: 'es',
    );
    final readAsync = ref.watch(dayReadProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text('Dia $dayId'),
        actions: [
          IconButton(
            tooltip: 'Actualizar lectura',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dayReadProvider(query)),
          ),
        ],
      ),
      body: readAsync.when(
        data: (data) => ReadContentView(dayTitle: dayTitle, data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar lectura:\n$error')),
      ),
    );
  }
}
