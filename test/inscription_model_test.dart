import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/inscription.dart';

void main() {
  group('Inscription.fromMap', () {
    test('applies defaults when the payload is empty', () {
      final inscription = Inscription.fromMap(const {}, 'insc_1');

      expect(inscription.id, 'insc_1');
      expect(inscription.apprenantId, '');
      expect(inscription.formationId, '');
      expect(inscription.status, InscriptionStatus.enAttente);
      expect(inscription.paiementId, isNull);
      expect(inscription.paiementEffectue, isFalse);
      expect(inscription.modules, isNull);
      expect(inscription.source, 'web');
    });

    test('parses the accepted status from its variants', () {
      for (final raw in const [
        'InscriptionStatus.acceptee',
        'accepte',
        'valide',
      ]) {
        expect(
          Inscription.fromMap({'status': raw}, 'insc').status,
          InscriptionStatus.acceptee,
          reason: raw,
        );
      }
    });

    test('parses the rejected status from its variants', () {
      for (final raw in const ['InscriptionStatus.rejetee', 'rejete']) {
        expect(
          Inscription.fromMap({'status': raw}, 'insc').status,
          InscriptionStatus.rejetee,
          reason: raw,
        );
      }
    });

    test('falls back to enAttente for an unknown status', () {
      expect(
        Inscription.fromMap(const {'status': 'inconnu'}, 'insc').status,
        InscriptionStatus.enAttente,
      );
    });

    test('reads the legacy etudiantId key when apprenantId is absent', () {
      final inscription = Inscription.fromMap(
        const {'etudiantId': 'student_legacy'},
        'insc_2',
      );

      expect(inscription.apprenantId, 'student_legacy');
      expect(inscription.etudiantId, 'student_legacy');
    });

    test('parses dates from strings and DateTime values', () {
      expect(
        Inscription.fromMap(
          const {'dateInscription': '2024-02-01T09:00:00.000'},
          'insc',
        ).dateInscription,
        DateTime(2024, 2, 1, 9),
      );
      expect(
        Inscription.fromMap(
          {'dateInscription': DateTime(2024, 2, 2)},
          'insc',
        ).dateInscription,
        DateTime(2024, 2, 2),
      );
    });

    test('falls back to now for an unparsable date', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));

      expect(
        Inscription.fromMap(const {'dateInscription': 42}, 'insc')
            .dateInscription
            .isAfter(before),
        isTrue,
      );
    });

    test('keeps modules only when the payload holds a list', () {
      expect(
        Inscription.fromMap(const {'modules': ['Dart', 'Flutter']}, 'insc').modules,
        ['Dart', 'Flutter'],
      );
      expect(
        Inscription.fromMap(const {'modules': 'Dart'}, 'insc').modules,
        isNull,
      );
    });

    test('reads the applicant contact details', () {
      final inscription = Inscription.fromMap(const {
        'prenom': 'Aminata',
        'nom': 'Diallo',
        'email': 'aminata@example.com',
        'telephone': '770000000',
        'description': 'Candidature web',
        'typeFormation': 'presentielle',
        'sexe': 'Femme',
        'source': 'admin',
      }, 'insc_3');

      expect(inscription.prenom, 'Aminata');
      expect(inscription.nom, 'Diallo');
      expect(inscription.email, 'aminata@example.com');
      expect(inscription.telephone, '770000000');
      expect(inscription.description, 'Candidature web');
      expect(inscription.typeFormation, 'presentielle');
      expect(inscription.sexe, 'Femme');
      expect(inscription.source, 'admin');
    });
  });

  test('fromFirestore reads the id from the map payload', () {
    final inscription = Inscription.fromFirestore(<String, dynamic>{
      'id': 'insc_4',
      'status': 'InscriptionStatus.acceptee',
    });

    expect(inscription.id, 'insc_4');
    expect(inscription.status, InscriptionStatus.acceptee);
  });

  test('etudiantId falls back to the constructor alias', () {
    final inscription = Inscription(
      id: 'insc_5',
      etudiantId: 'student_alias',
      formationId: 'form_1',
      status: InscriptionStatus.enAttente,
      dateInscription: DateTime(2024, 1, 1),
      paiementEffectue: false,
    );

    expect(inscription.apprenantId, 'student_alias');
    expect(inscription.etudiantId, 'student_alias');
  });

  test('toMap exposes both apprenantId and the legacy etudiantId', () {
    final inscription = Inscription(
      id: 'insc_6',
      apprenantId: 'student_6',
      formationId: 'form_2',
      status: InscriptionStatus.acceptee,
      dateInscription: DateTime(2024, 3, 1),
      paiementId: 'pay_1',
      paiementEffectue: true,
      dateAcceptation: '2024-03-02',
      modules: const ['Dart'],
    );

    final data = inscription.toMap();

    expect(data['apprenantId'], 'student_6');
    expect(data['etudiantId'], 'student_6');
    expect(data['status'], 'InscriptionStatus.acceptee');
    expect(data['dateInscription'], DateTime(2024, 3, 1).toIso8601String());
    expect(data['paiementId'], 'pay_1');
    expect(data['paiementEffectue'], isTrue);
    expect(data['dateAcceptation'], '2024-03-02');
    expect(data['modules'], ['Dart']);
    expect(inscription.toFirestore(), data);
  });

  test('toMap round trips through fromMap', () {
    final inscription = Inscription(
      id: 'insc_7',
      apprenantId: 'student_7',
      formationId: 'form_3',
      status: InscriptionStatus.rejetee,
      dateInscription: DateTime(2024, 4, 1),
      paiementEffectue: false,
      motifRejet: 'Dossier incomplet',
      source: 'admin',
    );

    final restored = Inscription.fromMap(inscription.toMap(), inscription.id);

    expect(restored.status, InscriptionStatus.rejetee);
    expect(restored.motifRejet, 'Dossier incomplet');
    expect(restored.source, 'admin');
    expect(restored.dateInscription, DateTime(2024, 4, 1));
  });
}
