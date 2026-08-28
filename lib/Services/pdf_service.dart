import 'dart:typed_data';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Generates a Premium High-Security Official PDF Payment Receipt
  Future<Uint8List> generatePaymentReceiptPdf({
    required Payment payment,
    required Inscription inscription,
    required Formation formation,
    String? studentMatricule,
    double? totalInscriptionDue,
    double? cumulativePaid,
    double? remainingBalance,
  }) async {
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#1D447A');
    final crimsonRed = PdfColor.fromHex('#A6192E');
    final goldColor = PdfColor.fromHex('#D4AF37');
    final darkTextColor = PdfColor.fromHex('#0F172A');
    final slateColor = PdfColor.fromHex('#334155');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    final studentName = '${inscription.prenom ?? ''} ${inscription.nom ?? ''}'.trim().toUpperCase();
    final matricule = studentMatricule ??
        (inscription.etudiantId.isNotEmpty
            ? (inscription.etudiantId.startsWith('MAT-')
                ? inscription.etudiantId
                : 'MAT-${inscription.etudiantId.length > 6 ? inscription.etudiantId.substring(inscription.etudiantId.length - 6) : inscription.etudiantId}')
            : 'MAT-OFFICIEL');

    final totalDue = totalInscriptionDue ?? (formation.prix > 0 ? formation.prix : payment.montant);
    final paidAmount = cumulativePaid ?? payment.montant;
    final balance = remainingBalance ?? math.max(0.0, totalDue - paidAmount);
    final isFullySettled = balance <= 0;

    final receiptRef = payment.referenceTransaction != null && payment.referenceTransaction!.trim().isNotEmpty
        ? payment.referenceTransaction!.trim()
        : 'REC-${payment.id.length > 8 ? payment.id.substring(payment.id.length - 8).toUpperCase() : payment.id.toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Decorative Security Frame
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: navyBlue, width: 1.5),
                ),
                padding: const pw.EdgeInsets.all(3),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#FCA5A5'), width: 0.75),
                  ),
                ),
              ),

              // 2. Diagonal Watermark in Center Background
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -math.pi / 5.5,
                    child: pw.Text(
                      'M@LI-NTIC • REÇU OFFICIEL • PAIEMENT VALIDÉ',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#E2E8F0'),
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ),

              // 3. Document Content
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text(
                                    'M@LI-NTIC',
                                    style: pw.TextStyle(
                                      fontSize: 24,
                                      fontWeight: pw.FontWeight.bold,
                                      color: navyBlue,
                                    ),
                                  ),
                                  pw.SizedBox(width: 4),
                                  pw.Container(
                                    width: 7,
                                    height: 7,
                                    decoration: pw.BoxDecoration(
                                      color: crimsonRed,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Centre Professionnel d\'Excellence & de Technologies Nouvelles',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontStyle: pw.FontStyle.italic,
                                  fontWeight: pw.FontWeight.bold,
                                  color: crimsonRed,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Agrément MEN-FP • Hamdallaye ACI 2000, Bamako (Mali)',
                                style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                              ),
                              pw.Text(
                                'Tél : (+223) 70 00 11 22 / 60 00 11 22 • contact@mali-ntic.ml',
                                style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: navyBlue,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: goldColor, width: 1),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'REÇU DE CAISSE',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'N° : $receiptRef',
                                style: pw.TextStyle(
                                  color: goldColor,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9.5,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Date : ${_formatDate(payment.dateEffectuation ?? payment.dateCreation)}',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),
                    // Gold & Navy Gradient Separation Bar
                    pw.Container(
                      height: 2.5,
                      decoration: pw.BoxDecoration(
                        color: navyBlue,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    pw.SizedBox(height: 12),

                    // Dual Cards: Student & Formation
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left Card: Student Info
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: borderGrey, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 4,
                                      height: 12,
                                      decoration: pw.BoxDecoration(
                                        color: navyBlue,
                                        borderRadius: pw.BorderRadius.circular(2),
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'BÉNÉFICIAIRE / APPRENANT',
                                      style: pw.TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: navyBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  studentName.isNotEmpty ? studentName : 'APPRENANT M@LI-NTIC',
                                  style: pw.TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: darkTextColor,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Row(
                                  children: [
                                    pw.Text('Matricule : ', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                                    pw.Text(matricule, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    pw.Text('Téléphone : ', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                                    pw.Text(inscription.telephone ?? 'Non renseigné', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                  ],
                                ),
                                if (inscription.email != null && inscription.email!.isNotEmpty) ...[
                                  pw.SizedBox(height: 2),
                                  pw.Row(
                                    children: [
                                      pw.Text('E-mail : ', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                                      pw.Expanded(
                                        child: pw.Text(inscription.email!, style: pw.TextStyle(fontSize: 8, color: slateColor)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        pw.SizedBox(width: 12),

                        // Right Card: Formation & Registration
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: borderGrey, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 4,
                                      height: 12,
                                      decoration: pw.BoxDecoration(
                                        color: crimsonRed,
                                        borderRadius: pw.BorderRadius.circular(2),
                                      ),
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'FORMATION & SESSION',
                                      style: pw.TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: crimsonRed,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  formation.titre,
                                  style: pw.TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: darkTextColor,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                if (inscription.modules != null && inscription.modules!.isNotEmpty) ...[
                                  pw.Text(
                                    'Modules : ${inscription.modules!.join(", ")}',
                                    style: pw.TextStyle(fontSize: 8, color: slateColor),
                                    maxLines: 1,
                                  ),
                                  pw.SizedBox(height: 2),
                                ],
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Row(
                                      children: [
                                        pw.Text('Modalité : ', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                                        pw.Text(inscription.typeFormation ?? 'Présentiel', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                      ],
                                    ),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColor.fromHex('#EBF5FF'),
                                        borderRadius: pw.BorderRadius.circular(4),
                                        border: pw.Border.all(color: PdfColor.fromHex('#93C5FD'), width: 0.5),
                                      ),
                                      child: pw.Text(
                                        'Tranche ${payment.trancheNumero}/${payment.nombreTranches}',
                                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 14),

                    // Financial Transactions Table
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 0.8),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.2),
                        1: const pw.FlexColumnWidth(1.6),
                        2: const pw.FlexColumnWidth(1.4),
                        3: const pw.FlexColumnWidth(1.8),
                      },
                      children: [
                        // Table Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: navyBlue),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: pw.Text(
                                'DÉSIGNATION / LIBELLÉ',
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: pw.Text(
                                'MODE DE RÈGLEMENT',
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: pw.Text(
                                'STATUT',
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: pw.Text(
                                'MONTANT ENCAISSÉ',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                              ),
                            ),
                          ],
                        ),

                        // Table Body
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.white),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Règlement Tranche ${payment.trancheNumero}/${payment.nombreTranches} — ${formation.titre}',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: darkTextColor),
                                  ),
                                  if (payment.motif != null && payment.motif!.trim().isNotEmpty) ...[
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Motif : ${payment.motif!.trim()}',
                                      style: pw.TextStyle(fontSize: 8, color: slateColor),
                                    ),
                                  ],
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'Réf Transaction : $receiptRef',
                                    style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                                  ),
                                ],
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    _formatPaymentMethod(payment.methode),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: navyBlue),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text('Guichet Caisse', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                ],
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#DEF7EC'),
                                  borderRadius: pw.BorderRadius.circular(4),
                                  border: pw.Border.all(color: PdfColor.fromHex('#31C48D'), width: 0.5),
                                ),
                                child: pw.Text(
                                  'VALIDÉ & ENCAISSÉ',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#03543F')),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '${payment.montant.toStringAsFixed(0)} FCFA',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: navyBlue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 12),

                    // Financial Summary Box & Account Statement
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left Info Note
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: borderGrey, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'OBSERVATIONS & CONDITIONS :',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  '• Tout versement donne droit à l\'accès aux cours et aux supports pédagogiques officiels.\n• Les attestations et certificats de formation ne sont délivrés qu\'après règlement intégral du solde de la formation.',
                                  style: pw.TextStyle(fontSize: 7.5, color: slateColor, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        pw.SizedBox(width: 16),

                        // Right Box: Complete Balance Breakdown
                        pw.Container(
                          width: 230,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: navyBlue, width: 1),
                            boxShadow: const [
                              pw.BoxShadow(
                                color: PdfColors.grey200,
                                blurRadius: 4,
                                offset: PdfPoint(0, 2),
                              ),
                            ],
                          ),
                          child: pw.Column(
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Coût Total Formation :', style: pw.TextStyle(fontSize: 8.5, color: slateColor)),
                                  pw.Text('${totalDue.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                ],
                              ),
                              if (payment.remise > 0) ...[
                                pw.SizedBox(height: 3),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Remise accordée :', style: pw.TextStyle(fontSize: 8, color: crimsonRed)),
                                    pw.Text('-${payment.remise.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                                  ],
                                ),
                              ],
                              pw.SizedBox(height: 4),
                              pw.Divider(color: borderGrey, thickness: 0.5),
                              pw.SizedBox(height: 4),
                              // CURRENT PAYMENT (HIGHLIGHTED)
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#DEF7EC'),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('MONTANT DU REÇU :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColor.fromHex('#03543F'))),
                                    pw.Text('${payment.montant.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#03543F'))),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Cumul Total Payé :', style: pw.TextStyle(fontSize: 8.5, color: slateColor)),
                                  pw.Text('${paidAmount.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                ],
                              ),
                              pw.SizedBox(height: 3),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Solde Restant Dû :', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: isFullySettled ? PdfColor.fromHex('#03543F') : crimsonRed)),
                                  pw.Text(
                                    isFullySettled ? '0 FCFA (SOLDÉ)' : '${balance.toStringAsFixed(0)} FCFA',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: isFullySettled ? PdfColor.fromHex('#03543F') : crimsonRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // Signatures & Official Stamp & QR Code
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Left: Student Signature
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('L\'Apprenant / Déposant', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                            pw.Text('(Pour acquit et acceptation)', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                            pw.SizedBox(height: 35),
                            pw.Container(
                              width: 120,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
                              ),
                            ),
                          ],
                        ),

                        // Center: Verification QR Code
                        pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'https://mali-ntic.ml/verify/receipt?ref=$receiptRef&amt=${payment.montant}&student=$studentName&date=${payment.dateCreation.toIso8601String()}',
                              width: 55,
                              height: 55,
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text('Contrôle d\'Authenticité', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                            pw.Text('Clé : SEC-${payment.id.hashCode.abs().toRadixString(16).toUpperCase()}', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                          ],
                        ),

                        // Right: Official Financial Direction Stamp & Signature
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Direction Financière & Caisse', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            pw.Text('M@LI-NTIC Bamako', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                            pw.SizedBox(height: 6),
                            // Circular Official Stamp Vector
                            pw.Container(
                              width: 90,
                              height: 38,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: crimsonRed, width: 1.2),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Center(
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'M@LI-NTIC • SERVICE CAISSE',
                                      style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: crimsonRed),
                                    ),
                                    pw.Text(
                                      'ENCAISSÉ & VALIDÉ',
                                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                                    ),
                                    pw.Text(
                                      _formatDate(payment.dateEffectuation ?? payment.dateCreation),
                                      style: pw.TextStyle(fontSize: 5.5, color: crimsonRed),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),
                    // Security Footer Bar
                    pw.Divider(color: borderGrey, thickness: 0.5),
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(
                        'Document officiel émis par M@LI-NTIC • Toute rature ou falsification annule la validité du reçu • NIF: 084123987A • RCCM: MA.BKO.2024.B.1298',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                      ),
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

  /// Generates a PDF Brochure for a Formation
  Future<Uint8List> generateFormationBrochurePdf(Formation formation) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0066CC');
    final secondaryColor = PdfColor.fromHex('#E60000');
    final darkTextColor = PdfColor.fromHex('#1E293B');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'M@LI-NTIC',
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.Text('Programme Officiel de Formation', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: secondaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('BROCHURE OFFICIELLE', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: primaryColor, thickness: 2),
              pw.SizedBox(height: 16),

              // Title
              pw.Text(
                formation.titre,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: darkTextColor),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                formation.description,
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 20),

              // Info Cards Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('PRIX DE LA FORMATION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text('${formation.prix.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('DURÉE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text('${formation.dureeSemaines} Semaines', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('STATUT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text('OUVERT AUX INSCRIPTIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Modules List
              pw.Text('PROGRAMME DÉTAILLÉ DES MODULES:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 10),
              if (formation.modules.isNotEmpty)
                ...formation.modules.asMap().entries.map((entry) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 20,
                          height: 20,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: primaryColor,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Text('${entry.key + 1}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(entry.value, style: pw.TextStyle(fontSize: 11, color: darkTextColor)),
                        ),
                      ],
                    ),
                  );
                })
              else
                pw.Text('Programme détaillé disponible lors de l\'inscription.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),

              pw.Spacer(),

              // Footer Action
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Inscriptions en ligne: ${Uri.base.origin.startsWith('http') ? Uri.base.origin : 'https://malintic.com'}', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Contact: +223 70 00 11 22', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
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

  /// Generates the exact Official Certificate / Attestation de Stage M@LI-NTIC
  /// strictly matching images/attestation_model.png
  Future<Uint8List> generateAttestationPdf({
    required Inscription inscription,
    required Formation formation,
    String mention = 'Très Bien',
  }) async {
    final pdf = pw.Document();

    final darkBlue = PdfColor.fromHex('#163E75');
    final royalBlue = PdfColor.fromHex('#1D447A');
    final crimsonRed = PdfColor.fromHex('#8B0000');
    final rubyRed = PdfColor.fromHex('#A6192E');
    final goldColor = PdfColor.fromHex('#F59E0B');
    final darkGold = PdfColor.fromHex('#D97706');
    final lightGold = PdfColor.fromHex('#FEF3C7');
    final warmYellow = PdfColor.fromHex('#FEF08A');

    final fontTimes = pw.Font.times();
    final fontTimesBold = pw.Font.timesBold();
    final fontTimesItalic = pw.Font.timesItalic();
    final fontTimesBoldItalic = pw.Font.timesBoldItalic();

    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('images/Malintic.png');
    } catch (_) {
      try {
        logoImage = await imageFromAssetBundle('images/logo.png');
      } catch (_) {}
    }

    // Determine module list
    final selectedModules = inscription.modules?.where((m) => m.trim().isNotEmpty).toList() ?? const <String>[];
    final modulesList = selectedModules.isNotEmpty
        ? selectedModules
        : (formation.modules.isNotEmpty ? formation.modules : [formation.titre]);
    final modulesString = modulesList.join(', ');

    // Determine dates & French period string
    final now = DateTime.now();
    final dateFait = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final isSfp = formation.estStage ||
        formation.titre.toUpperCase().contains('SFP') ||
        formation.titre.toUpperCase().contains('STAGE') ||
        (formation.modules.length > 5);

    final titlePart1 = isSfp ? 'ATTESTATION DE STAGE DE' : 'ATTESTATION DE';
    final titlePart2 = isSfp ? 'FORMATION PROFESSIONNELLE (SFP)' : 'FORMATION PROFESSIONNELLE';

    // Prefer formation dates for the period string
    final periodString = _formatFrenchPeriod(formation.dateDebut, formation.dateFin, now.year);

    final studentFullName = '${(inscription.prenom ?? '')} ${(inscription.nom ?? '')}'.trim().isNotEmpty
        ? '${(inscription.prenom ?? '')} ${(inscription.nom ?? '')}'.trim()
        : 'Sékou Kariba SAMAKÉ';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          final pageWidth = PdfPageFormat.a4.landscape.width;
          final pageHeight = PdfPageFormat.a4.landscape.height;

          return pw.Stack(
            children: [
              // 1. Exact Background Frame (Layered Geometric Steel Blue Border + White Chamfered/Bracket Card matching model)
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  size: PdfPoint(pageWidth, pageHeight),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    final w = size.x;
                    final h = size.y;

                    // Layer 1: Outer Dark Steel/Navy Blue Base
                    canvas
                      ..setColor(PdfColor.fromHex('#1E3F66'))
                      ..drawRect(0, 0, w, h)
                      ..fillPath();

                    // Layer 2: Mid Slate Blue Inset
                    canvas
                      ..setColor(PdfColor.fromHex('#2D5584'))
                      ..drawRect(3.5, 3.5, w - 7, h - 7)
                      ..fillPath();

                    // Layer 3: Steel Blue Gradient Inset
                    canvas
                      ..setColor(PdfColor.fromHex('#4572A2'))
                      ..drawRect(7.5, 7.5, w - 15, h - 15)
                      ..fillPath();

                    // Layer 4: Soft Accent Inset
                    canvas
                      ..setColor(PdfColor.fromHex('#6D96C2'))
                      ..drawRect(11.5, 11.5, w - 23, h - 23)
                      ..fillPath();

                    // Corner Geometric Shading Triangles for 3D Border Effect
                    // Top-Left Corner Facet
                    canvas
                      ..setColor(PdfColor.fromHex('#163252'))
                      ..moveTo(0, h)
                      ..lineTo(95, h)
                      ..lineTo(0, h - 95)
                      ..closePath()
                      ..fillPath();

                    // Top-Right Corner Facet
                    canvas
                      ..setColor(PdfColor.fromHex('#163252'))
                      ..moveTo(w, h)
                      ..lineTo(w - 95, h)
                      ..lineTo(w, h - 95)
                      ..closePath()
                      ..fillPath();

                    // Bottom-Left Corner Facet
                    canvas
                      ..setColor(PdfColor.fromHex('#163252'))
                      ..moveTo(0, 0)
                      ..lineTo(95, 0)
                      ..lineTo(0, 95)
                      ..closePath()
                      ..fillPath();

                    // Bottom-Right Corner Facet
                    canvas
                      ..setColor(PdfColor.fromHex('#163252'))
                      ..moveTo(w, 0)
                      ..lineTo(w - 95, 0)
                      ..lineTo(w, 95)
                      ..closePath()
                      ..fillPath();

                    // White Central Certificate Card with 4-Corner Chamfers & Symmetrical Side Bracket Indents
                    const m = 18.0;
                    const cut = 38.0;
                    final yTopBracket = h * 0.635;
                    final yBotBracket = h * 0.365;
                    const indent = 16.0;
                    const bevel = 13.0;

                    void traceCardPolygon(double offset) {
                      final mo = m + offset;
                      final cuto = cut - (offset * 0.4);
                      final ytb = yTopBracket - (offset * 0.2);
                      final ybb = yBotBracket + (offset * 0.2);
                      final indo = indent - (offset * 0.3);
                      final bevo = bevel - (offset * 0.2);

                      canvas
                        ..moveTo(mo + cuto, mo)
                        ..lineTo(w - mo - cuto, mo)
                        ..lineTo(w - mo, mo + cuto)
                        ..lineTo(w - mo, ybb - bevo)
                        ..lineTo(w - mo - indo, ybb)
                        ..lineTo(w - mo - indo, ytb)
                        ..lineTo(w - mo, ytb + bevo)
                        ..lineTo(w - mo, h - mo - cuto)
                        ..lineTo(w - mo - cuto, h - mo)
                        ..lineTo(mo + cuto, h - mo)
                        ..lineTo(mo, h - mo - cuto)
                        ..lineTo(mo, ytb + bevo)
                        ..lineTo(mo + indo, ytb)
                        ..lineTo(mo + indo, ybb)
                        ..lineTo(mo, ybb - bevo)
                        ..lineTo(mo, mo + cuto)
                        ..closePath();
                    }

                    // Fill Main White Card
                    canvas.setColor(PdfColors.white);
                    traceCardPolygon(0);
                    canvas.fillPath();

                    // Outer Card Blue Contour Outline
                    canvas
                      ..setColor(PdfColor.fromHex('#3B6FA3'))
                      ..setLineWidth(1.8);
                    traceCardPolygon(0);
                    canvas.strokePath();

                    // Fine Inner Accent Line
                    canvas
                      ..setColor(PdfColor.fromHex('#8CB0D7'))
                      ..setLineWidth(0.8);
                    traceCardPolygon(4.5);
                    canvas.strokePath();
                  },
                ),
              ),

              // 2. Left Gold Rosette Medal Badge with Red Satin Ribbons (Exact match with model)
              pw.Positioned(
                top: 135,
                left: 42,
                child: pw.Container(
                  width: 90,
                  height: 135,
                  child: pw.Stack(
                    alignment: pw.Alignment.topCenter,
                    children: [
                      // Red Ribbon Tails with Angle & Swallowtail V-cut
                      pw.Positioned(
                        top: 48,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Transform.rotate(
                              angle: 0.26,
                              child: pw.CustomPaint(
                                size: const PdfPoint(22, 58),
                                painter: (PdfGraphics canvas, PdfPoint size) {
                                  canvas
                                    ..setColor(PdfColor.fromHex('#DC2626'))
                                    ..moveTo(0, size.y)
                                    ..lineTo(size.x, size.y)
                                    ..lineTo(size.x, 12)
                                    ..lineTo(size.x / 2, 0)
                                    ..lineTo(0, 12)
                                    ..closePath()
                                    ..fillPath();
                                },
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Transform.rotate(
                              angle: -0.26,
                              child: pw.CustomPaint(
                                size: const PdfPoint(22, 58),
                                painter: (PdfGraphics canvas, PdfPoint size) {
                                  canvas
                                    ..setColor(PdfColor.fromHex('#BE123C'))
                                    ..moveTo(0, size.y)
                                    ..lineTo(size.x, size.y)
                                    ..lineTo(size.x, 12)
                                    ..lineTo(size.x / 2, 0)
                                    ..lineTo(0, 12)
                                    ..closePath()
                                    ..fillPath();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Outer Soft Golden Halo
                      pw.Container(
                        width: 78,
                        height: 78,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: lightGold,
                          border: pw.Border.all(color: PdfColor.fromHex('#FDE68A'), width: 1.2),
                        ),
                        child: pw.Center(
                          // Golden Medallion Ring
                          child: pw.Container(
                            width: 66,
                            height: 66,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: goldColor,
                              border: pw.Border.all(color: darkGold, width: 2.2),
                            ),
                            child: pw.Center(
                              // Inner Warm Yellow Disc
                              child: pw.Container(
                                width: 52,
                                height: 52,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  color: warmYellow,
                                  border: pw.Border.all(color: goldColor, width: 1.2),
                                ),
                                child: pw.Center(
                                  // Amber Gold 5-Point Star
                                  child: pw.CustomPaint(
                                    size: const PdfPoint(30, 30),
                                    painter: (PdfGraphics canvas, PdfPoint size) {
                                      final cx = size.x / 2;
                                      final cy = size.y / 2;
                                      const outerR = 14.0;
                                      const innerR = 6.0;

                                      canvas.setColor(darkGold);
                                      for (int i = 0; i < 5; i++) {
                                        final outerAngle = (i * 72 - 90) * 3.141592653589793 / 180;
                                        final innerAngle = (i * 72 + 36 - 90) * 3.141592653589793 / 180;

                                        final ox = cx + outerR * math.cos(outerAngle);
                                        final oy = cy + outerR * math.sin(outerAngle);
                                        final ix = cx + innerR * math.cos(innerAngle);
                                        final iy = cy + innerR * math.sin(innerAngle);

                                        if (i == 0) {
                                          canvas.moveTo(ox, oy);
                                        } else {
                                          canvas.lineTo(ox, oy);
                                        }
                                        canvas.lineTo(ix, iy);
                                      }
                                      canvas.closePath();
                                      canvas.fillPath();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Main Certificate Document Body (Exact text and styling from model)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 22),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Top Header : Logo M@LI-NTIC + Brand Title
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null) ...[
                          pw.Image(logoImage, width: 85, height: 58),
                          pw.SizedBox(width: 16),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'M@LI-NTIC',
                              style: pw.TextStyle(
                                font: fontTimesBold,
                                fontSize: 34,
                                color: royalBlue,
                                letterSpacing: 2.2,
                              ),
                            ),
                            pw.Text(
                              'L\'univers des Technologies',
                              style: pw.TextStyle(
                                font: fontTimesItalic,
                                fontSize: 13.5,
                                color: rubyRed,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 8),

                    // Header Horizontal Blue Separator Line
                    pw.Container(
                      width: 580,
                      height: 2.5,
                      color: royalBlue,
                    ),

                    pw.SizedBox(height: 14),

                    // Main Title (Dark Crimson Red Bold Serif)
                    pw.Text(
                      titlePart1,
                      style: pw.TextStyle(
                        font: fontTimesBold,
                        fontSize: 20.5,
                        color: crimsonRed,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      titlePart2,
                      style: pw.TextStyle(
                        font: fontTimesBold,
                        fontSize: 20.5,
                        color: crimsonRed,
                        letterSpacing: 1.2,
                      ),
                    ),

                    pw.SizedBox(height: 14),

                    // Attestation Declaration Statement
                    pw.Text(
                      'Je soussigné, Souleymane TRAORÉ, Directeur Général, atteste que :',
                      style: pw.TextStyle(
                        font: fontTimes,
                        fontSize: 14,
                        color: PdfColors.black,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Recipient Student Name (Large Serif, underlined with clean black rule)
                    pw.Column(
                      children: [
                        pw.Text(
                          studentFullName,
                          style: pw.TextStyle(
                            font: fontTimesBold,
                            fontSize: 24,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: 400,
                          height: 1.8,
                          color: PdfColors.black,
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // Body Training Text
                    pw.Text(
                      'A effectué un Stage de Formation Professionnelle avec assiduité à travers les modules suivants:',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontTimes,
                        fontSize: 12.5,
                        color: PdfColors.black,
                      ),
                    ),

                    pw.SizedBox(height: 6),

                    // List of Modules (In bold Crimson Red)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 50),
                      child: pw.Text(
                        modulesString,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: fontTimesBold,
                          fontSize: 12.5,
                          color: crimsonRed,
                          lineSpacing: 3,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Stage Period (Black prefix + Dark Blue bold dates)
                    pw.RichText(
                      text: pw.TextSpan(
                        style: pw.TextStyle(
                          font: fontTimes,
                          fontSize: 13,
                          color: PdfColors.black,
                        ),
                        children: [
                          pw.TextSpan(
                            text: 'Périodes du Stage : ',
                            style: pw.TextStyle(font: fontTimesBold),
                          ),
                          pw.TextSpan(
                            text: periodString,
                            style: pw.TextStyle(
                              font: fontTimesBold,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Legal Statement
                    pw.Text(
                      'La présente attestation est délivrée en exemple unique, pour servir et valoir ce que de droit.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontTimesBold,
                        fontSize: 12,
                        color: PdfColors.black,
                      ),
                    ),

                    pw.Spacer(),

                    // Centered Date & Signature Section (Exact match with model)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Fait à Bamako,  le $dateFait',
                          style: pw.TextStyle(
                            font: fontTimesBold,
                            fontSize: 12,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          width: 250,
                          height: 1.5,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Directeur Général',
                          style: pw.TextStyle(
                            font: fontTimesBoldItalic,
                            fontSize: 13,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Souleymane TRAORÉ',
                          style: pw.TextStyle(
                            font: fontTimesBoldItalic,
                            fontSize: 14.5,
                            color: darkBlue,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
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

  /// Generates an Official Student Comprehensive Profile & Academic Dossier PDF
  Future<Uint8List> generateStudentProfileDossierPdf({
    required String prenom,
    required String nom,
    required String email,
    required String telephone,
    String? matricule,
    String? genre,
    String? adresse,
    DateTime? dateCreation,
    List<Map<String, dynamic>> formations = const [],
    List<Map<String, dynamic>> paiements = const [],
    Map<String, dynamic> assiduite = const {},
    double totalDue = 0.0,
    double totalPaid = 0.0,
    double remainingBalance = 0.0,
  }) async {
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#1D447A');
    final crimsonRed = PdfColor.fromHex('#A6192E');
    final goldColor = PdfColor.fromHex('#D4AF37');
    final darkTextColor = PdfColor.fromHex('#0F172A');
    final slateColor = PdfColor.fromHex('#334155');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    final fullName = '$prenom $nom'.trim().toUpperCase();
    final studentMatricule = matricule ?? 'MAT-OFFICIEL';
    final isFullySettled = remainingBalance <= 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Security Frame
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: navyBlue, width: 1.5),
                ),
                padding: const pw.EdgeInsets.all(3),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#FCA5A5'), width: 0.75),
                  ),
                ),
              ),

              // Diagonal Watermark
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -math.pi / 5.5,
                    child: pw.Text(
                      'M@LI-NTIC • DOSSIER ÉTUDIANT OFFICIEL',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#F1F5F9'),
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Main Document
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text(
                                    'M@LI-NTIC',
                                    style: pw.TextStyle(
                                      fontSize: 22,
                                      fontWeight: pw.FontWeight.bold,
                                      color: navyBlue,
                                    ),
                                  ),
                                  pw.SizedBox(width: 4),
                                  pw.Container(
                                    width: 6,
                                    height: 6,
                                    decoration: pw.BoxDecoration(color: crimsonRed, shape: pw.BoxShape.circle),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Centre Professionnel d\'Excellence & de Technologies Nouvelles',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontStyle: pw.FontStyle.italic,
                                  fontWeight: pw.FontWeight.bold,
                                  color: crimsonRed,
                                ),
                              ),
                              pw.Text(
                                'Hamdallaye ACI 2000, Bamako • Tél : (+223) 70 00 11 22 • contact@mali-ntic.ml',
                                style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: navyBlue,
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(color: goldColor, width: 1),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'FICHE INDIVIDUELLE',
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10.5),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Matricule : $studentMatricule',
                                style: pw.TextStyle(color: goldColor, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                              ),
                              pw.Text(
                                'Édité le : ${_formatDate(DateTime.now())}',
                                style: const pw.TextStyle(color: PdfColors.white, fontSize: 7.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 8),
                    pw.Container(height: 2, color: navyBlue),
                    pw.SizedBox(height: 10),

                    // Section 1: Identification de l'Apprenant
                    pw.Container(
                      padding: const pw.EdgeInsets.all(9),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: borderGrey, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(width: 4, height: 10, color: navyBlue),
                              pw.SizedBox(width: 5),
                              pw.Text('ÉTAT CIVIL & COORDONNÉES', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Nom & Prénom :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text(fullName.isNotEmpty ? fullName : 'APPRENANT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Téléphone :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text(telephone.isNotEmpty ? telephone : 'Non renseigné', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('E-mail :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text(email.isNotEmpty ? email : 'Non renseigné', style: pw.TextStyle(fontSize: 8.5, color: darkTextColor)),
                                  ],
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Genre :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text(genre ?? 'M', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Section 2: Formations & Cursus
                    pw.Text('CURSUS PÉDAGOGIQUE & FORMATIONS SUIVIES', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 0.8),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.5),
                        1: const pw.FlexColumnWidth(2.5),
                        2: const pw.FlexColumnWidth(1.5),
                        3: const pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: navyBlue),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Formation / Intitulé', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Modules Associés', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Modalité', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: pw.Text('Progression', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                            ),
                          ],
                        ),
                        if (formations.isEmpty)
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text('Aucune formation enregistrée', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                              ),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                            ],
                          )
                        else
                          ...formations.map((f) {
                            final title = f['title']?.toString() ?? 'Formation M@LI-NTIC';
                            final mods = (f['modules'] as List<dynamic>? ?? []).map((m) => m['title']?.toString() ?? '').where((m) => m.isNotEmpty).join(', ');
                            final mode = f['modeSuivi']?.toString() ?? 'Présentiel';
                            final progress = f['progress']?.toString() ?? 'En cours';

                            return pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(mods.isNotEmpty ? mods : 'Tronc commun', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(mode, style: pw.TextStyle(fontSize: 7.5, color: navyBlue, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(progress, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // Section 3: Bilan Financier & Assiduité (Dual Cards)
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Financial Summary
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: borderGrey, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(width: 4, height: 10, color: goldColor),
                                    pw.SizedBox(width: 5),
                                    pw.Text('SITUATION FINANCIÈRE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                  ],
                                ),
                                pw.SizedBox(height: 5),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Total des Formations :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text('${totalDue.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Montant Versé :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text('${totalPaid.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#03543F'))),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Solde Restant :', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: isFullySettled ? PdfColor.fromHex('#03543F') : crimsonRed)),
                                    pw.Text(
                                      isFullySettled ? '0 FCFA (SOLDÉ)' : '${remainingBalance.toStringAsFixed(0)} FCFA',
                                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: isFullySettled ? PdfColor.fromHex('#03543F') : crimsonRed),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        pw.SizedBox(width: 10),

                        // Right: Attendance Summary
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(color: borderGrey, width: 0.8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    pw.Container(width: 4, height: 10, color: crimsonRed),
                                    pw.SizedBox(width: 5),
                                    pw.Text('ASSIDUITÉ & PRÉSENCES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                                  ],
                                ),
                                pw.SizedBox(height: 5),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Séances Présent :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text('${assiduite['presentCount'] ?? 0} séance(s)', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#03543F'))),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Absences :', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                                    pw.Text('${assiduite['absentCount'] ?? 0} séance(s)', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Taux Global d\'Assiduité :', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                    pw.Text('${assiduite['rate'] ?? '100%'}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // Section 4: Historique des Transactions
                    if (paiements.isNotEmpty) ...[
                      pw.Text('HISTORIQUE DES VERSEMENTS & REÇUS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderGrey, width: 0.8),
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Date', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Réf. / Reçu', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Mode', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Montant', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                            ],
                          ),
                          ...paiements.take(4).map((p) {
                            return pw.TableRow(
                              children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p['date']?.toString() ?? '', style: const pw.TextStyle(fontSize: 7))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p['reference']?.toString() ?? '', style: const pw.TextStyle(fontSize: 7))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(p['methode']?.toString() ?? '', style: const pw.TextStyle(fontSize: 7))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${p['montant']?.toString() ?? '0'} FCFA', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],

                    pw.Spacer(),

                    // Signatures & Stamp
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('L\'Apprenant(e)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                            pw.SizedBox(height: 25),
                            pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)))),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'https://mali-ntic.ml/verify/student?mat=$studentMatricule&nom=$fullName',
                              width: 45,
                              height: 45,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('Vérification Officielle', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Direction des Études M@LI-NTIC', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 85,
                              height: 32,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: crimsonRed, width: 1),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Center(
                                child: pw.Column(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text('M@LI-NTIC • ÉTUDES', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                                    pw.Text('DOSSIER VALIDÉ', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Divider(color: borderGrey, thickness: 0.5),
                    pw.Center(
                      child: pw.Text(
                        'Document académique officiel délivré par M@LI-NTIC Bamako • Agrément MEN-FP',
                        style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                      ),
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

  /// Generates a PDF Official Student ID Card
  Future<Uint8List> generateStudentCardPdf({
    required String prenom,
    required String nom,
    required String email,
    required String telephone,
    String formationTitre = 'Formation M@LI-NTIC',
    String? matricule,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0066CC');
    final secondaryColor = PdfColor.fromHex('#E60000');
    final darkTextColor = PdfColor.fromHex('#1E293B');

    final studentMatricule = (matricule != null && matricule.isNotEmpty)
        ? matricule
        : 'MAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(240, 150, marginAll: 10),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFFFFF'),
              border: pw.Border.all(color: primaryColor, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('M@LI-NTIC', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(color: secondaryColor, borderRadius: pw.BorderRadius.circular(3)),
                      child: pw.Text('CARTE ÉTUDIANT', style: pw.TextStyle(color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(color: primaryColor, thickness: 1),
                pw.SizedBox(height: 4),

                // Info body
                pw.Row(
                  children: [
                    pw.Container(
                      width: 45,
                      height: 55,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                      ),
                      child: pw.Center(
                        child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('$prenom $nom'.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                          pw.Text('Matricule: $studentMatricule', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('Tél: $telephone', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                          pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                          pw.Text('Formation: $formationTitre', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                        ],
                      ),
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'STUDENT-$studentMatricule-$email',
                      width: 40,
                      height: 40,
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('Centre M@LI-NTIC Bamako | www.mali-ntic.ml', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a Premium Official Attendance & Emargement Sheet PDF
  Future<Uint8List> generateAttendanceSheetPdf({
    String? formationTitle,
    String? formationTitre,
    String? moduleTitle,
    String? moduleTitre,
    String? cohortName,
    required String formateurNom,
    String jour = 'Séance',
    String heureDebut = '09:00',
    String heureFin = '11:00',
    String? salleOuLien,
    String modalite = 'Présentiel',
    DateTime? dateSeance,
    List<User>? students,
    List<Map<String, dynamic>>? apprenants,
  }) async {
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#1D447A');
    final darkTextColor = PdfColor.fromHex('#0F172A');
    final slateColor = PdfColor.fromHex('#334155');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    final actualFormationTitle = formationTitle ?? formationTitre ?? 'Formation M@LI-NTIC';
    final actualModuleTitle = moduleTitle ?? moduleTitre;
    final seanceDate = dateSeance ?? DateTime.now();
    final dateStr = '${jour.toUpperCase()} ${_formatDate(seanceDate)}';
    final qrData = 'MALINTIC-EMARGEMENT|FORM:${actualFormationTitle.replaceAll("|", "")}|MOD:${actualModuleTitle ?? "TRONC-COMMUN"}|DATE:$dateStr|HEURE:$heureDebut-$heureFin';

    // Normalize student list into rows
    final List<Map<String, String>> studentRows = [];
    if (students != null && students.isNotEmpty) {
      for (final s in students) {
        studentRows.add({
          'matricule': s.matricule ?? 'MAT-${s.id.substring(0, math.min(6, s.id.length)).toUpperCase()}',
          'nom': s.nomComplet.toUpperCase(),
          'phone': s.phone,
        });
      }
    } else if (apprenants != null && apprenants.isNotEmpty) {
      for (final a in apprenants) {
        final prenom = a['prenom']?.toString() ?? '';
        final nom = a['nom']?.toString() ?? '';
        final nomComplet = '$prenom $nom'.trim().toUpperCase();
        final tel = a['telephone']?.toString() ?? a['phone']?.toString() ?? 'N/A';
        final mat = a['matricule']?.toString() ?? 'MAT-OFFICIEL';
        studentRows.add({
          'matricule': mat,
          'nom': nomComplet.isNotEmpty ? nomComplet : (a['nom']?.toString() ?? 'APPRENANT'),
          'phone': tel,
        });
      }
    }

    final totalRows = math.max(studentRows.length, 12);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. TOP NATIONAL BORDER & HEADER
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#10B981'))),
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#F59E0B'))),
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#EF4444'))),
                ],
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CENTRE DE FORMATION PROFESSIONNELLE M@LI_NTIC',
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: navyBlue,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Agrément N° 2024/0842/MEN-DG - Bamako, République du Mali',
                        style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                      ),
                      pw.Text(
                        'Tél: +223 70 00 00 00 / 60 00 00 00 • Email: contact@malintic.ml',
                        style: pw.TextStyle(fontSize: 7.5, color: slateColor),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: navyBlue,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'FEUILLE D\'ÉMARGEMENT OFFICIELLE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(color: borderGrey, thickness: 0.8),
              pw.SizedBox(height: 6),

              // 2. SESSION METADATA CARD
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Formation : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: actualFormationTitle, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 2,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Module : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: actualModuleTitle ?? 'Tronc Commun', style: pw.TextStyle(fontSize: 8.5, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Formateur : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: formateurNom, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 2,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Cohorte / Groupe : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: cohortName ?? 'Tous Groupes', style: pw.TextStyle(fontSize: 8.5, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Séance : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: '$dateStr ($heureDebut - $heureFin)', style: pw.TextStyle(fontSize: 8.5, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 2,
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Salle / Modalité : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                                pw.TextSpan(text: '$modalite ${salleOuLien != null && salleOuLien.isNotEmpty ? "• $salleOuLien" : ""}', style: pw.TextStyle(fontSize: 8.5, color: darkTextColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // 3. TABLE OF STUDENTS
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FixedColumnWidth(24),
                  1: pw.FixedColumnWidth(75),
                  2: pw.FlexColumnWidth(3),
                  3: pw.FixedColumnWidth(80),
                  4: pw.FixedColumnWidth(65),
                  5: pw.FlexColumnWidth(2.2),
                  6: pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: navyBlue),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('N°', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Matricule', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Nom & Prénom de l\'Apprenant', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Contact', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Statut Présence', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Signature Apprenant', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Observations', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                    ],
                  ),

                  for (int i = 0; i < totalRows; i++) ...[
                    if (i < studentRows.length) ...[
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC')),
                        children: [
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 8, color: slateColor))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text(studentRows[i]['matricule']!, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                          pw.Container(height: 22, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text(studentRows[i]['nom']!, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text(studentRows[i]['phone']!, style: pw.TextStyle(fontSize: 7.5, color: slateColor))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('[  ] P   [  ] A   [  ] R', style: pw.TextStyle(fontSize: 7, color: slateColor))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('..........................', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(fontSize: 7, color: slateColor))),
                        ],
                      ),
                    ] else ...[
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC')),
                        children: [
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 8, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('................', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text('...................................................', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('................', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('[  ] P   [  ] A   [  ] R', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('..........................', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                          pw.Container(height: 22, alignment: pw.Alignment.center, child: pw.Text('', style: pw.TextStyle(fontSize: 7, color: borderGrey))),
                        ],
                      ),
                    ],
                  ],
                ],
              ),

              pw.Spacer(),

              // 4. SUMMARY & SIGNATURES SECTION
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILAN DE LA SÉANCE :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                        pw.SizedBox(height: 2),
                        pw.Text('• Inscrits convoqués : ${studentRows.length}', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                        pw.Text('• Total Présents (P) : .........   • Absents (A) : .........   • Retards (R) : .........', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                        pw.Text('• Taux de présence constaté : .............. %', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                      ],
                    ),
                    pw.Container(
                      width: 46,
                      height: 46,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        drawText: false,
                        color: navyBlue,
                      ),
                    ),
                    pw.Row(
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('Signature Formateur', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                            pw.SizedBox(height: 22),
                            pw.Text(formateurNom, style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                          ],
                        ),
                        pw.SizedBox(width: 20),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('Direction Pédagogique', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            pw.SizedBox(height: 22),
                            pw.Text('Visa & Cachet Officiel', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                          ],
                        ),
                      ],
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

  /// Triggers printing or downloading PDF
  Future<void> printOrDownloadPdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }

  String _formatPaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.virement:
        return 'Virement Bancaire';
      case PaymentMethod.carte:
        return 'Carte Bancaire';
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.moovMoney:
        return 'Moov Money';
    }
  }

  String _formatFrenchPeriod(DateTime? start, DateTime? end, int fallbackYear) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    if (start != null && end != null) {
      final startStr = '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1]}';
      final endStr = '${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]} ${end.year}';
      return '$startStr au $endStr';
    }
    return '26 Avril au 02 Août $fallbackYear';
  }

  /// Generates a Premium Official Trainer Honorarium & Compensation Slip PDF (Fiche de Paie / Honoraires Formateur)
  Future<Uint8List> generateTrainerHonorariumSlipPdf({
    required String formateurNom,
    required String email,
    required String telephone,
    String? matricule,
    String? specialite,
    String? periode,
    double tauxHoraire = 5000.0,
    double totalHeures = 0.0,
    double acompteVerse = 0.0,
    double primesOuBonus = 0.0,
    List<Map<String, dynamic>> modulesEnseignes = const [],
    String? note,
  }) async {
    final pdf = pw.Document();

    final navyBlue = PdfColor.fromHex('#1D447A');
    final crimsonRed = PdfColor.fromHex('#A6192E');
    final goldColor = PdfColor.fromHex('#D4AF37');
    final darkTextColor = PdfColor.fromHex('#0F172A');
    final slateColor = PdfColor.fromHex('#334155');
    final lightBgColor = PdfColor.fromHex('#F8FAFC');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    final refSlip = 'HON-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final brutCalculated = (totalHeures * tauxHoraire) + primesOuBonus;
    final netPayable = math.max(0.0, brutCalculated - acompteVerse);
    final periodStr = periode ?? '${_formatDate(DateTime(DateTime.now().year, DateTime.now().month, 1))} au ${_formatDate(DateTime.now())}';

    final qrData = 'MALINTIC-HONORAIRES|REF:$refSlip|FORMATEUR:$formateurNom|PERIODE:$periodStr|NET:${netPayable.toStringAsFixed(0)}FCFA';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. NATIONAL TRICOLOR TOP BAR
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#10B981'))),
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#F59E0B'))),
                  pw.Expanded(child: pw.Container(height: 3.5, color: PdfColor.fromHex('#EF4444'))),
                ],
              ),
              pw.SizedBox(height: 10),

              // 2. HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CENTRE DE FORMATION PROFESSIONNELLE M@LI_NTIC',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyBlue),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Agrément N° 2024/0842/MEN-DG - Bamako, République du Mali', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                      pw.Text('Département Financier & Pédagogique • contact@malintic.ml', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: navyBlue,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('BULLETIN D\'HONORAIRES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.Text('Réf: $refSlip', style: pw.TextStyle(fontSize: 7.5, color: goldColor)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(color: borderGrey, thickness: 0.8),
              pw.SizedBox(height: 6),

              // 3. TRAINER & PERIOD CARD
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BÉNÉFICIAIRE (FORMATEUR / CONSULTANT)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                        pw.SizedBox(height: 3),
                        pw.Text(formateurNom.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Matricule : ${matricule ?? "N/A"} • Spécialité : ${specialite ?? "Informatique & NTIC"}', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                        pw.Text('Contact : $telephone • $email', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PÉRIODE DE PRESTATION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                        pw.SizedBox(height: 3),
                        pw.Text(periodStr, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        pw.SizedBox(height: 2),
                        pw.Text('Taux horaire conventionné : ${tauxHoraire.toStringAsFixed(0)} FCFA / heure', style: pw.TextStyle(fontSize: 8, color: crimsonRed, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // 4. BREAKDOWN OF MODULES & HOURS
              pw.Text('DÉTAIL DES MODULES & HEURES D\'ENSEIGNEMENT EFFECTUÉES', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
              pw.SizedBox(height: 4),

              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 0.6),
                columnWidths: const {
                  0: pw.FixedColumnWidth(24),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FixedColumnWidth(60),
                  4: pw.FixedColumnWidth(70),
                  5: pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: navyBlue),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('N°', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Formation', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Module / Thématique', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Heures', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Taux (FCFA)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Montant Brut', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)))),
                    ],
                  ),

                  if (modulesEnseignes.isNotEmpty) ...[
                    for (int i = 0; i < modulesEnseignes.length; i++) ...[
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC')),
                        children: [
                          pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 8, color: slateColor))),
                          pw.Container(height: 20, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text(modulesEnseignes[i]['formation']?.toString() ?? 'Formation Générale', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                          pw.Container(height: 20, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text(modulesEnseignes[i]['module']?.toString() ?? 'Tronc Commun', style: pw.TextStyle(fontSize: 7.5, color: slateColor))),
                          pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text('${modulesEnseignes[i]['heures'] ?? "0"} h', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                          pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text(tauxHoraire.toStringAsFixed(0), style: pw.TextStyle(fontSize: 7.5, color: slateColor))),
                          pw.Container(height: 20, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.only(right: 6), child: pw.Text('${((modulesEnseignes[i]['heures'] as num? ?? 0) * tauxHoraire).toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                        ],
                      ),
                    ],
                  ] else ...[
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text('1', style: pw.TextStyle(fontSize: 8, color: slateColor))),
                        pw.Container(height: 20, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text('Enseignement & Encadrement Pédagogique', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                        pw.Container(height: 20, alignment: pw.Alignment.centerLeft, padding: const pw.EdgeInsets.only(left: 4), child: pw.Text('Modules Assignés - Centre M@LI_NTIC', style: pw.TextStyle(fontSize: 7.5, color: slateColor))),
                        pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text('${totalHeures.toStringAsFixed(0)} h', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                        pw.Container(height: 20, alignment: pw.Alignment.center, child: pw.Text(tauxHoraire.toStringAsFixed(0), style: pw.TextStyle(fontSize: 7.5, color: slateColor))),
                        pw.Container(height: 20, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.only(right: 6), child: pw.Text('${(totalHeures * tauxHoraire).toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                      ],
                    ),
                  ],
                ],
              ),

              pw.SizedBox(height: 10),

              // 5. FINANCIAL RECAP BOX
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: borderGrey, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CONDITIONS DE RÈGLEMENT & OBSERVATIONS :', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '• Les honoraires sont calculés sur la base des séances effectives renseignées sur les feuilles d\'émargement officielles.\n• Tout versement libère l\'administration après signature conjointe du présent bulletin.',
                            style: pw.TextStyle(fontSize: 7, color: slateColor, height: 1.3),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Note: $note', style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: darkTextColor)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: navyBlue, width: 1),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Heures :', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                              pw.Text('${totalHeures.toStringAsFixed(0)} h', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Brut :', style: pw.TextStyle(fontSize: 8, color: slateColor)),
                              pw.Text('${brutCalculated.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                            ],
                          ),
                          if (primesOuBonus > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Primes / Bonus :', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#10B981'))),
                                pw.Text('+${primesOuBonus.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#10B981'))),
                              ],
                            ),
                          ],
                          if (acompteVerse > 0) ...[
                            pw.SizedBox(height: 2),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Acomptes versés :', style: pw.TextStyle(fontSize: 7.5, color: crimsonRed)),
                                pw.Text('-${acompteVerse.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: crimsonRed)),
                              ],
                            ),
                          ],
                          pw.Divider(color: borderGrey, thickness: 0.5),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: navyBlue,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('NET À PAYER :', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                pw.Text('${netPayable.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: goldColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // 6. SIGNATURES & QR
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Le Formateur / Prestataire', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        pw.SizedBox(height: 20),
                        pw.Text(formateurNom, style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                      ],
                    ),

                    pw.Container(
                      width: 44,
                      height: 44,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        drawText: false,
                        color: navyBlue,
                      ),
                    ),

                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Direction Administrative & Financière', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                        pw.SizedBox(height: 20),
                        pw.Text('M@LI_NTIC • Visa & Bon à Payer', style: pw.TextStyle(fontSize: 7.5, color: slateColor)),
                      ],
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


