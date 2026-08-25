import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/schedule_utils.dart';

class StudentSchedule extends StatefulWidget {
  final User user;

  const StudentSchedule({super.key, required this.user});

  @override
  State<StudentSchedule> createState() => _StudentScheduleState();
}

class _StudentScheduleState extends State<StudentSchedule> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 1200 ? 1100.0 : width * 0.95;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 28),
                _buildScheduleCalendar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon Emploi du Temps',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Horaires de mes formations',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCalendar() {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _getStudentSchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
          );
        }

        final scheduleByDay = snapshot.data ?? {};

        if (scheduleByDay.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.schedule_rounded, size: 48, color: Colors.black12),
                  SizedBox(height: 16),
                  Text(
                    'Aucun emploi du temps',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final daysOrder = frenchWeekdays;

        return Column(
          children: daysOrder.map((day) {
            final daySchedules = scheduleByDay[day] ?? [];

            if (daySchedules.isEmpty) {
              return SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _buildDayCard(day, daySchedules),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDayCard(String day, List<Map<String, dynamic>> schedules) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                day,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12),
            ...schedules.map((schedule) {
              final formateur = schedule['formateur'] ?? 'Formateur';
              final formation = schedule['formation'] ?? 'Formation';
              final modules = schedule['modules'] as List<dynamic>? ?? [];
              final debut = schedule['heureDebut'] ?? '';
              final fin = schedule['heureFin'] ?? '';
              final group = schedule['groupe']?.toString();
              final modality = schedule['modalite']?.toString();
              final place = schedule['lieuOuLien']?.toString();

              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            '$debut - $fin',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        formation,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Avec: $formateur',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (group?.isNotEmpty == true || modality?.isNotEmpty == true || place?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          [if (group?.isNotEmpty == true) 'Groupe : $group', if (modality?.isNotEmpty == true) modality!, if (place?.isNotEmpty == true) place!].join(' • '),
                          style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                      if (modules.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: modules.map((m) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getStudentSchedule() async {
    final formations = _db.getFormations();
    Map<String, List<Map<String, dynamic>>> scheduleByDay = {};

    for (var f in formations) {
      final assignment = widget.user.assignedFormations.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['formationId'] == f.id,
        orElse: () => null,
      );
      if (assignment == null) continue;
      final selectedModules = (assignment['modules'] as List? ?? [])
          .map((item) => item is Map ? item['title']?.toString() : item.toString())
          .whereType<String>()
          .toSet();
      for (var h in f.horaires) {
        if (h.module?.isNotEmpty == true && !selectedModules.contains(h.module)) continue;
        if (!scheduleByDay.containsKey(h.jour)) {
          scheduleByDay[h.jour] = [];
        }
        scheduleByDay[h.jour]!.add({
          'formateur': 'Formateur Référent',
          'formation': f.titre,
          'modules': h.module?.isNotEmpty == true ? [h.module] : selectedModules.toList(),
          'heureDebut': h.heureDebut,
          'heureFin': h.heureFin,
          'groupe': h.groupe,
          'modalite': h.modalite,
          'lieuOuLien': h.lieuOuLien,
          'statut': 'Publié',
        });
      }
    }

    // Merge published Seance records
    final publishedSeances = _db.getSeances().where((s) => s.estPubliee).toList();
    final studentAssignedIds = widget.user.assignedFormations
        .map((f) => f['formationId']?.toString() ?? '')
        .toSet();

    final dayNames = frenchWeekdays;

    for (var s in publishedSeances) {
      if (!studentAssignedIds.contains(s.formationId)) continue;
      final dayName = dayNames[s.date.weekday - 1];
      if (!scheduleByDay.containsKey(dayName)) {
        scheduleByDay[dayName] = [];
      }
      scheduleByDay[dayName]!.add({
        'formateur': s.formateurNom,
        'formation': s.formationTitle,
        'modules': s.moduleTitle != null ? [s.moduleTitle!] : [],
        'heureDebut': s.heureDebut,
        'heureFin': s.heureFin,
        'groupe': null,
        'modalite': s.modalite,
        'lieuOuLien': s.salleOuLien,
        'statut': 'Publié',
      });
    }

    return scheduleByDay;
  }
}
