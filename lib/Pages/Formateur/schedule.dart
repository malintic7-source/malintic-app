import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';

class FormateurSchedule extends StatefulWidget {
  final User user;

  const FormateurSchedule({super.key, required this.user});

  @override
  State<FormateurSchedule> createState() => _FormateurScheduleState();
}

class _FormateurScheduleState extends State<FormateurSchedule>
    with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;

  String _selectedDay = 'Tous';
  String? _filterFormationId;
  String? _filterModule;

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

    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormationsForFormateur(widget.user.id),
      builder: (context, formationsSnap) {
        final formations =
            formationsSnap.data ??
            _db.getFormationsForFormateur(widget.user.id);

        return StreamBuilder<List<User>>(
          stream: _db.watchStudentsForFormateur(widget.user.id),
          builder: (context, studentsSnap) {
            // Build list of trainer's slots with auto-group computation
            final allSlots = <_FormateurSlotItem>[];

            for (final formation in formations) {
              final trainerModules = _db
                  .getModulesForFormateur(formation, widget.user.id)
                  .toSet();

              for (int i = 0; i < formation.horaires.length; i++) {
                final horaire = formation.horaires[i];
                final slotModule = horaire.module;

                // Check if this slot belongs to one of this trainer's assigned modules
                final isMyModule =
                    slotModule != null && trainerModules.contains(slotModule);
                final isSharedOrAssigned =
                    slotModule == null &&
                    (trainerModules.isNotEmpty ||
                        formation.formateurIds.contains(widget.user.id));

                if (!isMyModule && !isSharedOrAssigned) continue;

                // Compute automatic dynamic group for this module
                final enrolledStudents = _db.getStudentsForFormationModule(
                  formation.id,
                  slotModule,
                );

                allSlots.add(
                  _FormateurSlotItem(
                    formation: formation,
                    horaire: horaire,
                    horaireIndex: i,
                    moduleTitle:
                        slotModule ??
                        (trainerModules.isNotEmpty
                            ? trainerModules.first
                            : formation.titre),
                    groupStudents: enrolledStudents,
                  ),
                );
              }
            }

            // Filter slots
            final filteredSlots = allSlots.where((slot) {
              if (_selectedDay != 'Tous' && slot.horaire.jour != _selectedDay)
                return false;
              if (_filterFormationId != null &&
                  slot.formation.id != _filterFormationId)
                return false;
              if (_filterModule != null && slot.horaire.module != _filterModule)
                return false;
              return true;
            }).toList();

            // Sort by day and time
            filteredSlots.sort((a, b) {
              final dayCmp = _dayOrder(
                a.horaire.jour,
              ).compareTo(_dayOrder(b.horaire.jour));
              if (dayCmp != 0) return dayCmp;
              return a.horaire.heureDebut.compareTo(b.horaire.heureDebut);
            });

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isMobile, formations),
                        const SizedBox(height: 20),
                        _buildFiltersBar(isMobile, formations),
                        const SizedBox(height: 16),
                        _buildDayFilters(),
                        const SizedBox(height: 24),
                        _buildSlotsList(isMobile, filteredSlots, formations),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emploi du Temps',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Planifiez vos créneaux et gérez les groupes automatiques par module',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: formations.isEmpty
                ? null
                : () => _showAddOrEditSlotDialog(formations: formations),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 8 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              isMobile ? 'Créneau' : 'Ajouter un créneau',
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

  Widget _buildFiltersBar(bool isMobile, List<Formation> formations) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Formation filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _filterFormationId,
              hint: Text(
                'Toutes mes formations',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Toutes mes formations',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                ...formations.map(
                  (f) => DropdownMenuItem<String?>(
                    value: f.id,
                    child: Text(
                      f.titre,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _filterFormationId = val;
                  _filterModule = null;
                });
              },
            ),
          ),
        ),
      ],
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
              label: Text(
                day,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primary,
              backgroundColor: Colors.white,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                ),
              ),
              onSelected: (_) => setState(() => _selectedDay = day),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSlotsList(
    bool isMobile,
    List<_FormateurSlotItem> slots,
    List<Formation> formations,
  ) {
    if (slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun créneau pour cette sélection',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cliquez sur "Ajouter un créneau" pour programmer vos séances par module.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildSlotCard(slot, index, formations),
        );
      },
    );
  }

  Widget _buildSlotCard(
    _FormateurSlotItem slot,
    int index,
    List<Formation> formations,
  ) {
    final horaire = slot.horaire;
    final formation = slot.formation;
    final students = slot.groupStudents;
    final moduleName = horaire.module ?? 'Tous les modules';

    return Container(
      key: ValueKey(
        '${formation.id}_${horaire.jour}_${horaire.heureDebut}_$index',
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Day badge, time, and quick actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  horaire.jour,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '${horaire.heureDebut} - ${horaire.heureFin}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Edit & Delete actions
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                tooltip: 'Modifier ce créneau',
                color: Colors.grey.shade700,
                onPressed: () => _showAddOrEditSlotDialog(
                  formations: formations,
                  existingFormationId: formation.id,
                  existingHoraireIndex: slot.horaireIndex,
                  existingHoraire: horaire,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: 'Supprimer ce créneau',
                color: Colors.red.shade400,
                onPressed: () =>
                    _confirmDeleteSlot(formation.id, slot.horaireIndex),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Formation title & module
          Text(
            formation.titre,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),

          // Dynamic Auto-Group Card
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Groupe Automatique',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        moduleName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Student count chip
                    InkWell(
                      onTap: () => _showGroupMembersDialog(
                        moduleName,
                        formation.titre,
                        students,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: students.isNotEmpty
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_rounded,
                              size: 14,
                              color: students.isNotEmpty
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${students.length} apprenant${students.length > 1 ? 's' : ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: students.isNotEmpty
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (students.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...students
                          .take(4)
                          .map(
                            (st) => Chip(
                              avatar: CircleAvatar(
                                radius: 8,
                                backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  st.prenom.isNotEmpty
                                      ? st.prenom[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              label: Text(
                                st.nomComplet,
                                style: const TextStyle(fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      if (students.length > 4)
                        InkWell(
                          onTap: () => _showGroupMembersDialog(
                            moduleName,
                            formation.titre,
                            students,
                          ),
                          child: Chip(
                            label: Text(
                              '+${students.length - 4}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Bottom row: Modalité / Salle and Emargement Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (horaire.lieuOuLien != null && horaire.lieuOuLien!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      horaire.modalite == 'En ligne'
                          ? Icons.videocam_rounded
                          : Icons.room_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        horaire.lieuOuLien!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _printAttendanceSheet(
                      formation.titre,
                      moduleName,
                      students,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                    label: Text(
                      'Feuille PDF',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showEmargementDialog(
                      formation.id,
                      formation.titre,
                      moduleName,
                      students,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: Text(
                      'Émargement',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGroupMembersDialog(
    String moduleName,
    String formationTitle,
    List<User> students,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Groupe Automatique',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$formationTitle • $moduleName',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: students.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Aucun apprenant inscrit à ce module pour l\'instant.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (context, idx) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final st = students[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          st.prenom.isNotEmpty
                              ? st.prenom[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        st.nomComplet,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${st.email} • ${st.phone}',
                        style: GoogleFonts.poppins(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () =>
                _printAttendanceSheet(formationTitle, moduleName, students),
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
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddOrEditSlotDialog({
    required List<Formation> formations,
    String? existingFormationId,
    int? existingHoraireIndex,
    Horaire? existingHoraire,
  }) async {
    String selectedFormationId = existingFormationId ?? formations.first.id;
    Formation currentFormation = formations.firstWhere(
      (f) => f.id == selectedFormationId,
      orElse: () => formations.first,
    );
    List<String> trainerModules = _db.getModulesForFormateur(
      currentFormation,
      widget.user.id,
    );
    if (trainerModules.isEmpty && currentFormation.modules.isNotEmpty) {
      trainerModules = currentFormation.modules;
    }
    String? selectedModule =
        existingHoraire?.module ??
        (trainerModules.isNotEmpty ? trainerModules.first : null);
    String selectedDay = existingHoraire?.jour ?? 'Lundi';
    String heureDebut = existingHoraire?.heureDebut ?? '09:00';
    String heureFin = existingHoraire?.heureFin ?? '11:00';
    String modalite = existingHoraire?.modalite ?? 'Présentiel';
    final lieuController = TextEditingController(
      text: existingHoraire?.lieuOuLien ?? 'Salle Principale',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final moduleStudents = _db.getStudentsForFormationModule(
            currentFormation.id,
            selectedModule,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              existingHoraire != null
                  ? 'Modifier le créneau'
                  : 'Ajouter un créneau',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formation Dropdown
                    Text(
                      'Formation *',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormationId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: formations
                          .map(
                            (f) => DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.titre,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: existingHoraire != null
                          ? null
                          : (newId) {
                              if (newId != null) {
                                setModalState(() {
                                  selectedFormationId = newId;
                                  currentFormation = formations.firstWhere(
                                    (f) => f.id == newId,
                                  );
                                  trainerModules = _db.getModulesForFormateur(
                                    currentFormation,
                                    widget.user.id,
                                  );
                                  selectedModule = trainerModules.isNotEmpty
                                      ? trainerModules.first
                                      : null;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),

                    // Module Dropdown
                    Text(
                      'Module assigné (Groupe automatique) *',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedModule,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        if (trainerModules.isEmpty)
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              currentFormation.titre,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ...trainerModules.map(
                          (m) => DropdownMenuItem<String?>(
                            value: m,
                            child: Text(
                              m,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedModule = val),
                    ),
                    const SizedBox(height: 8),

                    // Auto-Group Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Groupe auto : ${moduleStudents.length} apprenant${moduleStudents.length > 1 ? 's' : ''} inscrits',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Day selection
                    Text(
                      'Jour *',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDay,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: _days
                          .where((d) => d != 'Tous')
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Time slots
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heure début *',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: heureDebut,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  hintText: '09:00',
                                ),
                                onChanged: (val) => heureDebut = val.trim(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Heure fin *',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                initialValue: heureFin,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  hintText: '11:00',
                                ),
                                onChanged: (val) => heureFin = val.trim(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Modalite
                    Text(
                      'Modalité & Salle / Lien',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: modalite,
                          items: const [
                            DropdownMenuItem(
                              value: 'Présentiel',
                              child: Text(
                                'Présentiel',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'En ligne',
                              child: Text(
                                'En ligne',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setModalState(() => modalite = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lieuController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              hintText: modalite == 'En ligne'
                                  ? 'Lien Google Meet / Zoom'
                                  : 'Salle ou labo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final newHoraire = Horaire(
                    jour: selectedDay,
                    heureDebut: heureDebut.isEmpty ? '09:00' : heureDebut,
                    heureFin: heureFin.isEmpty ? '11:00' : heureFin,
                    module: selectedModule,
                    groupe: 'Groupe $selectedModule',
                    modalite: modalite,
                    lieuOuLien: lieuController.text.trim().isEmpty
                        ? null
                        : lieuController.text.trim(),
                  );

                  if (existingHoraireIndex != null) {
                    await _db.updateHoraireInFormation(
                      selectedFormationId,
                      existingHoraireIndex,
                      newHoraire,
                    );
                  } else {
                    await _db.addHoraireToFormation(
                      selectedFormationId,
                      newHoraire,
                    );
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existingHoraireIndex != null
                              ? 'Créneau modifié avec succès.'
                              : 'Créneau assigné au groupe avec succès.',
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    setState(() {});
                  }
                },
                child: Text(
                  existingHoraireIndex != null
                      ? 'Enregistrer'
                      : 'Créer le créneau',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteSlot(String formationId, int horaireIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce créneau ?'),
        content: const Text(
          'Ce créneau sera retiré de votre emploi du temps et de celui des apprenants du module.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteHoraireFromFormation(formationId, horaireIndex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Créneau supprimé.'),
            backgroundColor: AppTheme.primary,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _showEmargementDialog(
    String formationId,
    String formationTitle,
    String moduleTitle,
    List<User> students,
  ) async {
    final Map<String, String> attendance = {
      for (final s in students) s.id: 'present',
    };

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final presentCount = attendance.values
              .where((v) => v == 'present')
              .length;
          final absentCount = attendance.values
              .where((v) => v == 'absent')
              .length;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feuille d\'émargement',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$formationTitle • $moduleTitle',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          label: Text(
                            '$presentCount Présents',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.12),
                          side: BorderSide.none,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          avatar: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 16,
                          ),
                          label: Text(
                            '$absentCount Absents',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (students.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Aucun apprenant inscrit dans ce groupe de module.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    else
                      ...students.map((st) {
                        final currentStatus = attendance[st.id] ?? 'present';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      st.nomComplet,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      st.email,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: 'present',
                                    label: Text(
                                      'Présent',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: 'absent',
                                    label: Text(
                                      'Absent',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                                selected: {currentStatus},
                                onSelectionChanged: (newSelection) {
                                  setModalState(() {
                                    attendance[st.id] = newSelection.first;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: students.isEmpty
                    ? null
                    : () async {
                        for (final student in students) {
                          await _db.recordAttendance(
                            userId: student.id,
                            formationId: formationId,
                            status: attendance[student.id] ?? 'present',
                            note: 'Module: $moduleTitle',
                          );
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Feuille d\'émargement enregistrée avec succès.',
                            ),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Valider l\'émargement',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _printAttendanceSheet(
    String formationTitre,
    String moduleName,
    List<User> students,
  ) async {
    try {
      final studentsData = students
          .map(
            (s) => {
              'prenom': s.prenom,
              'nom': s.nom,
              'email': s.email,
              'telephone': s.phone,
            },
          )
          .toList();

      final pdfBytes = await PdfService().generateAttendanceSheetPdf(
        formationTitre: formationTitre,
        moduleTitre: moduleName,
        formateurNom: widget.user.nomComplet,
        apprenants: studentsData,
        dateSeance: DateTime.now(),
      );

      final safeName = '${formationTitre}_$moduleName'.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Emargement_$safeName.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feuille d\'émargement PDF générée avec succès.'),
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

class _FormateurSlotItem {
  final Formation formation;
  final Horaire horaire;
  final int horaireIndex;
  final String moduleTitle;
  final List<User> groupStudents;

  _FormateurSlotItem({
    required this.formation,
    required this.horaire,
    required this.horaireIndex,
    required this.moduleTitle,
    required this.groupStudents,
  });
}
