// Removed Firestore import (migrating off Firebase)

enum InscriptionStatus { enAttente, acceptee, rejetee }

class Inscription {
  final String id;
  final String apprenantId;
  final String formationId;
  final InscriptionStatus status;
  final DateTime dateInscription;
  final String? paiementId;
  final bool paiementEffectue;
  final String? dateAcceptation;
  final String? motifRejet;
  final String? prenom;
  final String? nom;
  final String? email;
  final String? telephone;
  final String? description;
  final List<String>? modules;
  final String? typeFormation;
  final String? sexe;
  final String source;

  String get etudiantId => apprenantId;

  Inscription({
    required this.id,
    String? apprenantId,
    String? etudiantId,
    required this.formationId,
    required this.status,
    required this.dateInscription,
    this.paiementId,
    required this.paiementEffectue,
    this.dateAcceptation,
    this.motifRejet,
    this.prenom,
    this.nom,
    this.email,
    this.telephone,
    this.description,
    this.modules,
    this.typeFormation,
    this.sexe,
    this.source = 'web',
  }) : apprenantId = apprenantId ?? etudiantId ?? '';

  factory Inscription.fromMap(Map<String, dynamic> data, String id) {
    InscriptionStatus parseStatus(String statusStr) {
      if (statusStr.contains('acceptee') || statusStr.contains('accepte') || statusStr.contains('valide')) {
        return InscriptionStatus.acceptee;
      }
      if (statusStr.contains('rejetee') || statusStr.contains('rejete')) {
        return InscriptionStatus.rejetee;
      }
      return InscriptionStatus.enAttente;
    }

    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val != null && val.runtimeType.toString().contains('Timestamp')) {
        try {
          return (val as dynamic).toDate();
        } catch (_) {}
      }
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Inscription(
      id: id,
      apprenantId: data['apprenantId'] ?? data['etudiantId'] ?? '',
      formationId: data['formationId'] ?? '',
      status: parseStatus(data['status']?.toString() ?? 'InscriptionStatus.enAttente'),
      dateInscription: parseDate(data['dateInscription']),
      paiementId: data['paiementId'],
      paiementEffectue: data['paiementEffectue'] ?? false,
      dateAcceptation: data['dateAcceptation'],
      motifRejet: data['motifRejet'],
      prenom: data['prenom']?.toString(),
      nom: data['nom']?.toString(),
      email: data['email']?.toString(),
      telephone: data['telephone']?.toString(),
      description: data['description']?.toString(),
      modules: data['modules'] is List ? List<String>.from(data['modules']) : null,
      typeFormation: data['typeFormation']?.toString(),
      sexe: data['sexe']?.toString(),
      source: data['source']?.toString() ?? 'web',
    );
  }

  factory Inscription.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Inscription.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Inscription.fromMap(data, doc.id ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apprenantId': apprenantId,
      'etudiantId': apprenantId,
      'formationId': formationId,
      'status': status.name,
      'dateInscription': dateInscription.toIso8601String(),
      'paiementId': paiementId,
      'paiementEffectue': paiementEffectue,
      'dateAcceptation': dateAcceptation,
      'motifRejet': motifRejet,
      'prenom': prenom,
      'nom': nom,
      'email': email,
      'telephone': telephone,
      'description': description,
      'modules': modules,
      'typeFormation': typeFormation,
      'sexe': sexe,
      'source': source,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();
}
