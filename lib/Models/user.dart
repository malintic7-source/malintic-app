enum UserRole { admin, dg, daf, comptable, assistant, it, formateur, apprenant }

class User {
  final String id;
  final String email;
  final String nom;
  final String prenom;
  final String phone;
  final String? matricule;
  final UserRole role;

  /// #1 — Le mot de passe n'est JAMAIS stocké en clair côté client.
  /// Ce champ est uniquement utilisé de façon transitoire lors de la
  /// création de compte par un admin (transmission unique à l'API puis vidé).
  /// Il n'est JAMAIS inclus dans toMap() ni dans le LocalStorage.
  final String password;

  final String? photoUrl;
  final List<Map<String, dynamic>> assignedFormations;
  final String sexe;
  final bool estActif;
  final bool doitChangerMotDePasse;
  final DateTime dateCreation;
  final DateTime? dateModification;
  final String? specialite;

  User({
    required this.id,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.phone,
    this.matricule,
    required this.role,
    this.password = '',
    this.photoUrl,
    this.assignedFormations = const [],
    this.sexe = 'Homme',
    this.estActif = true,
    this.doitChangerMotDePasse = false,
    DateTime? dateCreation,
    this.dateModification,
    this.specialite,
  }) : dateCreation = dateCreation ?? DateTime.now();

  bool get isAdmin => role == UserRole.admin;
  bool get isDg => role == UserRole.dg;
  bool get isDaf => role == UserRole.daf;
  bool get isComptable => role == UserRole.comptable;
  bool get isAssistant => role == UserRole.assistant;
  bool get isIt => role == UserRole.it;
  bool get isFormateur => role == UserRole.formateur;
  bool get isApprenant => role == UserRole.apprenant;

  /// Utilisateurs ayant des droits d'administration et de gestion des comptes
  bool get hasAdminRights =>
      role == UserRole.admin || role == UserRole.dg || role == UserRole.it;

  /// Utilisateurs ayant des droits de gestion financière
  bool get hasFinanceRights =>
      role == UserRole.admin ||
      role == UserRole.dg ||
      role == UserRole.daf ||
      role == UserRole.comptable ||
      role == UserRole.it;

  /// Utilisateurs ayant des droits de gestion pédagogique
  bool get hasPedagogieRights =>
      role == UserRole.admin ||
      role == UserRole.dg ||
      role == UserRole.assistant ||
      role == UserRole.it;

  /// Utilisateurs membres du personnel
  bool get isStaff => role != UserRole.apprenant;

  factory User.fromMap(Map<String, dynamic> data, String id) {
    UserRole parseRole(String roleStr) {
      final normalized = roleStr.toLowerCase();
      if (normalized.contains('admin')) return UserRole.admin;
      if (normalized.contains('dg')) return UserRole.dg;
      if (normalized.contains('daf')) return UserRole.daf;
      if (normalized.contains('comptable')) return UserRole.comptable;
      if (normalized.contains('assistant')) return UserRole.assistant;
      if (normalized.contains('it')) return UserRole.it;
      if (normalized.contains('formateur')) return UserRole.formateur;
      return UserRole.apprenant;
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

    return User(
      id: id,
      email: data['email'] ?? '',
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      phone: data['phone'] ?? '',
      role: parseRole(data['role']?.toString() ?? 'UserRole.apprenant'),
      // #1 — Les mots de passe ne sont jamais réhydratés depuis l'API ou le stockage local.
      password: '',
      photoUrl: data['photoUrl'],
      matricule: data['matricule']?.toString(),
      assignedFormations: (data['assignedFormations'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      sexe: data['sexe']?.toString() ?? 'Homme',
      estActif: data['estActif'] ?? true,
      doitChangerMotDePasse: data['doitChangerMotDePasse'] == true || data['mustChangePassword'] == true,
      dateCreation: parseDate(data['dateCreation']),
      dateModification:
          data['dateModification'] != null ? parseDate(data['dateModification']) : null,
      specialite: data['specialite']?.toString(),
    );
  }

  // Alias pour compatibilité descendante
  factory User.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return User.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return User.fromMap(data, doc.id ?? '');
  }

  /// #1 — toMap() n'inclut JAMAIS le mot de passe dans la sérialisation.
  /// Pour créer un compte via l'API avec un mot de passe initial, utiliser
  /// [toMapWithPassword] qui est réservé à cet usage unique.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'phone': phone,
      'role': role.toString(),
      'photoUrl': photoUrl,
      'matricule': matricule,
      'assignedFormations': assignedFormations,
      'sexe': sexe,
      'estActif': estActif,
      'doitChangerMotDePasse': doitChangerMotDePasse,
      'dateCreation': dateCreation.toIso8601String(),
      'dateModification': dateModification?.toIso8601String(),
      'specialite': specialite,
    };
  }

  /// Utilisé uniquement lors de la création initiale de compte pour transmettre
  /// le mot de passe temporaire à l'API. Ne PAS utiliser pour le stockage local.
  Map<String, dynamic> toMapWithPassword() {
    final data = toMap();
    if (password.isNotEmpty) data['password'] = password;
    return data;
  }

  User copyWith({
    String? id,
    String? email,
    String? nom,
    String? prenom,
    String? phone,
    String? matricule,
    UserRole? role,
    String? password,
    String? photoUrl,
    List<Map<String, dynamic>>? assignedFormations,
    String? sexe,
    bool? estActif,
    bool? doitChangerMotDePasse,
    DateTime? dateCreation,
    DateTime? dateModification,
    String? specialite,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      phone: phone ?? this.phone,
      matricule: matricule ?? this.matricule,
      role: role ?? this.role,
      password: password ?? this.password,
      photoUrl: photoUrl ?? this.photoUrl,
      assignedFormations: assignedFormations ?? this.assignedFormations,
      sexe: sexe ?? this.sexe,
      estActif: estActif ?? this.estActif,
      doitChangerMotDePasse: doitChangerMotDePasse ?? this.doitChangerMotDePasse,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
      specialite: specialite ?? this.specialite,
    );
  }

  Map<String, dynamic> toFirestore() => toMap();

  String get nomComplet => '$prenom $nom';

  bool get isEtudiant => isApprenant;
  bool get isEmployee => isStaff;
}
