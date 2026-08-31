import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/seance.dart';
import 'package:gestion_formations/Services/accounting_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accounting & Attendance Exports Test Suite', () {
    final now = DateTime(2026, 8, 31, 10, 0);

    final dummyStudents = [
      User(
        id: 'user_1',
        nom: 'Touré',
        prenom: 'Mamadou',
        email: 'mamadou@malintic.com',
        phone: '+223 70 00 00 01',
        role: UserRole.apprenant,
        dateCreation: now,
      ),
      User(
        id: 'user_2',
        nom: 'Diallo',
        prenom: 'Aissatou',
        email: 'aissatou@malintic.com',
        phone: '+223 76 00 00 02',
        role: UserRole.apprenant,
        dateCreation: now,
      ),
    ];

    final dummyPayments = [
      Payment(
        id: 'pay_1',
        inscriptionId: 'insc_1',
        apprenantId: 'user_1',
        formationId: 'form_sfp_2026',
        montant: 50000.0,
        dateCreation: now,
        dateEffectuation: now,
        methode: PaymentMethod.orangeMoney,
        status: PaymentStatus.effectue,
        remise: 5000.0,
        referenceTransaction: 'OM_REF_123',
      ),
      Payment(
        id: 'pay_2',
        inscriptionId: 'insc_2',
        apprenantId: 'user_2',
        formationId: 'form_sfp_2026',
        montant: 25000.0,
        dateCreation: now.subtract(const Duration(days: 2)),
        dateEffectuation: now.subtract(const Duration(days: 2)),
        methode: PaymentMethod.carte,
        status: PaymentStatus.effectue,
        remise: 0.0,
        referenceTransaction: 'WAVE_REF_456',
      ),
    ];

    final dummyFormation = Formation(
      id: 'form_sfp_2026',
      titre: 'Stage Pratique SFP 2026',
      description: 'Stage pratique systèmes et réseaux',
      modules: ['Maintenance & Diagnostic', 'Réseaux Cisco', 'Virtualisation Linux'],
      modulesBonus: ['Soft Skills & CV'],
      prix: 50000.0,
      type: FormationType.mixte,
      status: FormationStatus.enCours,
      dureeSemaines: 8,
      horaires: const [],
      dateDebut: now,
      dateFin: now.add(const Duration(days: 60)),
      dateCreation: now,
      capaciteMax: 25,
      nombreInscrits: 2,
      estStage: true,
      formateurIds: ['formateur_1'],
    );

    final dummyInscriptions = [
      Inscription(
        id: 'insc_1',
        apprenantId: 'user_1',
        formationId: 'form_sfp_2026',
        dateInscription: now,
        status: InscriptionStatus.acceptee,
        modules: ['Maintenance & Diagnostic', 'Réseaux Cisco', 'Virtualisation Linux'],
        paiementEffectue: true,
        prenom: 'Mamadou',
        nom: 'Touré',
        email: 'mamadou@malintic.com',
        telephone: '+223 70 00 00 01',
      ),
      Inscription(
        id: 'insc_2',
        apprenantId: 'user_2',
        formationId: 'form_sfp_2026',
        dateInscription: now,
        status: InscriptionStatus.acceptee,
        modules: ['Maintenance & Diagnostic'],
        paiementEffectue: true,
        prenom: 'Aissatou',
        nom: 'Diallo',
        email: 'aissatou@malintic.com',
        telephone: '+223 76 00 00 02',
      ),
    ];

    final dummySeances = [
      Seance(
        id: 'seance_1',
        formationId: 'form_sfp_2026',
        formationTitle: 'Stage Pratique SFP 2026',
        moduleId: 'mod_1',
        moduleTitle: 'Maintenance & Diagnostic',
        formateurId: 'formateur_1',
        formateurNom: 'Ing. Sory',
        date: now,
        heureDebut: '10:00',
        heureFin: '12:00',
        salleOuLien: 'Salle A - Informatique',
      ),
    ];

    final Map<String, User> usersMap = {for (final u in dummyStudents) u.id: u};
    final Map<String, Formation> formationsMap = {'form_sfp_2026': dummyFormation};

    test('generateFinancialReportCSV creates valid UTF-8 BOM CSV with totals and deduplicates discounts', () {
      final multiTranchePayments = [
        ...dummyPayments,
        Payment(
          id: 'pay_1_tranche2',
          inscriptionId: 'insc_1',
          apprenantId: 'user_1',
          formationId: 'form_sfp_2026',
          montant: 20000.0,
          dateCreation: now,
          dateEffectuation: now,
          methode: PaymentMethod.orangeMoney,
          status: PaymentStatus.effectue,
          remise: 5000.0, // Same inscription discount recorded on tranche 2
          trancheNumero: 2,
          nombreTranches: 2,
        ),
        Payment(
          id: 'pay_pending',
          inscriptionId: 'insc_3',
          apprenantId: 'user_1',
          formationId: 'form_sfp_2026',
          montant: 30000.0,
          dateCreation: now,
          methode: PaymentMethod.especes,
          status: PaymentStatus.enAttente,
          remise: 0.0,
        ),
        Payment(
          id: 'pay_failed',
          inscriptionId: 'insc_4',
          apprenantId: 'user_2',
          formationId: 'form_sfp_2026',
          montant: 15000.0,
          dateCreation: now,
          methode: PaymentMethod.carte,
          status: PaymentStatus.echoue,
          remise: 0.0,
        ),
      ];

      final csvBytes = AccountingExportService.generateFinancialReportCSV(
        payments: multiTranchePayments,
        formationsMap: formationsMap,
        usersMap: usersMap,
      );

      expect(csvBytes.isNotEmpty, isTrue);
      // Check UTF-8 BOM: 0xEF, 0xBB, 0xBF
      expect(csvBytes[0], 0xEF);
      expect(csvBytes[1], 0xBB);
      expect(csvBytes[2], 0xBF);

      final content = utf8.decode(csvBytes.sublist(3));
      expect(content, contains('RAPPORT FINANCIER & COMPTABLE - MALINTIC'));
      expect(content, contains('Mamadou Touré'));
      expect(content, contains('Aissatou Diallo'));
      // Total encaissé validé = 50 000 + 25 000 + 20 000 = 95 000 (excludes pending 30k and failed 15k)
      expect(content, contains('TOTAL ENCAISSÉ (VALIDÉ);;;;95000'));
      // Total remise deduplicated for insc_1 = 5 000 (not 10 000!)
      expect(content, contains('TOTAL REMISES (DÉDUPLIQUÉ);5000'));
      expect(content, contains('TOTAL EN ATTENTE;;;;30000'));
      expect(content, contains('TOTAL ÉCHOUÉ / REJETÉ;15000'));
    });

    test('generateFinancialReportPDF generates non-empty printable PDF document', () async {
      final pdfBytes = await AccountingExportService.generateFinancialReportPDF(
        payments: dummyPayments,
        formationsMap: formationsMap,
        usersMap: usersMap,
        title: 'RAPPORT DE TEST',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, contains('%PDF'));
    });

    test('generateAttendanceSheetPDF generates valid A4 landscape attendance sheet', () async {
      final pdfBytes = await AccountingExportService.generateAttendanceSheetPDF(
        formation: dummyFormation,
        inscriptions: dummyInscriptions,
        students: dummyStudents,
        seances: dummySeances,
        moduleName: 'Maintenance & Diagnostic',
        formateurName: 'Ing. Sory',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, contains('%PDF'));
    });
  });
}
