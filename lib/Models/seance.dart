enum SeanceStatut { brouillon, publie }

class Seance {
  final String id;
  final String formationId;
  final String formationTitle;
  final String? moduleId;
  final String? moduleTitle;
  final String formateurId;
  final String formateurNom;
  final DateTime date;
  final String heureDebut;
  final String heureFin;
  final String? salleOuLien;
  final String modalite;
  final SeanceStatut statut;
  final DateTime dateCreation;
  final DateTime? datePublication;

  Seance({
    required this.id,
    required this.formationId,
    required this.formationTitle,
    this.moduleId,
    this.moduleTitle,
    required this.formateurId,
    required this.formateurNom,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    this.salleOuLien,
    this.modalite = 'Présentiel',
    this.statut = SeanceStatut.brouillon,
    DateTime? dateCreation,
    this.datePublication,
  }) : dateCreation = dateCreation ?? DateTime.now();

  bool get estPubliee => statut == SeanceStatut.publie;
  bool get estBrouillon => statut == SeanceStatut.brouillon;

  factory Seance.fromMap(Map<String, dynamic> data, String id) {
    SeanceStatut parseStatut(String? str) {
      if (str != null && (str.contains('publie') || str.contains('publié'))) {
        return SeanceStatut.publie;
      }
      return SeanceStatut.brouillon;
    }

    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Seance(
      id: id,
      formationId: data['formationId']?.toString() ?? '',
      formationTitle: data['formationTitle']?.toString() ?? '',
      moduleId: data['moduleId']?.toString(),
      moduleTitle: data['moduleTitle']?.toString(),
      formateurId: data['formateurId']?.toString() ?? '',
      formateurNom: data['formateurNom']?.toString() ?? '',
      date: parseDate(data['date']),
      heureDebut: data['heureDebut']?.toString() ?? '09:00',
      heureFin: data['heureFin']?.toString() ?? '11:00',
      salleOuLien: data['salleOuLien']?.toString(),
      modalite: data['modalite']?.toString() ?? 'Présentiel',
      statut: parseStatut(data['statut']?.toString()),
      dateCreation: parseDate(data['dateCreation']),
      datePublication: data['datePublication'] != null ? parseDate(data['datePublication']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'formationId': formationId,
      'formationTitle': formationTitle,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'formateurId': formateurId,
      'formateurNom': formateurNom,
      'date': date.toIso8601String(),
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'salleOuLien': salleOuLien,
      'modalite': modalite,
      'statut': statut.name,
      'dateCreation': dateCreation.toIso8601String(),
      'datePublication': datePublication?.toIso8601String(),
    };
  }

  Seance copyWith({
    String? id,
    String? formationId,
    String? formationTitle,
    String? moduleId,
    String? moduleTitle,
    String? formateurId,
    String? formateurNom,
    DateTime? date,
    String? heureDebut,
    String? heureFin,
    String? salleOuLien,
    String? modalite,
    SeanceStatut? statut,
    DateTime? dateCreation,
    DateTime? datePublication,
  }) {
    return Seance(
      id: id ?? this.id,
      formationId: formationId ?? this.formationId,
      formationTitle: formationTitle ?? this.formationTitle,
      moduleId: moduleId ?? this.moduleId,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      formateurId: formateurId ?? this.formateurId,
      formateurNom: formateurNom ?? this.formateurNom,
      date: date ?? this.date,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      salleOuLien: salleOuLien ?? this.salleOuLien,
      modalite: modalite ?? this.modalite,
      statut: statut ?? this.statut,
      dateCreation: dateCreation ?? this.dateCreation,
      datePublication: datePublication ?? this.datePublication,
    );
  }
}
