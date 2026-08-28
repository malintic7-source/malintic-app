// Removed Firestore import for Docker migration

enum FormationType { enligne, presentielle, mixte }

enum FormationStatus { programmee, enCours, terminee }

enum ImageFormat { carre, vertical }

class Horaire {
  final String jour;
  final String heureDebut;
  final String heureFin;
  /// Null means that the session is shared by every enrolled module.
  final String? module;
  /// A named cohort (for example "SFP-BDIA-A"). Empty/null means all groups.
  final String? groupe;
  final String? modalite;
  final String? lieuOuLien;

  Horaire({
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    this.module,
    this.groupe,
    this.modalite,
    this.lieuOuLien,
  });

  factory Horaire.fromMap(Map<String, dynamic> map) {
    return Horaire(
      jour: map['jour'] ?? '',
      heureDebut: map['heureDebut'] ?? '',
      heureFin: map['heureFin'] ?? '',
      module: map['module']?.toString(),
      groupe: map['groupe']?.toString(),
      modalite: map['modalite']?.toString(),
      lieuOuLien: map['lieuOuLien']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jour': jour,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'module': module,
      'groupe': groupe,
      'modalite': modalite,
      'lieuOuLien': lieuOuLien,
    };
  }
}

class Formation {
  final String id;
  final String titre;
  final String description;
  final List<String> modules;
  final Map<String, double> modulePrices;
  /// Associates each module title with the id of the trainer responsible for it.
  /// A module without an entry is deliberately kept unassigned.
  final Map<String, String> moduleFormateurIds;
  final List<String> modulesBonus;
  final String? imageUrl;
  final ImageFormat? imageFormat;
  final List<String> formateurIds;
  final double prix;
  final double? prixEnLigne;
  final FormationType type;
  final FormationStatus status;
  final int dureeSemaines;
  final String? dureeHeures;
  final List<Horaire> horaires;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final DateTime dateCreation;
  final int? capaciteMax;
  final int? nombreInscrits;
  final bool estStage;
  final int? maxModulesParEtudiant;

  Formation({
    required this.id,
    required this.titre,
    required this.description,
    required this.modules,
    this.modulePrices = const {},
    this.moduleFormateurIds = const {},
    this.modulesBonus = const [],
    this.imageUrl,
    this.imageFormat,
    required this.formateurIds,
    required this.prix,
    this.prixEnLigne,
    required this.type,
    required this.status,
    required this.dureeSemaines,
    this.dureeHeures,
    required this.horaires,
    this.dateDebut,
    this.dateFin,
    required this.dateCreation,
    this.capaciteMax,
    this.nombreInscrits = 0,
    this.estStage = false,
    this.maxModulesParEtudiant,
  });

  factory Formation.fromMap(Map<String, dynamic> data, String id) {
    FormationType parseType(String typeStr) {
      if (typeStr.contains('presentielle')) {
        return FormationType.presentielle;
      }
      if (typeStr.contains('mixte')) {
        return FormationType.mixte;
      }
      return FormationType.enligne;
    }

    FormationStatus parseStatus(String statusStr) {
      if (statusStr.contains('enCours')) {
        return FormationStatus.enCours;
      }
      if (statusStr.contains('terminee')) {
        return FormationStatus.terminee;
      }
      return FormationStatus.programmee;
    }

    ImageFormat? parseImageFormat(String? formatStr) {
      if (formatStr == null) return null;
      if (formatStr.contains('carre')) return ImageFormat.carre;
      if (formatStr.contains('vertical')) return ImageFormat.vertical;
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val != null && val.runtimeType.toString().contains('Timestamp')) {
        try {
          return (val as dynamic).toDate();
        } catch (_) {}
      }
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Formation(
      id: id,
      titre: data['titre'] ?? '',
      description: data['description'] ?? '',
      modules: List<String>.from(data['modules'] ?? []),
      modulePrices: (data['modulePrices'] as Map<dynamic, dynamic>? ?? {})
          .map((key, value) => MapEntry(key.toString(), (value as num).toDouble())),
      moduleFormateurIds:
          (data['moduleFormateurIds'] as Map<dynamic, dynamic>? ?? {})
              .map((key, value) => MapEntry(key.toString(), value.toString())),
      modulesBonus: List<String>.from(data['modulesBonus'] ?? []),
      imageUrl: data['imageUrl'],
      imageFormat: parseImageFormat(data['imageFormat']),
      formateurIds: List<String>.from(data['formateurIds'] ?? []),
      prix: (data['prix'] ?? 0).toDouble(),
      prixEnLigne: data['prixEnLigne']?.toDouble(),
      type: parseType(data['type']?.toString() ?? 'FormationType.enligne'),
      status: parseStatus(data['status']?.toString() ?? 'FormationStatus.programmee'),
      dureeSemaines: data['dureeSemaines'] ?? 0,
      dureeHeures: data['dureeHeures'],
      horaires: (data['horaires'] as List?)
              ?.map((h) => Horaire.fromMap(h as Map<String, dynamic>))
              .toList() ??
          [],
      dateDebut: parseDate(data['dateDebut']),
      dateFin: parseDate(data['dateFin']),
      dateCreation: parseDate(data['dateCreation']) ?? DateTime.now(),
      capaciteMax: data['capaciteMax'],
      nombreInscrits: data['nombreInscrits'] ?? 0,
      estStage: data['estStage'] ?? false,
      maxModulesParEtudiant: data['maxModulesParEtudiant'],
    );
  }

  factory Formation.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Formation.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Formation.fromMap(data, doc.id ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'modules': modules,
      'modulePrices': modulePrices,
      'moduleFormateurIds': moduleFormateurIds,
      'modulesBonus': modulesBonus,
      'imageUrl': imageUrl,
      'imageFormat': imageFormat?.toString(),
      'formateurIds': formateurIds,
      'prix': prix,
      'prixEnLigne': prixEnLigne,
      'type': type.name,
      'status': status.name,
      'dureeSemaines': dureeSemaines,
      'dureeHeures': dureeHeures,
      'horaires': horaires.map((h) => h.toMap()).toList(),
      'dateDebut': dateDebut?.toIso8601String(),
      'dateFin': dateFin?.toIso8601String(),
      'dateCreation': dateCreation.toIso8601String(),
      'capaciteMax': capaciteMax,
      'nombreInscrits': nombreInscrits,
      'estStage': estStage,
      'maxModulesParEtudiant': maxModulesParEtudiant,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  Formation copyWith({
    String? id,
    String? titre,
    String? description,
    List<String>? modules,
    Map<String, double>? modulePrices,
    Map<String, String>? moduleFormateurIds,
    List<String>? modulesBonus,
    String? imageUrl,
    ImageFormat? imageFormat,
    List<String>? formateurIds,
    double? prix,
    double? prixEnLigne,
    FormationType? type,
    FormationStatus? status,
    int? dureeSemaines,
    String? dureeHeures,
    List<Horaire>? horaires,
    DateTime? dateDebut,
    DateTime? dateFin,
    DateTime? dateCreation,
    int? capaciteMax,
    int? nombreInscrits,
    bool? estStage,
    int? maxModulesParEtudiant,
  }) {
    return Formation(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      modules: modules ?? this.modules,
      modulePrices: modulePrices ?? this.modulePrices,
      moduleFormateurIds: moduleFormateurIds ?? this.moduleFormateurIds,
      modulesBonus: modulesBonus ?? this.modulesBonus,
      imageUrl: imageUrl ?? this.imageUrl,
      imageFormat: imageFormat ?? this.imageFormat,
      formateurIds: formateurIds ?? this.formateurIds,
      prix: prix ?? this.prix,
      prixEnLigne: prixEnLigne ?? this.prixEnLigne,
      type: type ?? this.type,
      status: status ?? this.status,
      dureeSemaines: dureeSemaines ?? this.dureeSemaines,
      dureeHeures: dureeHeures ?? this.dureeHeures,
      horaires: horaires ?? this.horaires,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      dateCreation: dateCreation ?? this.dateCreation,
      capaciteMax: capaciteMax ?? this.capaciteMax,
      nombreInscrits: nombreInscrits ?? this.nombreInscrits,
      estStage: estStage ?? this.estStage,
      maxModulesParEtudiant: maxModulesParEtudiant ?? this.maxModulesParEtudiant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Formation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
