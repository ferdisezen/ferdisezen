import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velar_pos_login/staff_login/staff_login_screen.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester, {bool accept = false}) async {
    tester.view.physicalSize = const Size(1600, 940);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: StaffLoginScreen(onSubmit: (pin) async {
        submitted.add(pin);
        return accept;
      }),
    ));
    return submitted;
  }

  Future<void> enter(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
  }

  testWidgets('4 hane girilince PIN gönderilir', (tester) async {
    final submitted = await pump(tester, accept: true);
    await enter(tester, '1234');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();
    expect(submitted, ['1234']);
    expect(find.text('Hatalı PIN'), findsNothing);
  });

  testWidgets('Hatalı PIN uyarı gösterir, yeni tuşla sıfırlanır', (tester) async {
    await pump(tester);
    await enter(tester, '9999');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();
    expect(find.text('Hatalı PIN'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(find.text('Hatalı PIN'), findsNothing);
    expect(find.text('Oturum kapatıldı'), findsOneWidget);
  });

  testWidgets('Dar ekranda taşma olmadan yerleşir', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StaffLoginScreen(onSubmit: (_) async => true)));
    expect(tester.takeException(), isNull);
  });
}
