import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../../data/local/catalog_local_data_source.dart';
import '../../data/models/day_model.dart';
import '../../data/models/lesson_detail_meta.dart';
import '../../data/models/lesson_model.dart';
import '../../data/models/quarterly_model.dart';
import '../../data/repositories/catalog_repository.dart';

typedef LessonQuery = ({String quarterlyId, String lang});
typedef DayQuery = ({String quarterlyId, String lessonId, String lang});
typedef DayReadQuery = ({
  String quarterlyId,
  String lessonId,
  String dayId,
  String lang,
});
typedef QuarterlyImageQuery = ({String quarterlyId, String lang});
typedef LessonImageQuery = ({String quarterlyId, String lessonId, String lang});
typedef StudyMarksQuery = ({String quarterlyId, String lessonId, String lang});
typedef QuarterlyProgressQuery = ({String quarterlyId, String lang});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    getAccessToken: () =>
        ref.read(sessionControllerProvider.notifier).getAccessToken(),
    refreshAccessToken: () =>
        ref.read(sessionControllerProvider.notifier).refreshAccessToken(),
    onUnauthorized: () => ref.read(sessionControllerProvider.notifier).logout(),
  );
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    ref.watch(apiClientProvider),
    CatalogLocalDataSource(),
  );
});

final quarterliesProvider = FutureProvider<List<QuarterlyModel>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.fetchQuarterlies(lang: AppConfig.defaultLang);
});

final lessonsProvider = FutureProvider.family<List<LessonModel>, LessonQuery>((
  ref,
  query,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.fetchLessons(quarterlyId: query.quarterlyId, lang: query.lang);
});

final daysProvider = FutureProvider.family<List<DayModel>, DayQuery>((
  ref,
  query,
) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.fetchDays(
    quarterlyId: query.quarterlyId,
    lessonId: query.lessonId,
    lang: query.lang,
  );
});

final dayReadProvider =
    FutureProvider.family<Map<String, dynamic>, DayReadQuery>((
      ref,
      query,
    ) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchDayRead(
        quarterlyId: query.quarterlyId,
        lessonId: query.lessonId,
        dayId: query.dayId,
        lang: query.lang,
      );
    });

final quarterlyHeroImageProvider =
    FutureProvider.family<String?, QuarterlyImageQuery>((ref, query) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchQuarterlyHeroImage(
        quarterlyId: query.quarterlyId,
        lang: query.lang,
      );
    });

final lessonCoverImageProvider =
    FutureProvider.family<String?, LessonImageQuery>((ref, query) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchLessonCoverImage(
        quarterlyId: query.quarterlyId,
        lessonId: query.lessonId,
        lang: query.lang,
      );
    });

final lessonDetailMetaProvider =
    FutureProvider.family<LessonDetailMeta?, LessonImageQuery>((
      ref,
      query,
    ) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchLessonDetailMeta(
        quarterlyId: query.quarterlyId,
        lessonId: query.lessonId,
        lang: query.lang,
      );
    });

final quarterlyDescriptionProvider =
    FutureProvider.family<String?, QuarterlyImageQuery>((ref, query) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchQuarterlyDescription(
        quarterlyId: query.quarterlyId,
        lang: query.lang,
      );
    });

final quarterlyAuthorProvider =
    FutureProvider.family<String?, QuarterlyImageQuery>((ref, query) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.fetchQuarterlyAuthor(
        quarterlyId: query.quarterlyId,
        lang: query.lang,
      );
    });

final lessonStudyMarksProvider =
    FutureProvider.family<Map<String, bool>, StudyMarksQuery>((
      ref,
      query,
    ) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.getLessonStudyMarks(
        lang: query.lang,
        quarterlyId: query.quarterlyId,
        lessonId: query.lessonId,
      );
    });

final quarterlyStudyProgressProvider =
    FutureProvider.family<Map<String, int>, QuarterlyProgressQuery>((
      ref,
      query,
    ) async {
      final repo = ref.watch(catalogRepositoryProvider);
      return repo.getQuarterlyStudyProgress(
        lang: query.lang,
        quarterlyId: query.quarterlyId,
      );
    });
