import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Pages/Admin/inscriptions.dart';
import 'package:gestion_formations/Services/db_services.dart';

void main() {
  group('inscription fallback helpers', () {
    test('uses inscription data when the user document is missing', () {
      final result = resolveInscriptionUserData(null, {
        'prenom': 'Aminata',
        'nom': 'Diallo',
        'email': 'aminata@example.com',
        'telephone': '770000000',
      });

      expect(result['prenom'], 'Aminata');
      expect(result['nom'], 'Diallo');
      expect(result['email'], 'aminata@example.com');
      expect(result['telephone'], '770000000');
    });

    test('prefers the user document when it is available', () {
      final result = resolveInscriptionUserData({
        'prenom': 'Jean',
        'nom': 'Dupont',
        'email': 'jean@example.com',
        'telephone': '771234567',
      }, {
        'prenom': 'Aminata',
        'nom': 'Diallo',
        'email': 'aminata@example.com',
        'telephone': '770000000',
      });

      expect(result['prenom'], 'Jean');
      expect(result['nom'], 'Dupont');
      expect(result['email'], 'jean@example.com');
      expect(result['telephone'], '771234567');
    });

    test('builds a student profile payload from inscription data', () {
      final result = buildStudentUserDataFromInscription({
        'prenom': 'Aminata',
        'nom': 'Diallo',
        'email': 'aminata@example.com',
        'telephone': '770000000',
      }, 'student_123');

      expect(result['id'], 'student_123');
      expect(result['email'], 'aminata@example.com');
      expect(result['role'], UserRole.apprenant.toString());
      expect(result['estActif'], isTrue);
      expect(result['doitChangerMotDePasse'], isTrue);
    });
  });

  test('accepting a web inscription creates and links the student', () async {
    final db = LocalDataService();
    const email = 'nouvel.etudiant@example.com';
    final inscription = await db.createInscription(
      apprenantId: 'web_test_student',
      formationId: 'form_2',
      prenom: 'Nouvel',
      nom: 'Etudiant',
      email: email,
      telephone: '770000001',
      modules: ['React.js Fundamentals', 'Node.js & Express'],
    );

    final student = await db.acceptInscription(
      inscription.id,
      moduleHours: {
        'React.js Fundamentals': 6,
        'Node.js & Express': 8,
      },
    );

    final savedInscription = db.getInscriptionById(inscription.id)!;
    final assignment = student.assignedFormations.singleWhere(
      (item) => item['formationId'] == 'form_2',
    );
    final assignedModules = assignment['modules'] as List<dynamic>;

    expect(student.role, UserRole.apprenant);
    expect(student.email, email);
    expect(savedInscription.status, InscriptionStatus.acceptee);
    expect(savedInscription.apprenantId, student.id);
    expect(savedInscription.paiementId, isNull);
    expect(db.getPaymentsForInscription(inscription.id), isEmpty);
    expect(assignedModules, hasLength(2));
    expect(assignedModules.first['assignedHours'], 6);
    expect(assignedModules.last['assignedHours'], 8);
    expect(
      db.getNotifications().any(
        (notification) => notification.targetUserIds.contains(student.id),
      ),
      isTrue,
    );
  });

  test('SFP requires exactly three selected modules', () async {
    final db = LocalDataService();

    await expectLater(
      db.createInscription(
        apprenantId: 'web_sfp_invalid',
        formationId: 'form_sfp_2026',
        prenom: 'Moussa',
        nom: 'Traore',
        email: 'moussa@example.com',
        telephone: '770000002',
        modules: ['Base de données + IA', 'Initiation à Windows Server'],
      ),
      throwsA(isA<ArgumentError>()),
    );

    final validInscription = await db.createInscription(
      apprenantId: 'web_sfp_valid',
      formationId: 'form_sfp_2026',
      prenom: 'Moussa',
      nom: 'Traore',
      email: 'moussa_valid@example.com',
      telephone: '770000003',
      modules: [
        'Base de données + IA',
        'Initiation à Windows Server',
        'Initiation au Réseau Téléphonique VoIP',
      ],
    );

    expect(validInscription.modules, hasLength(3));
  });
}
