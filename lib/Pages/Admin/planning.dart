import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';

class AdminPlanning extends StatefulWidget {
  const AdminPlanning({super.key});

  @override
  State<AdminPlanning> createState() => _AdminPlanningState();
}

class _AdminPlanningState extends State<AdminPlanning>
    with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;

  bool _isCalendarView = true;
  String _selectedDay = 'Tous';
  String? _filterFormationId;
  String? _filterFormateurId;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _days = [
    'Tous',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormations(),
      builder: (context, snapshot) {
        final formations = snapshot.data ?? _db.getFormations();
        final users = _db.getUsers();
        final deletedUserIdsPlan = _db.getDeletedDocs('users');
        final deletedEmailsPlan = _db.getDeletedDocs('user_emails');
        final formateurs = users.where((u) {
          final email = u.email.trim().toLowerCase();
          return u.role == UserRole.formateur &&
              u.estActif &&
              !deletedUserIdsPlan.contains(u.id) &&
              (email.isEmpty || !deletedEmailsPlan.contains(email));
        }).toList();

        // Extract all session items with metadata
        final allSessions = <_SessionEntry>[];
        for (final formation in formations) {
          final totalFormationStudents = _db.getStudentsForFormation(formation.id).length;
          for (int i = 0; i < formation.horaires.length; i++) {
            final horaire = formation.horaires[i];
            final enrolledStudents = _db.getStudentsForFormationModule(
              formation.id,
              horaire.module,
            );

            // Determine assigned trainer for this session
            String? formateurNom;
            String? formateurId;
            if (horaire.module != null &&
                formation.moduleFormateurIds.containsKey(horaire.module)) {
              formateurId = formation.moduleFormateurIds[horaire.module];
            } else if (formation.formateurIds.isNotEmpty) {
              formateurId = formation.formateurIds.first;
            }
            if (formateurId != null) {
              final trainer = _db.getUserById(formateurId);
              if (trainer != null) formateurNom = trainer.nomComplet;
            }

            final sessionConflicts = _db.checkPlanningConflicts(
              day: horaire.jour,
              start: horaire.heureDebut,
              end: horaire.heureFin,
              formateurId: formateurId,
              salleOuLien: horaire.lieuOuLien,
              currentFormationId: formation.id,
              currentHoraireIndex: i,
            );

            allSessions.add(
              _SessionEntry(
                formation: formation,
                horaire: horaire,
                horaireIndex: i,
                formateurId: formateurId,
                formateurNom: formateurNom,
                enrolledStudents: enrolledStudents,
                totalFormationStudents: totalFormationStudents,
                conflicts: sessionConflicts,
              ),
            );
          }
        }

        final globalConflicts = _db.getAllPlanningConflicts();

        // Apply filters
        final filteredSessions = allSessions.where((s) {
          if (_selectedDay != 'Tous' && s.horaire.jour != _selectedDay) {
            return false;
          }
          if (_filterFormationId != null &&
              s.formation.id != _filterFormationId) {
            return false;
          }
          if (_filterFormateurId != null && s.formateurId != _filterFormateurId) {
            return false;
          }

          final query = _searchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            final matchFormation = s.formation.titre.toLowerCase().contains(
              query,
            );
            final matchModule = (s.horaire.module ?? '').toLowerCase().contains(
              query,
            );
            final matchGroupe = (s.horaire.groupe ?? '').toLowerCase().contains(
              query,
            );
            final matchSalle = (s.horaire.lieuOuLien ?? '')
                .toLowerCase()
                .contains(query);
            final matchFormateur = (s.formateurNom ?? '')
                .toLowerCase()
                .contains(query);
            if (!matchFormation &&
                !matchModule &&
                !matchGroupe &&
                !matchSalle &&
                !matchFormateur) {
              return false;
            }
          }
          return true;
        }).toList();

        // Sort by day and start time
        filteredSessions.sort((a, b) {
          final dayCompare = _dayOrder(
            a.horaire.jour,
          ).compareTo(_dayOrder(b.horaire.jour));
          if (dayCompare != 0) return dayCompare;
          return a.horaire.heureDebut.compareTo(b.horaire.heureDebut);
        });

        // Compute metrics
        final totalSessions = allSessions.length;
        final totalGroups = allSessions
            .map((s) => s.groupeDisplayName)
            .toSet()
            .length;
        final totalStudents = allSessions
            .expand((s) => s.enrolledStudents.map((u) => u.id))
            .toSet()
            .length;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile, formations),
              if (globalConflicts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildGlobalConflictsBanner(isMobile, globalConflicts, formations),
              ],
              const SizedBox(height: 16),
              _buildMetricsSummary(
                isMobile,
                totalSessions,
                formations.length,
                totalGroups,
                totalStudents,
              ),
              const SizedBox(height: 20),
              _buildFiltersBar(isMobile, formations, formateurs),
              const SizedBox(height: 16),
              _buildDayFilters(),
              const SizedBox(height: 20),
              if (_isCalendarView)
                _buildWeeklyCalendarGrid(isMobile, filteredSessions, formations)
              else
                _buildSessionsList(isMobile, filteredSessions),
            ],
          ),
        );
      },
    );
  }

  int _dayOrder(String day) {
    switch (day) {
      case 'Lundi':
        return 1;
      case 'Mardi':
        return 2;
      case 'Mercredi':
        return 3;
      case 'Jeudi':
        return 4;
      case 'Vendredi':
        return 5;
      case 'Samedi':
        return 6;
      case 'Dimanche':
        return 7;
      default:
        return 8;
    }
  }

  Widget _buildHeader(bool isMobile, List<Formation> formations) {
    return FadeTransition(
      opacity: _fadeController,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planning & Emploi du Temps',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestion visuelle des créneaux, salles et formateurs par semaine',
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 12 : 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Switcher (Calendrier / Liste)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewToggleButton(
                      icon: Icons.calendar_view_week_rounded,
                      label: 'Calendrier Hebdo',
                      isSelected: _isCalendarView,
                      onTap: () => setState(() => _isCalendarView = true),
                      isMobile: isMobile,
                    ),
                    _buildViewToggleButton(
                      icon: Icons.view_agenda_rounded,
                      label: 'Vue Liste',
                      isSelected: !_isCalendarView,
                      onTap: () => setState(() => _isCalendarView = false),
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 18,
                    vertical: isMobile ? 10 : 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _showSessionDialog(formations: formations),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: Text(
                  isMobile ? 'Créneau' : 'Programmer un Créneau',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalConflictsBanner(
    bool isMobile,
    List<Map<String, dynamic>> conflicts,
    List<Formation> formations,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${conflicts.length} conflit${conflicts.length > 1 ? 's' : ''} de planning détecté${conflicts.length > 1 ? 's' : ''} !',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                Text(
                  isMobile
                      ? 'Chevauchement de salles ou de formateurs.'
                      : 'Des créneaux horaires se chevauchent pour une même salle ou un même formateur.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF7F1D1D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 8 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => _showGlobalConflictsDialog(conflicts, formations),
            icon: const Icon(Icons.build_circle_outlined, size: 16),
            label: Text(
              isMobile ? 'Résoudre' : 'Inspecter & Résoudre',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalConflictsDialog(
    List<Map<String, dynamic>> conflicts,
    List<Formation> formations,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Détail des Conflits de Planning (${conflicts.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width < 600 ? MediaQuery.of(ctx).size.width * 0.9 : 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: conflicts.map((c) {
                final isRoom = c['type'] == 'salle';
                final form1Id = c['formation1Id'] as String;
                final form2Id = c['formation2Id'] as String;
                final form1 = formations.firstWhere((f) => f.id == form1Id, orElse: () => formations.first);
                final form2 = formations.firstWhere((f) => f.id == form2Id, orElse: () => formations.first);
                final horaire1 = c['horaire1'] as Horaire;
                final horaire2 = c['horaire2'] as Horaire;
                final hIdx1 = c['horaireIndex1'] as int;
                final hIdx2 = c['horaireIndex2'] as int;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isRoom ? Icons.meeting_room_rounded : Icons.person_off_rounded,
                            size: 18,
                            color: const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              c['title'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c['day'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c['description'] as String,
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF7F1D1D)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSessionDialog(
                                formations: formations,
                                existingEntry: _SessionEntry(
                                  formation: form1,
                                  horaire: horaire1,
                                  horaireIndex: hIdx1,
                                  enrolledStudents: const [],
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text(
                              'Modifier Cours 1',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              side: const BorderSide(color: Colors.deepOrange),
                              foregroundColor: Colors.deepOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSessionDialog(
                                formations: formations,
                                existingEntry: _SessionEntry(
                                  formation: form2,
                                  horaire: horaire2,
                                  horaireIndex: hIdx2,
                                  enrolledStudents: const [],
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text(
                              'Modifier Cours 2',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummary(
    bool isMobile,
    int totalSessions,
    int totalFormations,
    int totalGroups,
    int totalStudents,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isMobile
          ? LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(
                        Icons.schedule_rounded,
                        '$totalSessions',
                        'Séances',
                        AppTheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(
                        Icons.school_rounded,
                        '$totalFormations',
                        'Formations',
                        AppTheme.orangeAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(
                        Icons.groups_rounded,
                        '$totalGroups',
                        'Groupes',
                        AppTheme.indigoAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(
                        Icons.people_outline_rounded,
                        '$totalStudents',
                        'Apprenants',
                        AppTheme.success,
                      ),
                    ),
                  ],
                );
              },
            )
          : Wrap(
              spacing: 24,
              runSpacing: 12,
              alignment: WrapAlignment.spaceAround,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetricItem(
                  Icons.schedule_rounded,
                  '$totalSessions',
                  'Séances programmées',
                  AppTheme.primary,
                ),
                _buildMetricItem(
                  Icons.school_rounded,
                  '$totalFormations',
                  'Formations actives',
                  AppTheme.orangeAccent,
                ),
                _buildMetricItem(
                  Icons.groups_rounded,
                  '$totalGroups',
                  'Groupes constitués',
                  AppTheme.indigoAccent,
                ),
                _buildMetricItem(
                  Icons.people_outline_rounded,
                  '$totalStudents',
                  'Apprenants planifiés',
                  AppTheme.success,
                ),
              ],
            ),
    );
  }

  Widget _buildMetricItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersBar(
    bool isMobile,
    List<Formation> formations,
    List<User> formateurs,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search box
          SizedBox(
            width: isMobile ? double.infinity : 240,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher module, salle...',
                hintStyle: GoogleFonts.poppins(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
          ),

          // Formation filter
          SizedBox(
            width: isMobile ? double.infinity : 220,
            child: DropdownButtonFormField<String?>(
              initialValue: _filterFormationId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filtrer par Formation',
                labelStyle: GoogleFonts.poppins(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Toutes les formations',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ...formations.map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      f.titre,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _filterFormationId = val),
            ),
          ),

          // Formateur filter
          SizedBox(
            width: isMobile ? double.infinity : 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _filterFormateurId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filtrer par Formateur',
                labelStyle: GoogleFonts.poppins(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Tous les formateurs',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ...formateurs.map(
                  (u) => DropdownMenuItem(
                    value: u.id,
                    child: Text(
                      u.nomComplet,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _filterFormateurId = val),
            ),
          ),

          if (_filterFormationId != null ||
              _filterFormateurId != null ||
              _selectedDay != 'Tous' ||
              _searchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterFormationId = null;
                  _filterFormateurId = null;
                  _selectedDay = 'Tous';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Réinitialiser',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _days.map((day) {
          final isSelected = _selectedDay == day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(day),
              selectedColor: AppTheme.primary,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.white,
              labelStyle: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) => setState(() => _selectedDay = day),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyCalendarGrid(
    bool isMobile,
    List<_SessionEntry> sessions,
    List<Formation> formations,
  ) {
    final activeDays = _selectedDay == 'Tous'
        ? ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
        : [_selectedDay];

    return isMobile
        ? _buildMobileCalendarView(activeDays, sessions, formations)
        : _buildDesktopCalendarView(activeDays, sessions, formations);
  }

  Widget _buildDesktopCalendarView(
    List<String> days,
    List<_SessionEntry> sessions,
    List<Formation> formations,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: days.map((day) {
          final daySessions = sessions
              .where((s) => s.horaire.jour == day)
              .toList()
            ..sort((a, b) => a.horaire.heureDebut.compareTo(b.horaire.heureDebut));

          return Container(
            width: days.length == 1 ? 650 : 310,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDay == day
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.15),
                width: _selectedDay == day ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Day Column Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedDay == day
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: daySessions.isNotEmpty ? AppTheme.primary : Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            day,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: daySessions.isNotEmpty
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${daySessions.length} cours',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: daySessions.isNotEmpty ? AppTheme.primary : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                            color: AppTheme.primary,
                            tooltip: 'Ajouter un cours le $day',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showSessionDialog(
                              formations: formations,
                              defaultDay: day,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Day Column Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: daySessions.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.15),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 24,
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun cours programmé',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showSessionDialog(
                                  formations: formations,
                                  defaultDay: day,
                                ),
                                icon: const Icon(Icons.add, size: 14),
                                label: Text(
                                  'Programmer',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: daySessions.map((entry) {
                            return _buildCalendarSessionCard(entry);
                          }).toList(),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileCalendarView(
    List<String> days,
    List<_SessionEntry> sessions,
    List<Formation> formations,
  ) {
    return Column(
      children: days.map((day) {
        final daySessions = sessions
            .where((s) => s.horaire.jour == day)
            .toList()
          ..sort((a, b) => a.horaire.heureDebut.compareTo(b.horaire.heureDebut));

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mobile Day Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${daySessions.length} cours',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: daySessions.isNotEmpty ? AppTheme.primary : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                          color: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showSessionDialog(
                            formations: formations,
                            defaultDay: day,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mobile Day Sessions
              Padding(
                padding: const EdgeInsets.all(10),
                child: daySessions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Aucun cours ce jour-là',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: daySessions.map((entry) {
                          return _buildCalendarSessionCard(entry);
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarSessionCard(_SessionEntry entry) {
    final horaire = entry.horaire;
    final formation = entry.formation;
    final students = entry.enrolledStudents;
    final isEnLigne = horaire.modalite == 'En ligne';
    final hasConflict = entry.hasConflict;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: hasConflict ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasConflict
              ? const Color(0xFFEF4444)
              : AppTheme.primary.withValues(alpha: 0.18),
          width: hasConflict ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasConflict
                ? Colors.red.withValues(alpha: 0.08)
                : AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showStudentsDialog(entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Time badge + Modality + Conflict Alert + Popup menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasConflict
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: hasConflict ? const Color(0xFFDC2626) : AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${horaire.heureDebut} - ${horaire.heureFin}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasConflict ? const Color(0xFFDC2626) : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isEnLigne ? Colors.purple : Colors.teal).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        horaire.modalite ?? 'Présentiel',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isEnLigne ? Colors.purple : Colors.teal,
                        ),
                      ),
                    ),
                    if (hasConflict) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: entry.conflicts.join('\n'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFDC2626)),
                              const SizedBox(width: 2),
                              Text(
                                'Conflit',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (action) => _handleCardAction(action, entry),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'qr',
                          child: Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF1D447A)),
                              SizedBox(width: 8),
                              Text('Badge QR d\'émargement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'attendance',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                              SizedBox(width: 8),
                              Text('Feuille d\'émargement PDF', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'students',
                          child: Row(
                            children: [
                              Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text('Voir les apprenants', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Modifier', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Formation Title
                Text(
                  formation.titre,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Module Name
                if (horaire.module != null && horaire.module!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.bookmark_outline_rounded, size: 13, color: AppTheme.orangeAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          horaire.module!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.orangeAccent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Trainer + Room + Students Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Formateur
                    if (entry.formateurNom != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text(
                            entry.formateurNom!,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),

                    // Salle
                    if (horaire.lieuOuLien != null && horaire.lieuOuLien!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEnLigne ? Icons.link_rounded : Icons.meeting_room_outlined,
                            size: 13,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            horaire.lieuOuLien!,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),

                    // Apprenants
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (students.isNotEmpty
                                ? AppTheme.success
                                : (entry.totalFormationStudents > 0
                                    ? Colors.amber.shade700
                                    : Colors.grey))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        students.isNotEmpty
                            ? '${students.length} apprenant${students.length > 1 ? 's' : ''}'
                            : (entry.totalFormationStudents > 0
                                ? '0 sur ${entry.totalFormationStudents} inscrit${entry.totalFormationStudents > 1 ? 's' : ''}'
                                : '0 apprenant'),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: students.isNotEmpty
                              ? AppTheme.success
                              : (entry.totalFormationStudents > 0
                                  ? Colors.amber.shade900
                                  : Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsList(bool isMobile, List<_SessionEntry> sessions) {
    if (sessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun créneau programmé pour les filtres sélectionnés.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cliquez sur "Programmer un Créneau" pour ajouter une séance avec constitution automatique du groupe.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: sessions.map((entry) {
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: _buildSessionCard(isMobile, entry),
        );
      }).toList(),
    );
  }

  Widget _buildSessionCard(bool isMobile, _SessionEntry entry) {
    final horaire = entry.horaire;
    final formation = entry.formation;
    final students = entry.enrolledStudents;
    final groupName = entry.groupeDisplayName;
    final isEnLigne = horaire.modalite == 'En ligne';
    final hasConflict = entry.hasConflict;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: hasConflict ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasConflict
              ? const Color(0xFFEF4444)
              : Colors.grey.withValues(alpha: 0.12),
          width: hasConflict ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasConflict
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Day + Time + Modality + Conflict + Actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasConflict
                        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: hasConflict ? const Color(0xFFDC2626) : AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${horaire.jour} • ${horaire.heureDebut} - ${horaire.heureFin}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hasConflict ? const Color(0xFFDC2626) : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isEnLigne ? Colors.purple : Colors.teal).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEnLigne
                            ? Icons.videocam_rounded
                            : Icons.location_on_rounded,
                        size: 13,
                        color: isEnLigne ? Colors.purple : Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        horaire.modalite ?? 'Présentiel',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isEnLigne ? Colors.purple : Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasConflict) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: entry.conflicts.join('\n'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Conflit détecté',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Actions dropdown popup menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onSelected: (action) => _handleCardAction(action, entry),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'attendance',
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 8),
                          Text('Feuille d\'émargement PDF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'students',
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          SizedBox(width: 8),
                          Text('Voir les apprenants'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text('Modifier le créneau'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 8),
                          Text('Dupliquer sur un autre jour'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_forever_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Middle section: Formation, Module & Group Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formation.titre,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Module Badge
                          _buildChip(
                            Icons.menu_book_rounded,
                            horaire.module?.isNotEmpty == true
                                ? horaire.module!
                                : 'Tronc Commun',
                            AppTheme.primary,
                          ),
                          // Automatic Group Badge
                          InkWell(
                            onTap: () => _showStudentsDialog(entry),
                            borderRadius: BorderRadius.circular(8),
                            child: _buildChip(
                              Icons.groups_rounded,
                              students.isNotEmpty
                                  ? '$groupName (${students.length} inscrit${students.length > 1 ? 's' : ''})'
                                  : (entry.totalFormationStudents > 0
                                      ? '$groupName (0 sur ${entry.totalFormationStudents} inscrit${entry.totalFormationStudents > 1 ? 's' : ''})'
                                      : '$groupName (0 inscrit)'),
                              students.isNotEmpty ? Colors.indigo : (entry.totalFormationStudents > 0 ? Colors.amber.shade900 : Colors.grey),
                              isClickable: true,
                            ),
                          ),
                          // Trainer Badge
                          if (entry.formateurNom != null)
                            _buildChip(
                              Icons.person_pin_rounded,
                              'Formateur : ${entry.formateurNom}',
                              Colors.teal,
                            ),
                          // Room or Link Badge
                          if (horaire.lieuOuLien?.isNotEmpty == true)
                            _buildChip(
                              isEnLigne
                                  ? Icons.link_rounded
                                  : Icons.meeting_room_rounded,
                              horaire.lieuOuLien!,
                              Colors.deepOrange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom bar: étudiants + actions
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () => _showStudentsDialog(entry),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${students.length} apprenant${students.length > 1 ? 's' : ''} inscrit${students.length > 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      tooltip: 'Feuille d\'émargement PDF',
                      onPressed: () => _printAttendanceSheet(entry),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      tooltip: 'Modifier',
                      onPressed: () => _showSessionDialog(
                        formations: _db.getFormations(),
                        existingEntry: entry,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Supprimer',
                      onPressed: () => _confirmDeleteSession(entry),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    IconData icon,
    String label,
    Color color, {
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isClickable) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
          ],
        ],
      ),
    );
  }

  void _handleCardAction(String action, _SessionEntry entry) {
    switch (action) {
      case 'qr':
        _showQrEmargementDialog(entry);
        break;
      case 'attendance':
        _printAttendanceSheet(entry);
        break;
      case 'students':
        _showStudentsDialog(entry);
        break;
      case 'edit':
        _showSessionDialog(
          formations: _db.getFormations(),
          existingEntry: entry,
        );
        break;
      case 'duplicate':
        _showDuplicateDialog(entry);
        break;
      case 'delete':
        _confirmDeleteSession(entry);
        break;
    }
  }

  // --- SHOW STUDENTS DIALOG ---
  void _showStudentsDialog(_SessionEntry entry) {
    final students = entry.enrolledStudents;
    final groupName = entry.groupeDisplayName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apprenants du Groupe',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$groupName • ${entry.formation.titre}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: students.isEmpty
              ? (entry.totalFormationStudents > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '0 apprenant inscrit à ce module spécifique',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Aucun apprenant n\'a sélectionné le module « ${entry.horaire.module ?? 'Tronc commun'} ».\nLa formation « ${entry.formation.titre} » compte au total ${entry.totalFormationStudents} apprenant${entry.totalFormationStudents > 1 ? 's' : ''} inscrit${entry.totalFormationStudents > 1 ? 's' : ''} (liste ci-dessous) :',
                                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.brown.shade800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tous les apprenants inscrits à « ${entry.formation.titre} » :',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _db.getStudentsForFormation(entry.formation.id).length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final s = _db.getStudentsForFormation(entry.formation.id)[i];
                              final assignment = s.assignedFormations.firstWhere(
                                (a) => a['formationId'] == entry.formation.id,
                                orElse: () => <String, dynamic>{},
                              );
                              final rawMods = (assignment['modules'] as List<dynamic>? ?? [])
                                  .map((m) => m is Map ? m['title']?.toString() ?? '' : m.toString())
                                  .where((m) => m.isNotEmpty)
                                  .join(', ');

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    s.prenom.isNotEmpty ? s.prenom[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary),
                                  ),
                                ),
                                title: Text(s.nomComplet, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                subtitle: Text(
                                  rawMods.isNotEmpty ? 'Modules choisis : $rawMods' : s.email,
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aucun apprenant n\'est encore inscrit à cette formation.',
                          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                        ),
                      ),
                    ))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = students[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          s.prenom.isNotEmpty ? s.prenom[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        s.nomComplet,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${s.email} • ${s.phone}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: s.estActif
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.estActif ? 'Inscrit actif' : 'Inactif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: s.estActif ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1D447A)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF1D447A)),
            label: Text(
              'Badge QR',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D447A),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showQrEmargementDialog(entry);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(
              'Feuille d\'émargement PDF',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _printAttendanceSheet(entry),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // --- DUPLICATE SESSION DIALOG ---
  void _showDuplicateDialog(_SessionEntry entry) {
    String targetDay = _days
        .where((d) => d != 'Tous' && d != entry.horaire.jour)
        .first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Dupliquer ce créneau',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copier la séance de "${entry.formation.titre}" (${entry.horaire.heureDebut} - ${entry.horaire.heureFin}) vers un autre jour :',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: targetDay,
                decoration: const InputDecoration(
                  labelText: 'Nouveau Jour',
                  border: OutlineInputBorder(),
                ),
                items: _days
                    .where((d) => d != 'Tous')
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => targetDay = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _db.duplicateHoraireInFormation(
                  entry.formation.id,
                  entry.horaireIndex,
                  targetDay,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Séance dupliquée avec succès vers $targetDay.',
                      ),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Dupliquer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONFIRM DELETE SESSION ---
  void _confirmDeleteSession(_SessionEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le créneau ${entry.horaire.jour} (${entry.horaire.heureDebut}-${entry.horaire.heureFin}) de "${entry.formation.titre}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _db.deleteHoraireFromFormation(
                entry.formation.id,
                entry.horaireIndex,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Créneau supprimé avec succès.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // --- ADD / EDIT SESSION DIALOG ---
  void _showSessionDialog({
    required List<Formation> formations,
    _SessionEntry? existingEntry,
    String? defaultDay,
  }) {
    if (formations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord créer au moins une formation.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final isEdit = existingEntry != null;
    String selectedFormationId = isEdit
        ? existingEntry.formation.id
        : formations.first.id;
    Formation currentFormation = formations.firstWhere(
      (f) => f.id == selectedFormationId,
      orElse: () => formations.first,
    );

    String? selectedModule = isEdit
        ? existingEntry.horaire.module
        : (currentFormation.modules.isNotEmpty
              ? currentFormation.modules.first
              : null);
    String selectedDay = isEdit
        ? existingEntry.horaire.jour
        : (defaultDay ?? (_selectedDay != 'Tous' ? _selectedDay : 'Lundi'));
    String selectedModality = isEdit
        ? (existingEntry.horaire.modalite ?? 'Présentiel')
        : 'Présentiel';
    final startController = TextEditingController(
      text: isEdit ? existingEntry.horaire.heureDebut : '09:00',
    );
    final endController = TextEditingController(
      text: isEdit ? existingEntry.horaire.heureFin : '12:00',
    );
    final placeController = TextEditingController(
      text: isEdit ? (existingEntry.horaire.lieuOuLien ?? '') : 'Salle 1',
    );
    final customGroupController = TextEditingController(
      text: isEdit ? (existingEntry.horaire.groupe ?? '') : '',
    );

    // Trainer resolution
    String? resolvedTrainerId = isEdit ? existingEntry.formateurId : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Re-evaluate current formation when id changes
          currentFormation = formations.firstWhere(
            (f) => f.id == selectedFormationId,
            orElse: () => formations.first,
          );

          // Auto-select trainer assigned to this module if not explicitly modified
          if (selectedModule != null &&
              currentFormation.moduleFormateurIds.containsKey(selectedModule)) {
            resolvedTrainerId =
                currentFormation.moduleFormateurIds[selectedModule];
          } else if (currentFormation.formateurIds.isNotEmpty) {
            resolvedTrainerId = currentFormation.formateurIds.first;
          }

          // Automatically deduce the enrolled learners group
          final enrolledStudents = _db.getStudentsForFormationModule(
            currentFormation.id,
            selectedModule,
          );
          final autoGroupName =
              selectedModule != null && selectedModule!.isNotEmpty
              ? '${currentFormation.titre} • $selectedModule'
              : '${currentFormation.titre} • Tous modules';

          // Check planning conflicts in real-time
          final conflicts = _db.checkPlanningConflicts(
            day: selectedDay,
            start: startController.text.trim(),
            end: endController.text.trim(),
            formateurId: resolvedTrainerId,
            salleOuLien: placeController.text.trim(),
            currentFormationId: isEdit ? existingEntry.formation.id : null,
            currentHoraireIndex: isEdit ? existingEntry.horaireIndex : null,
          );

          final trainerUser = resolvedTrainerId != null
              ? _db.getUserById(resolvedTrainerId!)
              : null;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(
                  isEdit
                      ? Icons.edit_calendar_rounded
                      : Icons.add_alarm_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Modifier le Créneau' : 'Programmer un Créneau',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 550
                  ? MediaQuery.of(ctx).size.width * 0.9
                  : 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formation selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormationId,
                      decoration: const InputDecoration(
                        labelText: 'Formation *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: formations
                          .map(
                            (f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.titre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isEdit
                          ? null
                          : (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedFormationId = val;
                                  final newForm = formations.firstWhere(
                                    (f) => f.id == val,
                                  );
                                  selectedModule =
                                      newForm.modules.isNotEmpty
                                      ? newForm.modules.first
                                      : null;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 12),

                    // Module selector (if available)
                    if (currentFormation.modules.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: currentFormation.modules.contains(selectedModule) ? selectedModule : null,
                        decoration: const InputDecoration(
                          labelText: 'Module concerné *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les modules (Tronc commun - Tous les apprenants)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...currentFormation.modules.map(
                            (m) => DropdownMenuItem<String?>(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedModule = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // AUTOMATIC GROUP BADGE & STUDENTS PREVIEW
                    Builder(
                      builder: (context) {
                        final totalInFormation = _db.getStudentsForFormation(currentFormation.id).length;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.groups_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Groupe constitué automatiquement :',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                customGroupController.text.trim().isNotEmpty
                                    ? customGroupController.text.trim()
                                    : autoGroupName,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (enrolledStudents.isNotEmpty
                                              ? Colors.green
                                              : (totalInFormation > 0 ? Colors.amber.shade700 : Colors.grey))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      enrolledStudents.isNotEmpty
                                          ? '${enrolledStudents.length} apprenant${enrolledStudents.length > 1 ? 's' : ''} inscrit${enrolledStudents.length > 1 ? 's' : ''}'
                                          : (totalInFormation > 0
                                              ? '0 sur $totalInFormation inscrit${totalInFormation > 1 ? 's' : ''} à la formation'
                                              : '0 apprenant inscrit'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: enrolledStudents.isNotEmpty
                                            ? Colors.green.shade800
                                            : (totalInFormation > 0 ? Colors.amber.shade900 : Colors.grey.shade700),
                                      ),
                                    ),
                                  ),
                                  if (trainerUser != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '👨‍🏫 ${trainerUser.nomComplet}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.teal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Day & Modality
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: const InputDecoration(
                              labelText: 'Jour *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _days
                                .where((d) => d != 'Tous')
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedDay = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedModality,
                            decoration: const InputDecoration(
                              labelText: 'Modalité',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Présentiel',
                                child: Text('Présentiel'),
                              ),
                              DropdownMenuItem(
                                value: 'En ligne',
                                child: Text('En ligne'),
                              ),
                              DropdownMenuItem(
                                value: 'Mixte',
                                child: Text('Mixte'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedModality = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Times with pickers
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Début *',
                              prefixIcon: Icon(
                                Icons.schedule_rounded,
                                size: 16,
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onTap: () async {
                              final parts = startController.text.split(':');
                              final initH = int.tryParse(parts.first) ?? 9;
                              final initM = parts.length > 1
                                  ? (int.tryParse(parts[1]) ?? 0)
                                  : 0;
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: initH,
                                  minute: initM,
                                ),
                              );
                              if (picked != null) {
                                final formatted =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                setDialogState(
                                  () => startController.text = formatted,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Fin *',
                              prefixIcon: Icon(
                                Icons.schedule_rounded,
                                size: 16,
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onTap: () async {
                              final parts = endController.text.split(':');
                              final initH = int.tryParse(parts.first) ?? 12;
                              final initM = parts.length > 1
                                  ? (int.tryParse(parts[1]) ?? 0)
                                  : 0;
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: initH,
                                  minute: initM,
                                ),
                              );
                              if (picked != null) {
                                final formatted =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                setDialogState(
                                  () => endController.text = formatted,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Salle ou Lien
                    TextField(
                      controller: placeController,
                      decoration: const InputDecoration(
                        labelText: 'Salle ou Lien visio',
                        hintText: 'Ex. Salle 2 ou https://meet.google.com/...',
                        prefixIcon: Icon(Icons.room_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),

                    // PLANNING CONFLICTS WARNING
                    if (conflicts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Attention : Conflit de planning détecté !',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...conflicts.map(
                              (c) => Text(
                                '• $c',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final start = startController.text.trim();
                  final end = endController.text.trim();
                  if (start.isEmpty || end.isEmpty) return;

                  final groupeFinal =
                      customGroupController.text.trim().isNotEmpty
                      ? customGroupController.text.trim()
                      : autoGroupName;

                  final newHoraire = Horaire(
                    jour: selectedDay,
                    heureDebut: start,
                    heureFin: end,
                    module: selectedModule,
                    groupe: groupeFinal,
                    modalite: selectedModality,
                    lieuOuLien: placeController.text.trim().isNotEmpty
                        ? placeController.text.trim()
                        : null,
                  );

                  if (isEdit) {
                    if (existingEntry.formation.id == currentFormation.id) {
                      await _db.updateHoraireInFormation(
                        currentFormation.id,
                        existingEntry.horaireIndex,
                        newHoraire,
                      );
                    } else {
                      // Formation changed: remove from old, add to new
                      await _db.deleteHoraireFromFormation(
                        existingEntry.formation.id,
                        existingEntry.horaireIndex,
                      );
                      await _db.addHoraireToFormation(
                        currentFormation.id,
                        newHoraire,
                      );
                    }
                  } else {
                    await _db.addHoraireToFormation(
                      currentFormation.id,
                      newHoraire,
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Créneau mis à jour avec succès !'
                              : 'Séance et groupe programmés avec succès !',
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
                child: Text(isEdit ? 'Enregistrer' : 'Programmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQrEmargementDialog(_SessionEntry entry) {
    final horaire = entry.horaire;
    final formation = entry.formation;
    final formateurNom = entry.formateurNom ?? 'Formateur M@LI-NTIC';
    final dateStr = '${horaire.jour} (${horaire.heureDebut} - ${horaire.heureFin})';
    final tokenData = 'MALINTIC-EMARGEMENT|FORM:${formation.titre}|MOD:${horaire.module ?? "TRONC-COMMUN"}|JOUR:${horaire.jour}|HEURE:${horaire.heureDebut}-${horaire.heureFin}|FORMATEUR:$formateurNom';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D447A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1D447A), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Badge QR Émargement',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1D447A)),
                  ),
                  Text(
                    'Scanner pour valider la présence à la séance',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: tokenData,
                      version: QrVersions.auto,
                      size: 200.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1D447A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formation.titre,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D447A)),
                      textAlign: TextAlign.center,
                    ),
                    if (horaire.module != null && horaire.module!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Module : ${horaire.module}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.orangeAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • $formateurNom',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (horaire.lieuOuLien != null && horaire.lieuOuLien!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Lieu / Salle : ${horaire.lieuOuLien}',
                        style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.teal, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFF1D447A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF1D447A)),
                      label: Text(
                        'Copier Token',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1D447A)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tokenData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Jeton d\'émargement copié dans le presse-papiers !'),
                            backgroundColor: Color(0xFF1D447A),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                      label: Text(
                        'Feuille PDF',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _printAttendanceSheet(entry);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _printAttendanceSheet(_SessionEntry entry) async {
    try {
      final pdfBytes = await PdfService().generateAttendanceSheetPdf(
        formationTitle: entry.formation.titre,
        moduleTitle: entry.horaire.module,
        cohortName: entry.groupeDisplayName,
        formateurNom: entry.formateurNom ?? 'Formateur M@LI-NTIC',
        jour: entry.horaire.jour,
        heureDebut: entry.horaire.heureDebut,
        heureFin: entry.horaire.heureFin,
        salleOuLien: entry.horaire.lieuOuLien,
        modalite: entry.horaire.modalite ?? 'Présentiel',
        students: entry.enrolledStudents,
        dateSeance: DateTime.now(),
      );

      final safeName = '${entry.formation.titre}_${entry.horaire.jour}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Emargement_$safeName.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Feuille d\'émargement PDF générée avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération émargement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

class _SessionEntry {
  final Formation formation;
  final Horaire horaire;
  final int horaireIndex;
  final String? formateurId;
  final String? formateurNom;
  final List<User> enrolledStudents;
  final int totalFormationStudents;
  final List<String> conflicts;

  _SessionEntry({
    required this.formation,
    required this.horaire,
    required this.horaireIndex,
    this.formateurId,
    this.formateurNom,
    required this.enrolledStudents,
    this.totalFormationStudents = 0,
    this.conflicts = const [],
  });

  bool get hasConflict => conflicts.isNotEmpty;

  String get groupeDisplayName {
    if (horaire.groupe != null && horaire.groupe!.trim().isNotEmpty) {
      return horaire.groupe!.trim();
    }
    if (horaire.module != null && horaire.module!.trim().isNotEmpty) {
      return '${formation.titre} • ${horaire.module}';
    }
    return '${formation.titre} • Tous modules';
  }
}
