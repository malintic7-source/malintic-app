import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/accounting_export_service.dart';
import 'package:gestion_formations/Services/pdf_helper.dart';
import 'package:gestion_formations/config/theme.dart';

class ExportAccountingDialog extends StatefulWidget {
  final Formation? preselectedFormation;

  const ExportAccountingDialog({
    super.key,
    this.preselectedFormation,
  });

  static Future<void> show(BuildContext context, {Formation? preselectedFormation}) async {
    await showDialog(
      context: context,
      builder: (context) => ExportAccountingDialog(preselectedFormation: preselectedFormation),
    );
  }

  @override
  State<ExportAccountingDialog> createState() => _ExportAccountingDialogState();
}

class _ExportAccountingDialogState extends State<ExportAccountingDialog> {
  final LocalDataService _db = LocalDataService();

  int _exportType = 0; // 0 = CSV Excel, 1 = PDF Financier, 2 = Feuille d'émargement
  String? _selectedFormationId;
  String _periodFilter = 'all'; // 'all', 'this_month', 'this_year', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedFormation != null) {
      _selectedFormationId = widget.preselectedFormation!.id;
      _exportType = 2; // Si ouvert depuis une formation, présélectionner la feuille d'émargement
    }
  }

  Future<void> _handleExport({bool isPrint = false}) async {
    setState(() => _isGenerating = true);
    try {
      final payments = _db.getPayments();
      final formations = _db.getFormations();
      final inscriptions = _db.getInscriptions();
      final users = _db.getUsers();
      final seances = _db.getSeances();

      final formationsMap = {for (final f in formations) f.id: f};
      final usersMap = {for (final u in users) u.id: u};

      // Calcul des dates selon filtre
      DateTime? start = _startDate;
      DateTime? end = _endDate;
      final now = DateTime.now();

      if (_periodFilter == 'this_month') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (_periodFilter == 'this_year') {
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
      }

      // Filtrer les paiements par formation si sélectionnée
      var filteredPayments = payments;
      if (_selectedFormationId != null && _selectedFormationId!.isNotEmpty) {
        filteredPayments = payments.where((p) => p.formationId == _selectedFormationId).toList();
      }

      final dateSuffix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      if (_exportType == 0) {
        // Export CSV Excel
        final csvBytes = AccountingExportService.generateFinancialReportCSV(
          payments: filteredPayments,
          formationsMap: formationsMap,
          usersMap: usersMap,
          startDate: start,
          endDate: end,
        );

        await PdfHelper.downloadCSV(
          csvBytes,
          fileName: 'malintic_rapport_financier_$dateSuffix',
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export Excel / CSV généré avec succès.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else if (_exportType == 1) {
        // Rapport Financier PDF
        final formationName = _selectedFormationId != null ? formationsMap[_selectedFormationId]?.titre : null;
        final title = formationName != null ? 'RAPPORT FINANCIER — $formationName' : 'ÉTAT FINANCIER & COMPTABLE GLOBAL';

        final pdfBytes = await AccountingExportService.generateFinancialReportPDF(
          payments: filteredPayments,
          formationsMap: formationsMap,
          usersMap: usersMap,
          startDate: start,
          endDate: end,
          title: title,
        );

        if (isPrint) {
          await PdfHelper.printPDF(pdfBytes);
        } else {
          await PdfHelper.downloadPDF(
            pdfBytes,
            fileName: 'malintic_etat_financier_$dateSuffix',
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPrint ? 'Document envoyé à l\'impression.' : 'Rapport financier PDF téléchargé.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else if (_exportType == 2) {
        // Feuille d'émargement PDF
        Formation? formation;
        if (_selectedFormationId != null && _selectedFormationId!.isNotEmpty) {
          formation = formationsMap[_selectedFormationId];
        } else if (formations.isNotEmpty) {
          formation = formations.first;
        }

        if (formation == null) {
          throw Exception('Veuillez sélectionner une formation pour la feuille d\'émargement');
        }

        final formationSeances = seances.where((s) => s.formationId == formation!.id).toList();

        final pdfBytes = await AccountingExportService.generateAttendanceSheetPDF(
          formation: formation,
          inscriptions: inscriptions,
          students: users,
          seances: formationSeances,
        );

        if (isPrint) {
          await PdfHelper.printPDF(pdfBytes);
        } else {
          final cleanTitle = formation.titre.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
          await PdfHelper.downloadPDF(
            pdfBytes,
            fileName: 'malintic_emargement_${cleanTitle}_$dateSuffix',
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPrint ? 'Feuille d\'émargement envoyée à l\'impression.' : 'Feuille d\'émargement PDF téléchargée.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur export: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formations = _db.getFormations();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: isMobile ? width * 0.95 : 550,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre et Fermeture
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exports & Rapports',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Comptabilité, états financiers & émargement',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Choix du type d'export
              Text(
                'Type de document',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              _buildTypeCard(
                typeIndex: 0,
                icon: Icons.table_chart_rounded,
                title: 'Export Excel / CSV Universel',
                subtitle: 'Tableau financier encodé UTF-8 BOM avec totaux',
                badgeColor: AppTheme.success,
                badgeText: 'EXCEL / CSV',
              ),
              const SizedBox(height: 8),
              _buildTypeCard(
                typeIndex: 1,
                icon: Icons.picture_as_pdf_rounded,
                title: 'Rapport Financier Officiel PDF',
                subtitle: 'Synthèse KPIs, ventilation Wave/OM/Espèces & journal',
                badgeColor: AppTheme.primary,
                badgeText: 'PDF A4',
              ),
              const SizedBox(height: 8),
              _buildTypeCard(
                typeIndex: 2,
                icon: Icons.how_to_reg_rounded,
                title: 'Feuille d\'Émargement & Présence',
                subtitle: 'Grille d\'assiduité A4 Paysage avec signatures',
                badgeColor: AppTheme.accent,
                badgeText: 'A4 PAYSAGE',
              ),
              const SizedBox(height: 18),

              // 2. Filtre Formation
              Text(
                'Formation ciblée',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _selectedFormationId,
                    hint: Text('Toutes les formations', style: GoogleFonts.poppins(fontSize: 13)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes les formations (Global)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      ...formations.map((f) => DropdownMenuItem<String?>(
                            value: f.id,
                            child: Text(f.titre, style: GoogleFonts.poppins(fontSize: 13), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedFormationId = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Filtre Période (si type 0 ou 1)
              if (_exportType != 2) ...[
                Text(
                  'Période',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPeriodChoice('Tout l\'historique', 'all'),
                    _buildPeriodChoice('Ce mois-ci', 'this_month'),
                    _buildPeriodChoice('Cette année', 'this_year'),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Actions Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isGenerating ? null : () => Navigator.pop(context),
                    child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  ),
                  if (_exportType != 0) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isGenerating ? null : () => _handleExport(isPrint: true),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: Text('Imprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _handleExport(isPrint: false),
                    icon: _isGenerating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      _isGenerating ? 'Génération...' : 'Télécharger',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required int typeIndex,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color badgeColor,
    required String badgeText,
  }) {
    final isSelected = _exportType == typeIndex;

    return InkWell(
      onTap: () => setState(() => _exportType = typeIndex),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey.shade600, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // ignore: deprecated_member_use
            Radio<int>(
              value: typeIndex,
              // ignore: deprecated_member_use
              groupValue: _exportType,
              activeColor: AppTheme.primary,
              // ignore: deprecated_member_use
              onChanged: (val) => setState(() => _exportType = val ?? 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChoice(String label, String value) {
    final isSelected = _periodFilter == value;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textPrimary),
      onSelected: (_) => setState(() => _periodFilter = value),
    );
  }
}
