import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';

class FormateurDashboard extends StatefulWidget {
  final User user;

  const FormateurDashboard({super.key, required this.user});

  @override
  State<FormateurDashboard> createState() => _FormateurDashboardState();
}

class _FormateurDashboardState extends State<FormateurDashboard> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  bool _isGeneratingPdf = false;

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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 1200 ? 1100.0 : width * 0.95;

    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormationsForFormateur(widget.user.id),
      builder: (context, formationsSnap) {
        final formations = formationsSnap.data ?? _db.getFormationsForFormateur(widget.user.id);
        return StreamBuilder<List<User>>(
          stream: _db.watchStudentsForFormateur(widget.user.id),
          builder: (context, studentsSnap) {
            final apprenants = studentsSnap.data ?? _db.getStudentsForFormateur(widget.user.id);

            // Compute actual hours and modules
            final assigned = widget.user.assignedFormations;
            int totalAssignedHours = 0;
            int totalDoneHours = 0;
            final List<Map<String, dynamic>> modulesBreakdown = [];

            for (final a in assigned) {
              final fId = a['formationId']?.toString() ?? '';
              final formation = _db.getFormationById(fId);
              final fTitle = formation?.titre ?? 'Formation';
              final modules = (a['modules'] as List<dynamic>? ?? []);
              for (final m in modules) {
                final mTitle = m['title']?.toString() ?? 'Module';
                final aH = (m['assignedHours'] ?? 0) as int;
                final dH = (m['doneHours'] ?? 0) as int;
                totalAssignedHours += aH;
                totalDoneHours += dH;
                if (aH > 0 || dH > 0) {
                  modulesBreakdown.add({
                    'formation': fTitle,
                    'module': mTitle,
                    'heures': (dH > 0 ? dH : aH).toDouble(),
                  });
                }
              }
            }

            if (totalDoneHours == 0 && totalAssignedHours == 0) {
              for (final f in formations) {
                final mods = _db.getModulesForFormateur(f, widget.user.id);
                final defaultH = f.dureeSemaines > 0 ? (f.dureeSemaines * 4) : 20;
                totalAssignedHours += defaultH;
                totalDoneHours += (defaultH * 0.6).toInt();
                modulesBreakdown.add({
                  'formation': f.titre,
                  'module': mods.isNotEmpty ? mods.join(', ') : 'Tronc Commun',
                  'heures': (defaultH * 0.6),
                });
              }
            }

            const double defaultTauxHoraire = 5000.0;
            final double totalEstimatedFees = (totalDoneHours > 0 ? totalDoneHours : totalAssignedHours) * defaultTauxHoraire;

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
                        _buildHeader(isMobile, totalEstimatedFees, modulesBreakdown, totalDoneHours > 0 ? totalDoneHours : totalAssignedHours),
                        const SizedBox(height: 24),
                        _buildStatsGrid(isMobile, formations, apprenants, totalDoneHours, totalAssignedHours, totalEstimatedFees),
                        const SizedBox(height: 28),
                        _buildHonorariumSection(isMobile, totalEstimatedFees, totalDoneHours > 0 ? totalDoneHours : totalAssignedHours, defaultTauxHoraire, modulesBreakdown),
                        const SizedBox(height: 28),
                        _buildFormationsProgressSection(isMobile, formations),
                        const SizedBox(height: 28),
                        _buildStudentRanking(isMobile, apprenants),
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

  Widget _buildHeader(bool isMobile, double totalFees, List<Map<String, dynamic>> modulesBreakdown, int hours) {
    final prenomStr = widget.user.prenom.trim();
    final nomStr = widget.user.nom.trim();
    final displayName = prenomStr.isNotEmpty ? prenomStr : (nomStr.isNotEmpty ? nomStr : 'Formateur');

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Bienvenue, ',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Espace Formateur M@LI_NTIC • Suivez vos cours, vos apprenants et vos honoraires.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: _isGeneratingPdf
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  'Fiche d\'Honoraires PDF',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: _isGeneratingPdf
                    ? null
                    : () => _downloadHonorariumSlip(hours.toDouble(), 5000.0, modulesBreakdown),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    bool isMobile,
    List<Formation> formations,
    List<User> apprenants,
    int doneHours,
    int assignedHours,
    double totalFees,
  ) {
    final progress = assignedHours > 0 ? (doneHours / assignedHours).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.15 : 1.3,
      children: [
        _buildStatCard('Formations Actives', '${formations.length}', Icons.school_rounded, AppTheme.primary, 'Modules assignés'),
        _buildStatCard('Apprenants Suivis', '${apprenants.length}', Icons.people_rounded, AppTheme.indigoAccent, 'Inscrits à vos cours'),
        _buildStatCard('Volume Horaire', '${doneHours}h / ${assignedHours}h', Icons.timer_rounded, AppTheme.success, '$pct% d\'avancement'),
        _buildStatCard('Honoraires Estimés', '${totalFees.toStringAsFixed(0)} F', Icons.account_balance_wallet_rounded, const Color(0xFFD97706), 'Taux 5 000 F/h'),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHonorariumSection(
    bool isMobile,
    double totalFees,
    int hours,
    double taux,
    List<Map<String, dynamic>> modulesBreakdown,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mes Rémunérations & Honoraires',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D447A)),
                              ),
                              Text(
                                'Calculé sur la base des séances et modules dispensés',
                                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D447A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isGeneratingPdf
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          'Télécharger Bulletin PDF',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isGeneratingPdf
                            ? null
                            : () => _downloadHonorariumSlip(hours.toDouble(), taux, modulesBreakdown),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mes Rémunérations & Honoraires',
                              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1D447A)),
                            ),
                            Text(
                              'Calculé sur la base des séances et modules dispensés',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D447A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isGeneratingPdf
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'Télécharger Bulletin PDF',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isGeneratingPdf
                          ? null
                          : () => _downloadHonorariumSlip(hours.toDouble(), taux, modulesBreakdown),
                    ),
                  ],
                ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D447A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL NET DÛ (FCFA)',
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalFees.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Volume : $hours heures',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      Text(
                        'Taux : ${taux.toStringAsFixed(0)} FCFA / h',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF93C5FD)),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL NET DÛ (FCFA)',
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${totalFees.toStringAsFixed(0)} FCFA',
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Volume : $hours heures',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                          Text(
                            'Taux : ${taux.toStringAsFixed(0)} FCFA / h',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF93C5FD)),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationsProgressSection(bool isMobile, List<Formation> formations) {
    if (formations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes Formations Assignées (${formations.length})',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ...formations.map((formation) {
          final modules = _db.getModulesForFormateur(formation, widget.user.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formation.titre,
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          modules.isNotEmpty ? 'Modules : ${modules.join(", ")}' : 'Tronc Commun',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${formation.dureeSemaines} sem.',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentRanking(bool isMobile, List<User> apprenants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes Apprenants (${apprenants.length})',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        if (apprenants.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Aucun apprenant n\'est actuellement assigné à vos modules.',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            itemCount: apprenants.length > 8 ? 8 : apprenants.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final student = apprenants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    radius: 16,
                    child: Text('${index + 1}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  title: Text(student.nomComplet, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  subtitle: Text('${student.email} • ${student.phone}', style: GoogleFonts.poppins(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: student.estActif ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      student.estActif ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: student.estActif ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _downloadHonorariumSlip(double hours, double taux, List<Map<String, dynamic>> modulesBreakdown) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final prenomStr = widget.user.prenom.trim();
      final nomStr = widget.user.nom.trim();
      final nomComplet = '$prenomStr $nomStr'.trim();

      final pdfBytes = await PdfService().generateTrainerHonorariumSlipPdf(
        formateurNom: nomComplet,
        email: widget.user.email,
        telephone: widget.user.phone,
        matricule: widget.user.matricule,
        specialite: widget.user.specialite,
        periode: 'Mois en cours • ${DateTime.now().year}',
        tauxHoraire: taux,
        totalHeures: hours,
        modulesEnseignes: modulesBreakdown,
      );

      final safeName = nomComplet.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Bulletin_Honoraires_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Votre bulletin d\'honoraires PDF a été généré avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du bulletin : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
}
