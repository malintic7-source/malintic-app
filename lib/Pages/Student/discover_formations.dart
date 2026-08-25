import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';

class DiscoverFormationsPage extends StatefulWidget {
  final User user;

  const DiscoverFormationsPage({super.key, required this.user});

  @override
  State<DiscoverFormationsPage> createState() => _DiscoverFormationsPageState();
}

class _DiscoverFormationsPageState extends State<DiscoverFormationsPage> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  late GlobalKey qrKey;
  final searchController = TextEditingController();
  String filterType = 'Tous';
  int sortBy = 0;
  final Set<String> _expandedFormationIds = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    qrKey = GlobalKey();
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
  void dispose() {
    _fadeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 1200 ? 1100.0 : width * 0.95;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Découvrir',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.primary),
            tooltip: 'Fermer',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _contactAssistance,
        backgroundColor: AppTheme.primary,
        elevation: 8,
        child: Icon(Icons.support_agent_rounded, color: Colors.white),
      ),
      body: Center(
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
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildFilters(),
                  const SizedBox(height: 24),
                  _buildFormationsList(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorez nos formations',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Trouvez la formation qui vous correspond',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher une formation...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black38,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tous'),
          SizedBox(width: 8),
          _buildFilterChip('En ligne'),
          SizedBox(width: 8),
          _buildFilterChip('Présentielle'),
          SizedBox(width: 8),
          _buildFilterChip('Stage'),
          SizedBox(width: 16),
          Container(height: 32, width: 1, color: Colors.black12),
          SizedBox(width: 16),
          PopupMenuButton(
            onSelected: (value) => setState(() => sortBy = value),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Text('Récent')),
              PopupMenuItem(value: 1, child: Text('Prix ↑')),
              PopupMenuItem(value: 2, child: Text('Prix ↓')),
            ],
            icon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.sort_rounded, color: AppTheme.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = filterType == label;
    return GestureDetector(
      onTap: () => setState(() => filterType = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppTheme.primary : Colors.black).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildFormationsList(BuildContext context) {
    return FutureBuilder<List<Formation>>(
      future: _getFilteredAndSortedFormations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.school_rounded, size: 48, color: Colors.black12),
                SizedBox(height: 16),
                Text(
                  'Aucune formation trouvée',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => _buildFormationCard(context, snapshot.data![index], index),
        );
      },
    );
  }

  Widget _buildFormationCard(BuildContext context, Formation formation, int index) {
    final formationId = formation.id;
    final isExpanded = _expandedFormationIds.contains(formationId);

    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: Duration(milliseconds: 500),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.white,
              child: Column(
                children: [
                  // ListTile with Material ancestor to show ink splash
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onTap: () => _toggleFormationExpansion(formationId),
                    leading: formation.imageUrl != null && formation.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              formation.imageUrl!,
                              width: formation.imageFormat == ImageFormat.carre ? 54 : 40,
                              height: formation.imageFormat == ImageFormat.carre ? 54 : 71,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                width: formation.imageFormat == ImageFormat.carre ? 54 : 40,
                                height: formation.imageFormat == ImageFormat.carre ? 54 : 71,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        : Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.school_rounded, color: Colors.grey.shade600),
                          ),
                    title: Text(
                      formation.titre,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      formation.description,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (formation.type == FormationType.mixte && formation.prixEnLigne != null) ...[
                              Text(
                                'En ligne: ${AppFormat.fcfaShort(formation.prixEnLigne!)}',
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              Text(
                                'Présentiel: ${AppFormat.fcfaShort(formation.prix)}',
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ] else if (formation.type == FormationType.enligne) ...[
                              Text(
                                'En ligne: ${AppFormat.fcfaShort(formation.prixEnLigne ?? formation.prix)}',
                                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                            ] else ...[
                              Text(
                                'Présentiel: ${AppFormat.fcfaShort(formation.prix)}',
                                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black87),
                              ),
                            ],
                            SizedBox(height: 2),
                            Icon(
                              isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Partager la formation',
                          onPressed: () => _showFormationQrDialog(context, formation),
                          icon: Icon(Icons.share_rounded, size: 18, color: Colors.black54),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'details') {
                              _toggleFormationExpansion(formationId);
                            } else if (value == 'partager') {
                              _showFormationQrDialog(context, formation);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'details',
                              child: Text(isExpanded ? 'Cacher détails' : 'Voir détails'),
                            ),
                            PopupMenuItem(
                              value: 'partager',
                              child: Text('Partager'),
                            ),
                          ],
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: isExpanded
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildInfoTag(
                                      formation.type.toString().split('.').last == 'enligne' ? 'En ligne' : 'Présentielle',
                                      Icons.language_rounded,
                                      Color(0xFF3B82F6),
                                    ),
                                    _buildInfoTag(
                                      '${formation.dureeSemaines} sem',
                                      Icons.schedule_rounded,
                                      Color(0xFFA78BFA),
                                    ),
                                    if (formation.type == FormationType.mixte && formation.prixEnLigne != null) ...[
                                      _buildInfoTag(
                                        'En ligne: ${formation.prixEnLigne} F CFA',
                                        Icons.computer_rounded,
                                        Color(0xFF10B981),
                                      ),
                                      _buildInfoTag(
                                        'Présentielle: ${formation.prix} F CFA',
                                        Icons.location_on_rounded,
                                        Color(0xFF10B981),
                                      ),
                                    ] else if (formation.type == FormationType.enligne) ...[
                                      _buildInfoTag(
                                        'En ligne: ${(formation.prixEnLigne ?? formation.prix)} F CFA',
                                        Icons.attach_money_rounded,
                                        Color(0xFF10B981),
                                      ),
                                    ] else ...[
                                      _buildInfoTag(
                                        'Présentielle: ${formation.prix} F CFA',
                                        Icons.attach_money_rounded,
                                        Color(0xFF10B981),
                                      ),
                                    ],
                                    _buildInfoTag(
                                      '${formation.modules.length} modules',
                                      Icons.library_books_rounded,
                                      Color(0xFFEF4444),
                                    ),
                                  ],
                                ),
                                if (formation.modules.isNotEmpty) ...[
                                  SizedBox(height: 10),
                                  Text(
                                    'Modules',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formation.modules.join(' • '),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                                if (formation.modulesBonus.isNotEmpty) ...[
                                  SizedBox(height: 10),
                                  Text(
                                    'Modules bonus',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formation.modulesBonus.join(' • '),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                                if (formation.horaires.isNotEmpty) ...[
                                  SizedBox(height: 10),
                                  Text(
                                    'Horaires',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    formation.horaires.map((h) => '${h.jour}: ${h.heureDebut}-${h.heureFin}').join('\n'),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                                SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showEnrollDialog(context, formation),
                                    icon: Icon(Icons.app_registration_rounded, size: 16),
                                    label: Text("S'inscrire"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showFormationQrDialog(BuildContext context, Formation formation) async {
    await ShareFormationDialog.show(context, formation);
  }

  Future<void> _showEnrollDialog(BuildContext context, Formation formation) async {
    final status = await _checkEnrollmentStatus(formation.id);
    if (!context.mounted) return;

    if (status['isEnrolled']) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Inscription',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_rounded, size: 48, color: Color(0xFFEF4444)),
              SizedBox(height: 16),
              Text(
                'Vous êtes déjà inscrit à cette formation',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'État: ${status['enrollmentState']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
    } else {
      if (!context.mounted) return;
      _showEnrollmentForm(context, formation);
    }
  }

  Future<Map<String, dynamic>> _checkEnrollmentStatus(String formationId) async {
    final inscriptions = _db.getInscriptions().where(
      (ins) => ins.etudiantId == widget.user.id && ins.formationId == formationId
    ).toList();

    if (inscriptions.isEmpty) {
      return {'isEnrolled': false};
    }

    return {
      'isEnrolled': true,
      'enrollmentState': inscriptions.first.status,
    };
  }

  void _showEnrollmentForm(BuildContext context, Formation formation) {
    final selectedModules = <String>{};
    final descriptionController = TextEditingController();
    bool acceptConditions = false;
    bool bonusApplied = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'S\'inscrire à la formation',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Student Info (read-only)
                _buildFormSection(
                  'Vos informations',
                  [
                    _buildReadOnlyField('Email', widget.user.email),
                    _buildReadOnlyField('Prénom', widget.user.prenom),
                    _buildReadOnlyField('Nom', widget.user.nom),
                    _buildReadOnlyField('Téléphone', widget.user.phone),
                  ],
                ),
                SizedBox(height: 16),
                // Description
                Text(
                  'Parlez de vous',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Vos ambitions, motivations, niveau d\'étude...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                SizedBox(height: 16),
                // Modules Selection
                Text(
                  'Sélectionnez les modules (minimum 1)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                ...formation.modules.map((module) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        border: Border.all(
                          color: selectedModules.contains(module)
                              ? AppTheme.primary
                              : Colors.black12,
                          width: selectedModules.contains(module) ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: selectedModules.contains(module),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              // enforce maximum 3 modules
                              if (selectedModules.length >= 3) {
                                // show feedback
                                context.showSnack('Vous pouvez sélectionner au maximum 3 modules.');
                                return;
                              }
                              selectedModules.add(module);
                            } else {
                              selectedModules.remove(module);
                            }

                            // apply bonus automatically when 3 modules selected
                            bonusApplied = selectedModules.length >= 3 && formation.modulesBonus.isNotEmpty;
                          });
                        },
                        title: Text(
                          module,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        checkColor: Colors.white,
                        activeColor: AppTheme.primary,
                      ),
                    ),
                  );
                }),
                SizedBox(height: 16),
                if (bonusApplied) ...[
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonus automatique appliqué', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                        SizedBox(height: 6),
                        Text(
                          formation.modulesBonus.join(' • '),
                          style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                // Conditions Checkbox
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    border: Border.all(
                      color: acceptConditions ? AppTheme.primary : Colors.black12,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: acceptConditions,
                    onChanged: (value) {
                      setState(() => acceptConditions = value ?? false);
                    },
                    title: Text(
                      'J\'accepte les conditions et politiques',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    checkColor: Colors.white,
                    activeColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: selectedModules.isEmpty || !acceptConditions
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _submitEnrollment(
                            formation,
                            selectedModules.toList(),
                            descriptionController.text,
                            bonusApplied,
                          );
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'S\'inscrire',
                      style: GoogleFonts.poppins(
                        color: selectedModules.isEmpty || !acceptConditions
                            ? Colors.grey
                            : Colors.white,
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildFormSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        ...fields,
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.primary.withValues(alpha: 0.05),
          border: Border.all(color: Colors.black12),
        ),
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitEnrollment(
    Formation formation,
    List<String> selectedModules,
    String description,
    bool bonusApplied,
  ) async {
    try {
      if (!mounted) return;

      context.showSnack('✅ Inscription réussie!', background: const Color(0xFF10B981), duration: const Duration(seconds: 2));

      await Future.delayed(Duration(seconds: 1));
      if (!mounted) return;

      context.showSnack('✅ Inscription réussie!', background: const Color(0xFF10B981), duration: const Duration(seconds: 2));

      await Future.delayed(Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      context.showSnack('❌ Erreur lors de l\'inscription: $e', background: const Color(0xFFEF4444), duration: const Duration(seconds: 3));
    }
  }

  void _contactAssistance() {
    final whatsappUrl =
        'https://wa.me/13436428792?text=${Uri.encodeComponent("Bonjour, j'aurais besoin d'assistance concernant les formations. Mes infos: ${widget.user.email}")}';
    launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
  }

  Future<List<Formation>> _getFilteredAndSortedFormations() async {
    var formations = _db.getFormations();

    final query = searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      formations = formations
          .where((f) =>
              f.titre.toLowerCase().contains(query) ||
              f.description.toLowerCase().contains(query) ||
              f.modules.any((module) => module.toLowerCase().contains(query)))
          .toList();
    }

    if (filterType != 'Tous') {
      if (filterType == 'En ligne') {
        formations = formations.where((f) => f.type == FormationType.enligne).toList();
      } else if (filterType == 'Présentielle') {
        formations = formations.where((f) => f.type == FormationType.presentielle).toList();
      } else if (filterType == 'Stage') {
        formations = formations.where((f) => f.estStage).toList();
      }
    }

    if (sortBy == 1) {
      formations.sort((a, b) => a.prix.compareTo(b.prix));
    } else if (sortBy == 2) {
      formations.sort((a, b) => b.prix.compareTo(a.prix));
    }

    return formations;
  }
}
