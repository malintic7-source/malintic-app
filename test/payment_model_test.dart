import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/payment.dart';

void main() {
  group('Payment.fromMap', () {
    test('applies defaults when the payload is empty', () {
      final payment = Payment.fromMap(const {}, 'pay_1');

      expect(payment.id, 'pay_1');
      expect(payment.inscriptionId, '');
      expect(payment.apprenantId, '');
      expect(payment.formationId, '');
      expect(payment.montant, 0);
      expect(payment.status, PaymentStatus.enAttente);
      expect(payment.methode, PaymentMethod.carte);
      expect(payment.trancheNumero, 1);
      expect(payment.nombreTranches, 1);
      expect(payment.remise, 0);
      expect(payment.dateEffectuation, isNull);
      expect(payment.dateEcheance, isNull);
    });

    test('parses every payment status', () {
      expect(
        Payment.fromMap(const {'status': 'PaymentStatus.effectue'}, 'p').status,
        PaymentStatus.effectue,
      );
      expect(
        Payment.fromMap(const {'status': 'PaymentStatus.echoue'}, 'p').status,
        PaymentStatus.echoue,
      );
      expect(
        Payment.fromMap(const {'status': 'PaymentStatus.enAttente'}, 'p').status,
        PaymentStatus.enAttente,
      );
      expect(
        Payment.fromMap(const {'status': 'inconnu'}, 'p').status,
        PaymentStatus.enAttente,
      );
    });

    test('parses every payment method case insensitively', () {
      expect(
        Payment.fromMap(const {'methode': 'PaymentMethod.orangeMoney'}, 'p').methode,
        PaymentMethod.orangeMoney,
      );
      expect(
        Payment.fromMap(const {'methode': 'Moov Money'}, 'p').methode,
        PaymentMethod.moovMoney,
      );
      expect(
        Payment.fromMap(const {'methode': 'Virement bancaire'}, 'p').methode,
        PaymentMethod.virement,
      );
      expect(
        Payment.fromMap(const {'methode': 'Especes'}, 'p').methode,
        PaymentMethod.especes,
      );
      expect(
        Payment.fromMap(const {'methode': 'autre'}, 'p').methode,
        PaymentMethod.carte,
      );
    });

    test('reads the legacy etudiantId key when apprenantId is absent', () {
      final payment = Payment.fromMap(
        const {'etudiantId': 'student_legacy'},
        'pay_2',
      );

      expect(payment.apprenantId, 'student_legacy');
      expect(payment.etudiantId, 'student_legacy');
    });

    test('prefers apprenantId over the legacy etudiantId key', () {
      final payment = Payment.fromMap(
        const {'apprenantId': 'student_new', 'etudiantId': 'student_legacy'},
        'pay_3',
      );

      expect(payment.apprenantId, 'student_new');
    });

    test('parses dates from strings and DateTime values', () {
      final payment = Payment.fromMap({
        'dateCreation': '2024-02-01T10:00:00.000',
        'dateEffectuation': DateTime(2024, 2, 3),
        'dateEcheance': '2024-03-01T00:00:00.000',
      }, 'pay_4');

      expect(payment.dateCreation, DateTime(2024, 2, 1, 10));
      expect(payment.dateEffectuation, DateTime(2024, 2, 3));
      expect(payment.dateEcheance, DateTime(2024, 3, 1));
    });

    test('ignores unparsable optional dates', () {
      final payment = Payment.fromMap(
        const {'dateEffectuation': 'not-a-date', 'dateEcheance': 42},
        'pay_5',
      );

      expect(payment.dateEffectuation, isNull);
      expect(payment.dateEcheance, isNull);
    });

    test('coerces numeric fields to their expected types', () {
      final payment = Payment.fromMap(const {
        'montant': 150000,
        'trancheNumero': 2.0,
        'nombreTranches': 3.0,
        'remise': 5000,
      }, 'pay_6');

      expect(payment.montant, 150000.0);
      expect(payment.trancheNumero, 2);
      expect(payment.nombreTranches, 3);
      expect(payment.remise, 5000.0);
    });
  });

  group('Payment.fromFirestore', () {
    test('reads the id from the map payload', () {
      final payment = Payment.fromFirestore(<String, dynamic>{
        'id': 'pay_7',
        'montant': 25000,
        'status': 'PaymentStatus.effectue',
      });

      expect(payment.id, 'pay_7');
      expect(payment.montant, 25000.0);
      expect(payment.status, PaymentStatus.effectue);
    });

    test('defaults the id to an empty string when it is missing', () {
      final payment = Payment.fromFirestore(<String, dynamic>{'montant': 1});

      expect(payment.id, '');
    });
  });

  test('etudiantId falls back to the constructor alias', () {
    final payment = Payment(
      id: 'pay_8',
      inscriptionId: 'insc_1',
      etudiantId: 'student_alias',
      formationId: 'form_1',
      montant: 10000,
      status: PaymentStatus.enAttente,
      methode: PaymentMethod.especes,
      dateCreation: DateTime(2024, 1, 1),
    );

    expect(payment.apprenantId, 'student_alias');
    expect(payment.etudiantId, 'student_alias');
  });

  test('toMap exposes both apprenantId and the legacy etudiantId', () {
    final payment = Payment(
      id: 'pay_9',
      inscriptionId: 'insc_2',
      apprenantId: 'student_9',
      formationId: 'form_2',
      montant: 75000,
      status: PaymentStatus.effectue,
      methode: PaymentMethod.orangeMoney,
      dateCreation: DateTime(2024, 4, 1),
      dateEffectuation: DateTime(2024, 4, 2),
      referenceTransaction: 'REF-OM-1',
      motif: 'Acompte',
      moduleId: 'mod_1',
      trancheNumero: 2,
      nombreTranches: 3,
      remise: 2500,
      dateEcheance: DateTime(2024, 5, 1),
    );

    final data = payment.toMap();

    expect(data['apprenantId'], 'student_9');
    expect(data['etudiantId'], 'student_9');
    expect(data['status'], 'PaymentStatus.effectue');
    expect(data['methode'], 'PaymentMethod.orangeMoney');
    expect(data['dateCreation'], DateTime(2024, 4, 1).toIso8601String());
    expect(data['dateEffectuation'], DateTime(2024, 4, 2).toIso8601String());
    expect(data['dateEcheance'], DateTime(2024, 5, 1).toIso8601String());
    expect(data['referenceTransaction'], 'REF-OM-1');
    expect(data['trancheNumero'], 2);
    expect(data['nombreTranches'], 3);
    expect(data['remise'], 2500);
    expect(payment.toFirestore(), data);
  });

  test('toMap round trips through fromMap', () {
    final payment = Payment(
      id: 'pay_10',
      inscriptionId: 'insc_3',
      apprenantId: 'student_10',
      formationId: 'form_3',
      montant: 50000,
      status: PaymentStatus.echoue,
      methode: PaymentMethod.moovMoney,
      dateCreation: DateTime(2024, 5, 5),
      motifEchec: 'Solde insuffisant',
    );

    final restored = Payment.fromMap(payment.toMap(), payment.id);

    expect(restored.status, PaymentStatus.echoue);
    expect(restored.methode, PaymentMethod.moovMoney);
    expect(restored.montant, 50000.0);
    expect(restored.motifEchec, 'Solde insuffisant');
    expect(restored.dateCreation, DateTime(2024, 5, 5));
  });
}
