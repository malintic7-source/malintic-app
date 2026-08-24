import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/invoice_service.dart';
import 'package:gestion_formations/Services/pdf_helper.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/status_styles.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';

class PaymentsPage extends StatefulWidget {
  final User user;

  const PaymentsPage({super.key, required this.user});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildStudentPaymentView();
  }

  Widget _buildStudentPaymentView() {
    return _buildPageWrapper(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes paiements',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Suivi de vos transactions et téléchargement des reçus',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _buildStudentPaymentsList(),
          ],
        ),
      ),
    );
  }


  Widget _buildPageWrapper({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? fixedWidth,
  }) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = fixedWidth ?? (width > 1200 ? 1100.0 : width * 0.95);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }


  Widget _buildStudentPaymentsList() {
    return StreamBuilder<List<Payment>>(
      stream: _db.watchPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPayments = snapshot.data ?? [];
        final payments = allPayments.where((p) => p.etudiantId == widget.user.id).toList();

        if (payments.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 56, color: AppTheme.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    'Aucun paiement enregistré',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: payments.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + (index * 60)),
                builder: (context, anim, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - anim)),
                    child: Opacity(
                      opacity: anim,
                      child: _buildStudentPaymentCard(payments[index]),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentPaymentCard(Payment payment) {
    final statusColor = payment.status.color;
    final statusLabel = payment.status.label;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPaymentDetails(payment),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppFormat.fcfa(payment.montant),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 10),
                Text(
                  'Méthode : ${payment.methode.label}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${payment.dateCreation.day}/${payment.dateCreation.month}/${payment.dateCreation.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _downloadReceipt(payment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: Text(
                        'Reçu PDF',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPaymentDetails(Payment payment) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Détails du paiement',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('Montant', AppFormat.fcfa(payment.montant), AppTheme.primary),
              _buildDetailSection('Statut', payment.status.label, payment.status.color),
              _buildDetailSection('Méthode', payment.methode.label, AppTheme.primaryDark),
              _buildDetailSection('Date création', '${payment.dateCreation.day}/${payment.dateCreation.month}/${payment.dateCreation.year}', AppTheme.primary),
              if (payment.dateEffectuation != null)
                _buildDetailSection('Date effectuation', '${payment.dateEffectuation!.day}/${payment.dateEffectuation!.month}/${payment.dateEffectuation!.year}', const Color(0xFF10B981)),
              if (payment.referenceTransaction != null)
                _buildDetailSection('Référence', payment.referenceTransaction!, AppTheme.primary),
              if (payment.motifEchec != null)
                _buildDetailSection('Motif échec', payment.motifEchec!, const Color(0xFFEF4444)),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadReceipt(payment);
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Télécharger Reçu'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Fermer',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt(Payment payment) async {
    try {
      context.showSnack('📄 Génération du reçu PDF en cours...', duration: const Duration(seconds: 2));

      final inscription = _db.getInscriptions().where((i) => i.id == payment.inscriptionId).firstOrNull;
      final formation = inscription != null ? _db.getFormationById(inscription.formationId) : null;
      final formationTitle = formation?.titre ?? 'Formation M@LI-NTIC';
      final modules = inscription?.modules ?? [];

      final totalPaiements = _db.getPayments()
          .where((p) => p.inscriptionId == payment.inscriptionId && p.status == PaymentStatus.effectue)
          .fold<double>(0, (sum, p) => sum + p.montant);

      final montantTotal = formation != null ? (formation.type == FormationType.enligne ? formation.prixEnLigne ?? formation.prix : formation.prix) : payment.montant;
      final montantRestant = (montantTotal - totalPaiements) > 0 ? (montantTotal - totalPaiements) : 0.0;

      final pdfBytes = await InvoiceService.generateInvoicePDF(
        studentName: '${widget.user.prenom} ${widget.user.nom}',
        email: widget.user.email,
        phone: widget.user.phone,
        formationTitle: formationTitle,
        modules: modules,
        montantTotal: montantTotal,
        montantPaye: payment.montant,
        montantRestant: montantRestant,
        statut: payment.status.label,
        paymentHistory: [
          {
            'trancheNumero': payment.trancheNumero,
            'nombreTranches': payment.nombreTranches,
            'montant': payment.montant,
            'date': payment.dateCreation.toIso8601String(),
            'methode': payment.methode.label,
            'statut': payment.status.label,
          }
        ],
      );

      final fileName = 'Recu_Paiement_${payment.id}';
      await PdfHelper.downloadPDF(pdfBytes, fileName: fileName);

      if (!mounted) return;
      context.showSuccessSnack('✅ Reçu PDF téléchargé avec succès !');
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack('❌ Erreur de génération du PDF: $e');
    }
  }

  Widget _buildDetailSection(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
