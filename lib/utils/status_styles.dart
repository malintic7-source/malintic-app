import 'package:flutter/material.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/config/theme.dart';

/// Centralizes labels and colors for application statuses and roles.
extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.effectue:
        return 'Effectué';
      case PaymentStatus.enAttente:
        return 'En attente';
      case PaymentStatus.echoue:
        return 'Échoué';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.effectue:
        return AppTheme.success;
      case PaymentStatus.enAttente:
        return const Color(0xFFFB923C);
      case PaymentStatus.echoue:
        return AppTheme.error;
    }
  }
}

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.virement:
        return 'Virement';
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.carte:
        return 'Carte bancaire';
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.moovMoney:
        return 'Moov Money';
    }
  }
}

String inscriptionStatusLabel(String raw) {
  switch (raw) {
    case 'en_attente':
      return 'En Attente';
    case 'rejete':
      return 'Rejeté';
    case 'incomplet':
      return 'Incomplet';
    case 'complet':
      return 'Complet';
    case 'paiement_complet':
      return 'Complet';
    default:
      return 'En Attente';
  }
}

int inscriptionStatusColorValue(String raw) {
  switch (raw) {
    case 'en_attente':
      return 0xFFF59E0B;
    case 'rejete':
      return 0xFFEF4444;
    case 'incomplet':
      return 0xFFFB923C;
    case 'complet':
      return 0xFF10B981;
    case 'paiement_complet':
      return 0xFF10B981;
    default:
      return 0xFF6B7280;
  }
}

String fuzzyPaymentStatusLabel(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('valide') || s.contains('pay') || s.contains('effectue')) {
    return 'Validé';
  } else if (s.contains('incomplet') || s.contains('partiel') || s.contains('avance')) {
    return 'Incomplet';
  } else if (s.contains('attente')) {
    return 'En Attente';
  } else if (s.contains('echou') || s.contains('annul') || s.contains('rej')) {
    return 'Échoué';
  }
  return 'Validé';
}

int fuzzyPaymentStatusColorValue(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('valide') || s.contains('pay') || s.contains('effectue')) {
    return 0xFF10B981;
  } else if (s.contains('incomplet') || s.contains('partiel') || s.contains('avance')) {
    return 0xFFFB923C;
  } else if (s.contains('attente')) {
    return 0xFFF59E0B;
  } else if (s.contains('echou') || s.contains('annul') || s.contains('rej')) {
    return 0xFFEF4444;
  }
  return 0xFF10B981;
}

extension FormationStatusX on FormationStatus {
  String get label {
    switch (this) {
      case FormationStatus.enCours:
        return 'En Cours';
      case FormationStatus.terminee:
        return 'Terminée';
      default:
        return 'Programmée';
    }
  }
}

extension FormationTypeX on FormationType {
  String get label {
    switch (this) {
      case FormationType.presentielle:
        return 'Présentielle';
      case FormationType.mixte:
        return 'Mixte';
      default:
        return 'En ligne';
    }
  }
}

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Administrateur';
    case UserRole.dg:
      return 'Directeur Général (DG)';
    case UserRole.daf:
      return 'DAF';
    case UserRole.comptable:
      return 'Comptable';
    case UserRole.assistant:
      return 'Assistant(e)';
    case UserRole.it:
      return 'Responsable IT';
    case UserRole.formateur:
      return 'Formateur';
    case UserRole.apprenant:
      return 'Stagiaire / Apprenant';
  }
}
