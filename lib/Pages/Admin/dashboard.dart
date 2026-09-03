import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Widgets/chart_widgets.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';
import 'package:gestion_formations/Widgets/export_accounting_dialog.dart';
import 'package:gestion_formations/Widgets/quick_formation_preset_dialog.dart';

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
  StreamSubscription<void>? _dataSub;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Réactivité instantanée lors de toute modification sur la plateforme
    _dataSub = _db.watchAllDataChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataSub?.cancel();
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
              _buildProfitabilitySection(isMobile),
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
                          'Bienvenue, $displayName',
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
                'Lien public formation',
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
    return StreamBuilder<List<Payment>>(
      stream: _db.watchPayments(),
      builder: (context, paymentSnapshot) {
        final kpis = _db.getFinancialKpis();
        final totalRevenue = (kpis['totalReceived'] as num?)?.toDouble() ?? 0.0;
        final totalUnpaid = (kpis['totalBalance'] as num?)?.toDouble() ?? 0.0;
        final pendingInscriptions = (kpis['pendingCount'] as num?)?.toInt() ?? 0;
        final recoveryRate = (kpis['recoveryRate'] as num?)?.toDouble() ?? 0.0;

        final deletedUserIds = _db.getDeletedDocs('users');
        final deletedUserEmails = _db.getDeletedDocs('user_emails');
        final users = _db.getUsers().where((u) {
          final email = u.email.trim().toLowerCase();
          return !deletedUserIds.contains(u.id) &&
              (email.isEmpty || !deletedUserEmails.contains(email));
        }).toList();

        final etudiants = users.where((u) => u.role == UserRole.apprenant).length;
        final totalFormations = _db.getFormations().length;

        final revenueFormatted = totalRevenue >= 1000000
            ? '${(totalRevenue / 1000000).toStringAsFixed(2)}M FCFA'
            : '${totalRevenue.toStringAsFixed(0)} FCFA';

        final unpaidFormatted = totalUnpaid >= 1000000
            ? '${(totalUnpaid / 1000000).toStringAsFixed(2)}M FCFA'
            : '${totalUnpaid.toStringAsFixed(0)} FCFA';

        final cols = isMobile ? 2 : (isTablet ? 3 : 4);
        final ratio = isMobile ? 1.25 : (isTablet ? 1.45 : 1.75);

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
              subtitle: '${recoveryRate.toStringAsFixed(1)}% recouvré',
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
              subtitle: 'Solde dû stagiaires',
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: compact ? 16 : 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
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
    final actions = [
      {
        'label': 'Nouveau Versement',
        'icon': Icons.add_card_rounded,
        'color': AppTheme.success,
        'bg': const Color(0xFFECFDF5),
        'onTap': () => _showQuickPaymentModal(context),
      },
      {
        'label': 'Nouveau Stagiaire',
        'icon': Icons.person_add_alt_1_rounded,
        'color': AppTheme.primary,
        'bg': const Color(0xFFEFF6FF),
        'onTap': () => _showQuickAddStudentModal(context),
      },
      {
        'label': 'Demandes à Valider',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'onTap': () {
          if (widget.onNavigateTab != null) {
            widget.onNavigateTab!(3);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Accédez à l\'onglet Inscriptions dans le menu.')),
            );
          }
        },
      },
      {
        'label': 'Modèles Formation 1-Clic',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF7E22CE),
        'bg': const Color(0xFFFAF5FF),
        'onTap': () => QuickFormationPresetDialog.show(context),
      },
      {
        'label': 'Exports & Rapports',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFFDC2626),
        'bg': const Color(0xFFFEF2F2),
        'onTap': () => ExportAccountingDialog.show(context),
      },
    ];

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
        if (isMobile)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final a = actions[index];
              final col = a['color'] as Color;
              final bg = a['bg'] as Color;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: a['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: col.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(a['icon'] as IconData, color: col, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: actions.map((a) {
              final col = a['color'] as Color;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: a['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: col.withValues(alpha: 0.3)),
                      color: (a['bg'] as Color).withValues(alpha: 0.6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a['icon'] as IconData, size: 18, color: col),
                        const SizedBox(width: 8),
                        Text(
                          a['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: col,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ========== 3.5 PROFITABILITY & PERFORMANCE SECTION ==========
  Widget _buildProfitabilitySection(bool isMobile) {
    final profitability = _db.getFormationsProfitability();
    if (profitability.isEmpty) return const SizedBox.shrink();

    final totalEncaisse = profitability.fold<double>(0.0, (sum, p) => sum + (p['totalEncaisse'] as double));
    final totalCoutFormateurs = profitability.fold<double>(0.0, (sum, p) => sum + (p['coutFormateurs'] as double));
    final margeNetteGlobale = totalEncaisse - totalCoutFormateurs;
    final margeGlobalePct = totalEncaisse > 0 ? ((margeNetteGlobale / totalEncaisse) * 100).clamp(-100.0, 100.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFF1D447A).withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header : icon + titre + badge marge globale (responsive)
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D447A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF1D447A), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rentabilité & Performance',
                                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1D447A)),
                              ),
                              Text(
                                'Recettes vs Masse salariale',
                                style: GoogleFonts.poppins(fontSize: 10.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            margeNetteGlobale >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 14,
                            color: margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${margeGlobalePct.toStringAsFixed(1)}% Marge globale',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
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
                            color: const Color(0xFF1D447A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF1D447A), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rentabilité & Performance des Formations',
                              style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF1D447A)),
                            ),
                            Text(
                              'Recettes encaissées vs Masse salariale formateurs',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            margeNetteGlobale >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 14,
                            color: margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${margeGlobalePct.toStringAsFixed(1)}% Marge',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: margeNetteGlobale >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 14),

          // Mini KPI Summary Bar (responsive : column sur mobile)
          Container(
            padding: const EdgeInsets.all(12),
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
                    children: [
                      _buildProfitKpiItem('CA Encaissé', '${totalEncaisse.toStringAsFixed(0)} F', const Color(0xFFD4AF37)),
                      Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 1, color: Colors.white24),
                      _buildProfitKpiItem('Coût Formateurs', '${totalCoutFormateurs.toStringAsFixed(0)} F', const Color(0xFFFCA5A5)),
                      Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 1, color: Colors.white24),
                      _buildProfitKpiItem('Marge Nette', '${margeNetteGlobale.toStringAsFixed(0)} F', const Color(0xFF86EFAC)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfitKpiItem('Chiffre d\'Affaires Encaissé', '${totalEncaisse.toStringAsFixed(0)} F', const Color(0xFFD4AF37)),
                      Container(height: 28, width: 1, color: Colors.white24),
                      _buildProfitKpiItem('Coût Formateurs', '${totalCoutFormateurs.toStringAsFixed(0)} F', const Color(0xFFFCA5A5)),
                      Container(height: 28, width: 1, color: Colors.white24),
                      _buildProfitKpiItem('Marge Nette Globale', '${margeNetteGlobale.toStringAsFixed(0)} F', const Color(0xFF86EFAC)),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Formation Profitability List
          ...profitability.take(isMobile ? 3 : 5).map((p) {
            final titre = p['formationTitre'] as String;
            final nb = p['nbInscrits'] as int;
            final encaisse = p['totalEncaisse'] as double;
            final cout = p['coutFormateurs'] as double;
            final marge = p['margeNette'] as double;
            final pct = p['margePct'] as double;
            final isProfitable = p['estRentable'] as bool;

            final ratio = (encaisse > 0 && cout > 0) ? (cout / encaisse).clamp(0.0, 1.0) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : titre + badge inscrits
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titre,
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$nb inscrit(s)',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Ligne 2 : badge marge (pleine largeur sur mobile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isProfitable ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Marge : ${marge.toStringAsFixed(0)} F (${pct.toStringAsFixed(0)}%)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isProfitable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Ligne 3 : recettes / coût (Wrap pour éviter overflow)
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        'Recettes : ${encaisse.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text('•', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      Text(
                        'Coût : ${cout.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isProfitable ? (1.0 - ratio).clamp(0.05, 1.0) : 0.05,
                      backgroundColor: const Color(0xFFFCA5A5),
                      valueColor: AlwaysStoppedAnimation<Color>(isProfitable ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfitKpiItem(String title, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
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
    final deletedInscIds = _db.getDeletedDocs('inscriptions');
    final deletedUserIds = _db.getDeletedDocs('users');
    final deletedUserEmails = _db.getDeletedDocs('user_emails');

    final inscriptions = _db.getInscriptions().where((i) {
      final email = (i.email ?? '').trim().toLowerCase();
      return !deletedInscIds.contains(i.id) &&
          !deletedUserIds.contains(i.etudiantId) &&
          !deletedUserIds.contains(i.id) &&
          (email.isEmpty || !deletedUserEmails.contains(email));
    });

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
                    'Nouvelles inscriptions par mois',
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
    final debtors = acceptedInscriptions.where((i) => _db.getInscriptionBalance(i.id) > 0).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningDark, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  '⏰ Relances & Suivi des Impayés',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: debtors.isEmpty ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${debtors.length} dossier(s) en attente',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: debtors.isEmpty ? AppTheme.success : AppTheme.warningDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (debtors.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Parfait ! Tous les étudiants inscrits sont à 100% à jour de leur règlement.',
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.success),
                  ),
                ),
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
              final totalDue = _db.getInscriptionTotalDue(ins.id);
              final paid = _db.getInscriptionPaidAmount(ins.id);
              final balance = _db.getInscriptionBalance(ins.id);
              final progressPct = totalDue > 0 ? (paid / totalDue).clamp(0.0, 1.0) : 0.0;

              final studentName = student != null ? '${student.prenom} ${student.nom}' : (ins.prenom ?? 'Stagiaire');
              final phone = (student?.phone ?? ins.telephone ?? '').replaceAll(RegExp(r'\s+'), '');
              final formationTitle = formation?.titre ?? 'Formation M@LI-NTIC';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                          child: Text(
                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.warningDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formationTitle,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Solde: ${balance.toStringAsFixed(0)} FCFA',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.accent),
                            ),
                            Text(
                              'Payé: ${paid.toStringAsFixed(0)} / ${totalDue.toStringAsFixed(0)} F',
                              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(progressPct >= 0.75 ? AppTheme.success : AppTheme.warning),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // WhatsApp Direct Relance
                        if (phone.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: Text('WhatsApp', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () async {
                              final cleanPhone = phone.startsWith('+') ? phone.substring(1) : (phone.startsWith('00') ? phone.substring(2) : '223$phone');
                              final msg = Uri.encodeComponent(
                                'Bonjour $studentName, le centre M@LI-NTIC vous informe qu\'il vous reste un solde de ${balance.toStringAsFixed(0)} FCFA pour votre inscription à la formation "$formationTitle". Merci de contacter la comptabilité pour régulariser votre dossier et éditer votre reçu officiel.',
                              );
                              final waUrl = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
                              if (await canLaunchUrl(waUrl)) {
                                await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  Clipboard.setData(ClipboardData(text: phone));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numéro $phone copié !'), backgroundColor: AppTheme.success));
                                }
                              }
                            },
                          ),
                        const SizedBox(width: 6),
                        // Copier / Appel
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 12, color: AppTheme.primary),
                          label: Text(phone.isNotEmpty ? phone : 'Appeler', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: phone));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact $studentName ($phone) copié !'), backgroundColor: AppTheme.success));
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
          'Flux des activités récentes et audit',
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune formation disponible pour le partage.')));
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
    final trancheNumController = TextEditingController(text: '1');
    final totalTranchesController = TextEditingController(text: '1');
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

                            if (selectedFormationId != null) {
                              final insc = _db.getInscriptions().where(
                                (item) => item.etudiantId == v && item.formationId == selectedFormationId,
                              ).firstOrNull;
                              if (insc != null) {
                                remise = _db.getInscriptionDiscountTotal(insc.id);
                                final history = _db.getPaymentsForInscription(insc.id);
                                final settled = history.where((p) => p.status == PaymentStatus.effectue).toList();
                                trancheNum = settled.isEmpty
                                    ? 1
                                    : settled.map((p) => p.trancheNumero).reduce((a, b) => a > b ? a : b) + 1;
                                nombreTranches = history.isNotEmpty ? history.first.nombreTranches : (trancheNum > 1 ? trancheNum : 1);
                                if (trancheNum > nombreTranches) nombreTranches = trancheNum;
                                trancheNumController.text = '$trancheNum';
                                totalTranchesController.text = '$nombreTranches';
                                final b = _db.getInscriptionBalance(insc.id);
                                amountController.text = b.toStringAsFixed(0);
                                montant = b;
                                motifController.text = 'Versement Tranche $trancheNum';
                              }
                            }
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
                          setModalState(() {
                            selectedFormationId = v;
                            if (v != null && selectedStudentId != null) {
                              final insc = _db.getInscriptions().where(
                                (item) => item.etudiantId == selectedStudentId && item.formationId == v,
                              ).firstOrNull;
                              if (insc != null) {
                                remise = _db.getInscriptionDiscountTotal(insc.id);
                                final history = _db.getPaymentsForInscription(insc.id);
                                final settled = history.where((p) => p.status == PaymentStatus.effectue).toList();
                                trancheNum = settled.isEmpty
                                    ? 1
                                    : settled.map((p) => p.trancheNumero).reduce((a, b) => a > b ? a : b) + 1;
                                nombreTranches = history.isNotEmpty ? history.first.nombreTranches : (trancheNum > 1 ? trancheNum : 1);
                                if (trancheNum > nombreTranches) nombreTranches = trancheNum;
                                trancheNumController.text = '$trancheNum';
                                totalTranchesController.text = '$nombreTranches';
                                final b = _db.getInscriptionBalance(insc.id);
                                amountController.text = b.toStringAsFixed(0);
                                montant = b;
                                motifController.text = 'Versement Tranche $trancheNum';
                              }
                            }
                          });
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
                                Text('${baseTotal.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Remise Accordée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent)),
                                Text('- ${remise.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Net Dû (Après Remise):', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                Text('${netTotal.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Somme Déjà Versée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.success)),
                                Text('${alreadyPaid.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Solde Restant à Payer:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warningDark)),
                                Text('${balanceDue.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.warningDark)),
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
                                ? 'Remise appliquée : ${remise.toStringAsFixed(0)} FCFA (Modifier)'
                                : 'Accorder une remise (décision manuelle)',
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('N° Tranche', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: trancheNumController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => trancheNum = int.tryParse(v) ?? 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Tranches', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: totalTranchesController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => nombreTranches = int.tryParse(v) ?? 1,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Sélectionnez un stagiaire et une formation.')));
                    return;
                  }

                  final inscription = _db.getInscriptions().where(
                    (item) => item.etudiantId == selectedStudentId && item.formationId == selectedFormationId,
                  ).firstOrNull;

                  if (inscription == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Inscription introuvable.')));
                    return;
                  }

                  final m = montant > 0 ? montant : (double.tryParse(amountController.text) ?? 0);
                  if (m <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Le montant doit être supérieur à 0 FCFA.')));
                    return;
                  }

                  final tNum = int.tryParse(trancheNumController.text) ?? trancheNum;
                  final tTotal = int.tryParse(totalTranchesController.text) ?? nombreTranches;

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
                    referenceTransaction: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                    trancheNumero: tNum,
                    nombreTranches: tTotal,
                    remise: remise,
                    motif: motifController.text.isNotEmpty ? motifController.text : 'Versement Tranche $tNum',
                  );

                  try {
                    await _db.addPayment(payment);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(                      SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                    }
                    return;
                  }

                  await _db.logAction(
                    userNom: widget.user.nomComplet,
                    userRole: 'Admin',
                    action: 'Nouveau Versement',
                    description: 'Versement de ${m.toStringAsFixed(0)} FCFA enregistré pour ${inscription.id}',
                  );

                  if (mounted && ctx.mounted) {
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Versement enregistré avec succès.'), backgroundColor: AppTheme.success),
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
                Text(                'Nouveau stagiaire / étudiant', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
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
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Veuillez remplir au moins le prénom et le nom.')));
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
                      SnackBar(content: Text('Stagiaire $prenom $nom ($email) créé avec succès.'), backgroundColor: AppTheme.success),
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
                            Text('${basePrice.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Remise Accordée:', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent)),
                            Text('- ${calculatedDiscount.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Nouveau Total Net à Payer:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('${netPrice.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.success)),
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
                              label: Text('${(amt / 1000).toStringAsFixed(0)}k FCFA'),
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
        'title': 'Paiement ${p.montant.toStringAsFixed(0)} FCFA',
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
