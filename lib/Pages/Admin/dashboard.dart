import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/payment_report_service.dart';
import 'package:gestion_formations/Services/pdf_helper.dart';
import 'package:gestion_formations/Widgets/chart_widgets.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  final Function(int tabIndex)? onNavigateTab;

  const AdminDashboard({super.key, required this.user, this.onNavigateTab});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1100;
    final maxWidth = width > 1200 ? 1150.0 : width;
    final hp = isMobile ? 10.0 : isTablet ? 14.0 : 22.0;
    final vp = isMobile ? 10.0 : 22.0;
    final gap = isMobile ? 16.0 : 24.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              SizedBox(height: gap),
              _buildStatsGrid(isMobile, isTablet),
              SizedBox(height: gap),
              _buildQuickActionsGrid(isMobile),
              SizedBox(height: gap + 4),
              _buildFinancialAndTrainingCharts(isMobile),
              SizedBox(height: gap + 4),
              _buildMonthlyInscriptionsCard(isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              _buildPaymentDueAlertsSection(isMobile),
              SizedBox(height: gap + 4),
              _buildRecentActivities(isMobile),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 1. HEADER WITH QUICK SHARE BUTTON ==========
  Widget _buildHeader(bool isMobile) {
    final prenomStr = widget.user.prenom.trim();
    final nomStr = widget.user.nom.trim();
    final displayName = prenomStr.isNotEmpty ? prenomStr : (nomStr.isNotEmpty ? nomStr : 'Administrateur');

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
          boxShadow: AppTheme.heroShadow,
        ),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 22, vertical: isMobile ? 12 : 18),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bienvenue, $displayName 👋',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showShareFormationModal,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilotage académique & financier M@LINTIC',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Row(
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
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tableau de bord de pilotage académique et financier M@LINTIC.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(
                '🔗 Lien Public Formation',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _showShareFormationModal,
            ),
          ],
        ),
      ),
    );
  }

  // ========== 2. RICH KPI STATS GRID ==========
  Widget _buildStatsGrid(bool isMobile, bool isTablet) {
    return StreamBuilder<List<User>>(
      stream: _db.watchUsers(),
      builder: (context, userSnapshot) {
        final users = userSnapshot.data ?? [];
        final etudiants = users.where((u) => u.role == UserRole.apprenant).length;
        final totalFormations = _db.getFormations().length;

        final inscriptions = _db.getInscriptions();
        final pendingInscriptions = inscriptions.where((i) => i.status == InscriptionStatus.enAttente).length;

        final payments = _db.getPayments();
        final totalRevenue = payments
            .where((p) => p.status == PaymentStatus.effectue)
            .fold<double>(0, (sum, p) => sum + p.montant);

        // Compute total unpaid balance across accepted inscriptions
        final acceptedInscriptions = inscriptions.where((i) => i.status == InscriptionStatus.acceptee);
        final totalUnpaid = acceptedInscriptions.fold<double>(0, (sum, ins) {
          return sum + _db.getInscriptionBalance(ins.id);
        });

        final revenueFormatted = AppFormat.fcfaCompact(totalRevenue);

        final unpaidFormatted = AppFormat.fcfaCompact(totalUnpaid);

        final cols = isMobile ? 2 : (isTablet ? 3 : 4);
        final ratio = isMobile ? 1.15 : (isTablet ? 1.4 : 1.7);

        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: isMobile ? 8 : 12,
          mainAxisSpacing: isMobile ? 8 : 12,
          childAspectRatio: ratio,
          children: [
            _buildStatCard(
              title: 'Recettes Encaissées',
              value: revenueFormatted,
              subtitle: 'Encaissements validés',
              icon: Icons.payments_rounded,
              colors: const [AppTheme.success, AppTheme.successDark],
              onTap: () => widget.onNavigateTab?.call(5),
              chartWidget: MiniLineChart(
                data: const [20, 45, 60, 80, 75, 110, 140],
                colors: const [AppTheme.success, AppTheme.successDark],
                height: 38,
                width: 70,
              ),
            ),
            _buildStatCard(
              title: 'Reste à Recouvrer',
              value: unpaidFormatted,
              subtitle: 'Solde dû étudiants',
              icon: Icons.account_balance_wallet_rounded,
              colors: const [AppTheme.warningDark, AppTheme.accent],
              onTap: () => widget.onNavigateTab?.call(5),
              chartWidget: MiniBarChart(
                data: const [30, 25, 40, 15, 50, 35],
                colors: const [AppTheme.warningDark, AppTheme.accent],
                height: 38,
                width: 70,
              ),
            ),
            _buildStatCard(
              title: 'Demandes à Valider',
              value: '$pendingInscriptions',
              subtitle: 'En attente de contrôle',
              icon: Icons.assignment_late_rounded,
              colors: const [AppTheme.indigoAccent, AppTheme.purpleAccent],
              onTap: () => widget.onNavigateTab?.call(3),
              chartWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.indigoAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingInscriptions dossier(s)',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.indigoAccent),
                ),
              ),
            ),
            _buildStatCard(
              title: 'Étudiants Actifs',
              value: '$etudiants',
              subtitle: '$totalFormations formation(s)',
              icon: Icons.school_rounded,
              colors: const [AppTheme.primary, AppTheme.primaryDark],
              onTap: () => widget.onNavigateTab?.call(4),
              chartWidget: MiniPieChart(
                data: const {'Présentiel': 65, 'En Ligne': 35},
                colors: const [AppTheme.primary, AppTheme.accent],
                size: 38,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget chartWidget,
    VoidCallback? onTap,
  }) {
    final w = MediaQuery.of(context).size.width;
    final compact = w < 600;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(compact ? 14 : 18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        hoverColor: colors[0].withValues(alpha: 0.05),
        splashColor: colors[0].withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: colors[0].withValues(alpha: 0.18)),
          ),
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 7 : 10),
                    decoration: BoxDecoration(
                      color: colors[0].withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(compact ? 9 : 12),
                    ),
                    child: Icon(icon, color: colors[0], size: compact ? 16 : 20),
                  ),
                  if (!compact) chartWidget,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: compact ? 10 : 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: compact ? 15 : 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: compact ? 9 : 10, color: Colors.black45, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 3. QUICK ACTIONS GRID ==========
  Widget _buildQuickActionsGrid(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Text(
              'Actions Rapides',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _buildQuickActionButton(
              label: 'Nouveau Versement',
              icon: Icons.add_card_rounded,
              color: AppTheme.success,
              onTap: () => _showQuickPaymentModal(context),
            ),
            _buildQuickActionButton(
              label: 'Nouveau Stagiaire',
              icon: Icons.person_add_alt_1_rounded,
              color: AppTheme.primary,
              onTap: () => _showQuickAddStudentModal(context),
            ),
            _buildQuickActionButton(
              label: 'Demandes à Valider',
              icon: Icons.fact_check_rounded,
              color: AppTheme.warningDark,
              onTap: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(3);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Accédez à l\'onglet Inscriptions dans le menu.')),
                  );
                }
              },
            ),
            _buildQuickActionButton(
              label: 'Rapport Financier PDF',
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFE11D48),
              onTap: _exportFinancialSummaryPdf,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            color: color.withValues(alpha: 0.06),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 4. FINANCIAL & TRAINING CHARTS SECTION ==========
  Widget _buildFinancialAndTrainingCharts(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          return Column(
            children: [
              _buildMonthlyRevenueChartCard(),
              const SizedBox(height: 16),
              _buildTrainingDistributionChartCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildMonthlyRevenueChartCard()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildTrainingDistributionChartCard()),
          ],
        );
      },
    );
  }

  /// Calcule les encaissements réels des 6 derniers mois
  List<double> _computeMonthlyRevenue() {
    final payments = _db.getPayments();
    final now = DateTime.now();
    final result = List<double>.filled(6, 0);
    for (final p in payments) {
      if (p.status.name != 'effectue') continue;
      final payDate = p.dateEffectuation ?? p.dateCreation;
      final monthsAgo = (now.year - payDate.year) * 12 + (now.month - payDate.month);
      if (monthsAgo >= 0 && monthsAgo < 6) {
        result[5 - monthsAgo] = result[5 - monthsAgo] + p.montant;
      }
    }
    return result;
  }

  /// Calcule les inscriptions réelles des 6 derniers mois
  List<double> _computeMonthlyInscriptions() {
    final inscriptions = _db.getInscriptions();
    final now = DateTime.now();
    final result = List<double>.filled(6, 0);
    for (final ins in inscriptions) {
      final monthsAgo = (now.year - ins.dateInscription.year) * 12 + (now.month - ins.dateInscription.month);
      if (monthsAgo >= 0 && monthsAgo < 6) {
        result[5 - monthsAgo] += 1;
      }
    }
    return result;
  }

  /// Calcule la variation % du mois courant vs mois précédent
  String _computeVariationLabel(List<double> data) {
    if (data.length < 2) return 'N/A';
    final current = data[data.length - 1];
    final prev = data[data.length - 2];
    if (prev == 0) return current > 0 ? '+100%' : '0%';
    final pct = ((current - prev) / prev * 100).round();
    return pct >= 0 ? '+$pct%' : '$pct%';
  }

  Widget _buildMonthlyRevenueChartCard() {
    final revenueData = _computeMonthlyRevenue();
    final varLabel = _computeVariationLabel(revenueData);
    final isPositive = varLabel.startsWith('+');
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      const names = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      return names[(d.month - 1) % 12];
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Évolution des Recettes (FCFA)',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Encaissements réels — 6 derniers mois',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? AppTheme.success : AppTheme.error).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$varLabel ce mois',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: isPositive ? AppTheme.success : AppTheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: MiniLineChart(
              data: revenueData.isEmpty ? [0, 0, 0, 0, 0, 0] : revenueData,
              colors: const [AppTheme.primary, AppTheme.accent],
              height: 160,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months.map((m) => Text(
              m,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingDistributionChartCard() {
    final formations = _db.getFormations();
    final presentielCount = formations.where((f) => f.type.name == 'presentiel').length;
    final enLigneCount = formations.where((f) => f.type.name == 'enligne').length;
    final mixteCount = formations.where((f) => f.type.name == 'mixte').length;

    final dataMap = {
      'Présentiel': presentielCount > 0 ? presentielCount.toDouble() : 4.0,
      'En Ligne': enLigneCount > 0 ? enLigneCount.toDouble() : 2.0,
      'Mixte / Stage SFP': mixteCount > 0 ? mixteCount.toDouble() : 3.0,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition des Formations',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          Text(
            'Par modalité d\'apprentissage',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MiniPieChart(
                data: dataMap,
                colors: const [AppTheme.primary, AppTheme.accent, AppTheme.success],
                size: 70,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Présentiel', AppTheme.primary),
                    const SizedBox(height: 6),
                    _buildLegendItem('En Ligne', AppTheme.accent),
                    const SizedBox(height: 6),
                    _buildLegendItem('Mixte / Stage SFP', AppTheme.success),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ========== 5. PAYMENT DUE ALERTS SECTION ==========
  Widget _buildMonthlyInscriptionsCard(bool isMobile) {
    final inscData = _computeMonthlyInscriptions();
    final varLabel = _computeVariationLabel(inscData);
    final isPositive = varLabel.startsWith('+');
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      const names = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      return names[(d.month - 1) % 12];
    });
    final totalThis = inscData.isEmpty ? 0 : inscData.last.toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.indigoAccent.withValues(alpha: 0.15)),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📈 Nouvelles Inscriptions par Mois',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Demandes enregistrées — 6 derniers mois',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.indigoAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalThis ce mois',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.indigoAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPositive ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      varLabel,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: isPositive ? AppTheme.success : AppTheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: MiniBarChart(
              data: inscData.isEmpty ? [0, 0, 0, 0, 0, 0] : inscData,
              colors: const [AppTheme.indigoAccent, AppTheme.purpleAccent],
              height: 120,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: months.map((m) => Text(
              m,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDueAlertsSection(bool isMobile) {
    final acceptedInscriptions = _db.getInscriptions().where((i) => i.status == InscriptionStatus.acceptee).toList();
    final debtors = acceptedInscriptions.where((i) => _db.getInscriptionBalance(i.id) > 0).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.warningDark, size: 22),
                const SizedBox(width: 8),
                Text(
                  '⏰ Relances & Solde Dû par Stagiaire',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ],
            ),
            Text(
              '${debtors.length} alerte(s)',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warningDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (debtors.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                const SizedBox(width: 10),
                Text('Tous les étudiants inscrits sont à jour de leur règlement !', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: debtors.length,
            itemBuilder: (context, idx) {
              final ins = debtors[idx];
              final student = _db.getUserById(ins.etudiantId);
              final formation = _db.getFormationById(ins.formationId);
              final balance = _db.getInscriptionBalance(ins.id);

              final studentName = student != null ? '${student.prenom} ${student.nom}' : (ins.prenom ?? 'Stagiaire');
              final phone = student?.phone ?? ins.telephone ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                      child: Text(studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.warningDark)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          Text(formation?.titre ?? 'Formation', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Reste: ${AppFormat.fcfa(balance)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            side: const BorderSide(color: AppTheme.success),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.phone, size: 12, color: AppTheme.success),
                          label: Text(phone.isNotEmpty ? phone : 'Relancer', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.success)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: phone));
                            context.showSuccessSnack('Numéro $phone copié pour relance !');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ========== 6. RECENT ACTIVITIES & AUDIT STREAM ==========
  Widget _buildRecentActivities(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📜 Flux des Activités Récentes & Audit',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'Dernières opérations système enregistrées',
          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _getRecentActivities(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.primary)));
            }

            final activities = snapshot.data ?? [];
            if (activities.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Text('Aucune activité récente', style: GoogleFonts.poppins(color: AppTheme.textMuted)),
              );
            }

            return ListView.builder(
              itemCount: activities.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _getActivityColors(activity['type'].toString())),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_getActivityIcon(activity['type'].toString()), color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title'].toString(),
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                activity['description'].toString(),
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          activity['time'].toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ========== HELPER LOGIC & MODALS ==========
  void _showShareFormationModal() {
    final formations = _db.getFormations();
    if (formations.isEmpty) {
      context.showSnack('Aucune formation disponible pour le partage.');
      return;
    }

    Formation selected = formations.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.share_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Partager une Formation', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisir la formation à partager :', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Formation>(
                  initialValue: selected,
                  isExpanded: true,
                  items: formations.map((f) => DropdownMenuItem(value: f, child: Text(f.titre))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selected = val);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Vous pouvez générer les QR Codes et liens pour un partage à distance (Internet / WhatsApp) ou local (Wi-Fi de l\'établissement).',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: const Text('Afficher QR & Liens (LAN/Public)'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ShareFormationDialog.show(context, selected);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickPaymentModal(BuildContext context) {
    String? selectedStudentId;
    String? selectedFormationId;
    double montant = 0;
    double remise = 0;
    int trancheNum = 1;
    int nombreTranches = 1;
    PaymentMethod method = PaymentMethod.orangeMoney;

    final amountController = TextEditingController();
    final motifController = TextEditingController();
    List<Map<String, dynamic>> studentFormations = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double baseTotal = 0;
          double netTotal = 0;
          double alreadyPaid = 0;
          double balanceDue = 0;

          if (selectedStudentId != null && selectedFormationId != null) {
            final inscription = _db.getInscriptions().where(
              (item) => item.etudiantId == selectedStudentId && item.formationId == selectedFormationId,
            ).firstOrNull;

            baseTotal = _db.getFormationModulesTotal(
              selectedFormationId!,
              moduleIds: inscription?.modules,
              typeFormation: inscription?.typeFormation,
            );
            netTotal = (baseTotal - remise).clamp(0, double.infinity).toDouble();
            alreadyPaid = inscription != null ? _db.getInscriptionPaidAmount(inscription.id) : 0;
            balanceDue = (netTotal - alreadyPaid).clamp(0, double.infinity).toDouble();
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              '➕ Enregistrer un Nouveau Versement',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Stagiaire', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedStudentId,
                      hint: const Text('Choisir un stagiaire'),
                      items: _db.getUsers().where((u) => u.role == UserRole.apprenant).map((u) {
                        return DropdownMenuItem(value: u.id, child: Text('${u.prenom} ${u.nom} (${u.email})'));
                      }).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          selectedStudentId = v;
                          if (v != null) {
                            final student = _db.getUserById(v);
                            final assignedIds = student?.assignedFormations
                                    .map((item) => item['formationId']?.toString())
                                    .whereType<String>()
                                    .toSet() ??
                                <String>{};
                            final inscriptionIds = _db
                                .getInscriptions()
                                .where((item) => item.etudiantId == v)
                                .map((item) => item.formationId)
                                .toSet();

                            final list = _db
                                .getFormations()
                                .where((f) => assignedIds.contains(f.id) || inscriptionIds.contains(f.id))
                                .map((f) => {'id': f.id, 'titre': f.titre})
                                .toList();
                            studentFormations = list;
                            selectedFormationId = list.isNotEmpty ? list.first['id'].toString() : null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedStudentId != null) ...[
                      Text('Formation / Session', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedFormationId,
                        hint: const Text('Choisir une formation'),
                        items: studentFormations.map((f) {
                          return DropdownMenuItem(value: f['id'].toString(), child: Text(f['titre'].toString()));
                        }).toList(),
                        onChanged: (v) {
                          setModalState(() => selectedFormationId = v);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (selectedFormationId != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Prix Brut Initial:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                                Text(AppFormat.fcfa(baseTotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Remise Accordée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent)),
                                Text('- ${AppFormat.fcfa(remise)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Net Dû (Après Remise):', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                Text(AppFormat.fcfa(netTotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Somme Déjà Versée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.success)),
                                Text(AppFormat.fcfa(alreadyPaid), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Solde Restant à Payer:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warningDark)),
                                Text(AppFormat.fcfa(balanceDue), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.warningDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.accent, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.local_offer_rounded, color: AppTheme.accent, size: 20),
                          label: Text(
                            remise > 0
                                ? '🏷️ Remise Appliquée: ${AppFormat.fcfa(remise)} (Modifier)'
                                : '🏷️ Accorder une Remise (Décision Manuelle)',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent),
                          ),
                          onPressed: () {
                            _showApplyDiscountModal(
                              parentContext: ctx,
                              setDialogState: setModalState,
                              basePrice: baseTotal,
                              currentDiscount: remise,
                              onApplyDiscount: (val, motif) {
                                setModalState(() {
                                  remise = val;
                                  if (motif != null && motif.isNotEmpty) {
                                    motifController.text = motif;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Montant Versé (FCFA)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => montant = double.tryParse(v) ?? 0,
                    ),
                    const SizedBox(height: 16),
                    Text('Méthode de Règlement', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: method,
                      items: const [
                        DropdownMenuItem(value: PaymentMethod.orangeMoney, child: Text('Orange Money')),
                        DropdownMenuItem(value: PaymentMethod.moovMoney, child: Text('Moov Money')),
                        DropdownMenuItem(value: PaymentMethod.virement, child: Text('Virement Bancaire')),
                        DropdownMenuItem(value: PaymentMethod.especes, child: Text('Espèces')),
                        DropdownMenuItem(value: PaymentMethod.carte, child: Text('Carte Bancaire')),
                      ],
                      onChanged: (v) => setModalState(() => method = v ?? PaymentMethod.orangeMoney),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Valider le Versement'),
                onPressed: () async {
                  if (selectedStudentId == null || selectedFormationId == null) {
                    ctx.showSnack('Sélectionnez un stagiaire et une formation.');
                    return;
                  }

                  final inscription = _db.getInscriptions().where(
                    (item) => item.etudiantId == selectedStudentId && item.formationId == selectedFormationId,
                  ).firstOrNull;

                  if (inscription == null) {
                    ctx.showSnack('Inscription introuvable.');
                    return;
                  }

                  final m = montant > 0 ? montant : (double.tryParse(amountController.text) ?? 0);

                  final payment = Payment(
                    id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
                    inscriptionId: inscription.id,
                    etudiantId: selectedStudentId!,
                    formationId: selectedFormationId!,
                    montant: m,
                    status: PaymentStatus.effectue,
                    methode: method,
                    dateCreation: DateTime.now(),
                    dateEffectuation: DateTime.now(),
                    referenceTransaction: 'OM-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                    trancheNumero: trancheNum,
                    nombreTranches: nombreTranches,
                    remise: remise,
                    motif: motifController.text.isNotEmpty ? motifController.text : 'Versement Tranche $trancheNum',
                  );

                  await _db.addPayment(payment);
                  await _db.logAction(
                    userNom: widget.user.nomComplet,
                    userRole: 'Admin',
                    action: 'Nouveau Versement',
                    description: 'Versement de ${AppFormat.fcfa(m)} enregistré pour ${inscription.id}',
                  );

                  if (mounted && ctx.mounted) {
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Versement enregistré avec succès !'), backgroundColor: AppTheme.success),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickAddStudentModal(BuildContext context) {
    final prenomCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '00000000');
    final formations = _db.getFormations();
    String? selectedFormationId = formations.isNotEmpty ? formations.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('👥 Nouveau Stagiaire / Étudiant', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prénom', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: prenomCtrl,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 12),
                    Text('Nom', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nomCtrl,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 12),
                    Text('Email Identifiant (@malintic.ml)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        hintText: 'ex: amadou.traore@malintic.ml',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Téléphone', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 12),
                    Text('Mot de Passe par Défaut', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: passCtrl,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(height: 12),
                    Text('Formation à Affecter', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFormationId,
                      isExpanded: true,
                      items: formations.map((f) => DropdownMenuItem(value: f.id, child: Text(f.titre))).toList(),
                      onChanged: (v) => setModalState(() => selectedFormationId = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Créer le Stagiaire'),
                onPressed: () async {
                  final prenom = prenomCtrl.text.trim();
                  final nom = nomCtrl.text.trim();
                  var email = emailCtrl.text.trim().toLowerCase();
                  final phone = phoneCtrl.text.trim();

                  if (prenom.isEmpty || nom.isEmpty) {
                    ctx.showSnack('Veuillez remplir au moins le prénom et le nom.');
                    return;
                  }

                  if (email.isEmpty) {
                    final cleanPrenom = prenom.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                    final cleanNom = nom.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                    email = '$cleanPrenom.$cleanNom@malintic.ml';
                  } else if (!email.endsWith('@malintic.ml')) {
                    email = '${email.split('@').first}@malintic.ml';
                  }

                  final newStudent = User(
                    id: 'std_${DateTime.now().millisecondsSinceEpoch}',
                    email: email,
                    nom: nom,
                    prenom: prenom,
                    phone: phone,
                    role: UserRole.apprenant,
                    estActif: true,
                    assignedFormations: selectedFormationId != null ? [{'formationId': selectedFormationId}] : [],
                    dateCreation: DateTime.now(),
                    dateModification: DateTime.now(),
                  );

                  await _db.addUser(newStudent);
                  await _db.logAction(
                    userNom: widget.user.nomComplet,
                    userRole: 'Admin',
                    action: 'Nouveau Stagiaire',
                    description: 'Création rapide du stagiaire $prenom $nom ($email)',
                  );

                  if (mounted && ctx.mounted) {
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Stagiaire $prenom $nom ($email) créé avec succès !'), backgroundColor: AppTheme.success),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApplyDiscountModal({
    required BuildContext parentContext,
    required StateSetter setDialogState,
    required double basePrice,
    required double currentDiscount,
    required Function(double val, String? motif) onApplyDiscount,
  }) {
    final discountValController = TextEditingController(text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '');
    final reasonController = TextEditingController();
    bool isPercentage = false;
    double calculatedDiscount = currentDiscount;

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final netPrice = (basePrice - calculatedDiscount).clamp(0, double.infinity);

          void recalculate(String val) {
            final raw = double.tryParse(val.trim()) ?? 0;
            if (isPercentage) {
              calculatedDiscount = (basePrice * (raw / 100)).clamp(0, basePrice);
            } else {
              calculatedDiscount = raw.clamp(0, basePrice);
            }
            setModalState(() {});
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('Accorder une Remise (Décision Manuelle)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Prix Brut Initial:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                            Text(AppFormat.fcfa(basePrice), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Remise Accordée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent)),
                            Text('- ${AppFormat.fcfa(calculatedDiscount)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Nouveau Total Net à Payer:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text(AppFormat.fcfa(netPrice), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Type de Remise', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Montant Fixe (FCFA)', style: GoogleFonts.poppins(fontSize: 11))),
                          selected: !isPercentage,
                          onSelected: (sel) {
                            setModalState(() {
                              isPercentage = false;
                              recalculate(discountValController.text);
                            });
                          },
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(color: !isPercentage ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('Pourcentage (%)', style: GoogleFonts.poppins(fontSize: 11))),
                          selected: isPercentage,
                          onSelected: (sel) {
                            setModalState(() {
                              isPercentage = true;
                              recalculate(discountValController.text);
                            });
                          },
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(color: isPercentage ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(isPercentage ? 'Pourcentage (%)' : 'Valeur de la Remise (FCFA)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: discountValController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: isPercentage ? 'Ex: 10 pour 10%' : 'Ex: 15000 pour 15 000 FCFA',
                      prefixIcon: Icon(isPercentage ? Icons.percent : Icons.payments_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: recalculate,
                  ),
                  const SizedBox(height: 12),
                  Text('Raccourcis Rapides', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: isPercentage
                        ? [5, 10, 15, 20, 25, 50].map((pct) {
                            return ActionChip(
                              label: Text('$pct%'),
                              onPressed: () {
                                discountValController.text = pct.toString();
                                recalculate(pct.toString());
                              },
                            );
                          }).toList()
                        : [5000, 10000, 15000, 25000, 50000].map((amt) {
                            return ActionChip(
                              label: Text(AppFormat.fcfaCompact(amt)),
                              onPressed: () {
                                discountValController.text = amt.toString();
                                recalculate(amt.toString());
                              },
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Motif / Libellé de la Remise (Optionnel)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'Ex: Offre Spéciale SFP5 / Remise Partenaire',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Valider la Remise'),
                onPressed: () {
                  final m = reasonController.text.trim().isNotEmpty ? 'Remise: ${reasonController.text.trim()}' : null;
                  onApplyDiscount(calculatedDiscount, m);
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportFinancialSummaryPdf() async {
    final payments = _db.getPayments();
    final effectues = payments.where((p) => p.status == PaymentStatus.effectue).toList();

    final List<Map<String, dynamic>> reportData = effectues.map((p) {
      final student = _db.getUserById(p.etudiantId);
      final inscription = _db.getInscriptions().where((i) => i.id == p.etudiantId || (student != null && (i.telephone == student.phone || (i.prenom == student.prenom && i.nom == student.nom)))).firstOrNull;
      final formation = _db.getFormationById(p.formationId) ?? (inscription != null ? _db.getFormationById(inscription.formationId) : null);

      final studentName = student?.nomComplet ??
          (inscription != null ? '${inscription.prenom ?? ""} ${inscription.nom ?? ""}'.trim() : 'Apprenant');

      final userMatricule = student?.matricule ?? _db.getUsers().where((u) => u.phone == inscription?.telephone || (inscription != null && u.nom == inscription.nom && u.prenom == inscription.prenom)).firstOrNull?.matricule;
      final matricule = userMatricule?.isNotEmpty == true
          ? userMatricule!
          : 'MAT-${p.etudiantId.length > 6 ? p.etudiantId.substring(0, 6) : p.etudiantId}';

      final phone = student?.phone ?? inscription?.telephone ?? '';

      return {
        'id': p.id,
        'reference': p.referenceTransaction ?? p.id,
        'date': '${p.dateCreation.day.toString().padLeft(2, '0')}/${p.dateCreation.month.toString().padLeft(2, '0')}/${p.dateCreation.year}',
        'studentName': studentName,
        'stagiaire': studentName,
        'matricule': matricule,
        'phone': phone,
        'formation': formation?.titre ?? 'Formation Professionnelle',
        'montant': p.montant,
        'remise': p.remise,
        'status': 'Effectué',
        'methode': p.methode.name.toUpperCase(),
      };
    }).toList();

    final totalAmount = effectues.fold<double>(0, (sum, p) => sum + p.montant);
    final statusCounts = {'Effectué': effectues.length};

    final bytes = await PaymentReportService.generatePaymentReportPDF(
      payments: reportData,
      statusCounts: statusCounts,
      totalAmount: totalAmount,
    );

    await PdfHelper.downloadPDF(bytes, fileName: 'Rapport_Financier_M@LINTIC_${DateTime.now().millisecondsSinceEpoch}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Rapport financier PDF généré et téléchargé avec succès !'), backgroundColor: AppTheme.success),
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentActivities() async {
    final List<Map<String, dynamic>> activities = [];

    // Audit logs
    final logs = _db.getAuditLogs();
    for (var log in logs) {
      activities.add({
        'title': log.action,
        'description': '${log.userNom} (${log.userRole}): ${log.description}',
        'time': '${log.timestamp.day}/${log.timestamp.month} à ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
        'type': 'audit',
        'timestamp': log.timestamp.millisecondsSinceEpoch,
      });
    }

    // Payments
    final payments = _db.getPayments();
    for (var p in payments) {
      final student = _db.getUserById(p.etudiantId);
      final studentName = student != null ? '${student.prenom} ${student.nom}' : 'Étudiant';
      activities.add({
        'title': 'Paiement ${AppFormat.fcfa(p.montant)}',
        'description': '$studentName - Motif: ${p.motif ?? "Versement"} (${p.methode.name.toUpperCase()})',
        'time': '${p.dateCreation.day}/${p.dateCreation.month}',
        'type': 'payment',
        'timestamp': p.dateCreation.millisecondsSinceEpoch,
      });
    }

    // Users
    final users = _db.getUsers();
    for (var u in users) {
      activities.add({
        'title': u.role == UserRole.formateur ? 'Nouveau formateur' : 'Nouvel étudiant',
        'description': u.nomComplet,
        'time': '${u.dateCreation.day}/${u.dateCreation.month}',
        'type': u.role == UserRole.formateur ? 'user_formateur' : 'user_etudiant',
        'timestamp': u.dateCreation.millisecondsSinceEpoch,
      });
    }

    // Formations
    final formations = _db.getFormations();
    for (var f in formations) {
      activities.add({
        'title': 'Nouvelle formation',
        'description': f.titre,
        'time': '${f.dateCreation.day}/${f.dateCreation.month}',
        'type': 'formation',
        'timestamp': f.dateCreation.millisecondsSinceEpoch,
      });
    }

    activities.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    return activities.take(15).toList();
  }

  IconData _getActivityIcon(String type) {
    if (type == 'user_formateur') return Icons.person_add_rounded;
    if (type == 'user_etudiant') return Icons.school_rounded;
    if (type == 'formation') return Icons.book_rounded;
    if (type == 'payment') return Icons.payments_rounded;
    if (type == 'audit') return Icons.history_rounded;
    return Icons.info_rounded;
  }

  List<Color> _getActivityColors(String type) {
    if (type == 'user_formateur') {
      return [AppTheme.primary, AppTheme.primaryDark];
    } else if (type == 'user_etudiant') {
      return [AppTheme.indigoAccent, AppTheme.purpleAccent];
    } else if (type == 'formation') {
      return [AppTheme.primary, AppTheme.primaryDark];
    } else if (type == 'payment') {
      return [AppTheme.success, AppTheme.successDark];
    } else if (type == 'audit') {
      return [AppTheme.warningDark, AppTheme.accent];
    }
    return [AppTheme.primary, AppTheme.primaryDark];
  }
}
