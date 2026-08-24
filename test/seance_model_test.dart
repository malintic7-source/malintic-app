import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/seance.dart';

void main() {
  group('Seance.fromMap', () {
    test('applies defaults when the payload is empty', () {
      final seance = Seance.fromMap(const {}, 'seance_1');

      expect(seance.id, 'seance_1');
      expect(seance.formationId, '');
      expect(seance.formationTitle, '');
      expect(seance.moduleId, isNull);
      expect(seance.heureDebut, '09:00');
      expect(seance.heureFin, '11:00');
      expect(seance.modalite, 'Présentiel');
      expect(seance.statut, SeanceStatut.brouillon);
      expect(seance.datePublication, isNull);
    });

    test('parses the published status from both spellings', () {
      final fromEnum = Seance.fromMap(
        const {'statut': 'SeanceStatut.publie'},
        'seance_2',
      );
      final fromAccentedLabel = Seance.fromMap(
        const {'statut': 'publié'},
        'seance_3',
      );

      expect(fromEnum.statut, SeanceStatut.publie);
      expect(fromEnum.estPubliee, isTrue);
      expect(fromEnum.estBrouillon, isFalse);
      expect(fromAccentedLabel.statut, SeanceStatut.publie);
    });

    test('falls back to brouillon for an unknown status', () {
      final seance = Seance.fromMap(const {'statut': 'inconnu'}, 'seance_4');

      expect(seance.statut, SeanceStatut.brouillon);
      expect(seance.estBrouillon, isTrue);
      expect(seance.estPubliee, isFalse);
    });

    test('parses dates from strings and DateTime values', () {
      final seance = Seance.fromMap({
        'date': '2024-03-15T10:00:00.000',
        'dateCreation': DateTime(2024, 3, 1),
        'datePublication': '2024-03-10T08:30:00.000',
      }, 'seance_5');

      expect(seance.date, DateTime(2024, 3, 15, 10));
      expect(seance.dateCreation, DateTime(2024, 3, 1));
      expect(seance.datePublication, DateTime(2024, 3, 10, 8, 30));
    });

    test('falls back to now for an unparsable date', () {
      final before = DateTime.now();
      final seance = Seance.fromMap(const {'date': 'not-a-date'}, 'seance_6');

      expect(seance.date.isBefore(before), isFalse);
    });
  });

  test('toMap serializes dates and status as strings', () {
    final seance = Seance(
      id: 'seance_7',
      formationId: 'form_1',
      formationTitle: 'Flutter',
      moduleId: 'mod_1',
      moduleTitle: 'Dart',
      formateurId: 'formateur_1',
      formateurNom: 'Ousmane Diarra',
      date: DateTime(2024, 5, 2, 9),
      heureDebut: '09:00',
      heureFin: '12:00',
      salleOuLien: 'Salle A',
      modalite: 'Présentiel',
      statut: SeanceStatut.publie,
      dateCreation: DateTime(2024, 4, 1),
      datePublication: DateTime(2024, 4, 20),
    );

    final data = seance.toMap();

    expect(data['id'], 'seance_7');
    expect(data['formationTitle'], 'Flutter');
    expect(data['moduleTitle'], 'Dart');
    expect(data['salleOuLien'], 'Salle A');
    expect(data['statut'], 'SeanceStatut.publie');
    expect(data['date'], DateTime(2024, 5, 2, 9).toIso8601String());
    expect(data['dateCreation'], DateTime(2024, 4, 1).toIso8601String());
    expect(data['datePublication'], DateTime(2024, 4, 20).toIso8601String());
  });

  test('toMap round trips through fromMap', () {
    final seance = Seance(
      id: 'seance_8',
      formationId: 'form_2',
      formationTitle: 'Réseaux',
      formateurId: 'formateur_2',
      formateurNom: 'Awa Kone',
      date: DateTime(2024, 6, 10, 14),
      heureDebut: '14:00',
      heureFin: '16:00',
      modalite: 'En ligne',
      statut: SeanceStatut.publie,
      dateCreation: DateTime(2024, 6, 1),
    );

    final restored = Seance.fromMap(seance.toMap(), seance.id);

    expect(restored.formationTitle, seance.formationTitle);
    expect(restored.formateurNom, seance.formateurNom);
    expect(restored.date, seance.date);
    expect(restored.heureFin, seance.heureFin);
    expect(restored.modalite, 'En ligne');
    expect(restored.statut, SeanceStatut.publie);
  });

  group('Seance.copyWith', () {
    test('overrides only the provided fields', () {
      final seance = Seance(
        id: 'seance_9',
        formationId: 'form_3',
        formationTitle: 'Bureautique',
        formateurId: 'formateur_3',
        formateurNom: 'Fatoumata Sidibe',
        date: DateTime(2024, 7, 1, 8),
        heureDebut: '08:00',
        heureFin: '10:00',
        dateCreation: DateTime(2024, 6, 15),
      );

      final published = seance.copyWith(
        statut: SeanceStatut.publie,
        datePublication: DateTime(2024, 6, 20),
        salleOuLien: 'https://meet.example/abc',
      );

      expect(published.id, 'seance_9');
      expect(published.formationTitle, 'Bureautique');
      expect(published.heureDebut, '08:00');
      expect(published.statut, SeanceStatut.publie);
      expect(published.datePublication, DateTime(2024, 6, 20));
      expect(published.salleOuLien, 'https://meet.example/abc');
      expect(seance.statut, SeanceStatut.brouillon);
      expect(seance.datePublication, isNull);
    });

    test('keeps existing values when no override is given', () {
      final seance = Seance(
        id: 'seance_10',
        formationId: 'form_4',
        formationTitle: 'Comptabilité',
        formateurId: 'formateur_4',
        formateurNom: 'Ibrahim Traore',
        date: DateTime(2024, 8, 5, 9),
        heureDebut: '09:00',
        heureFin: '11:00',
        dateCreation: DateTime(2024, 8, 1),
      );

      final copy = seance.copyWith();

      expect(copy.toMap(), seance.toMap());
    });
  });

  test('dateCreation defaults to now when omitted', () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final seance = Seance(
      id: 'seance_11',
      formationId: 'form_5',
      formationTitle: 'Marketing',
      formateurId: 'formateur_5',
      formateurNom: 'Mariam Cisse',
      date: DateTime(2024, 9, 1),
      heureDebut: '09:00',
      heureFin: '11:00',
    );

    expect(seance.dateCreation.isAfter(before), isTrue);
  });
}
