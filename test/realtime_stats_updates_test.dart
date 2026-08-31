import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Models/payment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time Stats and Auto-Update Stream Test Suite', () {
    late LocalDataService db;

    setUp(() {
      db = LocalDataService();
    });

    test('watchAllDataChanges emits when payments or inscriptions are saved', () async {
      int changeEventCount = 0;
      final sub = db.watchAllDataChanges().listen((_) {
        changeEventCount++;
      });

      // 1. Create and accept an inscription
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'realtime.$timestamp@test.ml';
      final inscription = await db.createInscription(
        apprenantId: 'temp_realtime_$timestamp',
        formationId: 'form_sfp_2026',
        prenom: 'Moussa',
        nom: 'Diallo',
        email: email,
        telephone: '+223 70 11 22 33',
        modules: ['Création d’applications (Flutter)', 'Base de données + IA', 'Word et Excel'],
      );

      final stagiaire = await db.acceptInscription(
        inscription.id,
        moduleHours: {
          'Création d’applications (Flutter)': 20,
          'Base de données + IA': 20,
          'Word et Excel': 20,
        },
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(changeEventCount, greaterThanOrEqualTo(1));

      // 2. Add a test payment with valid balance
      final testPayment = Payment(
        id: 'test_pay_$timestamp',
        inscriptionId: inscription.id,
        etudiantId: stagiaire.id,
        formationId: 'form_sfp_2026',
        montant: 50000,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.orangeMoney,
        dateCreation: DateTime.now(),
      );

      await db.addPayment(testPayment);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(changeEventCount, greaterThanOrEqualTo(2));

      // 3. Update formation
      final formation = db.getFormations().first;
      await db.updateFormation(formation.copyWith(titre: '${formation.titre} (Actualisé)'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(changeEventCount, greaterThanOrEqualTo(3));

      await sub.cancel();
    });

    test('Individual streams emit updated counts and financial statistics', () async {
      Payment? emittedPayment;
      final sub = db.watchPayments().listen((payments) {
        if (payments.isNotEmpty) {
          emittedPayment = payments.last;
        }
      });

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'realtime.fin.$timestamp@test.ml';
      final inscription = await db.createInscription(
        apprenantId: 'temp_realtime_fin_$timestamp',
        formationId: 'form_sfp_2026',
        prenom: 'Aminata',
        nom: 'Traore',
        email: email,
        telephone: '+223 76 99 88 77',
        modules: ['Création d’applications (Flutter)', 'Base de données + IA', 'Word et Excel'],
      );

      final stagiaire = await db.acceptInscription(
        inscription.id,
        moduleHours: {
          'Création d’applications (Flutter)': 20,
          'Base de données + IA': 20,
          'Word et Excel': 20,
        },
      );

      final initialPaymentCount = db.getPayments().length;

      final newPay = Payment(
        id: 'test_pay_financial_$timestamp',
        inscriptionId: inscription.id,
        etudiantId: stagiaire.id,
        formationId: 'form_sfp_2026',
        montant: 40000,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.moovMoney,
        dateCreation: DateTime.now(),
      );

      await db.addPayment(newPay);
      await Future.delayed(const Duration(milliseconds: 50));

      final updatedPayments = db.getPayments();
      expect(updatedPayments.length, equals(initialPaymentCount + 1));
      expect(emittedPayment?.montant, equals(40000));

      await sub.cancel();
    });
  });
}
