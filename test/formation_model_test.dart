import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/formation.dart';

void main() {
  group('Formation data', () {
    test('stores the stage flag in firestore data', () {
      final formation = Formation(
        id: '1',
        titre: 'Formation test',
        description: 'Description',
        modules: ['Module 1'],
        formateurIds: ['formateur1'],
        prix: 100,
        type: FormationType.enligne,
        status: FormationStatus.programmee,
        dureeSemaines: 4,
        horaires: [],
        dateCreation: DateTime(2024, 1, 1),
        estStage: true,
        maxModulesParEtudiant: 5,
      );

      final data = formation.toFirestore();
      expect(data['estStage'], isTrue);
      expect(data['maxModulesParEtudiant'], 5);
    });

    test('stores the mixed type in firestore data', () {
      final formation = Formation(
        id: '2',
        titre: 'Formation mixte',
        description: 'Description',
        modules: ['Module 1'],
        formateurIds: ['formateur1'],
        prix: 100,
        type: FormationType.mixte,
        status: FormationStatus.programmee,
        dureeSemaines: 4,
        horaires: [],
        dateCreation: DateTime(2024, 1, 1),
      );

      final data = formation.toFirestore();
      expect(data['type'], 'mixte');
      expect(data['status'], 'programmee');
    });

    test('stores bonus modules in firestore data', () {
      final formation = Formation(
        id: '3',
        titre: 'Stage bonus',
        description: 'Description',
        modules: ['Module 1'],
        modulesBonus: ['Excel', 'PowerPoint'],
        formateurIds: ['formateur1'],
        prix: 100,
        type: FormationType.presentielle,
        status: FormationStatus.programmee,
        dureeSemaines: 4,
        horaires: [],
        dateCreation: DateTime(2024, 1, 1),
      );

      final data = formation.toFirestore();
      expect(data['modulesBonus'], ['Excel', 'PowerPoint']);
    });

    test('parses presentiel and en_cours variations correctly in fromMap', () {
      final raw = {
        'id': 'form_4',
        'titre': 'Formation Pratique',
        'description': 'Formation en présentiel',
        'modules': ['Module A', 'Module B'],
        'modulePrices': {'Module A': '50000', 'Module B': 75000},
        'type': 'presentiel',
        'status': 'en_cours',
        'prix': '125000,50',
        'dureeSemaines': '6',
        'dureeHeures': '60h',
        'estStage': 'true',
        'maxModulesParEtudiant': '3',
        'dateCreation': '2026-08-01T10:00:00.000Z',
      };

      final formation = Formation.fromMap(raw, 'form_4');
      expect(formation.type, FormationType.presentielle);
      expect(formation.status, FormationStatus.enCours);
      expect(formation.prix, 125000.50);
      expect(formation.dureeSemaines, 6);
      expect(formation.estStage, isTrue);
      expect(formation.maxModulesParEtudiant, 3);
      expect(formation.modulePrices['Module A'], 50000.0);
      expect(formation.modulePrices['Module B'], 75000.0);
    });

    test('parses status terminee and imageFormat correctly in fromMap', () {
      final raw = {
        'id': 'form_5',
        'titre': 'Formation Clôturée',
        'description': 'Description',
        'type': 'FormationType.mixte',
        'status': 'terminee',
        'imageFormat': 'vertical',
        'prix': 90000,
        'dureeSemaines': 4,
        'dateCreation': '2026-08-01T10:00:00.000Z',
      };

      final formation = Formation.fromMap(raw, 'form_5');
      expect(formation.type, FormationType.mixte);
      expect(formation.status, FormationStatus.terminee);
      expect(formation.imageFormat, ImageFormat.vertical);
    });
  });
}
