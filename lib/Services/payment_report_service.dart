import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:gestion_formations/config/theme.dart';

class PaymentReportService {
  static Future<Uint8List> generatePaymentReportPDF({
    required List<Map<String, dynamic>> payments,
    required Map<String, int> statusCounts,
    required double totalAmount,
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
                        'RAPPORT DE PAIEMENTS',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Centre de Formation Professionnelle',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColor.fromInt(0xFF6B7280),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Édité le ${_formatDate(DateTime.now())} • ${payments.length} opération(s)',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Résumé statistiques
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF3F4F6),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RÉSUMÉ DES PAIEMENTS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1F2937),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Total Paiements',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromInt(0xFF6B7280),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '$totalAmount FCFA',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Nombre Total',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromInt(0xFF6B7280),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${payments.length}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'En Attente',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromInt(0xFF6B7280),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${statusCounts['en_attente'] ?? 0}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Validés',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromInt(0xFF6B7280),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              '${statusCounts['valide'] ?? 0}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Tableau des paiements
              pw.Text(
                'DÉTAILS DES ENCAISSEMENTS & PAIEMENTS',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1F2937),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFFE5E7EB),
                  width: 0.8,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.2), // Étudiant / Apprenant (Identité & Traçabilité)
                  1: const pw.FlexColumnWidth(1.8), // Formation
                  2: const pw.FlexColumnWidth(1.6), // Montant
                  3: const pw.FlexColumnWidth(1.4), // Statut
                  4: const pw.FlexColumnWidth(1.8), // Date & Réf
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Text(
                          'Apprenant (ID / Matricule)',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Text(
                          'Formation',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Text(
                          'Montant',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Text(
                          'Statut',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Text(
                          'Date & Réf',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...payments.map((payment) {
                    final rawStatus = (payment['status'] ?? payment['statut'] ?? payment['statutMontant'] ?? 'effectue').toString();
                    final statusColor = _getStatusColor(rawStatus);
                    final statusLabel = _getStatusLabel(rawStatus);

                    // Extract Student Info
                    final studentName = (payment['studentName'] ??
                            payment['stagiaire'] ??
                            payment['etudiantNom'] ??
                            payment['nomComplet'] ??
                            payment['nom'] ??
                            'Apprenant')
                        .toString();

                    final matricule = (payment['matricule'] ??
                            payment['studentMatricule'] ??
                            payment['etudiantMatricule'] ??
                            payment['etudiantId'] ??
                            payment['studentId'] ??
                            '')
                        .toString();

                    final phone = (payment['phone'] ?? payment['telephone'] ?? '').toString();
                    final formationTitle = (payment['formation'] ?? payment['formationTitre'] ?? 'Formation').toString();
                    final methode = (payment['methode'] ?? payment['mode'] ?? '').toString();
                    final reference = (payment['reference'] ?? payment['ref'] ?? payment['id'] ?? '').toString();

                    // Resolve Date
                    String dateStr = 'N/A';
                    final rawDate = payment['date'] ?? payment['dateCreation'];
                    if (rawDate != null) {
                      if (rawDate is DateTime) {
                        dateStr = '${rawDate.day.toString().padLeft(2, '0')}/${rawDate.month.toString().padLeft(2, '0')}/${rawDate.year}';
                      } else {
                        final str = rawDate.toString();
                        dateStr = str.contains('T') ? str.split('T')[0] : (str.contains(' ') ? str.split(' ')[0] : str);
                      }

                    }

                    // Resolve Amount
                    final rawMontant = payment['montant'];
                    final double montantNum = (rawMontant is num)
                        ? rawMontant.toDouble()
                        : (double.tryParse(rawMontant?.toString() ?? '0') ?? 0.0);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: payments.indexOf(payment) % 2 == 1 ? PdfColor.fromInt(0xFFF9FAFB) : PdfColors.white,
                      ),
                      children: [
                        // Col 0: Apprenant avec Identifiant Unique de Traçabilité
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                studentName,
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF111827),
                                ),
                              ),
                              if (matricule.isNotEmpty && matricule != 'N/A')
                                pw.Text(
                                  'Matricule: $matricule',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromInt(AppTheme.primary.toARGB32()),
                                  ),
                                ),
                              if (phone.isNotEmpty)
                                pw.Text(
                                  'Tél: $phone',
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    color: PdfColor.fromInt(0xFF6B7280),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Col 1: Formation
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Text(
                            formationTitle,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              color: PdfColor.fromInt(0xFF374151),
                            ),
                          ),
                        ),

                        // Col 2: Montant
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${montantNum.toStringAsFixed(0)} FCFA',
                                style: pw.TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF059669),
                                ),
                              ),
                              if (methode.isNotEmpty)
                                pw.Text(
                                  methode.toUpperCase(),
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    color: PdfColor.fromInt(0xFF6B7280),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Col 3: Statut
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: statusColor,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              statusLabel,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),

                        // Col 4: Date & Réf
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                dateStr,
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF374151),
                                ),
                              ),
                              if (reference.isNotEmpty && reference != 'N/A')
                                  pw.Text(
                                    'Réf: ${reference.length > 12 ? '${reference.substring(0, 12)}...' : reference}',
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColor.fromInt(0xFF9CA3AF),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.Spacer(),

              // Pied de page
              pw.Divider(color: PdfColor.fromInt(0xFFD1D5DB)),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Document officiel - Traçabilité financière certifiée',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColor.fromInt(0xFF6B7280),
                    ),
                  ),
                  pw.Text(
                    'Généré le ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year} à ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColor.fromInt(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static PdfColor _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('valide') || s.contains('pay') || s.contains('effectue')) {
      return PdfColor.fromInt(0xFF10B981);
    } else if (s.contains('incomplet') || s.contains('partiel') || s.contains('avance')) {
      return PdfColor.fromInt(0xFFFB923C);
    } else if (s.contains('attente')) {
      return PdfColor.fromInt(0xFFF59E0B);
    } else if (s.contains('echou') || s.contains('annul') || s.contains('rej')) {
      return PdfColor.fromInt(0xFFEF4444);
    }
    return PdfColor.fromInt(0xFF10B981);
  }

  static String _getStatusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('valide') || s.contains('pay') || s.contains('effectue')) {
      return 'Validé';
    } else if (s.contains('incomplet') || s.contains('partiel') || s.contains('avance')) {
      return 'Incomplet';
    } else if (s.contains('attente')) {
      return 'En Attente';
    } else if (s.contains('echou') || s.contains('annul') || s.contains('rej')) {
      return 'Échoué';
    }
    return 'Validé';
  }
}
