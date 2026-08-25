import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/Pages/Student/discover_formations.dart';
import 'package:gestion_formations/Widgets/chart_widgets.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';

class StudentDashboard extends StatefulWidget {
  final User user;

  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isCompact = size.width < 600;
    final width = size.width;
    final maxWidth = width > 1200 ? 1100.0 : width * 0.95;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(top: isCompact ? 12 : 16, left: 16, right: 16, bottom: isCompact ? 80 : 96),
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
                    _buildWelcomeHeader(isMobile),
                    const SizedBox(height: 24),
                    _buildAttestationsSection(),
                    const SizedBox(height: 24),
                    _buildStatistics(),
                    const SizedBox(height: 40),
                    _buildModuleProgressSection(),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: isCompact ? 12 : 24,
              right: isCompact ? 12 : 24,
              child: SafeArea(
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiscoverFormationsPage(user: widget.user),
                      ),
                    );
                  },
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(Icons.explore_rounded, color: Colors.white),
                  label: Text(
                    'Découvrir',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildWelcomeHeader(bool isMobile) {
    final prenomStr = widget.user.prenom.trim();
    final nomStr = widget.user.nom.trim();
    final displayName = prenomStr.isNotEmpty ? prenomStr : (nomStr.isNotEmpty ? nomStr : 'Étudiant');

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                        'Bienvenue 👋, ',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.user.matricule?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${widget.user.matricule}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Votre espace de formation, soigneusement préparé pour vous.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final liveUser = _db.getUserById(widget.user.id) ?? widget.user;
    final userAssigned = liveUser.assignedFormations;
    final userAssignedIds = userAssigned.map((item) => item['formationId']?.toString()).whereType<String>().toSet();
    final userInscriptions = _db.getInscriptions().where((i) {
      final isSameUser = i.etudiantId == liveUser.id || (i.email != null && i.email!.trim().toLowerCase() == liveUser.email.trim().toLowerCase());
      return isSameUser && i.status == InscriptionStatus.acceptee;
    }).map((i) => i.formationId).toSet();

    final enrolledIds = {...userAssignedIds, ...userInscriptions}.whereType<String>().toSet();
    final formationCount = enrolledIds.length;

    int moduleCount = 0;
    int totalAssignedHours = 0;
    int totalDoneHours = 0;

    for (final a in userAssigned) {
      final modules = a['modules'] as List<dynamic>? ?? [];
      moduleCount += modules.length;
      for (final m in modules) {
        if (m is Map) {
          totalDoneHours += ((m['doneHours'] ?? 0) as num).toInt();
          totalAssignedHours += ((m['assignedHours'] ?? 0) as num).toInt();
        }
      }
    }

    final averageProgress = totalAssignedHours > 0 ? (totalDoneHours / totalAssignedHours).clamp(0.0, 1.0) : 0.0;
    final isCompact = MediaQuery.of(context).size.width < 700;

    return isCompact
        ? Column(
            children: [
              _buildStatCard(
                title: 'Formations actives',
                value: formationCount.toString(),
                subtitle: '$moduleCount modules enregistrés',
                icon: Icons.menu_book_rounded,
                color: AppTheme.primary,
                delay: 0,
                chartData: [12, 18, 22, 30, 34, formationCount.toDouble()],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Progression moyenne',
                value: AppFormat.percent(averageProgress),
                subtitle: 'Sur vos modules en cours',
                icon: Icons.show_chart_rounded,
                color: AppTheme.success,
                delay: 50,
                chartData: [0.3, 0.45, 0.56, 0.63, 0.68, averageProgress],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Formations actives',
                  value: formationCount.toString(),
                  subtitle: '$moduleCount modules enregistrés',
                  icon: Icons.menu_book_rounded,
                  color: AppTheme.primary,
                  delay: 0,
                  chartData: [12, 18, 22, 30, 34, formationCount.toDouble()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Progression moyenne',
                  value: AppFormat.percent(averageProgress),
                  subtitle: 'Sur vos modules en cours',
                  icon: Icons.show_chart_rounded,
                  color: AppTheme.success,
                  delay: 50,
                  chartData: [0.3, 0.45, 0.56, 0.63, 0.68, averageProgress],
                ),
              ),
            ],
          );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int delay,
    List<double>? chartData,
  }) {
    return SlideInUp(
      delay: Duration(milliseconds: delay),
      duration: const Duration(milliseconds: 600),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.72)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      if (chartData != null && chartData.isNotEmpty)
                        SizedBox(
                          width: 120,
                          child: SparkLineChart(
                            data: chartData,
                            color: color,
                            height: 40,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleProgressSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllModulesWithProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        final modules = snapshot.data ?? [];

        if (modules.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mes progrès',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.library_books_rounded, size: 48, color: Colors.black12),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun module en progression',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DiscoverFormationsPage(user: widget.user),
                          ),
                        );
                      },
                      child: const Text('Découvrir des formations'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes progrès',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return _buildModuleProgressCard(module, index);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildModuleProgressCard(Map<String, dynamic> module, int index) {
    final moduleTitle = module['title'] ?? 'Module';
    final formationTitle = module['formation'] ?? 'Formation';
    final doneHours = module['doneHours'] ?? 0;
    final assignedHours = module['assignedHours'] ?? 0;
    final progressPercent = assignedHours > 0 ? (doneHours / assignedHours * 100).toStringAsFixed(1) : '0';
    final progress = assignedHours > 0 ? (doneHours / assignedHours).clamp(0.0, 1.0) : 0.0;

    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moduleTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formationTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$doneHours / $assignedHours heures complétées',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllModulesWithProgress() async {
    final liveUser = _db.getUserById(widget.user.id) ?? widget.user;
    final List<Map<String, dynamic>> allModules = [];

    for (var a in liveUser.assignedFormations) {
      final formationTitle = a['title'] ?? 'Formation';
      final modules = a['modules'] as List<dynamic>? ?? [];

      for (var m in modules) {
        if (m is Map<String, dynamic>) {
          final title = m['title'] ?? 'Module';
          final done = (m['doneHours'] ?? 0) as int;
          final assigned = (m['assignedHours'] ?? 20) as int;
          final ratio = assigned == 0 ? 0.0 : (done / assigned).clamp(0.0, 1.0);

          allModules.add({
            'title': title,
            'formation': formationTitle,
            'doneHours': done,
            'assignedHours': assigned,
            'progress': ratio,
          });
        }
      }
    }

    return allModules;
  }

  Widget _buildAttestationsSection() {
    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormations(),
      builder: (context, snapshot) {
        final formations = snapshot.data ?? _db.getFormations();
        final currentUser = _db.getUserById(widget.user.id) ?? widget.user;
        final assigned = currentUser.assignedFormations;

        final completedAndPaidList = <Map<String, dynamic>>[];

        for (final item in assigned) {
          final formationId = item['formationId']?.toString() ?? '';
          final formation = formations.where((f) => f.id == formationId).firstOrNull ??
              Formation(
                id: formationId,
                titre: item['title'] ?? 'Formation',
                description: '',
                modules: [],
                formateurIds: [],
                prix: 0,
                type: FormationType.presentielle,
                status: FormationStatus.enCours,
                dureeSemaines: 4,
                horaires: [],
                dateCreation: DateTime.now(),
              );

          final isCompleted = _db.isStudentFormationCompleted(
            studentId: currentUser.id,
            formationId: formationId,
          );

          final inscription = _db.getInscriptions().where((i) {
            final isUser = i.etudiantId == currentUser.id ||
                (i.email != null && i.email!.trim().toLowerCase() == currentUser.email.trim().toLowerCase());
            return isUser && i.formationId == formationId && i.status == InscriptionStatus.acceptee;
          }).firstOrNull;

          final balance = inscription != null ? _db.getInscriptionBalance(inscription.id) : 999999.0;
          final isPaid = inscription != null && (inscription.paiementEffectue || balance <= 0);

          if (isCompleted && isPaid) {
            completedAndPaidList.add({
              'formation': formation,
              'inscription': inscription,
            });
          }
        }

        if (completedAndPaidList.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎓 Vos Attestations Officielles Disponibles',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'Félicitations pour la réussite de vos formations ! Vos attestations certifiées sont prêtes à être téléchargées.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...completedAndPaidList.map((item) {
                final form = item['formation'] as Formation;
                final insc = item['inscription'] as Inscription?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            form.titre,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text('Télécharger PDF', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            try {
                              final targetInscription = insc ??
                                  Inscription(
                                    id: 'ins_${currentUser.id}_${form.id}',
                                    etudiantId: currentUser.id,
                                    formationId: form.id,
                                    status: InscriptionStatus.acceptee,
                                    dateInscription: DateTime.now(),
                                    paiementEffectue: true,
                                    nom: currentUser.nom,
                                    prenom: currentUser.prenom,
                                    email: currentUser.email,
                                    telephone: currentUser.phone,
                                    modules: form.modules,
                                  );

                              final pdfBytes = await PdfService().generateAttestationPdf(
                                inscription: targetInscription,
                                formation: form,
                              );

                              await PdfService().printOrDownloadPdf(
                                pdfBytes: pdfBytes,
                                filename: 'Attestation_${currentUser.prenom}_${currentUser.nom}_${form.titre}.pdf',
                              );

                              if (context.mounted) {
                                context.showSuccessSnack('Attestation téléchargée avec succès !');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                context.showErrorSnack('Erreur: $e');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
