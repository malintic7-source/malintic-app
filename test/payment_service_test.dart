import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/utils/type_parsers.dart';

void main() {
  group('Type Parsers Suite', () {
    test('parseDouble parses strings with dot and comma correctly', () {
      expect(parseDouble(50000), 50000.0);
      expect(parseDouble('50000.5'), 50000.5);
      expect(parseDouble('50000,75'), 50000.75);
      expect(parseDouble(null, defaultValue: 100.0), 100.0);
      expect(parseDouble('invalid', defaultValue: 0.0), 0.0);
    });

    test('parseInt parses numeric strings and numbers correctly', () {
      expect(parseInt(42), 42);
      expect(parseInt('42'), 42);
      expect(parseInt('42.8'), 42);
      expect(parseInt(null, defaultValue: 1), 1);
      expect(parseInt('invalid', defaultValue: 5), 5);
    });

    test('parseBool handles booleans, integers and common strings', () {
      expect(parseBool(true), true);
      expect(parseBool(false), false);
      expect(parseBool(1), true);
      expect(parseBool(0), false);
      expect(parseBool('true'), true);
      expect(parseBool('FALSE'), false);
      expect(parseBool('1'), true);
      expect(parseBool('0'), false);
      expect(parseBool('oui'), true);
      expect(parseBool('non'), false);
      expect(parseBool(null, defaultValue: false), false);
    });

    test('parseStringList extracts string lists from various formats', () {
      expect(parseStringList(['a', 'b', 'c']), ['a', 'b', 'c']);
      expect(parseStringList(['  module1  ', 'module2']), ['module1', 'module2']);
      expect(parseStringList('["mod1", "mod2"]'), ['mod1', 'mod2']);
      expect(parseStringList(null), []);
    });
  });

  group('Payment Model Defensive Parsing', () {
    test('Payment.fromMap parses string numbers, missing fields, and custom enums without error', () {
      final rawData = {
        'inscriptionId': 'inscr_123',
        'apprenantId': 'user_456',
        'formationId': 'form_789',
        'montant': '75000', // String instead of double
        'status': 'PaymentStatus.effectue',
        'methode': 'orangeMoney',
        'dateCreation': '2026-08-30T10:00:00.000Z',
        'trancheNumero': '2', // String instead of int
        'nombreTranches': '3', // String instead of int
        'remise': '5000.5', // String instead of double
        'dateEcheance': '2026-09-30T00:00:00.000Z',
      };

      final payment = Payment.fromMap(rawData, 'pay_001');

      expect(payment.id, 'pay_001');
      expect(payment.inscriptionId, 'inscr_123');
      expect(payment.apprenantId, 'user_456');
      expect(payment.montant, 75000.0);
      expect(payment.status, PaymentStatus.effectue);
      expect(payment.methode, PaymentMethod.orangeMoney);
      expect(payment.trancheNumero, 2);
      expect(payment.nombreTranches, 3);
      expect(payment.remise, 5000.5);
      expect(payment.dateEcheance, isNotNull);
    });

    test('Payment.toMap produces valid serializable map', () {
      final payment = Payment(
        id: 'pay_002',
        inscriptionId: 'inscr_002',
        apprenantId: 'user_002',
        formationId: 'form_002',
        montant: 100000.0,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.moovMoney,
        dateCreation: DateTime(2026, 8, 30),
        trancheNumero: 1,
        nombreTranches: 2,
        remise: 10000.0,
      );

      final map = payment.toMap();
      expect(map['id'], 'pay_002');
      expect(map['montant'], 100000.0);
      expect(map['remise'], 10000.0);
      expect(map['trancheNumero'], 1);
      expect(map['nombreTranches'], 2);
      expect(map['methode'], 'moovMoney');
      expect(map['status'], 'effectue');
    });
  });

  group('Formation and Inscription Defensive Parsing', () {
    test('Formation.fromMap handles modulePrices and bonus modules robustly', () {
      final rawData = {
        'titre': 'Formation Intelligence Artificielle',
        'description': 'Formation intensive IA',
        'modules': ['Python', 'Machine Learning', 'Deep Learning'],
        'modulePrices': {
          'Python': '25000', // String price
          'Machine Learning': 35000, // Int price
          'Deep Learning': 40000.0, // Double price
        },
        'prix': '100000',
        'prixEnLigne': '80000',
        'dureeSemaines': '12',
        'dureeHeures': '60',
        'estStage': 'false',
        'nombreInscrits': '15',
        'dateCreation': '2026-08-01T00:00:00.000Z',
      };

      final formation = Formation.fromMap(rawData, 'form_ai');

      expect(formation.id, 'form_ai');
      expect(formation.titre, 'Formation Intelligence Artificielle');
      expect(formation.modules.length, 3);
      expect(formation.modulePrices['Python'], 25000.0);
      expect(formation.modulePrices['Machine Learning'], 35000.0);
      expect(formation.modulePrices['Deep Learning'], 40000.0);
      expect(formation.prix, 100000.0);
      expect(formation.prixEnLigne, 80000.0);
      expect(formation.dureeSemaines, 12);
      expect(formation.dureeHeures, '60');
      expect(formation.estStage, false);
      expect(formation.nombreInscrits, 15);
    });

    test('Inscription.fromMap handles paiementEffectue boolean variations', () {
      final rawTrue = {
        'apprenantId': 'app_1',
        'formationId': 'form_1',
        'paiementEffectue': 'true', // string true
        'status': 'acceptee',
        'dateInscription': '2026-08-30T00:00:00.000Z',
      };

      final inscr1 = Inscription.fromMap(rawTrue, 'inscr_1');
      expect(inscr1.paiementEffectue, true);
      expect(inscr1.status, InscriptionStatus.acceptee);

      final rawFalse = {
        'apprenantId': 'app_2',
        'formationId': 'form_1',
        'paiementEffectue': 0, // integer 0
        'status': 'enAttente',
        'dateInscription': '2026-08-30T00:00:00.000Z',
      };

      final inscr2 = Inscription.fromMap(rawFalse, 'inscr_2');
      expect(inscr2.paiementEffectue, false);
      expect(inscr2.status, InscriptionStatus.enAttente);
    });
  });

  group('Financial Calculations and Invoice Tests', () {
    test('Mathematical invariants hold strictly: Gross - Discount = Net, Net - Paid = Balance', () {
      const double tarifBrut = 150000.0;
      const double remise = 25000.0;
      final double netTotal = (tarifBrut - remise).clamp(0, double.infinity);
      expect(netTotal, 125000.0);

      const double versement1 = 50000.0;
      const double versement2 = 45000.0;
      final double cumulPaye = versement1 + versement2;
      expect(cumulPaye, 95000.0);

      final double soldeRestant = (netTotal - cumulPaye).clamp(0, double.infinity);
      expect(soldeRestant, 30000.0);
      expect(netTotal, cumulPaye + soldeRestant);

      final isFullySettled = soldeRestant <= 0;
      expect(isFullySettled, false);

      const double versementFinal = 30000.0;
      final double cumulFinal = cumulPaye + versementFinal;
      final double soldeFinal = (netTotal - cumulFinal).clamp(0, double.infinity);
      expect(soldeFinal, 0.0);
      expect(soldeFinal <= 0, true);
    });
  });
}
