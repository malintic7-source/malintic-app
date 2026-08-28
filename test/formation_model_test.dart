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
  });
}
