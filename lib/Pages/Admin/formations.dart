import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/imagekit_service.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';
import 'package:gestion_formations/Widgets/quick_formation_preset_dialog.dart';
import 'package:gestion_formations/Widgets/export_accounting_dialog.dart';

class _ModuleItemData {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  String? formateurId;
  bool isBonus;

  _ModuleItemData({
    required this.nameCtrl,
    required this.priceCtrl,
    this.formateurId,
    this.isBonus = false,
  });

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class AdminFormations extends StatefulWidget {
  const AdminFormations({super.key});

  @override
  State<AdminFormations> createState() => _AdminFormationsState();
}

class _AdminFormationsState extends State<AdminFormations>
    with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final ImageKitService _imageKit = ImageKitService();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController _cohortNameCtrl = TextEditingController();

  String selectedStatus = 'Tous';
  String selectedSort = 'Date création';
  String selectedFormationKind = 'Tous';
  String _filterType = 'Tous';
  String _filterStatus = 'Tous';
  String _searchQuery = '';
  final Set<String> _expandedFormationIds = {};
  late AnimationController _fadeController;
  StreamSubscription<void>? _dataSub;
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Mise à jour automatique instantanée des cartes statistiques de formations
    _dataSub = _db.watchAllDataChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _generateBrochurePdf(Formation formation) async {
    try {
      final bytes = await PdfService().generateFormationBrochurePdf(formation);
      await PdfService().printOrDownloadPdf(
        pdfBytes: bytes,
        filename: 'Brochure_${formation.titre.replaceAll(' ', '_')}.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brochure PDF téléchargée avec succès'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
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
          SizedBox(height: isMobile ? 14 : 22),
          _buildProfitabilityKpiBanner(isMobile),
          SizedBox(height: isMobile ? 16 : 26),
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text('Modèles', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => QuickFormationPresetDialog.show(context),
                ),
                const SizedBox(width: 8),
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
                      'Gérez le catalogue, modules, tarifs et sessions de formations',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18, color: AppTheme.accent),
                      label: Text('Émargement PDF', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () => ExportAccountingDialog.show(context),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3E8FF),
                        foregroundColor: const Color(0xFF7E22CE),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF7E22CE)),
                      label: Text('Modèles (1-Clic)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: () => QuickFormationPresetDialog.show(context),
                    ),
                    const SizedBox(width: 10),
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
                                  'Créer une formation',
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
              ],
            ),
    );
  }

  Widget _buildProfitabilityKpiBanner(bool isMobile) {
    return StreamBuilder<List<User>>(
      stream: _db.watchUsers(),
      builder: (context, userSnap) {
        return StreamBuilder<List<Formation>>(
          stream: _db.watchFormations(),
          builder: (context, formSnap) {
            final users = userSnap.data ?? _db.getUsers();
            final formations = formSnap.data ?? _db.getFormations();
            final payments = _db.getPayments();

            final learners = users.where((u) => u.role == UserRole.apprenant).toList();
            
            // Total encaisse
            final totalCollected = payments
                .where((p) => p.status == PaymentStatus.effectue)
                .fold<double>(0.0, (sum, p) => sum + p.montant);

            // Active enrollments
            int totalEnrolledCount = 0;
            int totalCapacity = 0;
            final activeCohorts = <String>{};

            for (final f in formations) {
              final enrolled = learners.where((u) => u.assignedFormations.any((a) => a['formationId'] == f.id)).toList();
              totalEnrolledCount += enrolled.length;
              totalCapacity += f.capaciteMax ?? (enrolled.length > 15 ? enrolled.length : 15);
              for (final u in enrolled) {
                final c = _db.getStudentCohort(studentId: u.id, formationId: f.id);
                if (c != null && c.trim().isNotEmpty && c != 'Non assigné') {
                  activeCohorts.add('${f.id}_$c');
                }
              }
            }

            final globalFillRate = totalCapacity > 0
                ? ((totalEnrolledCount / totalCapacity) * 100).clamp(0.0, 100.0)
                : 0.0;

            final kpis = [
              {
                'title': 'CA Total Encaissé',
                'value': '${totalCollected.toStringAsFixed(0)} F',
                'sub': 'Paiements validés',
                'icon': Icons.account_balance_wallet_rounded,
                'color': const Color(0xFF10B981),
                'bg': const Color(0xFFECFDF5),
              },
              {
                'title': 'Inscriptions Actives',
                'value': '$totalEnrolledCount',
                'sub': '${learners.length} apprenants inscrits',
                'icon': Icons.school_rounded,
                'color': AppTheme.primary,
                'bg': const Color(0xFFEFF6FF),
              },
              {
                'title': 'Taux Remplissage',
                'value': '${globalFillRate.toStringAsFixed(0)}%',
                'sub': '$totalEnrolledCount / $totalCapacity places',
                'icon': Icons.pie_chart_rounded,
                'color': const Color(0xFF8B5CF6),
                'bg': const Color(0xFFF5F3FF),
              },
              {
                'title': 'Groupes & Cohortes',
                'value': '${activeCohorts.length}',
                'sub': 'Groupes actifs',
                'icon': Icons.groups_rounded,
                'color': const Color(0xFFF59E0B),
                'bg': const Color(0xFFFFFBEB),
              },
            ];

            if (isMobile) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kpis.map((kpi) => Container(
                    width: 210,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (kpi['bg'] as Color),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(kpi['icon'] as IconData, size: 18, color: kpi['color'] as Color),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kpi['value'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          kpi['title'] as String,
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                        Text(
                          kpi['sub'] as String,
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.black38),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - (3 * 14)) / 4;
                return Row(
                  children: kpis.map((kpi) => Container(
                    width: cardWidth,
                    margin: EdgeInsets.only(right: kpi == kpis.last ? 0 : 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (kpi['bg'] as Color),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(kpi['icon'] as IconData, size: 20, color: kpi['color'] as Color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                kpi['title'] as String,
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                              ),
                              Text(
                                kpi['value'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                kpi['sub'] as String,
                                style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.black38),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFormationProfitabilityAndCohorts(Formation formation) {
    final enrolledStudents = _db.getStudentsForFormation(formation.id);
    final capacity = formation.capaciteMax ?? (enrolledStudents.length > 15 ? enrolledStudents.length : 15);
    final fillRate = capacity > 0 ? (enrolledStudents.length / capacity).clamp(0.0, 1.0) : 0.0;

    final payments = _db.getPayments();
    final studentIds = enrolledStudents.map((s) => s.id).toSet();
    final collected = payments
        .where((p) => p.status == PaymentStatus.effectue && (p.formationId == formation.id || studentIds.contains(p.etudiantId) || studentIds.contains(p.apprenantId)))
        .fold<double>(0.0, (sum, p) => sum + p.montant);
    final expectedTotal = enrolledStudents.length * formation.prix;
    final remaining = (expectedTotal - collected).clamp(0.0, double.infinity);

    final cohortsMap = <String, List<User>>{};
    for (final s in enrolledStudents) {
      final cohort = _db.getStudentCohort(studentId: s.id, formationId: formation.id) ?? 'Non assigné';
      cohortsMap.putIfAbsent(cohort, () => []).add(s);
    }

    final fillColor = fillRate >= 0.8
        ? const Color(0xFF10B981)
        : (fillRate >= 0.4 ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.query_stats_rounded, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Rentabilité & Remplissage',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fillColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(fillRate * 100).toStringAsFixed(0)}% rempli (${enrolledStudents.length}/$capacity)',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: fillColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillRate,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFinMiniMetric('Encaissé', '${collected.toStringAsFixed(0)} F', const Color(0xFF166534), const Color(0xFFDCFCE7)),
              _buildFinMiniMetric('Attendu', '${expectedTotal.toStringAsFixed(0)} F', const Color(0xFF1E293B), const Color(0xFFF1F5F9)),
              _buildFinMiniMetric('Reste Dû', '${remaining.toStringAsFixed(0)} F', const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Groupes / Cohortes :',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => ExportAccountingDialog.show(context, preselectedFormation: formation),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.how_to_reg_rounded, size: 13, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Émargement PDF',
                          style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _showCohortsManagementDialog(context, formation),
                    child: Text(
                      'Gérer les cohortes >',
                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (cohortsMap.isEmpty)
            Text(
              'Aucun apprenant inscrit pour le moment.',
              style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black45, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: cohortsMap.entries.map((entry) {
                final isUnassigned = entry.key == 'Non assigné';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUnassigned ? Colors.grey.shade200 : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isUnassigned ? Colors.grey.shade300 : AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${entry.key} (${entry.value.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isUnassigned ? Colors.black54 : AppTheme.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFinMiniMetric(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 9.5, color: textColor.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.poppins(fontSize: 11, color: textColor, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _showCohortsManagementDialog(BuildContext context, Formation formation) {
    final newCohortCtrl = TextEditingController();
    String searchQuery = '';
    String selectedCohortFilter = 'Tous';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allStudents = _db.getStudentsForFormation(formation.id);
          
          final existingCohorts = <String>{};
          for (final s in allStudents) {
            final c = _db.getStudentCohort(studentId: s.id, formationId: formation.id);
            if (c != null && c.trim().isNotEmpty) existingCohorts.add(c.trim());
          }

          final filteredStudents = allStudents.where((s) {
            final cohort = _db.getStudentCohort(studentId: s.id, formationId: formation.id) ?? 'Non assigné';
            if (selectedCohortFilter != 'Tous' && cohort != selectedCohortFilter) {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final query = searchQuery.toLowerCase();
              final matchName = '${s.prenom} ${s.nom}'.toLowerCase().contains(query);
              final matchMatricule = (s.matricule ?? '').toLowerCase().contains(query);
              return matchName || matchMatricule;
            }
            return true;
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gestion des Cohortes & Groupes',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Formation : ${formation.titre} • ${allStudents.length} apprenant(s)',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 650,
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCohortCtrl,
                            style: GoogleFonts.poppins(fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Nouveau nom de groupe (ex: Cohorte Matin, Groupe B, Samedi)...',
                              prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            final name = newCohortCtrl.text.trim();
                            if (name.isNotEmpty) {
                              setModalState(() {
                                existingCohorts.add(name);
                                newCohortCtrl.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Créer', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCohortFilterChip('Tous (${allStudents.length})', 'Tous', selectedCohortFilter, (val) {
                          setModalState(() => selectedCohortFilter = val);
                        }),
                        const SizedBox(width: 6),
                        ...existingCohorts.map((c) {
                          final count = allStudents.where((s) => _db.getStudentCohort(studentId: s.id, formationId: formation.id) == c).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildCohortFilterChip('$c ($count)', c, selectedCohortFilter, (val) {
                              setModalState(() => selectedCohortFilter = val);
                            }),
                          );
                        }),
                        _buildCohortFilterChip(
                          'Non assigné (${allStudents.where((s) => (_db.getStudentCohort(studentId: s.id, formationId: formation.id) ?? "").isEmpty).length})',
                          'Non assigné',
                          selectedCohortFilter,
                          (val) => setModalState(() => selectedCohortFilter = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setModalState(() => searchQuery = v),
                    style: GoogleFonts.poppins(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Rechercher un apprenant par nom ou matricule...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun apprenant trouvé dans cette sélection.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, _) => const Divider(height: 8),
                            itemBuilder: (context, idx) {
                              final student = filteredStudents[idx];
                              final currentCohort = _db.getStudentCohort(studentId: student.id, formationId: formation.id);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        '${student.prenom.isNotEmpty ? student.prenom[0] : ""}${student.nom.isNotEmpty ? student.nom[0] : ""}',
                                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${student.prenom} ${student.nom}',
                                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87),
                                          ),
                                          Text(
                                            'Matricule : ${student.matricule ?? "N/A"} • ${student.phone}',
                                            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 170,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: (currentCohort != null && currentCohort.isNotEmpty) ? currentCohort : null,
                                        isDense: true,
                                        style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black87),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: 'Groupe / Cohorte',
                                          labelStyle: GoogleFonts.poppins(fontSize: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: null,
                                            child: Text('Non assigné'),
                                          ),
                                          ...existingCohorts.map((c) => DropdownMenuItem<String>(
                                            value: c,
                                            child: Text(c),
                                          )),
                                        ],
                                        onChanged: (newCohort) async {
                                          await _db.updateStudentCohort(
                                            studentId: student.id,
                                            formationId: formation.id,
                                            cohortName: newCohort,
                                          );
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Fermer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCohortFilterChip(String label, String value, String selectedValue, ValueChanged<String> onSelected) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
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
                              'En ligne : ${formation.prixEnLigne!.toStringAsFixed(0)} F',
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
                              'Présentiel : ${formation.prix.toStringAsFixed(0)} F',
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
                              'En ligne : ${(formation.prixEnLigne ?? formation.prix).toStringAsFixed(0)} F',
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
                              'Présentiel : ${formation.prix.toStringAsFixed(0)} F',
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
                                _formatType(formation.type),
                              ),
                              _buildInfoRowCompact(
                                'Statut',
                                _formatStatus(formation.status),
                              ),
                              _buildInfoRowCompact(
                                'Durée',
                                '${formation.dureeSemaines} sem.',
                              ),
                              _buildInfoRowCompact(
                                'Places',
                                '${_db.getStudentsForFormation(formation.id).length}/${formation.capaciteMax ?? 0}',
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
                                  _formatDate(formation.dateDebut!),
                                ),
                              if (formation.dateFin != null)
                                _buildInfoRowCompact(
                                  'Fin',
                                  _formatDate(formation.dateFin!),
                                ),
                              if (formation.dureeHeures != null &&
                                  formation.dureeHeures!.isNotEmpty)
                                _buildInfoRowCompact(
                                  'Heures',
                                  formation.dureeHeures!,
                                ),
                            ],
                          ),
                          if (formation.modules.isNotEmpty || formation.modulesBonus.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            // Header modules dans la carte déployée (Wrap pour mobile)
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Programme & Modules (${formation.modules.length + formation.modulesBonus.length})',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                                Text(
                                  'Tarif individuel / Formateur',
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...formation.modules.map((moduleTitle) {
                              final price = formation.modulePrices[moduleTitle];
                              final formateurId = formation.moduleFormateurIds[moduleTitle];
                              final formateur = formateurId != null ? _db.getUserById(formateurId) : null;
                              final formateurName = formateur != null ? '${formateur.prenom} ${formateur.nom}' : (formateurId != null && formateurId.isNotEmpty ? formateurId : 'Non assigné');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        moduleTitle,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (price != null && price > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${price.toStringAsFixed(0)} FCFA',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 110),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: formateur != null ? AppTheme.primary.withValues(alpha: 0.1) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_rounded,
                                              size: 11,
                                              color: formateur != null ? AppTheme.primary : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                formateurName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: formateur != null ? AppTheme.primary : Colors.grey.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            ...formation.modulesBonus.map((moduleTitle) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        moduleTitle,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'BONUS OFFERT',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
                          _buildFormationProfitabilityAndCohorts(formation),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          // Action buttons bar
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showCohortsManagementDialog(context, formation),
                                icon: const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF7C3AED)),
                                label: Text(
                                  'Cohortes & Groupes',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                                  backgroundColor: const Color(0xFFF5F3FF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _generateBrochurePdf(formation),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                                label: Text(
                                  'Brochure PDF',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showFormationQrDialog(context, formation),
                                icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.primary),
                                label: Text(
                                  'Partager & QR',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.05),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showEditFormationDialog(context, formation),
                                icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                                label: Text(
                                  'Modifier',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 1,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Supprimer la formation',
                                onPressed: () => _confirmDeleteFormation(context, formation),
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  padding: const EdgeInsets.all(8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFFECACA)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
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
      final formationStatus = _formatStatus(formation.status);
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

  String _formatType(FormationType type) {
    switch (type) {
      case FormationType.presentielle:
        return 'Présentielle';
      case FormationType.mixte:
        return 'Mixte';
      default:
        return 'En ligne';
    }
  }

  String _formatStatus(FormationStatus status) {
    switch (status) {
      case FormationStatus.enCours:
        return 'En Cours';
      case FormationStatus.terminee:
        return 'Terminée';
      default:
        return 'Programmée';
    }
  }

  Future<void> _showFormationQrDialog(
    BuildContext context,
    Formation formation,
  ) async {
    await ShareFormationDialog.show(context, formation);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _parseDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;

    final isoDate = DateTime.tryParse(trimmed);
    if (isoDate != null) return isoDate;

    final frenchMatch = RegExp(
      r'^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$',
    ).firstMatch(trimmed);
    if (frenchMatch != null) {
      final day = int.parse(frenchMatch.group(1)!);
      final month = int.parse(frenchMatch.group(2)!);
      final year = int.parse(frenchMatch.group(3)!);
      return DateTime(year, month, day);
    }

    final dashFormat = RegExp(
      r'^(\d{4})[\/\-](\d{2})[\/\-](\d{2})$',
    ).firstMatch(trimmed);
    if (dashFormat != null) {
      final year = int.parse(dashFormat.group(1)!);
      final month = int.parse(dashFormat.group(2)!);
      final day = int.parse(dashFormat.group(3)!);
      return DateTime(year, month, day);
    }

    return null;
  }

  Widget _buildInteractiveModulesSection({
    required BuildContext context,
    required List<_ModuleItemData> moduleItems,
    required List<User> formateurs,
    required void Function(void Function()) setModalState,
  }) {
    final standardCount = moduleItems.where((i) => !i.isBonus).length;
    final bonusCount = moduleItems.where((i) => i.isBonus).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section modules (responsive)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_module_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Programme & Modules (${moduleItems.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$standardCount standard(s) • $bonusCount bonus offert(s)',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setModalState(() {
                        moduleItems.add(
                          _ModuleItemData(
                            nameCtrl: TextEditingController(),
                            priceCtrl: TextEditingController(),
                            formateurId: formateurs.isNotEmpty ? formateurs.first.id : null,
                            isBonus: false,
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 13),
                    label: Text(
                      '+ Module',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setModalState(() {
                        moduleItems.add(
                          _ModuleItemData(
                            nameCtrl: TextEditingController(),
                            priceCtrl: TextEditingController(),
                            formateurId: formateurs.isNotEmpty ? formateurs.first.id : null,
                            isBonus: true,
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.card_giftcard_rounded, size: 13, color: Color(0xFFD97706)),
                    label: Text(
                      '+ Bonus',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                      backgroundColor: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (moduleItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aucun module défini. Cliquez sur « + Module » ou « + Bonus » ci-dessus.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black45),
                ),
              ),
            )
          else
            ...moduleItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isBonus ? const Color(0xFFFEF3C7).withValues(alpha: 0.35) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isBonus ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isBonus ? const Color(0xFFD97706) : AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.isBonus ? '🎁 BONUS' : '#${idx + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.isBonus ? Colors.white : AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: item.nameCtrl,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: item.isBonus ? 'Intitulé du module bonus (ex: PowerPoint + IA)' : 'Intitulé du module (ex: Flutter & Dart)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                          tooltip: 'Supprimer ce module',
                          onPressed: () {
                            setModalState(() {
                              moduleItems.removeAt(idx);
                            });
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: item.priceCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Tarif unitaire (FCFA)',
                              hintText: 'ex: 35000',
                              helperText: 'Prix pour inscription à la carte hors-SFP',
                              helperStyle: GoogleFonts.poppins(fontSize: 9.5),
                              prefixIcon: const Icon(Icons.sell_outlined, size: 15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: (item.formateurId != null && formateurs.any((f) => f.id == item.formateurId))
                                ? item.formateurId
                                : null,
                            isDense: true,
                            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black87),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Formateur assigné',
                              labelStyle: GoogleFonts.poppins(fontSize: 10.5),
                              prefixIcon: const Icon(Icons.person_pin_rounded, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Non assigné'),
                              ),
                              ...formateurs.map((f) => DropdownMenuItem<String>(
                                value: f.id,
                                child: Text('${f.prenom} ${f.nom}'),
                              )),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                item.formateurId = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Checkbox(
                          value: item.isBonus,
                          onChanged: (val) {
                            setModalState(() {
                              item.isBonus = val ?? false;
                            });
                          },
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: const Color(0xFFD97706),
                        ),
                        Text(
                          'Module Bonus Offert (inclus gratuitement dans le pack)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: item.isBonus ? const Color(0xFF92400E) : Colors.black87,
                            fontWeight: item.isBonus ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showCreateFormationDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titreController = TextEditingController();
    final descriptionController = TextEditingController();
    final formateurs = _db.getUsers().where((u) => u.role == UserRole.formateur).toList();
    final moduleItems = <_ModuleItemData>[
      _ModuleItemData(
        nameCtrl: TextEditingController(),
        priceCtrl: TextEditingController(),
        formateurId: formateurs.isNotEmpty ? formateurs.first.id : null,
      ),
    ];
    
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
                    _buildInteractiveModulesSection(
                      context: context,
                      moduleItems: moduleItems,
                      formateurs: formateurs,
                      setModalState: setState,
                    ),
                    // Image picker avec upload ImageKit
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                          const SizedBox(height: 8),
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
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
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
                                            const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    AppTheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
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
                                          const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ImageFormat>(
                      initialValue: imageFormatValue,
                      decoration: InputDecoration(
                        labelText: 'Format de l\'image',
                        prefixIcon: const Icon(Icons.crop),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
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
                      'Prix (Présentiel ou Forfait Global)',
                      null,
                      Icons.attach_money_rounded,
                      isNumber: true,
                      helperText: 'Forfait fixe pour stage SFP (ex: 100000 FCFA)',
                    ),
                    if (typeValue == 'En ligne' || typeValue == 'Mixte')
                      _buildFormField(
                        prixEnLigneController,
                        'Prix en ligne (Forfait Global Ligne)',
                        null,
                        Icons.computer_rounded,
                        isNumber: true,
                        helperText: 'Forfait fixe en ligne pour SFP (ex: 125000 FCFA)',
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
                      helperText: 'Ex: 3 mois • 3 séances par semaine • 3h par séance',
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
                    // Section Type de Formation (Stage SFP vs Standard)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isStage ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isStage ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isStage,
                                onChanged: (value) {
                                  setState(() {
                                    isStage = value ?? false;
                                    if (isStage && maxModulesController.text.trim().isEmpty) {
                                      maxModulesController.text = '3';
                                    }
                                  });
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      isStage = !isStage;
                                      if (isStage && maxModulesController.text.trim().isEmpty) {
                                        maxModulesController.text = '3';
                                      }
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'C’est un stage professionnel (ex: SFP5)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isStage ? AppTheme.primary : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        isStage
                                            ? 'Prix fixe global pour le pack entier. Les candidats choisissent un nombre défini de modules.'
                                            : 'Formation modulaire standard (hors-SFP). Choix de modules à la carte avec total par prix unitaire.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isStage) ...[
                            const SizedBox(height: 10),
                            _buildFormField(
                              maxModulesController,
                              'Nombre max de modules sélectionnables par stagiaire',
                              null,
                              Icons.view_module_rounded,
                              isNumber: true,
                              helperText: 'Ex: 3 modules pour le SFP5 (parmi tous les modules proposés)',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: ['En ligne', 'Présentielle', 'Mixte'].contains(typeValue) ? typeValue : 'En ligne',
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon: const Icon(Icons.computer_rounded),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['Programmée', 'En Cours', 'Terminée'].contains(statusValue) ? statusValue : 'Programmée',
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: const Icon(Icons.info_rounded),
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
                child: const Text('Annuler'),
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

                            final modules = <String>[];
                            final modulesBonus = <String>[];
                            final modulePrices = <String, double>{};
                            final moduleFormateurIds = <String, String>{};

                            for (final item in moduleItems) {
                              final name = item.nameCtrl.text.trim();
                              if (name.isEmpty) continue;
                              if (item.isBonus) {
                                modulesBonus.add(name);
                              } else {
                                modules.add(name);
                              }
                              final price = double.tryParse(item.priceCtrl.text.trim());
                              if (price != null && price >= 0) {
                                modulePrices[name] = price;
                              }
                              if (item.formateurId != null && item.formateurId!.isNotEmpty) {
                                moduleFormateurIds[name] = item.formateurId!;
                              }
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
                                ? (int.tryParse(maxModulesController.text.trim()) ?? 3)
                                : null;
                            final dateDebut = dateDebutController.text.trim().isEmpty
                                ? null
                                : _parseDate(dateDebutController.text.trim());
                            final dateFin = dateFinController.text.trim().isEmpty
                                ? null
                                : _parseDate(dateFinController.text.trim());
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
      padding: const EdgeInsets.only(bottom: 12),
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
    final formateurs = _db.getUsers().where((u) => u.role == UserRole.formateur).toList();
    final moduleItems = <_ModuleItemData>[
      ...formation.modules.map((m) => _ModuleItemData(
        nameCtrl: TextEditingController(text: m),
        priceCtrl: TextEditingController(
          text: formation.modulePrices[m] != null && formation.modulePrices[m]! > 0
              ? formation.modulePrices[m]!.toStringAsFixed(0)
              : '',
        ),
        formateurId: formation.moduleFormateurIds[m],
        isBonus: false,
      )),
      ...formation.modulesBonus.map((m) => _ModuleItemData(
        nameCtrl: TextEditingController(text: m),
        priceCtrl: TextEditingController(
          text: formation.modulePrices[m] != null && formation.modulePrices[m]! > 0
              ? formation.modulePrices[m]!.toStringAsFixed(0)
              : '',
        ),
        formateurId: formation.moduleFormateurIds[m],
        isBonus: true,
      )),
    ];
    
    final imageUrlController = TextEditingController(
      text: formation.imageUrl ?? '',
    );
    final formateursController = TextEditingController(
      text: formation.formateurIds.join(', '),
    );
    final prixController = TextEditingController(
      text: formation.prix.toStringAsFixed(0),
    );
    final prixEnLigneController = TextEditingController(
      text: formation.prixEnLigne != null ? formation.prixEnLigne!.toStringAsFixed(0) : '',
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
          ? _formatDate(formation.dateDebut!)
          : '',
    );
    final dateFinController = TextEditingController(
      text: formation.dateFin != null ? _formatDate(formation.dateFin!) : '',
    );
    final capaciteController = TextEditingController(
      text: formation.capaciteMax?.toString() ?? '',
    );
    final maxModulesController = TextEditingController(
      text: (formation.maxModulesParEtudiant ?? (formation.estStage ? 3 : null))?.toString() ?? '',
    );
    String typeValue = _formatType(formation.type);
    String statusValue = _formatStatus(formation.status);
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
                    _buildInteractiveModulesSection(
                      context: context,
                      moduleItems: moduleItems,
                      formateurs: formateurs,
                      setModalState: setState,
                    ),
                    // Image picker avec upload ImageKit
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                          const SizedBox(height: 8),
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
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
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
                                            const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    AppTheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
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
                                          const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 48,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ImageFormat>(
                      initialValue: imageFormatValue,
                      decoration: InputDecoration(
                        labelText: 'Format de l\'image',
                        prefixIcon: const Icon(Icons.crop),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
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
                      'Prix (Présentiel ou Forfait Global)',
                      null,
                      Icons.attach_money_rounded,
                      isNumber: true,
                      helperText: 'Forfait fixe pour stage SFP (ex: 100000 FCFA)',
                    ),
                    if (typeValue == 'En ligne' || typeValue == 'Mixte')
                      _buildFormField(
                        prixEnLigneController,
                        'Prix en ligne (Forfait Global Ligne)',
                        null,
                        Icons.computer_rounded,
                        isNumber: true,
                        helperText: 'Forfait fixe en ligne pour SFP (ex: 125000 FCFA)',
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
                      helperText: 'Ex: 3 mois • 3 séances par semaine • 3h par séance',
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
                    // Section Type de Formation (Stage SFP vs Standard)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isStage ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isStage ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isStage,
                                onChanged: (value) {
                                  setState(() {
                                    isStage = value ?? false;
                                    if (isStage && maxModulesController.text.trim().isEmpty) {
                                      maxModulesController.text = '3';
                                    }
                                  });
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      isStage = !isStage;
                                      if (isStage && maxModulesController.text.trim().isEmpty) {
                                        maxModulesController.text = '3';
                                      }
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'C’est un stage professionnel (ex: SFP5)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isStage ? AppTheme.primary : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        isStage
                                            ? 'Prix fixe global pour le pack entier. Les candidats choisissent un nombre défini de modules.'
                                            : 'Formation modulaire standard (hors-SFP). Choix de modules à la carte avec total par prix unitaire.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isStage) ...[
                            const SizedBox(height: 10),
                            _buildFormField(
                              maxModulesController,
                              'Nombre max de modules sélectionnables par stagiaire',
                              null,
                              Icons.view_module_rounded,
                              isNumber: true,
                              helperText: 'Ex: 3 modules pour le SFP5 (parmi tous les modules proposés)',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: ['En ligne', 'Présentielle', 'Mixte'].contains(typeValue) ? typeValue : 'En ligne',
                      decoration: InputDecoration(
                        labelText: 'Type',
                        prefixIcon: const Icon(Icons.computer_rounded),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['Programmée', 'En Cours', 'Terminée'].contains(statusValue) ? statusValue : 'Programmée',
                      decoration: InputDecoration(
                        labelText: 'Statut',
                        prefixIcon: const Icon(Icons.info_rounded),
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
                child: const Text('Annuler'),
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

                            final modules = <String>[];
                            final modulesBonus = <String>[];
                            final modulePrices = <String, double>{};
                            final moduleFormateurIds = <String, String>{};

                            for (final item in moduleItems) {
                              final name = item.nameCtrl.text.trim();
                              if (name.isEmpty) continue;
                              if (item.isBonus) {
                                modulesBonus.add(name);
                              } else {
                                modules.add(name);
                              }
                              final price = double.tryParse(item.priceCtrl.text.trim());
                              if (price != null && price >= 0) {
                                modulePrices[name] = price;
                              }
                              if (item.formateurId != null && item.formateurId!.isNotEmpty) {
                                moduleFormateurIds[name] = item.formateurId!;
                              }
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
                                ? (int.tryParse(maxModulesController.text.trim()) ?? 3)
                                : null;
                            final dateDebut = dateDebutController.text.trim().isEmpty
                                ? null
                                : _parseDate(dateDebutController.text.trim());
                            final dateFin = dateFinController.text.trim().isEmpty
                                ? null
                                : _parseDate(dateFinController.text.trim());
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
