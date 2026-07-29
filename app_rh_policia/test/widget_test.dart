import 'package:flutter_test/flutter_test.dart';

import 'package:app_rh_policia/main.dart';

void main() {
  testWidgets('Role select muestra ambos botones', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Recursos Humanos'), findsOneWidget);
    expect(find.text('Entrar como Policía'), findsOneWidget);
  });
}
