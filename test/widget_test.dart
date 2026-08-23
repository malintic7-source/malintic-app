// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';

void main() {
  testWidgets('WelcomePage renders logo and poles on mobile and desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
    expect(find.textContaining('4 pôles à votre service'), findsWidgets);
  });
}

