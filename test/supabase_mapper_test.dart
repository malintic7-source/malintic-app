import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/supabase_mapper.dart';

void main() {
  group('SupabaseMapper', () {
    test('maps user snake_case row to User', () {
      final user = SupabaseMapper.userFromRow({
        'id': 'u1',
        'email': 'test@malintic.ml',
        'nom': 'Diallo',
        'prenom': 'Awa',
        'phone': '76000000',
        'matricule': 'STG-001',
        'role': 'admin',
        'photo_url': 'https://example.com/p.jpg',
        'est_actif': true,
        'assigned_formations': [],
        'date_creation': '2026-01-01T00:00:00.000Z',
      });

      expect(user.id, 'u1');
      expect(user.email, 'test@malintic.ml');
      expect(user.photoUrl, 'https://example.com/p.jpg');
      expect(user.isAdmin, isTrue);
    });

    test('maps formation to and from supabase row', () {
      final formation = Formation(
        id: 'f1',
        titre: 'Flutter',
        description: 'Desc',
        modules: ['Dart'],
        formateurIds: ['t1'],
        prix: 50000,
        type: FormationType.mixte,
        status: FormationStatus.enCours,
        dureeSemaines: 4,
        horaires: [],
        dateCreation: DateTime(2026, 1, 1),
        estStage: true,
        maxModulesParEtudiant: 3,
      );

      final row = SupabaseMapper.toRow('formations', formation.toMap());
      expect(row['photo_url'], isNull);
      expect(row['est_stage'], isTrue);
      expect(row['duree_semaines'], 4);
      expect(row['type'], 'mixte');

      final restored = SupabaseMapper.formationFromRow(row);
      expect(restored.titre, 'Flutter');
      expect(restored.estStage, isTrue);
      expect(restored.type, FormationType.mixte);
    });

    test('maps inscription etudiant_id to apprenantId', () {
      final inscription = SupabaseMapper.inscriptionFromRow({
        'id': 'i1',
        'etudiant_id': 'student_1',
        'formation_id': 'f1',
        'status': 'enAttente',
        'paiement_effectue': false,
        'date_inscription': '2026-02-01T10:00:00.000Z',
        'source': 'web',
      });

      expect(inscription.apprenantId, 'student_1');
      expect(inscription.formationId, 'f1');
      expect(inscription.source, 'web');
    });

    test('user select excludes password_hash', () {
      expect(SupabaseMapper.userSelect, isNot(contains('password_hash')));
    });
  });
}
