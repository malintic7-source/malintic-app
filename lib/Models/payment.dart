import 'package:gestion_formations/utils/app_logger.dart';

// Removed Firestore import (migrating off Firebase)

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

  factory Payment.fromMap(Map<String, dynamic> data, String id) {
    PaymentStatus parseStatus(String statusStr) {
      if (statusStr.contains('effectue')) {
        return PaymentStatus.effectue;
      }
      if (statusStr.contains('echoue')) {
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

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val != null && val.runtimeType.toString().contains('Timestamp')) {
        try {
          return (val as dynamic).toDate();
        } catch (e, s) {
          logHandledError(
            'Date de paiement illisible, valeur de repli utilisée',
            e,
            s,
          );
        }
      }
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Payment(
      id: id,
      inscriptionId: data['inscriptionId'] ?? '',
      apprenantId: data['apprenantId'] ?? data['etudiantId'] ?? '',
      formationId: data['formationId'] ?? '',
      montant: (data['montant'] ?? 0).toDouble(),
      status: parseStatus(data['status']?.toString() ?? 'PaymentStatus.enAttente'),
      methode: parseMethod(data['methode']?.toString() ?? 'PaymentMethod.carte'),
      dateCreation: parseDate(data['dateCreation']) ?? DateTime.now(),
      dateEffectuation: parseDate(data['dateEffectuation']),
      referenceTransaction: data['referenceTransaction'],
      motifEchec: data['motifEchec'],
      motif: data['motif']?.toString(),
      moduleId: data['moduleId']?.toString(),
      trancheNumero: (data['trancheNumero'] as num?)?.toInt() ?? 1,
      nombreTranches: (data['nombreTranches'] as num?)?.toInt() ?? 1,
      remise: (data['remise'] as num?)?.toDouble() ?? 0,
      dateEcheance: parseDate(data['dateEcheance']),
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
      'status': status.toString(),
      'methode': methode.toString(),
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
