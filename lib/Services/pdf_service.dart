import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/formation.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Generates a PDF Payment Receipt
  Future<Uint8List> generatePaymentReceiptPdf({
    required Payment payment,
    required Inscription inscription,
    required Formation formation,
  }) async {
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
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'M@LI-NTIC',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        'Centre de Formation Professionnelle en Nouvelles Technologies',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Bamako, Mali | Tél: +223 70 00 11 22 | Email: contact@mali-ntic.ml',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'REÇU DE PAIEMENT',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: secondaryColor, thickness: 2),
              pw.SizedBox(height: 16),

              // Transaction Info & Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Référence: ${payment.referenceTransaction ?? payment.id}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: darkTextColor),
                  ),
                  pw.Text(
                    'Date: ${_formatDate(payment.dateEffectuation ?? payment.dateCreation)}',
                    style: const pw.TextStyle(color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Student Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'INFORMATIONS DE L\'APPRENANT',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        if (inscription.sexe != null && inscription.sexe!.isNotEmpty)
                          pw.Text(
                            'Genre: ${inscription.sexe}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Nom & Prénom: ${(inscription.prenom ?? '')} ${(inscription.nom ?? '')}'.trim().toUpperCase(),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Matricule: ${inscription.etudiantId.isNotEmpty ? (inscription.etudiantId.startsWith('MAT-') ? inscription.etudiantId : 'MAT-${inscription.etudiantId.length > 6 ? inscription.etudiantId.substring(inscription.etudiantId.length - 6) : inscription.etudiantId}') : "MAT-OFFICIEL"}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Téléphone: ${inscription.telephone ?? "Non renseigné"}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'E-mail: ${inscription.email ?? "Non renseigné"}',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Date Inscription: ${_formatDate(inscription.dateInscription)}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Mode: ${inscription.typeFormation ?? "Présentiel"}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Payment Details Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Désignation / Formation', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Mode de Paiement', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Montant Versé', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(formation.titre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            if (inscription.modules != null && inscription.modules!.isNotEmpty) ...[
                              pw.SizedBox(height: 3),
                              pw.Text('Modules: ${inscription.modules!.join(", ")}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                            ],
                            pw.SizedBox(height: 3),
                            pw.Text('Type: ${inscription.typeFormation ?? "Régulière"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(_formatPaymentMethod(payment.methode), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text('${payment.montant.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: primaryColor)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Summary Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL PAYÉ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: primaryColor)),
                            pw.Text('${payment.montant.toStringAsFixed(0)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: primaryColor)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('STATUT:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text(_formatPaymentStatus(payment.status), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: secondaryColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Signatures & Stamp
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature de l\'Étudiant', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 35),
                      pw.Text('______________________', style: const pw.TextStyle(color: PdfColors.grey400)),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'MALI-NTIC-REC-${payment.id}-${payment.montant}',
                    width: 60,
                    height: 60,
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Cachet & Signature Direction M@LI-NTIC', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 35),
                      pw.Text('______________________', style: const pw.TextStyle(color: PdfColors.grey400)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Merci pour votre confiance ! Ce reçu fait foi de paiement officiel auprès de M@LI-NTIC.',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
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
    final crimsonRed = PdfColor.fromHex('#A6192E');
    final goldColor = PdfColor.fromHex('#F59E0B');
    final lightGold = PdfColor.fromHex('#FEF3C7');

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
              // 1. Exact Background (Vector Stepped Blue Border Frame matching model)
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  size: PdfPoint(pageWidth, pageHeight),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    final w = size.x;
                    final h = size.y;

                    // Outer Deep Slate/Navy Border
                    canvas
                      ..setColor(PdfColor.fromHex('#284B77'))
                      ..drawRect(0, 0, w, h)
                      ..fillPath();

                    // Medium Blue Shading Layer
                    canvas
                      ..setColor(PdfColor.fromHex('#3B6998'))
                      ..drawRect(6, 6, w - 12, h - 12)
                      ..fillPath();

                    // Soft Cyan/Sky Accent Layer
                    canvas
                      ..setColor(PdfColor.fromHex('#7B9EC2'))
                      ..drawRect(12, 12, w - 24, h - 24)
                      ..fillPath();

                    // Inner White Canvas with Chamfered / Stepped Corners
                    final cut = 28.0;
                    final m = 20.0;
                    canvas
                      ..setColor(PdfColors.white)
                      ..moveTo(m + cut, h - m)
                      ..lineTo(w - m - cut, h - m)
                      ..lineTo(w - m, h - m - cut)
                      ..lineTo(w - m, m + cut)
                      ..lineTo(w - m - cut, m)
                      ..lineTo(m + cut, m)
                      ..lineTo(m, m + cut)
                      ..lineTo(m, h - m - cut)
                      ..closePath()
                      ..fillPath();

                    // Fine Blue Contour Line
                    canvas
                      ..setColor(PdfColor.fromHex('#3B78C2'))
                      ..setLineWidth(1.8)
                      ..moveTo(m + cut, h - m)
                      ..lineTo(w - m - cut, h - m)
                      ..lineTo(w - m, h - m - cut)
                      ..lineTo(w - m, m + cut)
                      ..lineTo(w - m - cut, m)
                      ..lineTo(m + cut, m)
                      ..lineTo(m, m + cut)
                      ..lineTo(m, h - m - cut)
                      ..closePath()
                      ..strokePath();
                  },
                ),
              ),

              // 2. Left Gold Medal Rosette with Red Ribbons
              pw.Positioned(
                top: 145,
                left: 45,
                child: pw.Container(
                  width: 85,
                  height: 125,
                  child: pw.Stack(
                    alignment: pw.Alignment.topCenter,
                    children: [
                      // Red Ribbon Tails with Angle & Swallowtail
                      pw.Positioned(
                        bottom: 0,
                        child: pw.Row(
                          children: [
                            pw.Transform.rotate(
                              angle: 0.24,
                              child: pw.Container(
                                width: 19,
                                height: 50,
                                decoration: pw.BoxDecoration(
                                  color: crimsonRed,
                                  borderRadius: pw.BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Transform.rotate(
                              angle: -0.24,
                              child: pw.Container(
                                width: 19,
                                height: 50,
                                decoration: pw.BoxDecoration(
                                  color: crimsonRed,
                                  borderRadius: pw.BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Outer Golden Medallion Ring
                      pw.Container(
                        width: 74,
                        height: 74,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: goldColor,
                          border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 2.5),
                        ),
                        child: pw.Center(
                          child: pw.Container(
                            width: 58,
                            height: 58,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: lightGold,
                              border: pw.Border.all(color: goldColor, width: 1.5),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                '★',
                                style: pw.TextStyle(
                                  fontSize: 32,
                                  color: PdfColor.fromHex('#D97706'),
                                  fontWeight: pw.FontWeight.bold,
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
                                color: darkBlue,
                                letterSpacing: 2.5,
                              ),
                            ),
                            pw.Text(
                              'L\'univers des Technologies',
                              style: pw.TextStyle(
                                font: fontTimesItalic,
                                fontSize: 13.5,
                                color: crimsonRed,
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
                      color: darkBlue,
                    ),

                    pw.SizedBox(height: 14),

                    // Main Title (Dark Red Bold Serif)
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

  /// Generates a PDF Official Attendance Sheet (Feuille d'émargement)
  Future<Uint8List> generateAttendanceSheetPdf({
    required String formationTitre,
    String? moduleTitre,
    required String formateurNom,
    required List<Map<String, dynamic>> apprenants,
    DateTime? dateSeance,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0066CC');
    final secondaryColor = PdfColor.fromHex('#E60000');
    final darkTextColor = PdfColor.fromHex('#1E293B');
    final seanceDate = dateSeance ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
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
                      pw.Text('M@LI-NTIC', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Centre de Formation Professionnelle en Nouvelles Technologies', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text('Bamako, Mali | contact@mali-ntic.ml', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('FEUILLE D\'ÉMARGEMENT', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: secondaryColor, thickness: 1.5),
              pw.SizedBox(height: 10),

              // Details box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Formation: $formationTitre', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        if (moduleTitre != null && moduleTitre.isNotEmpty)
                          pw.Text('Module: $moduleTitre', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Formateur: $formateurNom', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        pw.Text('Date: ${_formatDate(seanceDate)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Attendance Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(28),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FixedColumnWidth(60),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('N°', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nom & Prénom', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Téléphone', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Présent(e)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Absent(e)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Signature', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  ...apprenants.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final student = entry.value;
                    final nomComplet = '${student['prenom'] ?? ''} ${student['nom'] ?? ''}'.trim();
                    final tel = student['telephone'] ?? student['phone'] ?? 'N/A';

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index.isEven ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
                      ),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$index', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(nomComplet.isNotEmpty ? nomComplet : (student['nom'] ?? 'Apprenant'), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$tel', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Center(
                            child: pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600))),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Center(
                            child: pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600))),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('....................', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400), textAlign: pw.TextAlign.center)),
                      ],
                    );
                  }),
                ],
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature du Formateur :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                      pw.SizedBox(height: 30),
                      pw.Text('________________________', style: const pw.TextStyle(color: PdfColors.grey400)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Visa Direction Pédagogique :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 30),
                      pw.Text('________________________', style: const pw.TextStyle(color: PdfColors.grey400)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('M@LI-NTIC - Système de Gestion Académique et Présences', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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

  String _formatPaymentStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.effectue:
        return 'PAYÉ ET VALIDÉ';
      case PaymentStatus.enAttente:
        return 'EN ATTENTE DE VALIDATION';
      case PaymentStatus.echoue:
        return 'ÉCHOUÉ';
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
}

