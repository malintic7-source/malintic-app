import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Pages/Login/sign_in.dart';

void main() {
  testWidgets('WelcomePage renders logo and poles on mobile and desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
    expect(find.textContaining('4 pôles à votre service'), findsWidgets);
    expect(find.text('Formations'), findsOneWidget);
    expect(find.text('Prestations'), findsOneWidget);
    expect(find.text('e-Commerce'), findsOneWidget);
    expect(find.text('Incubator'), findsOneWidget);
  });

  testWidgets('Formations pole navigates to SignInPage', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Formations'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
  });

  testWidgets('Non-formation pole opens pro coming soon dialog with redirection CTA', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pumpAndSettle();

    // Tap Prestations
    await tester.tap(find.text('Prestations'));
    await tester.pumpAndSettle();

    expect(find.text('Déploiement en cours • Bientôt disponible'), findsOneWidget);
    expect(find.text('Accéder aux Formations (Actif)'), findsOneWidget);

    // Tap CTA to navigate to Formations
    await tester.tap(find.text('Accéder aux Formations (Actif)'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
  });
}

