import 'package:flutter/material.dart';

import 'features/catalog/presentation/screens/quarterlies_screen.dart';

class ESFrontendApp extends StatelessWidget {
  const ESFrontendApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'Escuela Sabatica',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C5A4B)),
        scaffoldBackgroundColor: const Color(0xFF050916),
        textTheme: _scaledTextTheme(baseTheme.textTheme, factor: 0.94),
      ),
      home: const QuarterliesScreen(),
    );
  }
}

TextTheme _scaledTextTheme(TextTheme base, {double factor = 1.0}) {
  TextStyle? s(TextStyle? style) => style?.copyWith(
    fontSize: style.fontSize == null ? null : style.fontSize! * factor,
    color: Colors.white,
  );

  return base.copyWith(
    displayLarge: s(base.displayLarge),
    displayMedium: s(base.displayMedium),
    displaySmall: s(base.displaySmall),
    headlineLarge: s(base.headlineLarge),
    headlineMedium: s(base.headlineMedium),
    headlineSmall: s(base.headlineSmall),
    titleLarge: s(base.titleLarge),
    titleMedium: s(base.titleMedium),
    titleSmall: s(base.titleSmall),
    bodyLarge: s(base.bodyLarge),
    bodyMedium: s(base.bodyMedium),
    bodySmall: s(base.bodySmall),
    labelLarge: s(base.labelLarge),
    labelMedium: s(base.labelMedium),
    labelSmall: s(base.labelSmall),
  );
}
