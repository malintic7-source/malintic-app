import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Services/db_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🎯 Circuit Complet E2E - Simulation Réelle Multi-Rôles de A à Z (SFP5 Stagiaires & Étudiants)', () {
    late LocalDataService db;
    final testRunId = DateTime.now().microsecondsSinceEpoch;

    setUp(() {
      db = LocalDataService();
    });

    test('1. [Public / Candidat] Inscription SFP5 (Stage de Formation Professionnelle 5e Édition) avec sélection de 3 modules', () async {
      // Vérification que la formation SFP5 existe et est configurée en Stage
      final sfpFormation = db.getFormationById('form_sfp_2026');
      expect(sfpFormation, isNotNull);
      expect(sfpFormation!.estStage, isTrue);
      expect(sfpFormation.titre, contains('SFP5'));
      expect(sfpFormation.maxModulesParEtudiant, equals(3));
      expect(sfpFormation.modules, hasLength(19));

      // Inscription valide avec 3 modules officiels SFP5
      final emailStagiaire = 'stagiaire.sfp5.$testRunId@malintic.com';
      final selectedModulesSfp = [
        'Création d’applications (Flutter)',
        'Base de données + IA',
        'Intelligence Artificielle (IA)',
      ];

      final inscriptionSfp = await db.createInscription(
        apprenantId: 'temp_stagiaire_$testRunId',
        formationId: 'form_sfp_2026',
        prenom: 'Ibrahim',
        nom: 'Diallo',
        email: emailStagiaire,
        telephone: '+223 77 12 34 56',
        modules: selectedModulesSfp,
        typeFormation: 'presentiel',
      );

      expect(inscriptionSfp.id, isNotEmpty);
      expect(inscriptionSfp.formationId, equals('form_sfp_2026'));
      expect(inscriptionSfp.status, equals(InscriptionStatus.enAttente));
      expect(inscriptionSfp.modules, hasLength(3));

      // Tentative d'inscription invalide avec 2 modules seulement pour un stage SFP
      expect(
        () => db.createInscription(
          apprenantId: 'temp_invalide_$testRunId',
          formationId: 'form_sfp_2026',
          prenom: 'Test',
          nom: 'Invalide',
          email: 'invalide.$testRunId@malintic.com',
          telephone: '+223 70 00 00 00',
          modules: ['Création d’applications (Flutter)', 'Base de données + IA'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('2. [Administrateur] Traitement des Inscriptions : Rejet d\'un dossier & Validation/Enrôlement du Stagiaire SFP5', () async {
      // A. Dossier à rejeter
      final badInscription = await db.createInscription(
        apprenantId: 'bad_candidate_$testRunId',
        formationId: 'form_2',
        prenom: 'Candidat',
        nom: 'Doublon',
        email: 'doublon.$testRunId@example.com',
        telephone: '+223 66 00 00 00',
        modules: ['React.js Fundamentals'],
      );

      await db.updateInscriptionStatus(
        badInscription.id,
        'rejete',
        motifRejet: 'Dossier incomplet / informations de contact non joignables',
      );

      final rejected = db.getInscriptionById(badInscription.id);
      expect(rejected?.status, equals(InscriptionStatus.rejetee));
      expect(rejected?.motifRejet, contains('Dossier incomplet'));

      // B. Dossier SFP5 à valider
      final emailSfp = 'adama.traore.$testRunId@malintic.com';
      final inscriptionSfp = await db.createInscription(
        apprenantId: 'temp_adama_$testRunId',
        formationId: 'form_sfp_2026',
        prenom: 'Adama',
        nom: 'Traoré',
        email: emailSfp,
        telephone: '+223 75 11 22 33',
        modules: ['Création d’applications (Flutter)', 'Base de données + IA', 'Intelligence Artificielle (IA)'],
      );

      // Validation par l'Admin avec découpage horaire personnalisé par module
      final customModuleHours = {
        'Création d’applications (Flutter)': 20,
        'Base de données + IA': 20,
        'Intelligence Artificielle (IA)': 15,
      };

      final stagiaireUser = await db.acceptInscription(
        inscriptionSfp.id,
        moduleHours: customModuleHours,
      );

      // Vérifications de l'enrôlement Stagiaire
      expect(stagiaireUser.id, isNotEmpty);
      expect(stagiaireUser.role, equals(UserRole.apprenant));
      expect(stagiaireUser.email, equals(emailSfp));
      expect(stagiaireUser.matricule, isNotNull);

      final stagiaireFormations = stagiaireUser.assignedFormations;
      expect(stagiaireFormations, isNotEmpty);
      final sfpAssignment = stagiaireFormations.firstWhere((f) => f['formationId'] == 'form_sfp_2026');
      expect(sfpAssignment['title'], contains('SFP5'));
      
      final assignedMods = (sfpAssignment['modules'] as List<dynamic>);
      expect(assignedMods, hasLength(3));
      final flutterMod = assignedMods.firstWhere((m) => m['title'] == 'Création d’applications (Flutter)');
      expect(flutterMod['assignedHours'], equals(20));

      // L'inscription passe au statut acceptée
      final acceptedInsc = db.getInscriptionById(inscriptionSfp.id);
      expect(acceptedInsc?.status, equals(InscriptionStatus.acceptee));
      expect(acceptedInsc?.apprenantId, equals(stagiaireUser.id));
    });

    test('3. [Administrateur & Comptabilité] Gestion des Paiements par Tranches avec Remise SFP5', () async {
      final email = 'kadiatou.coulibaly.$testRunId@malintic.com';
      final inscription = await db.createInscription(
        apprenantId: 'temp_kadiatou_$testRunId',
        formationId: 'form_sfp_2026',
        prenom: 'Kadiatou',
        nom: 'Coulibaly',
        email: email,
        telephone: '+223 79 44 55 66',
        modules: ['Création d’applications (Flutter)', 'Base de données + IA', 'Intelligence Artificielle (IA)'],
      );

      final stagiaire = await db.acceptInscription(
        inscription.id,
        moduleHours: {'Création d’applications (Flutter)': 18, 'Base de données + IA': 18, 'Intelligence Artificielle (IA)': 18},
      );

      // Enregistrement Tranche 1 (Acompte de 70 000 FCFA avec remise exceptionnelle de 5 000 FCFA sur formation à 150 000)
      final paiementTranche1 = Payment(
        id: 'pay_tranche1_$testRunId',
        inscriptionId: inscription.id,
        etudiantId: stagiaire.id,
        formationId: 'form_sfp_2026',
        montant: 70000.0,
        remise: 5000.0,
        trancheNumero: 1,
        nombreTranches: 2,
        methode: PaymentMethod.orangeMoney,
        status: PaymentStatus.effectue,
        dateCreation: DateTime.now(),
        dateEcheance: DateTime.now().add(const Duration(days: 30)),
        referenceTransaction: 'OM-SFP5-2026-$testRunId',
      );

      await db.addPayment(paiementTranche1);

      final paymentsStagiaire = db.getPaymentsForInscription(inscription.id);
      expect(paymentsStagiaire, hasLength(1));
      expect(paymentsStagiaire.first.montant, equals(70000.0));
      expect(paymentsStagiaire.first.remise, equals(5000.0));
      expect(paymentsStagiaire.first.trancheNumero, equals(1));
      expect(paymentsStagiaire.first.dateEcheance, isNotNull);
      expect(db.getInscriptionPaidAmount(inscription.id), equals(70000.0));
      expect(db.getInscriptionBalance(inscription.id), equals(25000.0)); // Prix fixe global SFP5 100 000 - 5 000 (remise) - 70 000 (versé)
    });

    test('4. [Formateur] Émargement de Présence et Avancement des Heures Réalisées', () async {
      // Inscription et validation d'un stagiaire
      final email = 'presence.sfp5.$testRunId@malintic.com';
      final inscription = await db.createInscription(
        apprenantId: 'temp_presence_$testRunId',
        formationId: 'form_sfp_2026',
        prenom: 'Salif',
        nom: 'Keita',
        email: email,
        telephone: '+223 72 00 11 22',
        modules: ['Création d’applications (Flutter)', 'Base de données + IA', 'Intelligence Artificielle (IA)'],
      );

      final stagiaire = await db.acceptInscription(
        inscription.id,
        moduleHours: {'Création d’applications (Flutter)': 20, 'Base de données + IA': 20, 'Intelligence Artificielle (IA)': 15},
      );

      // Émargement par le Formateur
      await db.recordAttendance(
        userId: stagiaire.id,
        formationId: 'form_sfp_2026',
        status: 'present',
        note: 'Séance d\'introduction Flutter BLoC',
      );

      final studentWithAttendance = db.getUserById(stagiaire.id);
      final assignment = studentWithAttendance!.assignedFormations.firstWhere((f) => f['formationId'] == 'form_sfp_2026');
      final attendanceList = (assignment['attendance'] as List<dynamic>? ?? []);
      expect(attendanceList, isNotEmpty);
      expect(attendanceList.first['status'], equals('present'));

      // Avancement des heures par le formateur
      await db.updateModuleDoneHours(stagiaire.id, 'form_sfp_2026', 'Création d’applications (Flutter)', 4);
      final studentWithHours = db.getUserById(stagiaire.id);
      final updatedAssignment = studentWithHours!.assignedFormations.firstWhere((f) => f['formationId'] == 'form_sfp_2026');
      final flutterModule = (updatedAssignment['modules'] as List<dynamic>).firstWhere((m) => m['title'] == 'Création d’applications (Flutter)');
      expect(flutterModule['doneHours'], equals(4));
    });

    test('5. [Stagiaire SFP5] Connexion, Changement de Mot de Passe & Calcul de Progression', () async {
      final stagiaireInit = User(
        id: 'stagiaire_login_$testRunId',
        email: 'stagiaire.active.$testRunId@malintic.com',
        prenom: 'Moussa',
        nom: 'Diarra',
        phone: '+223 71 22 33 44',
        role: UserRole.apprenant,
        matricule: 'STG-SFP5-0099',
        estActif: true,
        doitChangerMotDePasse: true,
        assignedFormations: [
          {
            'formationId': 'form_sfp_2026',
            'title': 'Stage de Formation Professionnelle - SFP5',
            'dateAssigned': DateTime.now().toIso8601String(),
            'modules': [
              {'title': 'Création d’applications (Flutter)', 'assignedHours': 20, 'doneHours': 10},
              {'title': 'Base de données + IA', 'assignedHours': 20, 'doneHours': 5},
              {'title': 'Intelligence Artificielle (IA)', 'assignedHours': 15, 'doneHours': 5},
            ],
          }
        ],
      );

      await db.addUser(stagiaireInit);
      expect(db.getUserById(stagiaireInit.id)?.doitChangerMotDePasse, isTrue);

      // Simulation du changement de mot de passe réussi
      final updatedUser = stagiaireInit.copyWith(
        password: 'NouveauPassSecurise2026!',
        doitChangerMotDePasse: false,
      );
      await db.addUser(updatedUser);

      final stagiaireUpdated = db.getUserById(stagiaireInit.id);
      expect(stagiaireUpdated?.doitChangerMotDePasse, isFalse);
      expect(stagiaireUpdated?.password, equals('NouveauPassSecurise2026!'));

      // Vérification du calcul de progression globale SFP5
      final assigned = stagiaireUpdated!.assignedFormations.first;
      final modules = (assigned['modules'] as List<dynamic>);
      final totalAssigned = modules.fold<int>(0, (sum, m) => sum + ((m['assignedHours'] ?? 0) as int));
      final totalDone = modules.fold<int>(0, (sum, m) => sum + ((m['doneHours'] ?? 0) as int));

      expect(totalAssigned, equals(55));
      expect(totalDone, equals(20));
      final progressionPercent = (totalDone / totalAssigned * 100).round();
      expect(progressionPercent, equals(36));
    });

    test('6. [Admin / Employé LAN] Inscription au guichet/bureau pour un candidat SFP5 en direct', () async {
      // Un employé autorisé enregistre un candidat sur place au bureau
      final adminCreatedInsc = await db.createInscription(
        etudiantId: 'admin_desk_$testRunId',
        formationId: 'form_sfp_2026',
        prenom: 'Fatoumata',
        nom: 'Bagayoko',
        email: 'fatoumata.desk.$testRunId@malintic.com',
        telephone: '+223 76 88 99 00',
        modules: ['Adobe Photoshop', 'Adobe Première Pro', 'Canva + IA (Affiches)'],
        typeFormation: 'presentiel',
      );

      expect(adminCreatedInsc.id, isNotEmpty);
      expect(adminCreatedInsc.formationId, equals('form_sfp_2026'));
      expect(adminCreatedInsc.status, equals(InscriptionStatus.enAttente));
      expect(adminCreatedInsc.modules, hasLength(3));

      // Le prix de base calculé pour cette inscription SFP5 au guichet est bien le prix fixe de 100 000 FCFA
      final baseTotal = db.getInscriptionBaseTotal(adminCreatedInsc.id);
      expect(baseTotal, equals(100000.0));
    });
  });
}
