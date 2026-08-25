import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/utils/schedule_utils.dart';

class AdminPlanning extends StatefulWidget {
  const AdminPlanning({super.key});

  @override
  State<AdminPlanning> createState() => _AdminPlanningState();
}

class _AdminPlanningState extends State<AdminPlanning> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;

  String _selectedDay = 'Tous';
  String? _filterFormationId;
  String? _filterFormateurId;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _days = ['Tous', ...frenchWeekdays];

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
        final formateurs = users.where((u) => u.role == UserRole.formateur && u.estActif).toList();

        // Extract all session items with metadata
        final allSessions = <_SessionEntry>[];
        for (final formation in formations) {
          for (int i = 0; i < formation.horaires.length; i++) {
            final horaire = formation.horaires[i];
            final enrolledStudents = _db.getStudentsForFormationModule(formation.id, horaire.module);

            // Determine assigned trainer for this session
            String? formateurNom;
            String? formateurId;
            if (horaire.module != null && formation.moduleFormateurIds.containsKey(horaire.module)) {
              formateurId = formation.moduleFormateurIds[horaire.module];
            } else if (formation.formateurIds.isNotEmpty) {
              formateurId = formation.formateurIds.first;
            }
            if (formateurId != null) {
              final trainer = _db.getUserById(formateurId);
              if (trainer != null) formateurNom = trainer.nomComplet;
            }

            allSessions.add(_SessionEntry(
              formation: formation,
              horaire: horaire,
              horaireIndex: i,
              formateurId: formateurId,
              formateurNom: formateurNom,
              enrolledStudents: enrolledStudents,
            ));
          }
        }

        // Apply filters
        final filteredSessions = allSessions.where((s) {
          if (_selectedDay != 'Tous' && s.horaire.jour != _selectedDay) return false;
          if (_filterFormationId != null && s.formation.id != _filterFormationId) return false;
          if (_filterFormateurId != null && s.formateurId != _filterFormateurId) return false;

          final query = _searchController.text.trim().toLowerCase();
          if (query.isNotEmpty) {
            final matchFormation = s.formation.titre.toLowerCase().contains(query);
            final matchModule = (s.horaire.module ?? '').toLowerCase().contains(query);
            final matchGroupe = (s.horaire.groupe ?? '').toLowerCase().contains(query);
            final matchSalle = (s.horaire.lieuOuLien ?? '').toLowerCase().contains(query);
            final matchFormateur = (s.formateurNom ?? '').toLowerCase().contains(query);
            if (!matchFormation && !matchModule && !matchGroupe && !matchSalle && !matchFormateur) {
              return false;
            }
          }
          return true;
        }).toList();

        // Sort by day and start time
        filteredSessions.sort((a, b) {
          final dayCompare = weekdayOrder(a.horaire.jour).compareTo(weekdayOrder(b.horaire.jour));
          if (dayCompare != 0) return dayCompare;
          return a.horaire.heureDebut.compareTo(b.horaire.heureDebut);
        });

        // Compute metrics
        final totalSessions = allSessions.length;
        final totalGroups = allSessions.map((s) => s.groupeDisplayName).toSet().length;
        final totalStudents = allSessions.expand((s) => s.enrolledStudents.map((u) => u.id)).toSet().length;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile, formations),
              const SizedBox(height: 16),
              _buildMetricsSummary(isMobile, totalSessions, formations.length, totalGroups, totalStudents),
              const SizedBox(height: 20),
              _buildFiltersBar(isMobile, formations, formateurs),
              const SizedBox(height: 16),
              _buildDayFilters(),
              const SizedBox(height: 20),
              _buildSessionsList(isMobile, filteredSessions),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, List<Formation> formations) {
    return FadeTransition(
      opacity: _fadeController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
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
                  'Gestion des créneaux et groupes d\'apprenants par module',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 12 : 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 10 : 14,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
            onPressed: () => _showSessionDialog(formations: formations),
            icon: const Icon(Icons.add_alarm_rounded, size: 18),
            label: Text(
              isMobile ? 'Créneau' : 'Programmer un Créneau',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
            ),
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 14),
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
                      child: _buildMetricItem(Icons.schedule_rounded, '$totalSessions', 'Séances', AppTheme.primary),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(Icons.school_rounded, '$totalFormations', 'Formations', AppTheme.orangeAccent),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(Icons.groups_rounded, '$totalGroups', 'Groupes', AppTheme.indigoAccent),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildMetricItem(Icons.people_outline_rounded, '$totalStudents', 'Apprenants', AppTheme.success),
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
                _buildMetricItem(Icons.schedule_rounded, '$totalSessions', 'Séances programmées', AppTheme.primary),
                _buildMetricItem(Icons.school_rounded, '$totalFormations', 'Formations actives', AppTheme.orangeAccent),
                _buildMetricItem(Icons.groups_rounded, '$totalGroups', 'Groupes constitués', AppTheme.indigoAccent),
                _buildMetricItem(Icons.people_outline_rounded, '$totalStudents', 'Apprenants planifiés', AppTheme.success),
              ],
            ),
    );
  }

  Widget _buildMetricItem(IconData icon, String value, String label, Color color) {
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
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersBar(bool isMobile, List<Formation> formations, List<User> formateurs) {
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toutes les formations', style: TextStyle(fontSize: 12))),
                ...formations.map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(f.titre, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous les formateurs', style: TextStyle(fontSize: 12))),
                ...formateurs.map(
                  (u) => DropdownMenuItem(
                    value: u.id,
                    child: Text(u.nomComplet, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _filterFormateurId = val),
            ),
          ),

          if (_filterFormationId != null || _filterFormateurId != null || _selectedDay != 'Tous' || _searchController.text.isNotEmpty)
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
              label: Text('Réinitialiser', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
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
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Aucun créneau programmé pour les filtres sélectionnés.',
              style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            // Top row: Day + Time + Actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${horaire.jour} • ${horaire.heureDebut} - ${horaire.heureFin}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isEnLigne ? Colors.purple : Colors.teal).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEnLigne ? Icons.videocam_rounded : Icons.location_on_rounded,
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
                const Spacer(),
                // Actions dropdown popup menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                  onSelected: (action) => _handleCardAction(action, entry),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'students',
                      child: Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 18, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Voir les apprenants'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Modifier le créneau'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 18, color: Colors.amber),
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
                          Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
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
                            horaire.module?.isNotEmpty == true ? horaire.module! : 'Tronc Commun',
                            AppTheme.primary,
                          ),
                          // Automatic Group Badge
                          InkWell(
                            onTap: () => _showStudentsDialog(entry),
                            borderRadius: BorderRadius.circular(8),
                            child: _buildChip(
                              Icons.groups_rounded,
                              '$groupName (${students.length} inscrit${students.length > 1 ? 's' : ''})',
                              Colors.indigo,
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
                              isEnLigne ? Icons.link_rounded : Icons.meeting_room_rounded,
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

            // Bottom bar: Quick button to see enrolled group
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _showStudentsDialog(entry),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${students.length} apprenant${students.length > 1 ? 's' : ''} dans ce groupe (cliquer pour voir la liste)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                      tooltip: 'Modifier',
                      onPressed: () => _showSessionDialog(
                        formations: _db.getFormations(),
                        existingEntry: entry,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
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

  Widget _buildChip(IconData icon, String label, Color color, {bool isClickable = false}) {
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
      case 'students':
        _showStudentsDialog(entry);
        break;
      case 'edit':
        _showSessionDialog(formations: _db.getFormations(), existingEntry: entry);
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
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$groupName • ${entry.formation.titre}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: students.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Aucun apprenant n\'est encore inscrit à ce module.',
                      style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = students[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          s.prenom.isNotEmpty ? s.prenom[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      title: Text(s.nomComplet, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('${s.email} • ${s.phone}', style: const TextStyle(fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.estActif ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
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
    String targetDay = _days.where((d) => d != 'Tous' && d != entry.horaire.jour).first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Dupliquer ce créneau',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
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
                decoration: const InputDecoration(labelText: 'Nouveau Jour', border: OutlineInputBorder()),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                await _db.duplicateHoraireInFormation(entry.formation.id, entry.horaireIndex, targetDay);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Séance dupliquée avec succès vers $targetDay.'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _db.deleteHoraireFromFormation(entry.formation.id, entry.horaireIndex);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Créneau supprimé avec succès.'), backgroundColor: Colors.red),
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
  }) {
    if (formations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord créer au moins une formation.'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    final isEdit = existingEntry != null;
    String selectedFormationId = isEdit ? existingEntry.formation.id : formations.first.id;
    Formation currentFormation = formations.firstWhere(
      (f) => f.id == selectedFormationId,
      orElse: () => formations.first,
    );

    String? selectedModule = isEdit ? existingEntry.horaire.module : (currentFormation.modules.isNotEmpty ? currentFormation.modules.first : null);
    String selectedDay = isEdit ? existingEntry.horaire.jour : 'Lundi';
    String selectedModality = isEdit ? (existingEntry.horaire.modalite ?? 'Présentiel') : 'Présentiel';
    final startController = TextEditingController(text: isEdit ? existingEntry.horaire.heureDebut : '09:00');
    final endController = TextEditingController(text: isEdit ? existingEntry.horaire.heureFin : '12:00');
    final placeController = TextEditingController(text: isEdit ? (existingEntry.horaire.lieuOuLien ?? '') : 'Salle 1');
    final customGroupController = TextEditingController(text: isEdit ? (existingEntry.horaire.groupe ?? '') : '');

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
          if (selectedModule != null && currentFormation.moduleFormateurIds.containsKey(selectedModule)) {
            resolvedTrainerId = currentFormation.moduleFormateurIds[selectedModule];
          } else if (currentFormation.formateurIds.isNotEmpty) {
            resolvedTrainerId = currentFormation.formateurIds.first;
          }

          // Automatically deduce the enrolled learners group
          final enrolledStudents = _db.getStudentsForFormationModule(currentFormation.id, selectedModule);
          final autoGroupName = selectedModule != null && selectedModule!.isNotEmpty
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

          final trainerUser = resolvedTrainerId != null ? _db.getUserById(resolvedTrainerId!) : null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_calendar_rounded : Icons.add_alarm_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Modifier le Créneau' : 'Programmer un Créneau',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 550 ? MediaQuery.of(ctx).size.width * 0.9 : 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formation Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormationId,
                      decoration: const InputDecoration(
                        labelText: 'Formation *',
                        prefixIcon: Icon(Icons.school_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: formations.map((f) {
                        return DropdownMenuItem(
                          value: f.id,
                          child: Text(f.titre, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedFormationId = val;
                            final newForm = formations.firstWhere((f) => f.id == val);
                            selectedModule = newForm.modules.isNotEmpty ? newForm.modules.first : null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Module Dropdown
                    DropdownButtonFormField<String?>(
                      initialValue: selectedModule,
                      decoration: const InputDecoration(
                        labelText: 'Module concerné *',
                        prefixIcon: Icon(Icons.menu_book_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous les modules (Tronc commun)')),
                        ...currentFormation.modules.map(
                          (m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedModule = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // AUTOMATIC GROUP BADGE & STUDENTS PREVIEW
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.groups_rounded, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Groupe constitué automatiquement :',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customGroupController.text.trim().isNotEmpty
                                ? customGroupController.text.trim()
                                : autoGroupName,
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${enrolledStudents.length} apprenant${enrolledStudents.length > 1 ? 's' : ''} inscrit${enrolledStudents.length > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                              if (trainerUser != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '👨‍🏫 ${trainerUser.nomComplet}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Day & Modality
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: const InputDecoration(labelText: 'Jour *', border: OutlineInputBorder(), isDense: true),
                            items: _days
                                .where((d) => d != 'Tous')
                                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedDay = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedModality,
                            decoration: const InputDecoration(labelText: 'Modalité', border: OutlineInputBorder(), isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Présentiel', child: Text('Présentiel')),
                              DropdownMenuItem(value: 'En ligne', child: Text('En ligne')),
                              DropdownMenuItem(value: 'Mixte', child: Text('Mixte')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedModality = val);
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
                              prefixIcon: Icon(Icons.schedule_rounded, size: 16),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onTap: () async {
                              final parts = startController.text.split(':');
                              final initH = int.tryParse(parts.first) ?? 9;
                              final initM = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: initH, minute: initM),
                              );
                              if (picked != null) {
                                final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                setDialogState(() => startController.text = formatted);
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
                              prefixIcon: Icon(Icons.schedule_rounded, size: 16),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onTap: () async {
                              final parts = endController.text.split(':');
                              final initH = int.tryParse(parts.first) ?? 12;
                              final initM = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: initH, minute: initM),
                              );
                              if (picked != null) {
                                final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                setDialogState(() => endController.text = formatted);
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
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                                const SizedBox(width: 6),
                                Text(
                                  'Attention : Conflit de planning détecté !',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...conflicts.map(
                              (c) => Text('• $c', style: const TextStyle(fontSize: 11, color: Colors.red)),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final start = startController.text.trim();
                  final end = endController.text.trim();
                  if (start.isEmpty || end.isEmpty) return;

                  final groupeFinal = customGroupController.text.trim().isNotEmpty
                      ? customGroupController.text.trim()
                      : autoGroupName;

                  final newHoraire = Horaire(
                    jour: selectedDay,
                    heureDebut: start,
                    heureFin: end,
                    module: selectedModule,
                    groupe: groupeFinal,
                    modalite: selectedModality,
                    lieuOuLien: placeController.text.trim().isNotEmpty ? placeController.text.trim() : null,
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
                      await _db.addHoraireToFormation(currentFormation.id, newHoraire);
                    }
                  } else {
                    await _db.addHoraireToFormation(currentFormation.id, newHoraire);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Créneau mis à jour avec succès !' : 'Séance et groupe programmés avec succès !'),
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
}

class _SessionEntry {
  final Formation formation;
  final Horaire horaire;
  final int horaireIndex;
  final String? formateurId;
  final String? formateurNom;
  final List<User> enrolledStudents;

  _SessionEntry({
    required this.formation,
    required this.horaire,
    required this.horaireIndex,
    this.formateurId,
    this.formateurNom,
    required this.enrolledStudents,
  });

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
