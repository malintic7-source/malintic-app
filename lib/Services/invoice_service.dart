import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/status_styles.dart';

class InvoiceService {
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
    List<Map<String, dynamic>> paymentHistory = const [],
  }) async {
    final pdf = pw.Document();

    // Charger le logo
    final ByteData imageData = await rootBundle.load('images/logo.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête avec logo
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Image(image),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FACTURE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Malintic',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColor.fromInt(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Informations étudiant
              pw.Text(
                'ÉTUDIANT',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF6B7280),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                studentName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1F2937),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                email,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF6B7280),
                ),
              ),
              pw.Text(
                phone,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF6B7280),
                ),
              ),
              pw.SizedBox(height: 30),

              // Formation
              pw.Text(
                'FORMATION',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1F2937),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                formationTitle,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),

              // Tableau des modules
              pw.Text(
                'MODULES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1F2937),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE5E7EB),
                  width: 1,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Module',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Statut',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...modules.map((module) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                            module,
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Container(
                            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF10B981),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'Inclus',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 30),

              // Tableau de paiement
              pw.Text(
                'DÉTAILS DE PAIEMENT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1F2937),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE5E7EB),
                  width: 1,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Montant',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Statut',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Montant Total',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$montantTotal FCFA',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF6B7280),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF3F4F6),
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Montant Payé',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$montantPaye FCFA',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF10B981),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF10B981),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Payé',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Montant Restant',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$montantRestant FCFA',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: montantRestant > 0
                                ? PdfColor.fromInt(0xFFEF4444)
                                : PdfColor.fromInt(0xFF10B981),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(inscriptionStatusColorValue(statut)),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            inscriptionStatusLabel(statut),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              if (paymentHistory.isNotEmpty) ...[
                pw.Text(
                  'HISTORIQUE DES VERSEMENTS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1F2937),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE5E7EB)),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromInt(AppTheme.primary.toARGB32())),
                      children: ['Tranche', 'Montant', 'Remise', 'État'].map(
                        (label) => pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                        ),
                      ).toList(),
                    ),
                    ...paymentHistory.map(
                      (payment) => pw.TableRow(
                        children: [
                          '${payment['trancheNumero'] ?? 1}/${payment['nombreTranches'] ?? 1}',
                          '${payment['montant'] ?? 0} FCFA',
                          '${payment['remise'] ?? 0} FCFA',
                          '${payment['statusLabel'] ?? 'En attente'}',
                        ].map(
                          (value) => pw.Padding(
                            padding: pw.EdgeInsets.all(6),
                            child: pw.Text(value, style: pw.TextStyle(fontSize: 9)),
                          ),
                        ).toList(),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
              pw.Spacer(),

              // Pied de page
              pw.Divider(color: PdfColor.fromInt(0xFFD1D5DB)),
              pw.SizedBox(height: 12),
              pw.Text(
                'Générée le ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF6B7280),
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
