import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/audit_log.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Services/db_services.dart';

/// Billing helpers of [LocalDataService]: module pricing, inscription totals
/// and the guard rails enforced when recording a payment.
void main() {
  final db = LocalDataService();
  int counter = 0;

  Future<Formation> addFormation({
    required double prix,
    double? prixEnLigne,
    Map<String, double> modulePrices = const {},
    List<String> modules = const ['Module A', 'Module B'],
  }) async {
    final formation = Formation(
      id: 'form_billing_${counter++}',
      titre: 'Formation billing',
      description: 'Formation de test',
      modules: modules,
      modulePrices: modulePrices,
      formateurIds: const ['formateur_1'],
      prix: prix,
      prixEnLigne: prixEnLigne,
      type: FormationType.mixte,
      status: FormationStatus.programmee,
      dureeSemaines: 4,
      horaires: const [],
      dateCreation: DateTime(2024, 1, 1),
    );
    await db.addFormation(formation);
    return formation;
  }

  Future<Inscription> addInscription(
    Formation formation, {
    List<String>? modules,
    String? typeFormation,
  }) {
    return db.createInscription(
      apprenantId: 'student_billing_${counter++}',
      formationId: formation.id,
      prenom: 'Awa',
      nom: 'Kone',
      email: 'awa.billing$counter@example.com',
      telephone: '770000000',
      modules: modules,
      typeFormation: typeFormation,
    );
  }

  Payment buildPayment(
    Inscription inscription, {
    required double montant,
    PaymentStatus status = PaymentStatus.effectue,
    int trancheNumero = 1,
    int nombreTranches = 1,
    double remise = 0,
  }) {
    return Payment(
      id: 'pay_billing_${counter++}',
      inscriptionId: inscription.id,
      apprenantId: inscription.apprenantId,
      formationId: inscription.formationId,
      montant: montant,
      status: status,
      methode: PaymentMethod.especes,
      dateCreation: DateTime(2024, 1, 1),
      trancheNumero: trancheNumero,
      nombreTranches: nombreTranches,
      remise: remise,
    );
  }

  group('getFormationModulesTotal', () {
    test('returns 0 for an unknown formation', () {
      expect(db.getFormationModulesTotal('form_does_not_exist'), 0);
    });

    test('falls back to the flat price when no module is priced', () async {
      final formation = await addFormation(prix: 100000);

      expect(db.getFormationModulesTotal(formation.id), 100000);
    });

    test('prefers the online price for an online inscription', () async {
      final formation = await addFormation(prix: 100000, prixEnLigne: 80000);

      expect(
        db.getFormationModulesTotal(formation.id, typeFormation: 'En ligne'),
        80000,
      );
      expect(
        db.getFormationModulesTotal(formation.id, typeFormation: 'Présentielle'),
        100000,
      );
    });

    test('sums the selected module prices when they are configured', () async {
      final formation = await addFormation(
        prix: 100000,
        modules: const ['Module A', 'Module B', 'Module C'],
        modulePrices: const {'Module A': 30000, 'Module B': 25000},
      );

      expect(
        db.getFormationModulesTotal(formation.id, moduleIds: const ['Module A']),
        30000,
      );
      expect(
        db.getFormationModulesTotal(
          formation.id,
          moduleIds: const ['Module A', 'Module B'],
        ),
        55000,
      );
    });

    test('sums every module when no selection is given', () async {
      final formation = await addFormation(
        prix: 100000,
        modulePrices: const {'Module A': 30000, 'Module B': 25000},
      );

      expect(db.getFormationModulesTotal(formation.id), 55000);
    });

    test('falls back to the flat price when the priced modules total zero',
        () async {
      final formation = await addFormation(
        prix: 100000,
        modulePrices: const {'Module A': 0, 'Module B': 0},
      );

      expect(db.getFormationModulesTotal(formation.id), 100000);
    });
  });

  group('inscription totals', () {
    test('are zero for an unknown inscription', () {
      expect(db.getInscriptionBaseTotal('insc_does_not_exist'), 0);
      expect(db.getInscriptionTotalDue('insc_does_not_exist'), 0);
      expect(db.getInscriptionPaidAmount('insc_does_not_exist'), 0);
      expect(db.getInscriptionBalance('insc_does_not_exist'), 0);
    });

    test('derive the base total from the selected modules', () async {
      final formation = await addFormation(
        prix: 100000,
        modulePrices: const {'Module A': 30000, 'Module B': 25000},
      );
      final inscription =
          await addInscription(formation, modules: const ['Module A']);

      expect(db.getInscriptionBaseTotal(inscription.id), 30000);
      expect(db.getInscriptionTotalDue(inscription.id), 30000);
      expect(db.getInscriptionBalance(inscription.id), 30000);
    });

    test('only count completed payments as paid', () async {
      final formation = await addFormation(prix: 60000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(
        inscription,
        montant: 20000,
        trancheNumero: 1,
        nombreTranches: 3,
      ));
      await db.addPayment(buildPayment(
        inscription,
        montant: 20000,
        status: PaymentStatus.enAttente,
        trancheNumero: 2,
        nombreTranches: 3,
      ));

      expect(db.getInscriptionPaidAmount(inscription.id), 20000);
      expect(db.getInscriptionBalance(inscription.id), 40000);
    });

    test('keep the highest discount instead of adding them up', () async {
      final formation = await addFormation(prix: 100000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(
        inscription,
        montant: 10000,
        remise: 5000,
        trancheNumero: 1,
        nombreTranches: 2,
      ));
      await db.addPayment(buildPayment(
        inscription,
        montant: 10000,
        remise: 20000,
        trancheNumero: 2,
        nombreTranches: 2,
      ));

      expect(db.getInscriptionDiscountTotal(inscription.id), 20000);
      expect(db.getInscriptionTotalDue(inscription.id), 80000);
      expect(db.getInscriptionBalance(inscription.id), 60000);
    });

    test('ignore the discount carried by a failed payment', () async {
      final formation = await addFormation(prix: 50000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(
        inscription,
        montant: 10000,
        status: PaymentStatus.echoue,
        remise: 15000,
      ));

      expect(db.getInscriptionDiscountTotal(inscription.id), 0);
      expect(db.getInscriptionTotalDue(inscription.id), 50000);
    });

    test('clamp to zero when the discount exceeds the base total', () async {
      final formation = await addFormation(prix: 40000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(
        inscription,
        montant: 10000,
        status: PaymentStatus.enAttente,
        remise: 60000,
      ));

      expect(db.getInscriptionDiscountTotal(inscription.id), 60000);
      expect(db.getInscriptionTotalDue(inscription.id), 0);
      expect(db.getInscriptionBalance(inscription.id), 0);
    });
  });

  group('addPayment validation', () {
    test('rejects a non positive amount', () async {
      final formation = await addFormation(prix: 50000);
      final inscription = await addInscription(formation);

      await expectLater(
        db.addPayment(buildPayment(inscription, montant: 0)),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        db.addPayment(buildPayment(inscription, montant: -1000)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects an out of range installment number', () async {
      final formation = await addFormation(prix: 50000);
      final inscription = await addInscription(formation);

      await expectLater(
        db.addPayment(buildPayment(
          inscription,
          montant: 1000,
          trancheNumero: 0,
        )),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        db.addPayment(buildPayment(
          inscription,
          montant: 1000,
          trancheNumero: 3,
          nombreTranches: 2,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects a duplicated completed installment', () async {
      final formation = await addFormation(prix: 100000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(
        inscription,
        montant: 10000,
        trancheNumero: 1,
        nombreTranches: 2,
      ));

      await expectLater(
        db.addPayment(buildPayment(
          inscription,
          montant: 10000,
          trancheNumero: 1,
          nombreTranches: 2,
        )),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a payment exceeding the remaining balance', () async {
      final formation = await addFormation(prix: 30000);
      final inscription = await addInscription(formation);

      await expectLater(
        db.addPayment(buildPayment(inscription, montant: 30001)),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts a pending payment above the balance', () async {
      final formation = await addFormation(prix: 30000);
      final inscription = await addInscription(formation);
      final payment = buildPayment(
        inscription,
        montant: 90000,
        status: PaymentStatus.enAttente,
      );

      await db.addPayment(payment);

      expect(
        db.getPaymentsForInscription(inscription.id).map((p) => p.id),
        contains(payment.id),
      );
      expect(db.getInscriptionPaidAmount(inscription.id), 0);
    });

    test('marks the inscription as paid once the total is covered', () async {
      final formation = await addFormation(prix: 25000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(inscription, montant: 25000));

      expect(db.getInscriptionById(inscription.id)!.paiementEffectue, isTrue);
      expect(db.getInscriptionBalance(inscription.id), 0);
    });

    test('records an audit log entry for the payment', () async {
      final formation = await addFormation(prix: 15000);
      final inscription = await addInscription(formation);

      await db.addPayment(buildPayment(inscription, montant: 15000));

      expect(
        db.getAuditLogs().any((log) =>
            log.action == 'Paiement effectué' &&
            log.description.contains('15000')),
        isTrue,
      );
    });
  });

  test('deletePayment removes the payment and frees the balance', () async {
    final formation = await addFormation(prix: 20000);
    final inscription = await addInscription(formation);
    final payment = buildPayment(inscription, montant: 20000);

    await db.addPayment(payment);
    expect(db.getInscriptionPaidAmount(inscription.id), 20000);

    await db.deletePayment(payment.id);

    expect(db.getPayments().any((p) => p.id == payment.id), isFalse);
    expect(db.getInscriptionPaidAmount(inscription.id), 0);
    expect(db.getInscriptionBalance(inscription.id), 20000);
  });

  test('getPaymentsForInscription also matches payments recorded per student',
      () async {
    final formation = await addFormation(prix: 50000);
    final inscription = await addInscription(formation);
    final orphanPayment = Payment(
      id: 'pay_billing_orphan_${counter++}',
      inscriptionId: 'insc_unknown',
      apprenantId: inscription.apprenantId,
      formationId: inscription.formationId,
      montant: 5000,
      status: PaymentStatus.enAttente,
      methode: PaymentMethod.especes,
      dateCreation: DateTime(2024, 1, 1),
    );

    await db.addPayment(orphanPayment);

    expect(
      db.getPaymentsForInscription(inscription.id).map((p) => p.id),
      contains(orphanPayment.id),
    );
  });

  test('logAction prepends the entry with its severity', () async {
    await db.logAction(
      userNom: 'Auditeur',
      userRole: 'admin',
      action: 'Test audit',
      description: 'Entrée de test',
      targetId: 'target_1',
      targetType: 'payment',
      severity: AuditSeverity.critical,
    );

    final latest = db.getAuditLogs().first;

    expect(latest.action, 'Test audit');
    expect(latest.userNom, 'Auditeur');
    expect(latest.targetId, 'target_1');
    expect(latest.targetType, 'payment');
    expect(latest.severity, AuditSeverity.critical);
  });
}
