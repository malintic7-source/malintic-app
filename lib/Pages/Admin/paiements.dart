import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/payment_report_service.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/invoice_service.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/Widgets/pro_data_table.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPaiements extends StatefulWidget {
  const AdminPaiements({super.key});

  @override
  State<AdminPaiements> createState() => _AdminPaiementsState();
}

class _AdminPaiementsState extends State<AdminPaiements> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  StreamSubscription<void>? _dataSub;
  Timer? _refreshTimer;

  int _selectedTab = 0; // 0: Suivi par Stagiaire & Tranches, 1: Historique des Transactions
  String? _selectedStudentId;
  String? _selectedFormationId;
  double _montant = 0;
  double _remise = 0;
  int _trancheNumero = 1;
  int _nombreTranches = 1;
  String _motif = '';
  PaymentMethod _selectedMethod = PaymentMethod.orangeMoney;

  String _searchQuery = '';
  String _filterStatus = 'all';

  List<Map<String, dynamic>> _studentFormations = [];

  final _amountController = TextEditingController();
  final _discountController = TextEditingController();
  final _installmentController = TextEditingController(text: '1');
  final _totalInstallmentsController = TextEditingController(text: '1');
  final _motifController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });

    // Mise à jour automatique instantanée des cartes statistiques financières
    _dataSub = _db.watchAllDataChanges().listen((_) {
      if (mounted) setState(() {});
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataSub?.cancel();
    _refreshTimer?.cancel();
    _amountController.dispose();
    _discountController.dispose();
    _installmentController.dispose();
    _totalInstallmentsController.dispose();
    _motifController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final hp = isMobile ? 10.0 : 16.0;
    final vp = isMobile ? 10.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: vp, horizontal: hp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 14 : 20),
          _buildFinancialStatsCards(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildTabNavigation(),
          SizedBox(height: isMobile ? 14 : 20),
          _selectedTab == 0 ? _buildStagiairesTranchesTab(isMobile) : _buildTransactionsHistoryTab(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Paiements',
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Suivi financier des stagiaires et règlement par tranche.',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.88)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: Text('Rapport PDF', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                        onPressed: _generatePaymentReport,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          tooltip: 'Actualiser',
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          onPressed: () => setState(() {}),
                        ),
                      ),
                    ],
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
                        Text(
                          'Gestion des Paiements & Tranches',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Suivi financier des stagiaires, règlement par tranche et reçus de versement officiels.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text('Rapport PDF', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: _generatePaymentReport,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      tooltip: 'Actualiser les paiements',
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Données des paiements actualisées !'),
                            backgroundColor: AppTheme.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFinancialStatsCards(bool isMobile) {
    return StreamBuilder<List<Payment>>(
      stream: _db.watchPayments(),
      builder: (context, snapshot) {
        final kpis = _db.getFinancialKpis();
        final totalReceived = (kpis['totalReceived'] as num?)?.toDouble() ?? 0.0;
        final totalDue = (kpis['totalDue'] as num?)?.toDouble() ?? 0.0;
        final totalBalance = (kpis['totalBalance'] as num?)?.toDouble() ?? 0.0;
        final recoveryRate = (kpis['recoveryRate'] as num?)?.toDouble() ?? 0.0;
        final totalTransactions = (kpis['totalTransactions'] as num?)?.toInt() ?? 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isMobile ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard('Encaissé Total', '${totalReceived.toStringAsFixed(0)} FCFA', Icons.account_balance_wallet_rounded, AppTheme.success, cardWidth),
                _buildStatCard('Reste à Recouvrer', '${totalBalance.toStringAsFixed(0)} FCFA', Icons.pending_actions_rounded, const Color(0xFFD4AF37), cardWidth),
                _buildStatCard('Total Dû Formations', '${totalDue.toStringAsFixed(0)} FCFA', Icons.receipt_rounded, AppTheme.primary, cardWidth),
                _buildStatCard('Taux de Recouvrement', '${recoveryRate.toStringAsFixed(1)}% ($totalTransactions reçus)', Icons.insights_rounded, Colors.purple, cardWidth),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Suivi par Stagiaire & Tranches',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _selectedTab == 0 ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Journal des Transactions',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _selectedTab == 1 ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagiairesTranchesTab(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar('Rechercher un stagiaire par nom, e-mail...'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 20),
                    label: Text('Nouveau Paiement', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _openAddPaymentDialog(null, null),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildSearchBar('Rechercher un stagiaire par nom, e-mail...')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 20),
                    label: Text('Nouveau Paiement', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _openAddPaymentDialog(null, null),
                  ),
                ],
              ),
        const SizedBox(height: 20),
        StreamBuilder<List<Inscription>>(
          stream: _db.watchInscriptions(),
          builder: (context, snapshot) {
            final deletedInscIds2 = _db.getDeletedDocs('inscriptions');
            final deletedUserIds2 = _db.getDeletedDocs('users');
            final deletedEmails2 = _db.getDeletedDocs('user_emails');

            final filteredInscriptions = (snapshot.data ?? []).where((ins) {
              final email = (ins.email ?? '').trim().toLowerCase();
              if (deletedInscIds2.contains(ins.id)) return false;
              if (deletedUserIds2.contains(ins.etudiantId)) return false;
              if (deletedUserIds2.contains(ins.id)) return false;
              if (email.isNotEmpty && deletedEmails2.contains(email)) return false;
              final student = _db.getUserById(ins.etudiantId);
              final prenom = (ins.prenom ?? student?.prenom ?? '').toLowerCase();
              final nom = (ins.nom ?? student?.nom ?? '').toLowerCase();
              final emailQ = (ins.email ?? student?.email ?? '').toLowerCase();
              final phone = (ins.telephone ?? student?.phone ?? '').toLowerCase();
              final matricule = (student?.matricule ?? '').toLowerCase();
              final fullText = '$prenom $nom $emailQ $phone $matricule'.toLowerCase();
              if (_searchQuery.isEmpty) return true;
              return fullText.contains(_searchQuery);
            }).toList();

            if (filteredInscriptions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.payments_outlined, size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune inscription ou stagiaire trouvé.',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredInscriptions.length,
              itemBuilder: (context, index) {
                final ins = filteredInscriptions[index];
                final student = _db.getUserById(ins.etudiantId);
                final formation = _db.getFormationById(ins.formationId);

                final prenom = ins.prenom ?? student?.prenom ?? '';
                final nom = ins.nom ?? student?.nom ?? 'Stagiaire';
                final fullName = '$prenom $nom'.trim();
                final email = ins.email ?? student?.email ?? '';
                final phone = ins.telephone ?? student?.phone ?? '';

                final totalDue = _db.getInscriptionTotalDue(ins.id);
                final paidAmount = _db.getInscriptionPaidAmount(ins.id);
                final balance = _db.getInscriptionBalance(ins.id);

                final paymentsHistory = _db.getPaymentsForInscription(ins.id);
                final tranchesPaid = paymentsHistory.where((p) => p.status == PaymentStatus.effectue).length;
                final totalTranches = paymentsHistory.isNotEmpty ? paymentsHistory.first.nombreTranches : 1;

                final progress = totalDue == 0 ? 1.0 : (paidAmount / totalDue).clamp(0.0, 1.0);

                return FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: balance == 0 ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: balance == 0 ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                balance == 0 ? Icons.check_circle_rounded : Icons.person_rounded,
                                color: balance == 0 ? AppTheme.success : AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullName,
                                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: balance == 0 ? AppTheme.success.withValues(alpha: 0.12) : const Color(0xFFD4AF37).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          balance == 0 ? 'SOLDER (100%)' : 'Tranche $tranchesPaid / $totalTranches',
                                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: balance == 0 ? AppTheme.success : const Color(0xFFD4AF37)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formation?.titre ?? "Formation"} • $email ${phone.isNotEmpty ? "• $phone" : ""}',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(balance == 0 ? AppTheme.success : AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Payé / Reste — Wrap pour mobile
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payé: ${paidAmount.toStringAsFixed(0)} FCFA / ${totalDue.toStringAsFixed(0)} FCFA',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    balance == 0 ? 'Solde réglé ✓' : 'Reste: ${balance.toStringAsFixed(0)} FCFA',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      color: balance == 0 ? AppTheme.success : AppTheme.error,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Payé: ${paidAmount.toStringAsFixed(0)} FCFA / ${totalDue.toStringAsFixed(0)} FCFA',
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  Text(
                                    balance == 0 ? 'Solde réglé' : 'Reste: ${balance.toStringAsFixed(0)} FCFA',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, fontWeight: FontWeight.w800,
                                      color: balance == 0 ? AppTheme.success : AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        // Actions : icônes + bouton (colonne sur mobile)
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.request_quote_rounded, color: AppTheme.primary, size: 21),
                                        tooltip: 'Facture complète',
                                        onPressed: () => _generateInvoicePdf(ins),
                                      ),
                                      if (paymentsHistory.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 20),
                                          tooltip: 'Reçu dernier versement',
                                          onPressed: () => _generateReceiptPdf(paymentsHistory.last),
                                        ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: balance == 0 ? Colors.grey.shade400 : AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.add_card_rounded, size: 16),
                                    label: Text(
                                      balance == 0 ? 'Formation Soldée' : '➕ Régler Tranche N°${tranchesPaid + 1}',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: balance == 0 ? null : () => _openAddPaymentDialog(ins.etudiantId, ins.formationId),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.request_quote_rounded, color: AppTheme.primary, size: 21),
                                        tooltip: 'Télécharger la facture complète',
                                        onPressed: () => _generateInvoicePdf(ins),
                                      ),
                                      if (paymentsHistory.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 20),
                                          tooltip: 'Télécharger le reçu du dernier versement',
                                          onPressed: () => _generateReceiptPdf(paymentsHistory.last),
                                        ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: balance == 0 ? Colors.grey.shade400 : AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.add_card_rounded, size: 16),
                                    label: Text(
                                      balance == 0 ? 'Formation Soldée' : '➕ Régler Tranche N°${tranchesPaid + 1}',
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: balance == 0 ? null : () => _openAddPaymentDialog(ins.etudiantId, ins.formationId),
                                  ),
                                ],
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

  Widget _buildSearchBar(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        Text('Statut : ', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _filterStatus,
          underline: const SizedBox(),
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tous les paiements')),
            DropdownMenuItem(value: 'valide', child: Text('Validés uniquement')),
          ],
          onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
        ),
      ],
    );
  }

  Widget _buildTransactionsHistoryTab(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFiltersRow(),
        const SizedBox(height: 14),
        _buildPaymentsList(isMobile),
      ],
    );
  }

  Widget _buildPaymentsList(bool isMobile) {
    return StreamBuilder<List<Payment>>(
      stream: _db.watchPayments(),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        final filteredPayments = payments.where((p) {
          if (_filterStatus == 'valide') return p.status == PaymentStatus.effectue;
          return true;
        }).toList();

        if (filteredPayments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 48, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text('Aucun versement trouvé', style: GoogleFonts.poppins(color: Colors.black54)),
                ],
              ),
            ),
          );
        }

        if (isMobile) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredPayments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = filteredPayments[index];
              final student = _db.getUserById(p.etudiantId);
              final studentName = student?.nomComplet ?? 'Stagiaire #${p.etudiantId.length > 6 ? p.etudiantId.substring(0, 6) : p.etudiantId}';
              final statusColor = _getStatusColorFromPayment(p.status);
              final statusLabel = _getStatusLabelFromPayment(p.status);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            studentName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tranche ${p.trancheNumero}/${p.nombreTranches}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${p.montant.toStringAsFixed(0)} FCFA',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (p.status == PaymentStatus.enAttente)
                          TextButton.icon(
                            onPressed: () => _confirmPendingPayment(p),
                            icon: const Icon(Icons.verified_rounded, size: 16, color: AppTheme.success),
                            label: const Text('Valider', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                          ),
                        TextButton.icon(
                          onPressed: () => _generateReceiptPdf(p),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: AppTheme.error),
                          label: const Text('Reçu PDF', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                        ),
                        IconButton(
                          onPressed: () => _sendWhatsAppPaymentNotice(p),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF25D366)),
                          tooltip: 'Notifier sur WhatsApp',
                        ),
                        IconButton(
                          onPressed: () => _confirmDeletePayment(context, p),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        }

        final tableRows = filteredPayments.map((p) {
          final student = _db.getUserById(p.etudiantId);
          final studentName = student != null ? '${student.prenom} ${student.nom}' : 'Stagiaire #${p.etudiantId.substring(0, 6)}';
          final statusColor = _getStatusColorFromPayment(p.status);
          final statusLabel = _getStatusLabelFromPayment(p.status);

          return ProDataRow(
            cells: [
              ProDataCell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      studentName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    if (student?.email != null)
                      Text(student!.email, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              ProDataCell(
                child: Text('Tranche ${p.trancheNumero}/${p.nombreTranches}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ProDataCell(
                text: '${p.montant.toStringAsFixed(0)} FCFA',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
              ProDataCell(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ),
              ProDataCell(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.status == PaymentStatus.enAttente)
                      IconButton(
                        onPressed: () => _confirmPendingPayment(p),
                        icon: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 20),
                        tooltip: 'Valider le paiement',
                      ),
                    IconButton(
                       onPressed: () => _generateReceiptPdf(p),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.error, size: 20),
                      tooltip: 'Reçu PDF',
                    ),
                    IconButton(
                      onPressed: () => _sendWhatsAppPaymentNotice(p),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 20),
                      tooltip: 'Notifier WhatsApp',
                    ),
                    IconButton(
                      onPressed: () => _confirmDeletePayment(context, p),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                      tooltip: 'Supprimer',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList();

        return ProDataTable(
          title: 'Historique Global des Transactions',
          subtitle: '${filteredPayments.length} versement(s) enregistré(s)',
          isLoading: !snapshot.hasData,
          emptyMessage: 'Aucun versement trouvé',
          columns: const [
            ProColumn(label: 'Stagiaire'),
            ProColumn(label: 'Tranche'),
            ProColumn(label: 'Montant'),
            ProColumn(label: 'Statut'),
            ProColumn(label: 'Actions', numeric: true),
          ],
          rows: tableRows,
        );
      },
    );
  }

  Future<void> _confirmPendingPayment(Payment payment) async {
    try {
      await _db.updatePaymentStatus(payment.id, 'effectue');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Paiement validé.'), backgroundColor: AppTheme.success),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $error'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _sendWhatsAppPaymentNotice(Payment payment) async {
    final student = _db.getUserById(payment.etudiantId);
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dossier apprenant introuvable.')),
      );
      return;
    }

    final rawPhone = student.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone introuvable pour cet apprenant.')),
      );
      return;
    }

    final ref = payment.referenceTransaction?.isNotEmpty == true ? payment.referenceTransaction! : payment.id.substring(0, 8);
    final text = 'Bonjour ${student.nomComplet},\n\n'
        'Le Centre M@LI_NTIC accuse bonne réception de votre règlement de ${payment.montant.toStringAsFixed(0)} FCFA '
        '(Tranche ${payment.trancheNumero}/${payment.nombreTranches}, Réf: $ref).\n\n'
        'Votre reçu officiel de paiement est disponible dans votre Espace Apprenant.\n\n'
        'Cordialement,\n'
        'Direction Financière & Comptabilité M@LI_NTIC';

    final uri = Uri.parse('https://wa.me/$rawPhone?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur WhatsApp: $e')),
        );
      }
    }
  }

  void _openAddPaymentDialog(String? preselectStudentId, String? preselectFormationId) {
    setState(() {
      _selectedStudentId = preselectStudentId;
      _selectedFormationId = preselectFormationId;
    });

    if (preselectStudentId != null) {
      _loadStudentFormations(preselectStudentId);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double baseTotal = 0;
          double netTotal = 0;
          double alreadyPaid = 0;
          double balanceDue = 0;

          if (_selectedStudentId != null && _selectedFormationId != null) {
            final inscription = _db.getInscriptions().where(
              (item) => item.etudiantId == _selectedStudentId && item.formationId == _selectedFormationId,
            ).firstOrNull;

            baseTotal = _db.getFormationModulesTotal(
              _selectedFormationId!,
              moduleIds: inscription?.modules,
              typeFormation: inscription?.typeFormation,
            );
            netTotal = (baseTotal - _remise).clamp(0, double.infinity).toDouble();
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SizedBox(
                  width: MediaQuery.of(ctx).size.width * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Stagiaire', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedStudentId,
                      hint: const Text('Choisir un stagiaire'),
                      items: _db.getUsers().where((u) => u.role == UserRole.apprenant).map((u) {
                        return DropdownMenuItem(value: u.id, child: Text('${u.prenom} ${u.nom} (${u.email})'));
                      }).toList(),
                      onChanged: (v) {
                        setDialogState(() => _selectedStudentId = v);
                        if (v != null) _loadStudentFormations(v);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedStudentId != null) ...[
                      Text('Formation / Session', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedFormationId,
                        hint: const Text('Choisir une formation'),
                        items: _studentFormations.map((f) {
                          return DropdownMenuItem(value: f['id'].toString(), child: Text(f['titre'].toString()));
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => _selectedFormationId = v);
                          if (v != null) _prefillPaymentFields(v);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_selectedFormationId != null) ...[
                      // Financial breakdown card
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
                                Text('- ${_remise.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accent)),
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

                      // Dedicated Manual Discount Decision Button
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
                            _remise > 0
                                ? '🏷️ Remise Appliquée: ${_remise.toStringAsFixed(0)} FCFA (Modifier)'
                                : '🏷️ Accorder une Remise (Décision Manuelle)',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent),
                          ),
                          onPressed: () => _showApplyDiscountModal(
                            parentContext: ctx,
                            setDialogState: setDialogState,
                            basePrice: baseTotal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text('Montant Versé pour cette Tranche (FCFA)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => _montant = double.tryParse(v) ?? 0,
                    ),
                    const SizedBox(height: 16),
                    Text('Méthode de Règlement', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: _selectedMethod,
                      items: const [
                        DropdownMenuItem(value: PaymentMethod.orangeMoney, child: Text('Orange Money')),
                        DropdownMenuItem(value: PaymentMethod.moovMoney, child: Text('Moov Money')),
                        DropdownMenuItem(value: PaymentMethod.virement, child: Text('Virement Bancaire')),
                        DropdownMenuItem(value: PaymentMethod.especes, child: Text('Espèces')),
                        DropdownMenuItem(value: PaymentMethod.carte, child: Text('Carte Bancaire')),
                      ],
                      onChanged: (v) => setDialogState(() => _selectedMethod = v ?? PaymentMethod.orangeMoney),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('N° Tranche', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _installmentController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                onChanged: (v) => _trancheNumero = int.tryParse(v) ?? 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nombre Tranches', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _totalInstallmentsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                onChanged: (v) => _nombreTranches = int.tryParse(v) ?? 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              StatefulBuilder(
                builder: (context, setBtnState) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Valider le Versement'),
                    onPressed: () async {
                      setDialogState(() {});
                      final saved = await _submitPayment();
                      if (saved) {
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                        if (mounted) setState(() {});
                      }
                    },
                  );
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
  }) {
    final discountValController = TextEditingController(text: _remise > 0 ? _remise.toStringAsFixed(0) : '');
    final reasonController = TextEditingController();
    bool isPercentage = false;
    double calculatedDiscount = _remise;

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
                  setDialogState(() {
                    _remise = calculatedDiscount;
                    _discountController.text = calculatedDiscount.toStringAsFixed(0);
                    if (reasonController.text.trim().isNotEmpty) {
                      _motifController.text = 'Remise: ${reasonController.text.trim()}';
                      _motif = _motifController.text;
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _submitPayment() async {
    if (_selectedStudentId == null || _selectedFormationId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Veuillez sélectionner un stagiaire et une formation.'), backgroundColor: AppTheme.warning),
      );
      return false;
    }

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? _montant;
    final parsedDiscount = double.tryParse(_discountController.text.trim()) ?? _remise;
    final parsedInstallment = int.tryParse(_installmentController.text.trim()) ?? _trancheNumero;
    final parsedTotalInstallments = int.tryParse(_totalInstallmentsController.text.trim()) ?? _nombreTranches;
    final parsedMotif = _motifController.text.trim();

    if (parsedAmount <= 0) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Le montant du versement doit être supérieur à 0 FCFA.'), backgroundColor: AppTheme.warning),
      );
      return false;
    }

    final inscription = _db.getInscriptions().where(
      (item) => item.etudiantId == _selectedStudentId && item.formationId == _selectedFormationId,
    ).firstOrNull;

    if (inscription == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Inscription introuvable pour ce stagiaire.'), backgroundColor: AppTheme.error),
      );
      return false;
    }

    if (parsedInstallment < 1 || parsedTotalInstallments < 1 || parsedInstallment > parsedTotalInstallments) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Le numéro de tranche doit être compris entre 1 et le nombre total de tranches.'), backgroundColor: AppTheme.warning),
        );
      }
      return false;
    }

    final baseTotal = _db.getInscriptionBaseTotal(inscription.id);
    final currentDiscount = _db.getInscriptionDiscountTotal(inscription.id);
    final effectiveDiscount = parsedDiscount > currentDiscount ? parsedDiscount : currentDiscount;
    final remaining = (baseTotal - effectiveDiscount - _db.getInscriptionPaidAmount(inscription.id))
        .clamp(0, double.infinity)
        .toDouble();
    if (parsedAmount > remaining) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Le versement dépasse le solde restant (${remaining.toStringAsFixed(0)} FCFA).'), backgroundColor: AppTheme.warning),
        );
      }
      return false;
    }

    _motif = parsedMotif.isNotEmpty ? parsedMotif : 'Versement Tranche $parsedInstallment';

    final payment = Payment(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      inscriptionId: inscription.id,
      etudiantId: _selectedStudentId!,
      formationId: _selectedFormationId!,
      montant: parsedAmount,
      status: PaymentStatus.effectue,
      methode: _selectedMethod,
      dateCreation: DateTime.now(),
      dateEffectuation: DateTime.now(),
      referenceTransaction: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      trancheNumero: parsedInstallment,
      nombreTranches: parsedTotalInstallments,
      remise: parsedDiscount,
      motif: _motif,
    );

    try {
      await _db.addPayment(payment);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ $error'), backgroundColor: AppTheme.error),
        );
      }
      return false;
    }
    final currentUser = AuthProvider().currentUser;
    await _db.logAction(
      userNom: currentUser?.nomComplet ?? 'Admin',
      userRole: currentUser?.role.name ?? 'admin',
      action: 'Nouveau Versement',
      description: 'Versement de ${parsedAmount.toStringAsFixed(0)} FCFA (Tranche $parsedInstallment/$parsedTotalInstallments) enregistré.',
    );

    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Versement enregistré avec succès !'), backgroundColor: AppTheme.success),
    );
    return true;
  }

  Future<void> _loadStudentFormations(String studentId) async {
    final student = _db.getUserById(studentId);
    final assignedIds = student?.assignedFormations
            .map((item) => item['formationId']?.toString())
            .whereType<String>()
            .toSet() ??
        <String>{};
    final inscriptionIds = _db.getInscriptions()
        .where((item) => item.etudiantId == studentId)
        .map((item) => item.formationId)
        .toSet();

    final formations = _db
        .getFormations()
        .where((f) => assignedIds.contains(f.id) || inscriptionIds.contains(f.id))
        .map((f) => {'id': f.id, 'titre': f.titre})
        .toList();

    if (mounted) {
      setState(() {
        _studentFormations = formations;
        _selectedFormationId = formations.isNotEmpty ? formations.first['id'].toString() : null;
      });
      if (_selectedFormationId != null) _prefillPaymentFields(_selectedFormationId!);
    }
  }

  void _prefillPaymentFields(String formationId) {
    final formation = _db.getFormationById(formationId);
    if (formation == null) return;

    final inscription = _db.getInscriptions().where(
      (item) => item.etudiantId == _selectedStudentId && item.formationId == formationId,
    ).firstOrNull;

    final total = _db.getFormationModulesTotal(
      formationId,
      moduleIds: inscription?.modules,
      typeFormation: inscription?.typeFormation,
    );

    final existingDiscount = inscription == null ? 0.0 : _db.getInscriptionDiscountTotal(inscription.id);
    final existingPaid = inscription == null ? 0.0 : _db.getInscriptionPaidAmount(inscription.id);
    final balance = (total - existingDiscount - existingPaid).clamp(0, double.infinity).toDouble();

    final history = inscription == null ? <Payment>[] : _db.getPaymentsForInscription(inscription.id);
    final settledHistory = history.where((payment) => payment.status == PaymentStatus.effectue).toList();
    final nextInstallment = settledHistory.isEmpty
        ? 1
        : settledHistory.map((payment) => payment.trancheNumero).reduce((a, b) => a > b ? a : b) + 1;

    _amountController.text = balance.toStringAsFixed(0);
    _montant = balance;
    _discountController.text = existingDiscount.toStringAsFixed(0);
    _remise = existingDiscount;
    _installmentController.text = nextInstallment.toString();
    _totalInstallmentsController.text = history.isEmpty ? '1' : history.first.nombreTranches.toString();
    _motifController.text = history.isEmpty ? 'Acompte / Inscription' : 'Versement $nextInstallment';
    _motif = _motifController.text;
  }

  Future<void> _generateReceiptPdf(Payment p) async {
    try {
      final inscription = _db.getInscriptionById(p.inscriptionId) ??
          Inscription(
            id: p.inscriptionId,
            etudiantId: p.etudiantId,
            formationId: p.formationId,
            status: InscriptionStatus.acceptee,
            dateInscription: p.dateCreation,
            paiementEffectue: true,
          );

      final formation = _db.getFormationById(p.formationId) ??
          Formation(
            id: p.formationId,
            titre: 'Formation M@LI-NTIC',
            description: '',
            modules: [],
            formateurIds: [],
            prix: p.montant,
            type: FormationType.presentielle,
            status: FormationStatus.enCours,
            dureeSemaines: 4,
            dureeHeures: '30h',
            horaires: [],
            dateCreation: DateTime.now(),
          );

      final student = _db.getUserById(inscription.etudiantId);
      final totalDue = _db.getInscriptionTotalDue(inscription.id);
      final paid = _db.getInscriptionPaidAmount(inscription.id);
      final balance = _db.getInscriptionBalance(inscription.id);
      final matricule = student?.matricule ??
          (inscription.etudiantId.isNotEmpty
              ? (inscription.etudiantId.startsWith('MAT-')
                  ? inscription.etudiantId
                  : 'MAT-${inscription.etudiantId.length > 6 ? inscription.etudiantId.substring(inscription.etudiantId.length - 6) : inscription.etudiantId}')
              : 'MAT-OFFICIEL');

      final pdfBytes = await PdfService().generatePaymentReceiptPdf(
        payment: p,
        inscription: inscription,
        formation: formation,
        studentMatricule: matricule,
        totalInscriptionDue: totalDue > 0 ? totalDue : formation.prix,
        cumulativePaid: paid > 0 ? paid : p.montant,
        remainingBalance: balance,
      );

      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Recu_Paiement_${p.referenceTransaction ?? p.id}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur génération reçu PDF: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  /// Produces one up-to-date invoice for the whole registration, rather than
  /// a receipt for an individual instalment.
  Future<void> _generateInvoicePdf(Inscription inscription) async {
    try {
      final student = _db.getUserById(inscription.etudiantId);
      final formation = _db.getFormationById(inscription.formationId);
      final selectedModules = inscription.modules?.where((module) => module.trim().isNotEmpty).toList() ?? const <String>[];
      final modules = selectedModules.isNotEmpty
          ? selectedModules
          : (formation?.estStage == true ? const <String>[] : formation?.modules ?? const <String>[]);
      final history = _db.getPaymentsForInscription(inscription.id);
      final totalDue = _db.getInscriptionTotalDue(inscription.id);
      final paid = _db.getInscriptionPaidAmount(inscription.id);
      final balance = _db.getInscriptionBalance(inscription.id);
      final status = balance <= 0
          ? 'paiement_complet'
          : paid > 0 ? 'incomplet' : 'en_attente';

      final pdfBytes = await InvoiceService.generateInvoicePDF(
        studentName: '${inscription.prenom ?? student?.prenom ?? ''} ${inscription.nom ?? student?.nom ?? ''}'.trim(),
        email: inscription.email ?? student?.email ?? '',
        phone: inscription.telephone ?? student?.phone ?? '',
        formationTitle: formation?.titre ?? 'Formation M@LI-NTIC',
        modules: modules,
        montantTotal: totalDue,
        montantPaye: paid,
        montantRestant: balance,
        statut: status,
        paymentHistory: history.map((payment) => {
          'trancheNumero': payment.trancheNumero,
          'nombreTranches': payment.nombreTranches,
          'montant': payment.montant.toStringAsFixed(0),
          'remise': payment.remise.toStringAsFixed(0),
          'statusLabel': _invoicePaymentStatusLabel(payment.status),
        }).toList(),
      );
      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Facture_${inscription.id}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur génération facture: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  String _invoicePaymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.effectue:
        return 'Effectué';
      case PaymentStatus.echoue:
        return 'Échoué';
      case PaymentStatus.enAttente:
        return 'En attente';
    }
  }

  Future<void> _confirmDeletePayment(BuildContext context, Payment payment) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer le paiement', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: const Text('Voulez-vous vraiment supprimer ce versement ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deletePayment(payment.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Paiement supprimé avec succès'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _generatePaymentReport() async {
    final payments = _db.getPayments();
    final statusCounts = <String, int>{
      'valide': payments.where((p) => p.status == PaymentStatus.effectue).length,
      'en_attente': payments.where((p) => p.status == PaymentStatus.enAttente).length,
      'echoue': payments.where((p) => p.status == PaymentStatus.echoue).length,
    };
    final totalAmount = payments
        .where((p) => p.status == PaymentStatus.effectue)
        .fold<double>(0, (sum, p) => sum + p.montant);

    final rawPaymentsList = payments.map((p) {
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
        'studentName': studentName,
        'etudiantNom': studentName,
        'matricule': matricule,
        'phone': phone,
        'formation': formation?.titre ?? 'Formation',
        'formationTitre': formation?.titre ?? 'Formation',
        'montant': p.montant,
        'status': p.status.name,
        'methode': p.methode.name.toUpperCase(),
        'date': p.dateCreation.toIso8601String(),
      };
    }).toList();

    final pdfBytes = await PaymentReportService.generatePaymentReportPDF(
      payments: rawPaymentsList,
      statusCounts: statusCounts,
      totalAmount: totalAmount,
    );

    await PdfService().printOrDownloadPdf(
      pdfBytes: pdfBytes,
      filename: 'Rapport_Financier_MALI_NTIC.pdf',
    );
  }

  Color _getStatusColorFromPayment(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.effectue:
        return AppTheme.success;
      case PaymentStatus.enAttente:
        return const Color(0xFFD4AF37);
      case PaymentStatus.echoue:
        return AppTheme.error;
    }
  }

  String _getStatusLabelFromPayment(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.effectue:
        return 'Payé';
      case PaymentStatus.enAttente:
        return 'En attente';
      case PaymentStatus.echoue:
        return 'Échoué';
    }
  }
}
