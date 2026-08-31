import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:gestion_formations/config/theme.dart';

class InvoiceService {
  static String _formatCurrency(num value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(' ');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  static Future<Uint8List> generateInvoicePDF({
    required String studentName,
    required String email,
    required String phone,
    required String formationTitle,
    required List<String> modules,
    required double montantTotal,
    required double montantPaye,
    required double montantRestant,
    required String statut,
    double? montantBrut,
    double remise = 0.0,
    List<Map<String, dynamic>> paymentHistory = const [],
  }) async {
    final pdf = pw.Document();

    // Charger le logo
    pw.MemoryImage? image;
    try {
      final ByteData imageData = await rootBundle.load('images/logo.png');
      final Uint8List imageBytes = imageData.buffer.asUint8List();
      image = pw.MemoryImage(imageBytes);
    } catch (_) {}

    final effectiveRemise = remise > 0 ? remise : 0.0;
    final effectiveBrut = montantBrut != null && montantBrut > 0
        ? montantBrut
        : (effectiveRemise > 0 ? (montantTotal + effectiveRemise) : montantTotal);

    final primaryColor = PdfColor.fromInt(AppTheme.primary.toARGB32());
    final successColor = PdfColor.fromInt(0xFF10B981);
    final errorColor = PdfColor.fromInt(0xFFEF4444);
    final textDark = PdfColor.fromInt(0xFF1F2937);
    final textMuted = PdfColor.fromInt(0xFF6B7280);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête avec logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      if (image != null)
                        pw.Container(
                          width: 55,
                          height: 55,
                          margin: const pw.EdgeInsets.only(right: 14),
                          child: pw.Image(image),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MALINTIC SFP',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            'Centre de Formation Professionnelle & Informatique',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'FACTURE OFFICIELLE',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date : ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                        style: pw.TextStyle(fontSize: 9, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300, thickness: 0.8),
              pw.SizedBox(height: 14),

              // Informations étudiant & Formation (2 colonnes)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bloc Étudiant
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor(0.97, 0.98, 0.99),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DESTINATAIRE / APPRENANT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            studentName.isNotEmpty ? studentName : 'Apprenant',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text(email, style: pw.TextStyle(fontSize: 9, color: textMuted)),
                          ],
                          if (phone.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text('Tél : $phone', style: pw.TextStyle(fontSize: 9, color: textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  // Bloc Formation
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor(0.97, 0.98, 0.99),
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FORMATION SOUSCRITE',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            formationTitle,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${modules.length} module(s) enregistré(s)',
                            style: pw.TextStyle(fontSize: 9, color: primaryColor, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // Tableau des modules
              if (modules.isNotEmpty) ...[
                pw.Text(
                  'PROGRAMME ET MODULES RETENUS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FlexColumnWidth(4),
                    2: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: primaryColor),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('N°', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Intitulé du Module', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Statut', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    // Modules
                    ...modules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final mod = entry.value;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: idx % 2 == 0 ? const PdfColor(0.98, 0.98, 0.98) : PdfColors.white),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(mod, style: const pw.TextStyle(fontSize: 8.5)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('Inclus', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: successColor), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 18),
              ],

              // Synthèse Financière & Décomposition Arithmétique
              pw.Text(
                'DÉCOMPOSITION DU RÈGLEMENT FINANCIER',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Élément de Facturation', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Montant (FCFA)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Observation', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),

                  // Si remise accordée, afficher le Tarif Brut et la Remise
                  if (effectiveRemise > 0) ...[
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Tarif de Base / Montant Brut', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${_formatCurrency(effectiveBrut)} FCFA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark), textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Tarif catalogue', style: pw.TextStyle(fontSize: 8, color: textMuted), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor(0.99, 0.95, 0.95)),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Remise Exceptionnelle Accordée', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: errorColor)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('- ${_formatCurrency(effectiveRemise)} FCFA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: errorColor), textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Déduction', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: errorColor), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                  ],

                  // Total Net Dû
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor(0.95, 0.97, 1.0)),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(effectiveRemise > 0 ? 'Total Net Dû' : 'Montant Total de la Formation', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${_formatCurrency(montantTotal)} FCFA', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Net exigible', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),

                  // Montant Déjà Encaissé / Réglé
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor(0.95, 0.99, 0.96)),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Montant Déjà Réglé (Encaissé)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: successColor)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${_formatCurrency(montantPaye)} FCFA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: successColor), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Payé', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: successColor), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),

                  // Solde Restant
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: montantRestant <= 0 ? const PdfColor(0.93, 0.99, 0.95) : const PdfColor(1.0, 0.97, 0.95),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Solde Restant à Payer', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: montantRestant <= 0 ? successColor : errorColor)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${_formatCurrency(montantRestant)} FCFA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: montantRestant <= 0 ? successColor : errorColor), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          montantRestant <= 0 ? 'SOLDÉ 100%' : 'À RÉGLER',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: montantRestant <= 0 ? successColor : errorColor),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Historique des tranches si disponible
              if (paymentHistory.isNotEmpty) ...[
                pw.Text(
                  'HISTORIQUE DES TRANCHES & VERSEMENTS ENREGISTRÉS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor(0.15, 0.20, 0.30)),
                      children: ['Tranche', 'Montant Versé', 'Remise Rattachée', 'Statut'].map(
                        (label) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                      ).toList(),
                    ),
                    ...paymentHistory.map(
                      (payment) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('Tranche ${payment['trancheNumero'] ?? 1}/${payment['nombreTranches'] ?? 1}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${payment['montant'] ?? 0} FCFA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${payment['remise'] ?? 0} FCFA', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${payment['statusLabel'] ?? 'Effectué'}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],

              pw.Spacer(),

              // Pied de page officiel
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Malintic SFP — Centre de Formation & Solutions Numériques — Bamako, Mali',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Document certifié conforme',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
