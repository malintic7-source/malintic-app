import 'package:gestion_formations/utils/type_parsers.dart';

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

  factory Inscription.fromMap(Map<dynamic, dynamic> data, String id) {
    InscriptionStatus parseStatus(String statusStr) {
      final normalized = statusStr.toLowerCase();
      if (normalized.contains('acceptee') ||
          normalized.contains('accepte') ||
          normalized.contains('valide') ||
          normalized.contains('approuve')) {
        return InscriptionStatus.acceptee;
      }
      if (normalized.contains('rejetee') ||
          normalized.contains('rejete') ||
          normalized.contains('refuse')) {
        return InscriptionStatus.rejetee;
      }
      return InscriptionStatus.enAttente;
    }

    final rawModules = data['modules'];
    final List<String>? parsedModules = rawModules != null ? parseStringList(rawModules) : null;

    return Inscription(
      id: id,
      apprenantId: parseString(data['apprenantId'] ?? data['etudiantId']),
      formationId: parseString(data['formationId']),
      status: parseStatus(parseString(data['status'], defaultValue: 'InscriptionStatus.enAttente')),
      dateInscription: parseDate(data['dateInscription']),
      paiementId: parseStringOrNull(data['paiementId']),
      paiementEffectue: parseBool(data['paiementEffectue']),
      dateAcceptation: parseStringOrNull(data['dateAcceptation']),
      motifRejet: parseStringOrNull(data['motifRejet']),
      prenom: parseStringOrNull(data['prenom']),
      nom: parseStringOrNull(data['nom']),
      email: parseStringOrNull(data['email']),
      telephone: parseStringOrNull(data['telephone']),
      description: parseStringOrNull(data['description']),
      modules: parsedModules,
      typeFormation: parseStringOrNull(data['typeFormation']),
      sexe: parseStringOrNull(data['sexe']),
      source: parseString(data['source'], defaultValue: 'web'),
    );
  }

  factory Inscription.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Inscription.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Inscription.fromMap(data, doc.id ?? '');
  }

  Inscription copyWith({
    String? id,
    String? apprenantId,
    String? etudiantId,
    String? formationId,
    InscriptionStatus? status,
    DateTime? dateInscription,
    String? paiementId,
    bool? paiementEffectue,
    String? dateAcceptation,
    String? motifRejet,
    String? prenom,
    String? nom,
    String? email,
    String? telephone,
    String? description,
    List<String>? modules,
    String? typeFormation,
    String? sexe,
    String? source,
  }) {
    return Inscription(
      id: id ?? this.id,
      apprenantId: apprenantId ?? etudiantId ?? this.apprenantId,
      formationId: formationId ?? this.formationId,
      status: status ?? this.status,
      dateInscription: dateInscription ?? this.dateInscription,
      paiementId: paiementId ?? this.paiementId,
      paiementEffectue: paiementEffectue ?? this.paiementEffectue,
      dateAcceptation: dateAcceptation ?? this.dateAcceptation,
      motifRejet: motifRejet ?? this.motifRejet,
      prenom: prenom ?? this.prenom,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      description: description ?? this.description,
      modules: modules ?? this.modules,
      typeFormation: typeFormation ?? this.typeFormation,
      sexe: sexe ?? this.sexe,
      source: source ?? this.source,
    );
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Inscription && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
