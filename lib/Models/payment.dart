import 'package:gestion_formations/utils/type_parsers.dart';

enum PaymentStatus { enAttente, effectue, echoue }

enum PaymentMethod { carte, virement, especes, orangeMoney, moovMoney }

class Payment {
  final String id;
  final String inscriptionId;
  final String apprenantId;
  final String formationId;
  final double montant;
  final PaymentStatus status;
  final PaymentMethod methode;
  final DateTime dateCreation;
  final DateTime? dateEffectuation;
  final String? referenceTransaction;
  final String? motifEchec;
  final String? motif;
  final String? moduleId;
  final int trancheNumero;
  final int nombreTranches;
  final double remise;
  final DateTime? dateEcheance;

  String get etudiantId => apprenantId;

  Payment({
    required this.id,
    required this.inscriptionId,
    String? apprenantId,
    String? etudiantId,
    required this.formationId,
    required this.montant,
    required this.status,
    required this.methode,
    required this.dateCreation,
    this.dateEffectuation,
    this.referenceTransaction,
    this.motifEchec,
    this.motif,
    this.moduleId,
    this.trancheNumero = 1,
    this.nombreTranches = 1,
    this.remise = 0,
    this.dateEcheance,
  }) : apprenantId = apprenantId ?? etudiantId ?? '';

  factory Payment.fromMap(Map<dynamic, dynamic> data, String id) {
    PaymentStatus parseStatus(String statusStr) {
      final normalized = statusStr.toLowerCase();
      if (normalized.contains('effectue') || normalized.contains('paye') || normalized.contains('succes')) {
        return PaymentStatus.effectue;
      }
      if (normalized.contains('echoue') || normalized.contains('rejete') || normalized.contains('annule')) {
        return PaymentStatus.echoue;
      }
      return PaymentStatus.enAttente;
    }

    PaymentMethod parseMethod(String methodStr) {
      final normalized = methodStr.toLowerCase();
      if (normalized.contains('orange')) {
        return PaymentMethod.orangeMoney;
      }
      if (normalized.contains('moov')) {
        return PaymentMethod.moovMoney;
      }
      if (normalized.contains('virement')) {
        return PaymentMethod.virement;
      }
      if (normalized.contains('espece')) {
        return PaymentMethod.especes;
      }
      return PaymentMethod.carte;
    }

    return Payment(
      id: id,
      inscriptionId: parseString(data['inscriptionId']),
      apprenantId: parseString(data['apprenantId'] ?? data['etudiantId']),
      formationId: parseString(data['formationId']),
      montant: parseDouble(data['montant']),
      status: parseStatus(parseString(data['status'], defaultValue: 'PaymentStatus.enAttente')),
      methode: parseMethod(parseString(data['methode'], defaultValue: 'PaymentMethod.carte')),
      dateCreation: parseDate(data['dateCreation']),
      dateEffectuation: parseDateOrNull(data['dateEffectuation']),
      referenceTransaction: parseStringOrNull(data['referenceTransaction']),
      motifEchec: parseStringOrNull(data['motifEchec']),
      motif: parseStringOrNull(data['motif']),
      moduleId: parseStringOrNull(data['moduleId']),
      trancheNumero: parseInt(data['trancheNumero'], defaultValue: 1),
      nombreTranches: parseInt(data['nombreTranches'], defaultValue: 1),
      remise: parseDouble(data['remise']),
      dateEcheance: parseDateOrNull(data['dateEcheance']),
    );
  }

  factory Payment.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Payment.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Payment.fromMap(data, doc.id ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inscriptionId': inscriptionId,
      'apprenantId': apprenantId,
      'etudiantId': apprenantId,
      'formationId': formationId,
      'montant': montant,
      'status': status.name,
      'methode': methode.name,
      'dateCreation': dateCreation.toIso8601String(),
      'dateEffectuation': dateEffectuation?.toIso8601String(),
      'referenceTransaction': referenceTransaction,
      'motifEchec': motifEchec,
      'motif': motif,
      'moduleId': moduleId,
      'trancheNumero': trancheNumero,
      'nombreTranches': nombreTranches,
      'remise': remise,
      'dateEcheance': dateEcheance?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();
}
