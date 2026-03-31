import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/typography_preset.dart';
import '../../../auth/presentation/access/access_control.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../data/models/quarterly_model.dart';
import '../providers/catalog_providers.dart';
import 'lessons_screen.dart';

class QuarterliesScreen extends ConsumerStatefulWidget {
  const QuarterliesScreen({super.key});

  @override
  ConsumerState<QuarterliesScreen> createState() => _QuarterliesScreenState();
}

class _QuarterliesScreenState extends ConsumerState<QuarterliesScreen> {
  bool _syncing = false;

  Future<void> _syncCatalog() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    final repo = ref.read(catalogRepositoryProvider);
    final total = await repo.syncAllQuarterliesCatalog(
      lang: AppConfig.defaultLang,
    );
    if (!mounted) return;
    ref.invalidate(quarterliesProvider);

    final message = total > 0
        ? 'Sincronizacion completada: $total trimestres actualizados.'
        : 'No fue posible sincronizar. Mostrando datos locales.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final quarterliesAsync = ref.watch(quarterliesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050918),
      body: SafeArea(
        child: quarterliesAsync.when(
          data: (quarterlies) {
            if (quarterlies.isEmpty) {
              return _ErrorOrEmpty(
                message: 'No hay trimestres disponibles.',
                onRefresh: () => _syncCatalog(),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                    child: _TopHeader(
                      onRefresh: _syncCatalog,
                      isSyncing: _syncing,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'Escuela Sabatica',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: EsTypePreset.homeMainTitle,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'EDICION PARA\nADULTOS',
                    onTapAll: () {},
                  ),
                ),
                SliverToBoxAdapter(
                  child: _QuarterlyCarousel(
                    quarterlies: quarterlies,
                    onTap: (quarterly) {
                      final canOpenLessons = ref.read(
                        canOpenScreenProvider(AppScreenKey.mobileLessons),
                      );
                      if (!canOpenLessons) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tu cuenta no tiene acceso a esta pantalla.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LessonsScreen(quarterly: quarterly),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                // SliverToBoxAdapter(
                //   child: _SectionTitle(title: 'INVERSE', onTapAll: () {}),
                // ),
                // SliverToBoxAdapter(
                //   child: _InverseCarousel(quarterlies: quarterlies),
                // ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF9EA8FF)),
          ),
          error: (error, _) => _ErrorOrEmpty(
            message:
                'Error al cargar trimestres.\nVerifica API_BASE_URL.\nActual: ${AppConfig.apiBaseUrl}\n\n$error',
            onRefresh: () => _syncCatalog(),
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends ConsumerWidget {
  const _TopHeader({required this.onRefresh, required this.isSyncing});

  final Future<void> Function() onRefresh;
  final bool isSyncing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final logged = session.isAuthenticated;

    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            );
          },
          icon: Icon(
            logged ? Icons.account_circle : Icons.account_circle_outlined,
            color: Colors.white,
            size: 40,
          ),
          tooltip: logged ? 'Cuenta' : 'Iniciar sesion',
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.translate_rounded,
            color: Colors.white,
            size: 30,
          ),
          tooltip: 'Idioma (proximamente)',
        ),
        IconButton(
          onPressed: isSyncing ? null : () => onRefresh(),
          icon: isSyncing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 26,
                ),
          tooltip: 'Sincronizar',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onTapAll});

  final String title;
  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: EsTypePreset.homeSectionTitle,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0.4,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onTapAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA7B7FF),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            label: const Text(
              'Ver todo',
              style: TextStyle(
                fontSize: EsTypePreset.homeSeeAll,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuarterlyCarousel extends StatelessWidget {
  const _QuarterlyCarousel({required this.quarterlies, required this.onTap});

  final List<QuarterlyModel> quarterlies;
  final ValueChanged<QuarterlyModel> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: quarterlies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final quarterly = quarterlies[index];
          return SizedBox(
            width: 210,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onTap(quarterly),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: quarterly.coverUrl.isEmpty
                          ? Container(
                              color: const Color(0xFF1B223D),
                              child: const Center(
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.white70,
                                  size: 46,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: quarterly.coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: const Color(0xFF1B223D),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    quarterly.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: EsTypePreset.homeCardTitle,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// class _InverseCarousel extends StatelessWidget {
//   const _InverseCarousel({required this.quarterlies});

//   final List<QuarterlyModel> quarterlies;

//   static const _palette = <Color>[
//     Color(0xFF8DB07C),
//     Color(0xFF6FA0CE),
//     Color(0xFF85A9C4),
//     Color(0xFFC3A66F),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 268,
//       child: ListView.separated(
//         padding: const EdgeInsets.symmetric(horizontal: 18),
//         scrollDirection: Axis.horizontal,
//         itemCount: quarterlies.length,
//         separatorBuilder: (_, _) => const SizedBox(width: 14),
//         itemBuilder: (context, index) {
//           final quarterly = quarterlies[index];
//           final bg = _palette[index % _palette.length];
//           return SizedBox(
//             width: 210,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(18),
//                     child: Container(
//                       color: bg,
//                       child: Stack(
//                         children: [
//                           const Positioned(
//                             top: 20,
//                             right: 16,
//                             child: Icon(
//                               Icons.north_east_rounded,
//                               color: Colors.white70,
//                               size: 26,
//                             ),
//                           ),
//                           Center(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 const Icon(
//                                   Icons.shield_outlined,
//                                   color: Colors.white,
//                                   size: 54,
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Text(
//                                   quarterly.quarterlyId,
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: EsTypePreset.homeQuarterId,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   quarterly.title,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: EsTypePreset.homeInverseCardTitle,
//                     fontWeight: FontWeight.w600,
//                     height: 1.18,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

class _ErrorOrEmpty extends StatelessWidget {
  const _ErrorOrEmpty({required this.message, required this.onRefresh});

  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
