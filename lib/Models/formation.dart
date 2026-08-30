import 'package:gestion_formations/utils/type_parsers.dart';

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

  factory Horaire.fromMap(Map<dynamic, dynamic> map) {
    return Horaire(
      jour: parseString(map['jour']),
      heureDebut: parseString(map['heureDebut']),
      heureFin: parseString(map['heureFin']),
      module: parseStringOrNull(map['module']),
      groupe: parseStringOrNull(map['groupe']),
      modalite: parseStringOrNull(map['modalite']),
      lieuOuLien: parseStringOrNull(map['lieuOuLien']),
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
  final int nombreInscrits;
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

  factory Formation.fromMap(Map<dynamic, dynamic> data, String id) {
    FormationType parseType(String typeStr) {
      final lower = typeStr.toLowerCase();
      if (lower.contains('presentiel')) {
        return FormationType.presentielle;
      }
      if (lower.contains('mixte')) {
        return FormationType.mixte;
      }
      return FormationType.enligne;
    }

    FormationStatus parseStatus(String statusStr) {
      final lower = statusStr.toLowerCase();
      if (lower.contains('encours') || lower.contains('en_cours') || lower.contains('cours') || lower.contains('active')) {
        return FormationStatus.enCours;
      }
      if (lower.contains('termine') || lower.contains('cloture')) {
        return FormationStatus.terminee;
      }
      return FormationStatus.programmee;
    }

    ImageFormat? parseImageFormat(String? formatStr) {
      if (formatStr == null) return null;
      final lower = formatStr.toLowerCase();
      if (lower.contains('carre')) return ImageFormat.carre;
      if (lower.contains('vertical') || lower.contains('portrait')) return ImageFormat.vertical;
      return null;
    }

    final rawPrices = data['modulePrices'] as Map<dynamic, dynamic>? ?? {};
    final parsedPrices = <String, double>{};
    for (final entry in rawPrices.entries) {
      parsedPrices[entry.key.toString()] = parseDouble(entry.value);
    }

    final rawFormateurIds = data['moduleFormateurIds'] as Map<dynamic, dynamic>? ?? {};
    final parsedFormateurIds = <String, String>{};
    for (final entry in rawFormateurIds.entries) {
      parsedFormateurIds[entry.key.toString()] = entry.value.toString();
    }

    final rawHoraires = data['horaires'] as List<dynamic>? ?? [];
    final parsedHoraires = <Horaire>[];
    for (final h in rawHoraires) {
      if (h is Map) {
        parsedHoraires.add(Horaire.fromMap(h));
      }
    }

    return Formation(
      id: id,
      titre: parseString(data['titre']),
      description: parseString(data['description']),
      modules: parseStringList(data['modules']),
      modulePrices: parsedPrices,
      moduleFormateurIds: parsedFormateurIds,
      modulesBonus: parseStringList(data['modulesBonus']),
      imageUrl: parseStringOrNull(data['imageUrl']),
      imageFormat: parseImageFormat(parseStringOrNull(data['imageFormat'])),
      formateurIds: parseStringList(data['formateurIds']),
      prix: parseDouble(data['prix']),
      prixEnLigne: parseDoubleOrNull(data['prixEnLigne']),
      type: parseType(data['type']?.toString() ?? 'FormationType.enligne'),
      status: parseStatus(data['status']?.toString() ?? 'FormationStatus.programmee'),
      dureeSemaines: parseInt(data['dureeSemaines']),
      dureeHeures: parseStringOrNull(data['dureeHeures']),
      horaires: parsedHoraires,
      dateDebut: parseDateOrNull(data['dateDebut']),
      dateFin: parseDateOrNull(data['dateFin']),
      dateCreation: parseDate(data['dateCreation']),
      capaciteMax: parseIntOrNull(data['capaciteMax']),
      nombreInscrits: parseInt(data['nombreInscrits']),
      estStage: parseBool(data['estStage']),
      maxModulesParEtudiant: parseIntOrNull(data['maxModulesParEtudiant']),
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
