import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:esfrontend/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:esfrontend/features/catalog/presentation/screens/quarterlies_screen.dart';

void main() {
  testWidgets('App renders catalog shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quarterliesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: QuarterliesScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('No hay trimestres disponibles.'), findsOneWidget);
  });
}
