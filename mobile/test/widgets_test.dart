import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wgf_connect/core/utils/format.dart';
import 'package:wgf_connect/core/widgets/visuals.dart';

void main() {
  testWidgets('Il logo si disegna e il pulsante risponde al tocco', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const WgfLogo(size: 80, progress: 0.5),
          GradientButton(label: 'Entra', onPressed: () => tapped++),
        ]),
      ),
    ));
    expect(find.byType(WgfLogo), findsOneWidget);
    await tester.tap(find.text('Entra'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tapped, 1);
  });

  testWidgets('FadeSlideIn completa l\'animazione', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FadeSlideIn(child: Text('ciao'))));
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 1.0);
  });

  test('splitTags divide e pulisce i tag', () {
    expect(splitTags(' Minecraft, Fortnite ;\nZelda,, '), ['Minecraft', 'Fortnite', 'Zelda']);
  });
}
