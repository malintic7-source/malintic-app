import 'package:gestion_formations/Models/audit_log.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/notification.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/seance.dart';
import 'package:gestion_formations/Models/user.dart';

/// Converts between Dart domain maps and Supabase PostgreSQL row format (snake_case).
class SupabaseMapper {
  SupabaseMapper._();

  static const userSelect =
      'id,email,nom,prenom,phone,matricule,role,photo_url,specialite,sexe,est_actif,assigned_formations,date_creation,date_modification';

  static const formationSelect =
      'id,titre,description,prix,prix_en_ligne,modules,module_prices,modules_bonus,formateur_ids,module_formateur_ids,type,status,duree_semaines,duree_heures,horaires,photo_url,est_stage,max_modules_par_etudiant,nombre_inscrits,capacite_max,date_debut,date_fin,date_creation,image_format';

  static const inscriptionSelect =
      'id,etudiant_id,formation_id,nom,prenom,email,telephone,sexe,type_formation,description,modules,status,paiement_effectue,paiement_id,motif_rejet,date_inscription,date_acceptation,source';

  static const paymentSelect =
      'id,inscription_id,etudiant_id,formation_id,montant,remise,tranche_numero,nombre_tranches,status,methode,reference,date_paiement,date_creation,date_effectuation,motif,module_id';

  static const seanceSelect =
      'id,formation_id,formateur_id,module_title,statut,date_debut,date_fin,contenu,date_creation';

  static const auditLogSelect =
      'id,user_nom,user_role,action,description,timestamp,target_id,target_type,severity';

  static const notificationSelect =
      'id,title,description,image_url,sender_id,sender_email,target_roles,target_user_ids,audience,read_by,reminder_count,created_at,updated_at';

  static String selectFor(String collection) {
    switch (collection) {
      case 'users':
        return userSelect;
      case 'formations':
        return formationSelect;
      case 'inscriptions':
        return inscriptionSelect;
      case 'payments':
        return paymentSelect;
      case 'seances':
        return seanceSelect;
      case 'audit_logs':
        return auditLogSelect;
      case 'notifications':
        return notificationSelect;
      default:
        return '*';
    }
  }

  static Map<String, dynamic> toRow(String collection, Map<String, dynamic> data) {
    switch (collection) {
      case 'users':
        return _userToRow(data);
      case 'formations':
        return _formationToRow(data);
      case 'inscriptions':
        return _inscriptionToRow(data);
      case 'payments':
        return _paymentToRow(data);
      case 'seances':
        return _seanceToRow(data);
      case 'audit_logs':
        return _auditLogToRow(data);
      case 'notifications':
        return _notificationToRow(data);
      default:
        return Map<String, dynamic>.from(data);
    }
  }

  static User userFromRow(Map<String, dynamic> row) {
    return User.fromMap(_userFromRow(row), row['id']?.toString() ?? '');
  }

  static Formation formationFromRow(Map<String, dynamic> row) {
    return Formation.fromMap(_formationFromRow(row), row['id']?.toString() ?? '');
  }

  static Inscription inscriptionFromRow(Map<String, dynamic> row) {
    return Inscription.fromMap(_inscriptionFromRow(row), row['id']?.toString() ?? '');
  }

  static Payment paymentFromRow(Map<String, dynamic> row) {
    return Payment.fromMap(_paymentFromRow(row), row['id']?.toString() ?? '');
  }

  static Seance seanceFromRow(Map<String, dynamic> row) {
    return Seance.fromMap(_seanceFromRow(row), row['id']?.toString() ?? '');
  }

  static AuditLog auditLogFromRow(Map<String, dynamic> row) {
    return AuditLog.fromMap(_auditLogFromRow(row));
  }

  static AppNotification notificationFromRow(Map<String, dynamic> row) {
    return AppNotification.fromMap(_notificationFromRow(row), row['id']?.toString() ?? '');
  }

  // ─── Users ───────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _userToRow(Map<String, dynamic> data) {
    final row = <String, dynamic>{
      'id': data['id'],
      'email': data['email'],
      'nom': data['nom'],
      'prenom': data['prenom'],
      'phone': data['phone'],
      'matricule': data['matricule'],
      'role': data['role'],
      'photo_url': data['photoUrl'] ?? data['photo_url'],
      'specialite': data['specialite'],
      'sexe': data['sexe'] ?? 'Homme',
      'est_actif': data['estActif'] ?? data['est_actif'] ?? true,
      'assigned_formations':
          data['assignedFormations'] ?? data['assigned_formations'] ?? [],
      'date_creation': data['dateCreation'] ?? data['date_creation'],
      'date_modification': data['dateModification'] ?? data['date_modification'],
    };
    if (data['password'] != null && data['password'].toString().isNotEmpty) {
      row['password_hash'] = data['password'];
    }
    row.removeWhere((_, v) => v == null);
    return row;
  }

  static Map<String, dynamic> _userFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'email': row['email'],
      'nom': row['nom'],
      'prenom': row['prenom'],
      'phone': row['phone'],
      'matricule': row['matricule'],
      'role': row['role'],
      'photoUrl': row['photo_url'] ?? row['photoUrl'],
      'specialite': row['specialite'],
      'sexe': row['sexe'],
      'estActif': row['est_actif'] ?? row['estActif'] ?? true,
      'assignedFormations': row['assigned_formations'] ?? row['assignedFormations'] ?? [],
      'dateCreation': row['date_creation'] ?? row['dateCreation'],
      'dateModification': row['date_modification'] ?? row['dateModification'],
    };
  }

  // ─── Formations ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _formationToRow(Map<String, dynamic> data) {
    final row = <String, dynamic>{
      'id': data['id'],
      'titre': data['titre'],
      'description': data['description'],
      'prix': data['prix'],
      'prix_en_ligne': data['prixEnLigne'] ?? data['prix_en_ligne'],
      'modules': data['modules'] ?? [],
      'module_prices': data['modulePrices'] ?? data['module_prices'] ?? {},
      'modules_bonus': data['modulesBonus'] ?? data['modules_bonus'] ?? [],
      'formateur_ids': data['formateurIds'] ?? data['formateur_ids'] ?? [],
      'module_formateur_ids':
          data['moduleFormateurIds'] ?? data['module_formateur_ids'] ?? {},
      'type': data['type'],
      'status': data['status'],
      'duree_semaines': data['dureeSemaines'] ?? data['duree_semaines'] ?? 0,
      'duree_heures': data['dureeHeures'] ?? data['duree_heures'],
      'horaires': data['horaires'] ?? [],
      'photo_url': data['imageUrl'] ?? data['photo_url'],
      'est_stage': data['estStage'] ?? data['est_stage'] ?? false,
      'max_modules_par_etudiant':
          data['maxModulesParEtudiant'] ?? data['max_modules_par_etudiant'],
      'nombre_inscrits': data['nombreInscrits'] ?? data['nombre_inscrits'] ?? 0,
      'capacite_max': data['capaciteMax'] ?? data['capacite_max'],
      'date_debut': data['dateDebut'] ?? data['date_debut'],
      'date_fin': data['dateFin'] ?? data['date_fin'],
      'date_creation': data['dateCreation'] ?? data['date_creation'],
      'image_format': data['imageFormat'] ?? data['image_format'],
    };
    row.removeWhere((_, v) => v == null);
    return row;
  }

  static Map<String, dynamic> _formationFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'titre': row['titre'],
      'description': row['description'],
      'prix': row['prix'],
      'prixEnLigne': row['prix_en_ligne'] ?? row['prixEnLigne'],
      'modules': row['modules'] ?? [],
      'modulePrices': row['module_prices'] ?? row['modulePrices'] ?? {},
      'modulesBonus': row['modules_bonus'] ?? row['modulesBonus'] ?? [],
      'formateurIds': row['formateur_ids'] ?? row['formateurIds'] ?? [],
      'moduleFormateurIds':
          row['module_formateur_ids'] ?? row['moduleFormateurIds'] ?? {},
      'type': row['type'],
      'status': row['status'],
      'dureeSemaines': row['duree_semaines'] ?? row['dureeSemaines'] ?? 0,
      'dureeHeures': row['duree_heures'] ?? row['dureeHeures'],
      'horaires': row['horaires'] ?? [],
      'imageUrl': row['photo_url'] ?? row['imageUrl'],
      'estStage': row['est_stage'] ?? row['estStage'] ?? false,
      'maxModulesParEtudiant':
          row['max_modules_par_etudiant'] ?? row['maxModulesParEtudiant'],
      'nombreInscrits': row['nombre_inscrits'] ?? row['nombreInscrits'] ?? 0,
      'capaciteMax': row['capacite_max'] ?? row['capaciteMax'],
      'dateDebut': row['date_debut'] ?? row['dateDebut'],
      'dateFin': row['date_fin'] ?? row['dateFin'],
      'dateCreation': row['date_creation'] ?? row['dateCreation'],
      'imageFormat': row['image_format'] ?? row['imageFormat'],
    };
  }

  // ─── Inscriptions ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _inscriptionToRow(Map<String, dynamic> data) {
    final row = <String, dynamic>{
      'id': data['id'],
      'etudiant_id': data['apprenantId'] ?? data['etudiantId'] ?? data['etudiant_id'],
      'formation_id': data['formationId'] ?? data['formation_id'],
      'nom': data['nom'],
      'prenom': data['prenom'],
      'email': data['email'],
      'telephone': data['telephone'],
      'sexe': data['sexe'] ?? 'Homme',
      'type_formation': data['typeFormation'] ?? data['type_formation'],
      'description': data['description'],
      'modules': data['modules'] ?? [],
      'status': data['status'],
      'paiement_effectue': data['paiementEffectue'] ?? data['paiement_effectue'] ?? false,
      'paiement_id': data['paiementId'] ?? data['paiement_id'],
      'motif_rejet': data['motifRejet'] ?? data['motif_rejet'],
      'date_inscription': data['dateInscription'] ?? data['date_inscription'],
      'date_acceptation': data['dateAcceptation'] ?? data['date_acceptation'],
      'source': data['source'] ?? 'web',
    };
    row.removeWhere((_, v) => v == null);
    return row;
  }

  static Map<String, dynamic> _inscriptionFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'apprenantId': row['etudiant_id'] ?? row['apprenantId'] ?? row['etudiantId'],
      'formationId': row['formation_id'] ?? row['formationId'],
      'nom': row['nom'],
      'prenom': row['prenom'],
      'email': row['email'],
      'telephone': row['telephone'],
      'sexe': row['sexe'],
      'typeFormation': row['type_formation'] ?? row['typeFormation'],
      'description': row['description'],
      'modules': row['modules'],
      'status': row['status'],
      'paiementEffectue': row['paiement_effectue'] ?? row['paiementEffectue'] ?? false,
      'paiementId': row['paiement_id'] ?? row['paiementId'],
      'motifRejet': row['motif_rejet'] ?? row['motifRejet'],
      'dateInscription': row['date_inscription'] ?? row['dateInscription'],
      'dateAcceptation': row['date_acceptation'] ?? row['dateAcceptation'],
      'source': row['source'] ?? 'web',
    };
  }

  // ─── Payments ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _paymentToRow(Map<String, dynamic> data) {
    final row = <String, dynamic>{
      'id': data['id'],
      'inscription_id': data['inscriptionId'] ?? data['inscription_id'],
      'etudiant_id': data['apprenantId'] ?? data['etudiantId'] ?? data['etudiant_id'],
      'formation_id': data['formationId'] ?? data['formation_id'],
      'montant': data['montant'],
      'remise': data['remise'] ?? 0,
      'tranche_numero': data['trancheNumero'] ?? data['tranche_numero'] ?? 1,
      'nombre_tranches': data['nombreTranches'] ?? data['nombre_tranches'] ?? 1,
      'status': data['status'],
      'methode': data['methode'],
      'reference': data['referenceTransaction'] ?? data['reference'],
      'date_paiement':
          data['dateEffectuation'] ?? data['date_paiement'] ?? data['dateCreation'],
      'date_creation': data['dateCreation'] ?? data['date_creation'],
      'date_effectuation': data['dateEffectuation'] ?? data['date_effectuation'],
      'motif': data['motif'],
      'module_id': data['moduleId'] ?? data['module_id'],
    };
    row.removeWhere((_, v) => v == null);
    return row;
  }

  static Map<String, dynamic> _paymentFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'inscriptionId': row['inscription_id'] ?? row['inscriptionId'],
      'apprenantId': row['etudiant_id'] ?? row['apprenantId'] ?? row['etudiantId'],
      'formationId': row['formation_id'] ?? row['formationId'] ?? '',
      'montant': row['montant'],
      'remise': row['remise'] ?? 0,
      'trancheNumero': row['tranche_numero'] ?? row['trancheNumero'] ?? 1,
      'nombreTranches': row['nombre_tranches'] ?? row['nombreTranches'] ?? 1,
      'status': row['status'],
      'methode': row['methode'],
      'referenceTransaction': row['reference'] ?? row['referenceTransaction'],
      'dateCreation': row['date_creation'] ?? row['date_paiement'] ?? row['dateCreation'],
      'dateEffectuation': row['date_effectuation'] ?? row['date_paiement'] ?? row['dateEffectuation'],
      'motif': row['motif'],
      'moduleId': row['module_id'] ?? row['moduleId'],
    };
  }

  // ─── Séances ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _seanceToRow(Map<String, dynamic> data) {
    DateTime? date;
    final rawDate = data['date'];
    if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate);
    }

    final heureDebut = data['heureDebut']?.toString() ?? '09:00';
    final heureFin = data['heureFin']?.toString() ?? '11:00';

    DateTime? dateDebut;
    DateTime? dateFin;
    if (date != null) {
      final partsDeb = heureDebut.split(':');
      final partsFin = heureFin.split(':');
      dateDebut = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(partsDeb.first) ?? 9,
        partsDeb.length > 1 ? int.tryParse(partsDeb[1]) ?? 0 : 0,
      );
      dateFin = DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(partsFin.first) ?? 11,
        partsFin.length > 1 ? int.tryParse(partsFin[1]) ?? 0 : 0,
      );
    }

    return {
      'id': data['id'],
      'formation_id': data['formationId'] ?? data['formation_id'],
      'formateur_id': data['formateurId'] ?? data['formateur_id'],
      'module_title': data['moduleTitle'] ?? data['module_title'],
      'statut': data['statut'],
      'date_debut': dateDebut?.toIso8601String(),
      'date_fin': dateFin?.toIso8601String(),
      'contenu': Map<String, dynamic>.from(data),
      'date_creation': data['dateCreation'] ?? data['date_creation'],
    }..removeWhere((_, v) => v == null);
  }

  static Map<String, dynamic> _seanceFromRow(Map<String, dynamic> row) {
    final payload = row['contenu'] ?? row['payload'];
    if (payload is Map && payload.containsKey('formationId')) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is Map && payload.containsKey('id')) {
      return Map<String, dynamic>.from(payload);
    }

    DateTime date = DateTime.now();
    String heureDebut = '09:00';
    String heureFin = '11:00';

    final dateDebut = row['date_debut'];
    if (dateDebut != null) {
      final parsed = dateDebut is DateTime
          ? dateDebut
          : DateTime.tryParse(dateDebut.toString());
      if (parsed != null) {
        date = DateTime(parsed.year, parsed.month, parsed.day);
        heureDebut =
            '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
    }
    final dateFin = row['date_fin'];
    if (dateFin != null) {
      final parsed = dateFin is DateTime
          ? dateFin
          : DateTime.tryParse(dateFin.toString());
      if (parsed != null) {
        heureFin =
            '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      }
    }

    return {
      'id': row['id'],
      'formationId': row['formation_id'] ?? '',
      'formationTitle': row['titre'] ?? '',
      'moduleTitle': row['module_title'],
      'formateurId': row['formateur_id'] ?? '',
      'formateurNom': '',
      'date': date.toIso8601String(),
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'statut': row['statut'] ?? 'brouillon',
      'dateCreation': row['date_creation'],
    };
  }

  // ─── Audit logs ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _auditLogToRow(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_nom': data['userNom'] ?? data['user_nom'],
      'user_role': data['userRole'] ?? data['user_role'],
      'action': data['action'],
      'description': data['description'],
      'timestamp': data['timestamp'],
      'target_id': data['targetId'] ?? data['target_id'],
      'target_type': data['targetType'] ?? data['target_type'],
      'severity': data['severity'] ?? 'info',
    }..removeWhere((_, v) => v == null);
  }

  static Map<String, dynamic> _auditLogFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'userNom': row['user_nom'] ?? row['userNom'] ?? 'Système',
      'userRole': row['user_role'] ?? row['userRole'] ?? 'Admin',
      'action': row['action'],
      'description': row['description'],
      'timestamp': row['timestamp'],
      'targetId': row['target_id'] ?? row['targetId'],
      'targetType': row['target_type'] ?? row['targetType'],
      'severity': row['severity'] ?? 'info',
    };
  }

  // ─── Notifications ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _notificationToRow(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'title': data['title'],
      'description': data['description'],
      'image_url': data['imageUrl'] ?? data['image_url'],
      'sender_id': data['senderId'] ?? data['sender_id'],
      'sender_email': data['senderEmail'] ?? data['sender_email'],
      'target_roles': data['targetRoles'] ?? data['target_roles'] ?? [],
      'target_user_ids': data['targetUserIds'] ?? data['target_user_ids'] ?? [],
      'audience': data['audience'] ?? [],
      'read_by': data['readBy'] ?? data['read_by'] ?? [],
      'reminder_count': data['reminderCount'] ?? data['reminder_count'] ?? 0,
      'created_at': data['createdAt'] ?? data['created_at'],
      'updated_at': data['updatedAt'] ?? data['updated_at'],
    }..removeWhere((_, v) => v == null);
  }

  static Map<String, dynamic> _notificationFromRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'imageUrl': row['image_url'] ?? row['imageUrl'],
      'senderId': row['sender_id'] ?? row['senderId'] ?? '',
      'senderEmail': row['sender_email'] ?? row['senderEmail'] ?? '',
      'targetRoles': row['target_roles'] ?? row['targetRoles'] ?? [],
      'targetUserIds': row['target_user_ids'] ?? row['targetUserIds'] ?? [],
      'audience': row['audience'] ?? [],
      'readBy': row['read_by'] ?? row['readBy'] ?? [],
      'reminderCount': row['reminder_count'] ?? row['reminderCount'] ?? 0,
      'createdAt': row['created_at'] ?? row['createdAt'],
      'updatedAt': row['updated_at'] ?? row['updatedAt'],
    };
  }
}
