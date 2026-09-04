import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/formation.dart';

void main() {
  group('Horaire', () {
    test('applies defaults when the payload is empty', () {
      final horaire = Horaire.fromMap(const {});

      expect(horaire.jour, '');
      expect(horaire.heureDebut, '');
      expect(horaire.heureFin, '');
      expect(horaire.module, isNull);
      expect(horaire.groupe, isNull);
      expect(horaire.modalite, isNull);
      expect(horaire.lieuOuLien, isNull);
    });

    test('round trips through toMap', () {
      final horaire = Horaire(
        jour: 'Lundi',
        heureDebut: '09:00',
        heureFin: '12:00',
        module: 'Module A',
        groupe: 'SFP-BDIA-A',
        modalite: 'Présentiel',
        lieuOuLien: 'Salle 2',
      );

      final restored = Horaire.fromMap(horaire.toMap());

      expect(restored.jour, 'Lundi');
      expect(restored.heureDebut, '09:00');
      expect(restored.heureFin, '12:00');
      expect(restored.module, 'Module A');
      expect(restored.groupe, 'SFP-BDIA-A');
      expect(restored.modalite, 'Présentiel');
      expect(restored.lieuOuLien, 'Salle 2');
    });
  });

  group('Formation.fromMap', () {
    test('applies defaults when the payload is empty', () {
      final formation = Formation.fromMap(const {}, 'form_1');

      expect(formation.id, 'form_1');
      expect(formation.titre, '');
      expect(formation.description, '');
      expect(formation.modules, isEmpty);
      expect(formation.modulePrices, isEmpty);
      expect(formation.moduleFormateurIds, isEmpty);
      expect(formation.modulesBonus, isEmpty);
      expect(formation.imageUrl, isNull);
      expect(formation.imageFormat, isNull);
      expect(formation.formateurIds, isEmpty);
      expect(formation.prix, 0);
      expect(formation.prixEnLigne, isNull);
      expect(formation.type, FormationType.enligne);
      expect(formation.status, FormationStatus.programmee);
      expect(formation.dureeSemaines, 0);
      expect(formation.horaires, isEmpty);
      expect(formation.dateDebut, isNull);
      expect(formation.dateFin, isNull);
      expect(formation.capaciteMax, isNull);
      expect(formation.nombreInscrits, 0);
      expect(formation.estStage, isFalse);
      expect(formation.maxModulesParEtudiant, isNull);
    });

    test('parses every formation type', () {
      expect(
        Formation.fromMap(const {'type': 'FormationType.presentielle'}, 'f').type,
        FormationType.presentielle,
      );
      expect(
        Formation.fromMap(const {'type': 'FormationType.mixte'}, 'f').type,
        FormationType.mixte,
      );
      expect(
        Formation.fromMap(const {'type': 'FormationType.enligne'}, 'f').type,
        FormationType.enligne,
      );
      expect(
        Formation.fromMap(const {'type': 'inconnu'}, 'f').type,
        FormationType.enligne,
      );
    });

    test('parses every formation status', () {
      expect(
        Formation.fromMap(const {'status': 'FormationStatus.enCours'}, 'f').status,
        FormationStatus.enCours,
      );
      expect(
        Formation.fromMap(const {'status': 'FormationStatus.terminee'}, 'f').status,
        FormationStatus.terminee,
      );
      expect(
        Formation.fromMap(const {'status': 'inconnu'}, 'f').status,
        FormationStatus.programmee,
      );
    });

    test('parses the image format when it is known', () {
      expect(
        Formation.fromMap(const {'imageFormat': 'ImageFormat.carre'}, 'f').imageFormat,
        ImageFormat.carre,
      );
      expect(
        Formation.fromMap(const {'imageFormat': 'ImageFormat.vertical'}, 'f')
            .imageFormat,
        ImageFormat.vertical,
      );
      expect(
        Formation.fromMap(const {'imageFormat': 'panoramique'}, 'f').imageFormat,
        isNull,
      );
    });

    test('normalizes the module maps', () {
      final formation = Formation.fromMap(const {
        'modulePrices': {'Module A': 30000, 'Module B': 25000.5},
        'moduleFormateurIds': {'Module A': 'formateur_1'},
      }, 'form_2');

      expect(formation.modulePrices, {'Module A': 30000.0, 'Module B': 25000.5});
      expect(formation.moduleFormateurIds, {'Module A': 'formateur_1'});
    });

    test('parses the nested horaires', () {
      final formation = Formation.fromMap(const {
        'horaires': [
          {'jour': 'Lundi', 'heureDebut': '09:00', 'heureFin': '12:00'},
          {'jour': 'Mardi', 'heureDebut': '14:00', 'heureFin': '16:00'},
        ],
      }, 'form_3');

      expect(formation.horaires, hasLength(2));
      expect(formation.horaires.first.jour, 'Lundi');
      expect(formation.horaires.last.heureFin, '16:00');
    });

    test('parses dates and defaults dateCreation to now', () {
      final formation = Formation.fromMap(const {
        'dateDebut': '2024-09-01T00:00:00.000',
        'dateFin': '2024-12-01T00:00:00.000',
      }, 'form_4');

      expect(formation.dateDebut, DateTime(2024, 9, 1));
      expect(formation.dateFin, DateTime(2024, 12, 1));
      expect(
        formation.dateCreation.isAfter(
          DateTime.now().subtract(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });

    test('ignores unparsable dates', () {
      final formation = Formation.fromMap(const {
        'dateDebut': 'not-a-date',
        'dateFin': 42,
      }, 'form_5');

      expect(formation.dateDebut, isNull);
      expect(formation.dateFin, isNull);
    });
  });

  test('fromFirestore reads the id from the map payload', () {
    final formation = Formation.fromFirestore(<String, dynamic>{
      'id': 'form_6',
      'titre': 'Flutter avancé',
    });

    expect(formation.id, 'form_6');
    expect(formation.titre, 'Flutter avancé');
  });

  test('toMap round trips through fromMap', () {
    final formation = Formation(
      id: 'form_7',
      titre: 'Développement Mobile',
      description: 'Formation Flutter',
      modules: const ['Module A', 'Module B'],
      modulePrices: const {'Module A': 30000},
      moduleFormateurIds: const {'Module A': 'formateur_1'},
      modulesBonus: const ['Excel'],
      imageUrl: 'https://example.com/affiche.png',
      imageFormat: ImageFormat.vertical,
      formateurIds: const ['formateur_1'],
      prix: 100000,
      prixEnLigne: 80000,
      type: FormationType.mixte,
      status: FormationStatus.enCours,
      dureeSemaines: 12,
      dureeHeures: '120h',
      horaires: [
        Horaire(jour: 'Lundi', heureDebut: '09:00', heureFin: '12:00'),
      ],
      dateDebut: DateTime(2024, 9, 1),
      dateFin: DateTime(2024, 12, 1),
      dateCreation: DateTime(2024, 8, 1),
      capaciteMax: 25,
      nombreInscrits: 10,
      estStage: true,
      maxModulesParEtudiant: 3,
    );

    final data = formation.toMap();
    final restored = Formation.fromMap(data, formation.id);

    expect(formation.toFirestore(), data);
    expect(restored.titre, 'Développement Mobile');
    expect(restored.modules, ['Module A', 'Module B']);
    expect(restored.modulePrices, {'Module A': 30000.0});
    expect(restored.moduleFormateurIds, {'Module A': 'formateur_1'});
    expect(restored.modulesBonus, ['Excel']);
    expect(restored.imageFormat, ImageFormat.vertical);
    expect(restored.prixEnLigne, 80000);
    expect(restored.type, FormationType.mixte);
    expect(restored.status, FormationStatus.enCours);
    expect(restored.dureeHeures, '120h');
    expect(restored.horaires.single.jour, 'Lundi');
    expect(restored.dateDebut, DateTime(2024, 9, 1));
    expect(restored.dateCreation, DateTime(2024, 8, 1));
    expect(restored.capaciteMax, 25);
    expect(restored.nombreInscrits, 10);
    expect(restored.estStage, isTrue);
    expect(restored.maxModulesParEtudiant, 3);
  });

  group('Formation.copyWith', () {
    test('overrides only the provided fields', () {
      final formation = Formation(
        id: 'form_8',
        titre: 'Réseaux',
        description: 'Formation réseaux',
        modules: const ['Module A'],
        formateurIds: const ['formateur_1'],
        prix: 50000,
        type: FormationType.presentielle,
        status: FormationStatus.programmee,
        dureeSemaines: 6,
        horaires: const [],
        dateCreation: DateTime(2024, 1, 1),
      );

      final started = formation.copyWith(
        status: FormationStatus.enCours,
        nombreInscrits: 5,
      );

      expect(started.id, 'form_8');
      expect(started.titre, 'Réseaux');
      expect(started.status, FormationStatus.enCours);
      expect(started.nombreInscrits, 5);
      expect(formation.status, FormationStatus.programmee);
      expect(formation.nombreInscrits, 0);
    });

    test('keeps existing values when no override is given', () {
      final formation = Formation(
        id: 'form_9',
        titre: 'Comptabilité',
        description: 'Formation comptable',
        modules: const ['Module A'],
        formateurIds: const ['formateur_1'],
        prix: 45000,
        type: FormationType.enligne,
        status: FormationStatus.terminee,
        dureeSemaines: 8,
        horaires: const [],
        dateCreation: DateTime(2024, 2, 1),
      );

      expect(formation.copyWith().toMap(), formation.toMap());
    });
  });

  test('equality is based on the identifier only', () {
    Formation build(String id, String titre) => Formation(
          id: id,
          titre: titre,
          description: 'Description',
          modules: const [],
          formateurIds: const [],
          prix: 0,
          type: FormationType.enligne,
          status: FormationStatus.programmee,
          dureeSemaines: 0,
          horaires: const [],
          dateCreation: DateTime(2024, 1, 1),
        );

    expect(build('form_10', 'A'), build('form_10', 'B'));
    expect(build('form_10', 'A').hashCode, build('form_10', 'B').hashCode);
    expect(build('form_10', 'A'), isNot(build('form_11', 'A')));
  });
}
