import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/imagekit_service.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/status_styles.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';

class AdminFormations extends StatefulWidget {
  const AdminFormations({super.key});

  @override
  State<AdminFormations> createState() => _AdminFormationsState();
}

class _AdminFormationsState extends State<AdminFormations>
    with TickerProviderStateMixin {
  final searchController = TextEditingController();
  final LocalDataService _db = LocalDataService();
  String selectedStatus = 'Tous';
  String selectedSort = 'Date création';
  String selectedFormationKind = 'Tous';
  final Set<String> _expandedFormationIds = {};
  late AnimationController _fadeController;

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
    searchController.dispose();
    super.dispose();
  }

  Future<void> _generateBrochurePdf(Formation formation) async {
    try {
      final pdfBytes = await PdfService().generateFormationBrochurePdf(formation);
      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Brochure_${formation.titre.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack('Erreur génération brochure PDF: $e');
    }
  }

  void _toggleFormationExpansion(String formationId) {
    setState(() {
      if (_expandedFormationIds.contains(formationId)) {
        _expandedFormationIds.remove(formationId);
      } else {
        _expandedFormationIds.add(formationId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1100;
    final hp = isMobile ? 10.0 : isTablet ? 14.0 : 20.0;
    final vp = isMobile ? 10.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: vp, horizontal: hp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 28),
          _buildSearchAndFilters(isMobile),
          SizedBox(height: isMobile ? 16 : 28),
          _buildFormationsStream(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: isMobile
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Gérez le catalogue et les sessions de formations',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppTheme.heroShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCreateFormationDialog(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'Créer',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Formations',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérez le catalogue et les sessions de formations',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.heroShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCreateFormationDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Créer',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.softShadow,
          ),
          child: TextField(
            controller: searchController,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Rechercher une formation...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),

        SizedBox(height: 16),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildKindChip('Toutes les formations', 'Tous'),
              const SizedBox(width: 8),
              _buildKindChip('Stage SFP (A la carte)', 'Stage'),
              const SizedBox(width: 8),
              _buildKindChip('Présentiel', 'presentielle'),
              const SizedBox(width: 8),
              _buildKindChip('En Ligne', 'enligne'),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              _buildFilterChip('Tous statuts', 'Tous'),
              const SizedBox(width: 8),
              _buildFilterChip('En Cours', 'En Cours'),
              const SizedBox(width: 8),
              _buildFilterChip('Programmée', 'Programmée'),
              const SizedBox(width: 8),
              _buildFilterChip('Terminée', 'Terminée'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKindChip(String label, String value) {
    final isSelected = selectedFormationKind == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFormationKind = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? AppTheme.primary : Colors.white,
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedStatus == value;
    return GestureDetector(
      onTap: () => setState(() => selectedStatus = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? AppTheme.primaryGradient
              : null,
          color: isSelected ? null : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildFormationsStream(BuildContext context, bool isMobile) {
    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        final formations = snapshot.data ?? [];
        final filtered = _filterFormations(formations);
        final sorted = _sortFormations(filtered);

        if (sorted.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.school_rounded, size: 48, color: Colors.black12),
                  SizedBox(height: 16),
                  Text(
                    'Aucune formation',
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

        return ListView.builder(
          itemCount: sorted.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _buildFormationCardPremium(context, sorted[index], index),
          ),
        );
      },
    );
  }

  Widget _buildFormationCardPremium(
    BuildContext context,
    Formation formation,
    int index,
  ) {
    final formationId = formation.id;
    final isExpanded = _expandedFormationIds.contains(formationId);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SlideInUp(
      delay: Duration(milliseconds: 30 + (index * 30)),
      duration: const Duration(milliseconds: 380),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _toggleFormationExpansion(formationId),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Thumbnail
                        formation.imageUrl != null && formation.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  formation.imageUrl!,
                                  width: isMobile ? 54 : 64,
                                  height: isMobile ? 54 : 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: isMobile ? 54 : 64,
                                    height: isMobile ? 54 : 64,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.school_rounded, color: Colors.grey.shade500, size: 24),
                                  ),
                                ),
                              )
                            : Container(
                                width: isMobile ? 54 : 64,
                                height: isMobile ? 54 : 64,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.school_rounded, color: AppTheme.primary, size: 26),
                              ),
                        const SizedBox(width: 12),
                        // Title and Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formation.titre,
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (formation.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  formation.description,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                  maxLines: isMobile ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Action menu
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                          onSelected: (value) {
                            if (value == 'modifier') {
                              _showEditFormationDialog(context, formation);
                            } else if (value == 'supprimer') {
                              _confirmDeleteFormation(context, formation);
                            } else if (value == 'partager') {
                              _showFormationQrDialog(context, formation);
                            } else if (value == 'brochure_pdf') {
                              _generateBrochurePdf(formation);
                            } else if (value == 'voir') {
                              _toggleFormationExpansion(formationId);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'voir',
                              child: Text(isExpanded ? 'Cacher détails' : 'Voir détails'),
                            ),
                            const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                            const PopupMenuItem(value: 'partager', child: Text('Partager')),
                            const PopupMenuItem(
                              value: 'brochure_pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFFE60000)),
                                  SizedBox(width: 8),
                                  Text('Brochure PDF'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'supprimer',
                              child: Text('Supprimer', style: TextStyle(color: AppTheme.error)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Price and Tag Badges Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (formation.type == FormationType.mixte && formation.prixEnLigne != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Text(
                              'En ligne : ${AppFormat.fcfaShort(formation.prixEnLigne!)}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              'Présentiel : ${AppFormat.fcfaShort(formation.prix)}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ] else if (formation.type == FormationType.enligne) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Text(
                              'En ligne : ${AppFormat.fcfaShort(formation.prixEnLigne ?? formation.prix)}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              'Présentiel : ${AppFormat.fcfaShort(formation.prix)}',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                        if (formation.estStage)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFED7AA)),
                            ),
                            child: Text(
                              'Stage SFP',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFC2410C)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInfoRowCompact(
                                'Type',
                                formation.type.label,
                              ),
                              _buildInfoRowCompact(
                                'Statut',
                                formation.status.label,
                              ),
                              _buildInfoRowCompact(
                                'Durée',
                                '${formation.dureeSemaines} sem.',
                              ),
                              _buildInfoRowCompact(
                                'Places',
                                '${formation.nombreInscrits ?? 0}/${formation.capaciteMax ?? 0}',
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (formation.dateDebut != null)
                                _buildInfoRowCompact(
                                  'Début',
                                  AppFormat.date(formation.dateDebut!),
                                ),
                              if (formation.dateFin != null)
                                _buildInfoRowCompact(
                                  'Fin',
                                  AppFormat.date(formation.dateFin!),
                                ),
                              if (formation.dureeHeures != null &&
                                  formation.dureeHeures!.isNotEmpty)
                                _buildInfoRowCompact(
                                  'Heures',
                                  formation.dureeHeures!,
                                ),
                            ],
                          ),
                          if (formation.modules.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Modules',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              formation.modules.join(' • '),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (formation.moduleFormateurIds.isNotEmpty) ...[
                            SizedBox(height: 8),
                            Text(
                              formation.moduleFormateurIds.entries
                                  .map((entry) => '${entry.key} → ${entry.value}')
                                  .join('\n'),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (formation.modulesBonus.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Modules bonus',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              formation.modulesBonus.join(' • '),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (formation.formateurIds.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Formateurs',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              formation.formateurIds.join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (formation.horaires.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Horaires',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              formation.horaires
                                  .map(
                                    (h) =>
                                        '${h.jour}: ${h.heureDebut}-${h.heureFin}',
                                  )
                                  .join('\n'),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowCompact(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<Formation> _filterFormations(List<Formation> formations) {
    final query = searchController.text.trim().toLowerCase();
    return formations.where((formation) {
      final formationStatus = formation.status.label;
      final matchesStatus =
          selectedStatus == 'Tous' || formationStatus == selectedStatus;
      final matchesType = selectedFormationKind == 'Tous' ||
          (selectedFormationKind == 'Stage'
              ? formation.estStage
              : (selectedFormationKind == 'presentielle'
                  ? formation.type == FormationType.presentielle
                  : (selectedFormationKind == 'enligne'
                      ? formation.type == FormationType.enligne
                      : !formation.estStage)));
      final matchesSearch =
          query.isEmpty ||
          formation.titre.toLowerCase().contains(query) ||
          formation.description.toLowerCase().contains(query) ||
          formation.modules.any((module) => module.toLowerCase().contains(query));
      return matchesStatus && matchesType && matchesSearch;
    }).toList();
  }

  List<Formation> _sortFormations(List<Formation> formations) {
    final sorted = [...formations];
    switch (selectedSort) {
      case 'Prix':
        sorted.sort((a, b) => a.prix.compareTo(b.prix));
        break;
      case 'Titre':
        sorted.sort((a, b) => a.titre.compareTo(b.titre));
        break;
      default:
        sorted.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    }
    return sorted;
  }

  Future<void> _showFormationQrDialog(
    BuildContext context,
    Formation formation,
  ) async {
    await ShareFormationDialog.show(context, formation);
  }

  Map<String, double> _parseModulePrices(String rawPrices) {
    final prices = <String, double>{};
    for (final entry in rawPrices.split(';')) {
      final parts = entry.split('=');
      if (parts.length != 2) continue;
      final module = parts.first.trim();
      final price = double.tryParse(parts.last.trim());
      if (module.isNotEmpty && price != null && price >= 0) {
        prices[module] = price;
      }
    }
    return prices;
  }

  Map<String, String> _parseModuleFormateurIds(String rawAssignments) {
    final assignments = <String, String>{};
    for (final entry in rawAssignments.split(';')) {
      final parts = entry.split('=');
      if (parts.length != 2) continue;
      final module = parts[0].trim();
      final formateurId = parts[1].trim();
      if (module.isNotEmpty && formateurId.isNotEmpty) {
        assignments[module] = formateurId;
      }
    }
    return assignments;
  }

  String? _validateModuleFormateurIds(
    Map<String, String> assignments,
    List<String> modules,
  ) {
    for (final entry in assignments.entries) {
      if (!modules.contains(entry.key)) {
        return 'Le module « ${entry.key} » n’existe pas dans cette formation.';
      }
      final formateur = _db.getUserById(entry.value);
      if (formateur == null || formateur.role != UserRole.formateur) {
        return 'Le formateur « ${entry.value} » est introuvable ou n’a pas le rôle Formateur.';
      }
    }
    return null;
  }

  void _showCreateFormationDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titreController = TextEditingController();
    final descriptionController = TextEditingController();
    final modulesController = TextEditingController();
    final modulesBonusController = TextEditingController();
    final modulePricesController = TextEditingController();
    final moduleFormateursController = TextEditingController();
    
    final imageUrlController = TextEditingController();
    final formateursController = TextEditingController();
    final prixController = TextEditingController();
    final prixEnLigneController = TextEditingController();
    final dureeController = TextEditingController();
    final heuresController = TextEditingController();
    final horairesController = TextEditingController();
    final dateDebutController = TextEditingController();
    final dateFinController = TextEditingController();
    final capaciteController = TextEditingController();
    final maxModulesController = TextEditingController();
    String typeValue = 'En ligne';
    String statusValue = 'Programmée';
    bool isStage = false;
    String? uploadedImageUrl;
    bool isUploading = false;
    ImageFormat? imageFormatValue;

    showDialog(
      context: context,
      builder: (context) => SizedBox(
        width: 600,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Créer une formation',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormField(
                      titreController,
                      'Titre',
                      'Titre requis',
                      Icons.title_rounded,
                    ),
                    _buildFormField(
                      descriptionController,
                      'Description',
                      'Description requise',
                      Icons.description_rounded,
                      maxLines: 3,
                    ),
                    _buildFormField(
                      modulesController,
                      'Modules (séparés par des virgules)',
                      null,
                      Icons.book_rounded,
                      helperText: 'Exemple : HTML, CSS, Flutter',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      modulesBonusController,
                      'Modules Bonus Offerts (optionnels, séparés par virgules)',
                      null,
                      Icons.card_giftcard_rounded,
                      helperText: 'Exemple : Initiation PowerPoint + IA, Support Rédaction',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      modulePricesController,
                      'Prix par module (Module=prix, séparés par ;)',
                      null,
                      Icons.payments_rounded,
                      helperText: 'Exemple : HTML=25000; React=50000',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      moduleFormateursController,
                      'Responsable de chaque module (Module=ID formateur ; …)',
                      null,
                      Icons.person_pin_rounded,
                      helperText: 'Exemple : HTML=formateur_1; Flutter=formateur_2',
                      maxLines: 2,
                    ),
                    // Image picker avec upload ImageKit
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Image',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (uploadedImageUrl != null &&
                              uploadedImageUrl!.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    uploadedImageUrl!,
                                    fit: BoxFit.cover,
                                    height: 150,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 150,
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          uploadedImageUrl = null;
                                          imageUrlController.clear();
                                        });
                                      },
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: Text(
                                        'Supprimer',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                      final localContext = context;
                                      setState(() {
                                        isUploading = true;
                                      });
                                      try {
                                        final imageKitService =
                                            ImageKitService();
                                        final url = await imageKitService
                                            .pickAndUploadImage();
                                        if (!mounted) return;
                                        if (url != null) {
                                          setState(() {
                                            uploadedImageUrl = url;
                                            imageUrlController.text = url;
                                          });
                                        }
                                      } catch (e) {
                                        if (!localContext.mounted) return;
                                        ScaffoldMessenger.of(
                                          localContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Erreur: ${e.toString()}',
                                            ),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            isUploading = false;
                                          });
                                        }
                                      }
                                    },
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUploading
                                        ? Colors.grey.shade300
                                        : AppTheme.primary,
                                    style: BorderStyle.solid,
                                  ),
                                  color: isUploading
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                ),
                                child: isUploading
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    AppTheme.primary,
                                                  ),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Upload en cours...',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: AppTheme.primary,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Cliquer pour ajouter une image',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildFormField(
                      imageUrlController,
                      'URL de l\'image (optionnel)',
                      null,
                      Icons.link_rounded,
                      helperText: 'Coller un lien (http...) ou utiliser le sélecteur ci-dessus',
                      onChanged: (val) {
                        setState(() {
                          uploadedImageUrl = val.trim().isEmpty ? null : val.trim();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<ImageFormat>(
                      initialValue: imageFormatValue,
                      decoration: InputDecoration(
                        labelText: 'Format de l\'image',
                        prefixIcon: Icon(Icons.crop),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ImageFormat.carre,
                          child: Text('Carré (1:1)'),
                        ),
                        DropdownMenuItem(
                          value: ImageFormat.vertical,
                          child: Text('Vertical (9:16)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => imageFormatValue = value);
                      },
                    ),
                    _buildFormField(
                      formateursController,
                      'Formateurs (IDs)',
                      null,
                      Icons.school_rounded,
                    ),
                    _buildFormField(
                      prixController,
                      'Prix',
                      null,
                      Icons.attach_money_rounded,
                      isNumber: true,
                    ),
                    if (typeValue == 'En ligne' || typeValue == 'Mixte')
                      _buildFormField(
                        prixEnLigneController,
                        'Prix en ligne',
                        null,
                        Icons.computer_rounded,
                        isNumber: true,
                      ),
                    _buildFormField(
                      dureeController,
                      'Durée (semaines)',
                      null,
                      Icons.schedule_rounded,
                      isNumber: true,
                    ),
                    _buildFormField(
                      heuresController,
                      'Heures',
                      null,
                      Icons.timer_rounded,
                    ),
                    _buildFormField(
                      horairesController,
                      'Horaires',
                      null,
                      Icons.access_time_rounded,
                      maxLines: 3,
                    ),
                    _buildFormField(
                      dateDebutController,
                      'Début (JJ/MM/AAAA)',
                      null,
                      Icons.calendar_today_rounded,
                    ),
                    _buildFormField(
                      dateFinController,
                      'Fin (JJ/MM/AAAA)',
                      null,
                      Icons.calendar_today_rounded,
                    ),
                    _buildFormField(
                      capaciteController,
                      'Places max',
                      null,
                      Icons.people_rounded,
                      isNumber: true,
                    ),
                    if (isStage)
                      Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: _buildFormField(
                          maxModulesController,
                          'Nbr max de modules par étudiant (SFP)',
                          null,
                          Icons.view_module_rounded,
                          isNumber: true,
                        ),
                      ),
                    SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'C’est un stage',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      value: isStage,
                      onChanged: (value) =>
                          setState(() => isStage = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.primary,
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['En ligne', 'Présentielle', 'Mixte'].contains(typeValue) ? typeValue : 'En ligne',
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.computer_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['En ligne', 'Présentielle', 'Mixte']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => typeValue = value);
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['Programmée', 'En Cours', 'Terminée'].contains(statusValue) ? statusValue : 'Programmée',
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: Icon(Icons.info_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['Programmée', 'En Cours', 'Terminée']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => statusValue = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: isUploading ? null : AppTheme.heroGradient,
                  color: isUploading ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isUploading ? null : AppTheme.heroShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isUploading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final modules = modulesController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty)
                                .toList();
                            final modulesBonus = modulesBonusController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty)
                                .toList();
                            final modulePrices = _parseModulePrices(modulePricesController.text);
                            final moduleFormateurIds = _parseModuleFormateurIds(
                              moduleFormateursController.text,
                            );
                            final assignmentError = _validateModuleFormateurIds(
                              moduleFormateurIds,
                              modules,
                            );
                            if (assignmentError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(assignmentError)),
                              );
                              return;
                            }
                            final formateurIds = {
                              ...formateursController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty),
                              ...moduleFormateurIds.values,
                            }.toList();
                            final prix =
                                double.tryParse(prixController.text.trim()) ?? 0.0;
                            final prixEnLigne = prixEnLigneController.text.trim().isEmpty
                                ? null
                                : double.tryParse(prixEnLigneController.text.trim());
                            final dureeSemaines =
                                int.tryParse(dureeController.text.trim()) ?? 0;
                            final capaciteMax = int.tryParse(
                              capaciteController.text.trim(),
                            );
                            final maxModulesParEtudiant = isStage
                                ? int.tryParse(maxModulesController.text.trim())
                                : null;
                            final dateDebut = dateDebutController.text.trim().isEmpty
                                ? null
                                : AppFormat.parseFrenchOrIsoDate(dateDebutController.text.trim());
                            final dateFin = dateFinController.text.trim().isEmpty
                                ? null
                                : AppFormat.parseFrenchOrIsoDate(dateFinController.text.trim());
                            final horaires = _parseHoraires(
                              horairesController.text.trim(),
                            );

                            final newFormation = Formation(
                              id: '',
                              titre: titreController.text.trim(),
                              description: descriptionController.text.trim(),
                              modules: modules,
                              modulesBonus: modulesBonus,
                              modulePrices: modulePrices,
                              moduleFormateurIds: moduleFormateurIds,
                              imageUrl: imageUrlController.text.trim().isEmpty
                                  ? null
                                  : imageUrlController.text.trim(),
                              imageFormat: imageFormatValue,
                              formateurIds: formateurIds,
                              prix: prix,
                              prixEnLigne: prixEnLigne,
                              type: typeValue == 'Présentielle'
                                  ? FormationType.presentielle
                                  : typeValue == 'Mixte'
                                  ? FormationType.mixte
                                  : FormationType.enligne,
                              status: statusValue == 'En Cours'
                                  ? FormationStatus.enCours
                                  : statusValue == 'Terminée'
                                  ? FormationStatus.terminee
                                  : FormationStatus.programmee,
                              dureeSemaines: dureeSemaines,
                              dureeHeures: heuresController.text.trim().isEmpty
                                  ? null
                                  : heuresController.text.trim(),
                              horaires: horaires,
                              dateDebut: dateDebut,
                              dateFin: dateFin,
                              dateCreation: DateTime.now(),
                              capaciteMax: capaciteMax,
                              nombreInscrits: 0,
                              estStage: isStage,
                              maxModulesParEtudiant: maxModulesParEtudiant,
                            );

                            setState(() => isUploading = true);
                            final localContext = context;
                            try {
                              await _db.addFormation(newFormation);
                              if (!localContext.mounted) return;
                              Navigator.pop(localContext);
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Formation créée avec succès'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            } catch (e) {
                              if (!localContext.mounted) return;
                              setState(() => isUploading = false);
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        isUploading ? 'Création...' : 'Créer',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    TextEditingController controller,
    String label,
    String? validator,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
    String? helperText,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: GoogleFonts.poppins(fontSize: 13),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: validator != null
            ? (value) => value?.trim().isEmpty == true ? validator : null
            : null,
      ),
    );
  }

  void _showEditFormationDialog(BuildContext context, Formation formation) {
    final titreController = TextEditingController(text: formation.titre);
    final descriptionController = TextEditingController(
      text: formation.description,
    );
    final modulesController = TextEditingController(
      text: formation.modules.join(', '),
    );
    final modulesBonusController = TextEditingController(
      text: formation.modulesBonus.join(', '),
    );
    final modulePricesController = TextEditingController(
      text: formation.modulePrices.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
    );
    final moduleFormateursController = TextEditingController(
      text: formation.moduleFormateurIds.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; '),
    );
    
    final imageUrlController = TextEditingController(
      text: formation.imageUrl ?? '',
    );
    final formateursController = TextEditingController(
      text: formation.formateurIds.join(', '),
    );
    final prixController = TextEditingController(
      text: formation.prix.toString(),
    );
    final prixEnLigneController = TextEditingController(
      text: formation.prixEnLigne?.toString() ?? '',
    );
    final dureeController = TextEditingController(
      text: formation.dureeSemaines.toString(),
    );
    final heuresController = TextEditingController(
      text: formation.dureeHeures ?? '',
    );
    final horairesController = TextEditingController(
      text: formation.horaires
          .map((h) => '${h.jour};${h.heureDebut};${h.heureFin}')
          .join('\n'),
    );
    final dateDebutController = TextEditingController(
      text: formation.dateDebut != null
          ? AppFormat.date(formation.dateDebut!)
          : '',
    );
    final dateFinController = TextEditingController(
      text: formation.dateFin != null ? AppFormat.date(formation.dateFin!) : '',
    );
    final capaciteController = TextEditingController(
      text: formation.capaciteMax?.toString() ?? '',
    );
    final maxModulesController = TextEditingController(
      text: formation.maxModulesParEtudiant?.toString() ?? '',
    );
    String typeValue = formation.type.label;
    String statusValue = formation.status.label;
    bool isStage = formation.estStage;
    final formKey = GlobalKey<FormState>();
    String? uploadedImageUrl = formation.imageUrl;
    bool isUploading = false;
    ImageFormat? imageFormatValue = formation.imageFormat;

    showDialog(
      context: context,
      builder: (context) => SizedBox(
        width: 600,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Modifier la formation',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormField(
                      titreController,
                      'Titre',
                      'Titre requis',
                      Icons.title_rounded,
                    ),
                    _buildFormField(
                      descriptionController,
                      'Description',
                      'Description requise',
                      Icons.description_rounded,
                      maxLines: 3,
                    ),
                    _buildFormField(
                      modulesController,
                      'Modules (séparés par des virgules)',
                      null,
                      Icons.book_rounded,
                      helperText: 'Exemple : HTML, CSS, Flutter',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      modulesBonusController,
                      'Modules Bonus Offerts (optionnels, séparés par virgules)',
                      null,
                      Icons.card_giftcard_rounded,
                      helperText: 'Exemple : Initiation PowerPoint + IA, Support Rédaction',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      modulePricesController,
                      'Prix par module (Module=prix, séparés par ;)',
                      null,
                      Icons.payments_rounded,
                      helperText: 'Exemple : HTML=25000; React=50000',
                      maxLines: 2,
                    ),
                    _buildFormField(
                      moduleFormateursController,
                      'Responsable de chaque module (Module=ID formateur ; …)',
                      null,
                      Icons.person_pin_rounded,
                      helperText: 'Exemple : HTML=formateur_1; Flutter=formateur_2',
                      maxLines: 2,
                    ),
                    // Image picker avec upload ImageKit
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Image',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (uploadedImageUrl != null &&
                              uploadedImageUrl!.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    uploadedImageUrl!,
                                    fit: BoxFit.cover,
                                    height: 150,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 150,
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          uploadedImageUrl = null;
                                          imageUrlController.clear();
                                        });
                                      },
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: Text(
                                        'Supprimer',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                    final localContext = context;
                                      setState(() {
                                        isUploading = true;
                                      });
                                      try {
                                        final imageKitService =
                                            ImageKitService();
                                        final url = await imageKitService
                                            .pickAndUploadImage();
                                        if (url != null) {
                                          setState(() {
                                            uploadedImageUrl = url;
                                            imageUrlController.text = url;
                                          });
                                        }
                                      } catch (e) {
                                        if (!localContext.mounted) return;
                                        ScaffoldMessenger.of(
                                          localContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Erreur: ${e.toString()}',
                                            ),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                      } finally {
                                        setState(() {
                                          isUploading = false;
                                        });
                                      }
                                    },
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUploading
                                        ? Colors.grey.shade300
                                        : AppTheme.primary,
                                    style: BorderStyle.solid,
                                  ),
                                  color: isUploading
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                ),
                                child: isUploading
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    AppTheme.primary,
                                                  ),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Upload en cours...',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: AppTheme.primary,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Cliquer pour ajouter une image',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildFormField(
                      imageUrlController,
                      'URL de l\'image (optionnel)',
                      null,
                      Icons.link_rounded,
                      helperText: 'Coller un lien (http...) ou utiliser le sélecteur ci-dessus',
                      onChanged: (val) {
                        setState(() {
                          uploadedImageUrl = val.trim().isEmpty ? null : val.trim();
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<ImageFormat>(
                      initialValue: imageFormatValue,
                      decoration: InputDecoration(
                        labelText: 'Format de l\'image',
                        prefixIcon: Icon(Icons.crop),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ImageFormat.carre,
                          child: Text('Carré (1:1)'),
                        ),
                        DropdownMenuItem(
                          value: ImageFormat.vertical,
                          child: Text('Vertical (9:16)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => imageFormatValue = value);
                      },
                    ),
                    _buildFormField(
                      formateursController,
                      'Formateurs (IDs)',
                      null,
                      Icons.school_rounded,
                    ),
                    _buildFormField(
                      prixController,
                      'Prix',
                      null,
                      Icons.attach_money_rounded,
                      isNumber: true,
                    ),
                    if (typeValue == 'En ligne' || typeValue == 'Mixte')
                      _buildFormField(
                        prixEnLigneController,
                        'Prix en ligne',
                        null,
                        Icons.computer_rounded,
                        isNumber: true,
                      ),
                    _buildFormField(
                      dureeController,
                      'Durée (semaines)',
                      null,
                      Icons.schedule_rounded,
                      isNumber: true,
                    ),
                    _buildFormField(
                      heuresController,
                      'Heures',
                      null,
                      Icons.timer_rounded,
                    ),
                    _buildFormField(
                      horairesController,
                      'Horaires',
                      null,
                      Icons.access_time_rounded,
                      maxLines: 3,
                    ),
                    _buildFormField(
                      dateDebutController,
                      'Début (JJ/MM/AAAA)',
                      null,
                      Icons.calendar_today_rounded,
                    ),
                    _buildFormField(
                      dateFinController,
                      'Fin (JJ/MM/AAAA)',
                      null,
                      Icons.calendar_today_rounded,
                    ),
                    _buildFormField(
                      capaciteController,
                      'Places max',
                      null,
                      Icons.people_rounded,
                      isNumber: true,
                    ),
                    if (isStage)
                      Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: _buildFormField(
                          maxModulesController,
                          'Nbr max de modules par étudiant (SFP)',
                          null,
                          Icons.view_module_rounded,
                          isNumber: true,
                        ),
                      ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['En ligne', 'Présentielle', 'Mixte'].contains(typeValue) ? typeValue : 'En ligne',
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.computer_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['En ligne', 'Présentielle', 'Mixte']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => typeValue = value);
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['Programmée', 'En Cours', 'Terminée'].contains(statusValue) ? statusValue : 'Programmée',
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: Icon(Icons.info_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['Programmée', 'En Cours', 'Terminée']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => statusValue = value);
                      },
                    ),
                    SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'C’est un stage',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      value: isStage,
                      onChanged: (value) =>
                          setState(() => isStage = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: isUploading ? null : AppTheme.heroGradient,
                  color: isUploading ? Colors.grey.shade400 : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isUploading ? null : AppTheme.heroShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isUploading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            final modules = modulesController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty)
                                .toList();
                            final modulesBonus = modulesBonusController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty)
                                .toList();
                            final modulePrices = _parseModulePrices(modulePricesController.text);
                            final moduleFormateurIds = _parseModuleFormateurIds(
                              moduleFormateursController.text,
                            );
                            final assignmentError = _validateModuleFormateurIds(
                              moduleFormateurIds,
                              modules,
                            );
                            if (assignmentError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(assignmentError)),
                              );
                              return;
                            }
                            final formateurIds = {
                              ...formateursController.text
                                .split(',')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty),
                              ...moduleFormateurIds.values,
                            }.toList();
                            final prix =
                                double.tryParse(prixController.text.trim()) ?? 0.0;
                            final prixEnLigne = prixEnLigneController.text.trim().isEmpty
                                ? null
                                : double.tryParse(prixEnLigneController.text.trim());
                            final dureeSemaines =
                                int.tryParse(dureeController.text.trim()) ?? 0;
                            final capaciteMax = int.tryParse(
                              capaciteController.text.trim(),
                            );
                            final maxModulesParEtudiant = isStage
                                ? int.tryParse(maxModulesController.text.trim())
                                : null;
                            final dateDebut = dateDebutController.text.trim().isEmpty
                                ? null
                                : AppFormat.parseFrenchOrIsoDate(dateDebutController.text.trim());
                            final dateFin = dateFinController.text.trim().isEmpty
                                ? null
                                : AppFormat.parseFrenchOrIsoDate(dateFinController.text.trim());
                            final horaires = _parseHoraires(
                              horairesController.text.trim(),
                            );

                            final updatedFormation = Formation(
                              id: formation.id,
                              titre: titreController.text.trim(),
                              description: descriptionController.text.trim(),
                              modules: modules,
                              modulesBonus: modulesBonus,
                              modulePrices: modulePrices,
                              moduleFormateurIds: moduleFormateurIds,
                              imageUrl: imageUrlController.text.trim().isEmpty
                                  ? null
                                  : imageUrlController.text.trim(),
                              imageFormat: imageFormatValue,
                              formateurIds: formateurIds,
                              prix: prix,
                              prixEnLigne: prixEnLigne,
                              type: typeValue == 'Présentielle'
                                  ? FormationType.presentielle
                                  : typeValue == 'Mixte'
                                  ? FormationType.mixte
                                  : FormationType.enligne,
                              status: statusValue == 'En Cours'
                                  ? FormationStatus.enCours
                                  : statusValue == 'Terminée'
                                  ? FormationStatus.terminee
                                  : FormationStatus.programmee,
                              dureeSemaines: dureeSemaines,
                              dureeHeures: heuresController.text.trim().isEmpty
                                  ? null
                                  : heuresController.text.trim(),
                              horaires: horaires,
                              dateDebut: dateDebut,
                              dateFin: dateFin,
                              dateCreation: formation.dateCreation,
                              capaciteMax: capaciteMax,
                              nombreInscrits: formation.nombreInscrits,
                              estStage: isStage,
                              maxModulesParEtudiant: maxModulesParEtudiant,
                            );

                            setState(() => isUploading = true);
                            final localContext = context;
                            try {
                              await _db.updateFormation(updatedFormation);
                              if (!localContext.mounted) return;
                              Navigator.pop(localContext);
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Formation mise à jour avec succès'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            } catch (e) {
                              if (!localContext.mounted) return;
                              setState(() => isUploading = false);
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: ${e.toString()}'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        isUploading ? 'Enregistrement...' : 'Enregistrer',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFormation(
    BuildContext context,
    Formation formation,
  ) async {
    final localContext = context;
    final confirmed = await showDialog<bool>(
      context: localContext,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer la formation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${formation.titre}" ?',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, true),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Supprimer',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteFormation(formation.id);
      if (!localContext.mounted) return;
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          content: Text('Formation supprimée'),
          backgroundColor: AppTheme.error,
        ),
      );
    } catch (e) {
      if (!localContext.mounted) return;
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  List<Horaire> _parseHoraires(String rawHoraires) {
    if (rawHoraires.trim().isEmpty) return [];
    final lines = rawHoraires.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return lines.map((line) {
      final parts = line.split(RegExp(r'[;,]')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 3) {
        return Horaire(
          jour: parts[0],
          heureDebut: parts[1],
          heureFin: parts[2],
        );
      } else if (parts.length == 2) {
        return Horaire(
          jour: parts[0],
          heureDebut: parts[1],
          heureFin: 'Fin de cours',
        );
      }
      return Horaire(
        jour: line,
        heureDebut: '09h00',
        heureFin: '17h00',
      );
    }).toList();
  }
}
