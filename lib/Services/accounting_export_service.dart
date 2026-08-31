import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/seance.dart';
import 'package:gestion_formations/config/theme.dart';

class AccountingExportService {
  static String _formatDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  static String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  static String _formatCurrency(num amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(' ');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _formatMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.moovMoney:
        return 'Moov Money';
      case PaymentMethod.especes:
        return 'Espèces';
      case PaymentMethod.virement:
        return 'Virement';
      case PaymentMethod.carte:
        return 'Carte Bancaire';
    }
  }

  /// Génère un export CSV financier universel encodé en UTF-8 BOM pour Excel
  static Uint8List generateFinancialReportCSV({
    required List<Payment> payments,
    Map<String, Formation>? formationsMap,
    Map<String, User>? usersMap,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final buffer = StringBuffer();

    // Entête du rapport
    buffer.writeln('RAPPORT FINANCIER & COMPTABLE - MALINTIC');
    buffer.writeln('Date d\'exportation;${_formatDateTime(DateTime.now())}');
    if (startDate != null || endDate != null) {
      final startStr = startDate != null ? _formatDate(startDate) : 'Début';
      final endStr = endDate != null ? _formatDate(endDate) : 'Ce jour';
      buffer.writeln('Période sélectionnée;$startStr au $endStr');
    }
    buffer.writeln();

    // Colonnes
    buffer.writeln(
      'ID Transaction;Date Règlement;Apprenant / Client;Formation;Montant Payé (FCFA);Mode de Règlement;Statut;Remise (FCFA);Date Échéance;Référence',
    );

    double totalEncaisse = 0;
    double totalEnAttente = 0;
    double totalEchoue = 0;
    final Map<String, double> remisesByInscription = {};

    for (final p in payments) {
      final pDate = p.dateEffectuation ?? p.dateCreation;
      if (startDate != null && pDate.isBefore(startDate)) continue;
      if (endDate != null && pDate.isAfter(endDate.add(const Duration(days: 1)))) continue;

      if (p.status == PaymentStatus.effectue) {
        totalEncaisse += p.montant;
      } else if (p.status == PaymentStatus.enAttente) {
        totalEnAttente += p.montant;
      } else {
        totalEchoue += p.montant;
      }

      // Enregistrement dédupliqué de la remise (max remise accordée sur ce dossier d'inscription)
      final dossierKey = p.inscriptionId.isNotEmpty ? p.inscriptionId : '${p.apprenantId}_${p.formationId}';
      if (p.remise > 0) {
        final currentMax = remisesByInscription[dossierKey] ?? 0;
        if (p.remise > currentMax) {
          remisesByInscription[dossierKey] = p.remise;
        }
      }

      final userName = usersMap?[p.apprenantId]?.nomComplet ?? p.apprenantId;
      final formationName = formationsMap?[p.formationId]?.titre ?? p.formationId;
      final dateStr = _formatDateTime(pDate);
      final echeanceStr = p.dateEcheance != null ? _formatDate(p.dateEcheance!) : '-';
      final modeStr = _formatMethodName(p.methode);
      final statusStr = p.status == PaymentStatus.effectue
          ? 'EFFECTUÉ'
          : (p.status == PaymentStatus.echoue ? 'ÉCHOUÉ' : 'EN ATTENTE');

      buffer.writeln(
        '"${p.id}";"$dateStr";"$userName";"$formationName";${p.montant.toStringAsFixed(0)};"$modeStr";"$statusStr";${p.remise.toStringAsFixed(0)};"$echeanceStr";"${p.referenceTransaction ?? '-'}"',
      );
    }

    final totalRemise = remisesByInscription.values.fold<double>(0, (sum, r) => sum + r);

    buffer.writeln();
    buffer.writeln('TOTAL ENCAISSÉ (VALIDÉ);;;;${totalEncaisse.toStringAsFixed(0)};;TOTAL REMISES (DÉDUPLIQUÉ);${totalRemise.toStringAsFixed(0)};');
    buffer.writeln('TOTAL EN ATTENTE;;;;${totalEnAttente.toStringAsFixed(0)};;TOTAL ÉCHOUÉ / REJETÉ;${totalEchoue.toStringAsFixed(0)};');

    // UTF-8 BOM + UTF-8 bytes
    final utf8Bytes = utf8.encode(buffer.toString());
    final bom = [0xEF, 0xBB, 0xBF];
    return Uint8List.fromList([...bom, ...utf8Bytes]);
  }

  /// Génère un rapport financier complet et soigné en PDF A4
  static Future<Uint8List> generateFinancialReportPDF({
    required List<Payment> payments,
    Map<String, Formation>? formationsMap,
    Map<String, User>? usersMap,
    DateTime? startDate,
    DateTime? endDate,
    String title = 'ÉTAT FINANCIER & COMPTABLE',
  }) async {
    final pdf = pw.Document();

    // Charger logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData imageData = await rootBundle.load('images/logo.png');
      logoImage = pw.MemoryImage(imageData.buffer.asUint8List());
    } catch (_) {}

    // Filtrer les paiements
    final filteredPayments = payments.where((p) {
      final pDate = p.dateEffectuation ?? p.dateCreation;
      if (startDate != null && pDate.isBefore(startDate)) return false;
      if (endDate != null && pDate.isAfter(endDate.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    double totalEncaisse = 0;
    double totalEnAttente = 0;
    double totalEchoue = 0;
    int countValide = 0;
    int countAttente = 0;
    int countEchoue = 0;
    final Map<String, double> parMode = {};

    for (final p in filteredPayments) {
      final mode = _formatMethodName(p.methode);
      if (p.status == PaymentStatus.effectue) {
        totalEncaisse += p.montant;
        countValide++;
        parMode[mode] = (parMode[mode] ?? 0) + p.montant;
      } else if (p.status == PaymentStatus.enAttente) {
        totalEnAttente += p.montant;
        countAttente++;
      } else {
        totalEchoue += p.montant;
        countEchoue++;
      }
    }

    final primaryColor = PdfColor.fromInt(AppTheme.primary.toARGB32());
    final successColor = PdfColor.fromInt(0xFF10B981);
    final warningColor = PdfColor.fromInt(0xFFF59E0B);
    final textDark = PdfColor.fromInt(0xFF1F2937);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  if (logoImage != null)
                    pw.Container(width: 45, height: 45, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logoImage)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MALINTIC SFP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Centre d\'Excellence & Formation Professionnelle', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.Text('Date : ${_formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Malintic - Document comptable officiel et confidentiel', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (context) => [
          // Cartes de synthèse KPI
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.97, 0.98, 0.98),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiPdfItem('Total Encaissé', '${_formatCurrency(totalEncaisse)} FCFA', successColor, '$countValide transaction(s)'),
                _buildKpiPdfItem('En Attente', '${_formatCurrency(totalEnAttente)} FCFA', warningColor, '$countAttente transaction(s)'),
                _buildKpiPdfItem('Total Transactions', '${filteredPayments.length}', primaryColor, '$countValide validée(s)'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Répartition par mode de paiement
          if (parMode.isNotEmpty) ...[
            pw.Text('VENTILATION PAR MODE DE RÈGLEMENT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: parMode.entries.map((e) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('${e.key} : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('${_formatCurrency(e.value)} FCFA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 18),
          ],

          // Tableau détaillé des règlements
          pw.Text('JOURNAL DÉTAILLÉ DES TRANSACTIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2), // Date
              1: pw.FlexColumnWidth(3.0), // Apprenant
              2: pw.FlexColumnWidth(3.0), // Formation
              3: pw.FlexColumnWidth(1.8), // Mode
              4: pw.FlexColumnWidth(2.2), // Montant
              5: pw.FlexColumnWidth(1.8), // Statut
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor(0.12, 0.16, 0.23)),
                children: [
                  _buildTableHeader('Date'),
                  _buildTableHeader('Apprenant / Client'),
                  _buildTableHeader('Formation'),
                  _buildTableHeader('Mode'),
                  _buildTableHeader('Montant (FCFA)'),
                  _buildTableHeader('Statut'),
                ],
              ),
              // Lignes
              ...filteredPayments.map((p) {
                final isEven = filteredPayments.indexOf(p) % 2 == 0;
                final isValide = p.status == PaymentStatus.effectue;
                final isEchoue = p.status == PaymentStatus.echoue;
                final userName = usersMap?[p.apprenantId]?.nomComplet ?? p.apprenantId;
                final formationName = formationsMap?[p.formationId]?.titre ?? p.formationId;
                final pDate = p.dateEffectuation ?? p.dateCreation;

                final statusColor = isValide
                    ? successColor
                    : (isEchoue ? PdfColors.red600 : warningColor);
                final statusLabel = isValide
                    ? 'EFFECTUÉ'
                    : (isEchoue ? 'ÉCHOUÉ' : 'EN ATTENTE');

                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : const PdfColor(0.97, 0.98, 0.98)),
                  children: [
                    _buildTableCell(_formatDate(pDate)),
                    _buildTableCell(userName, isBold: true),
                    _buildTableCell(formationName),
                    _buildTableCell(_formatMethodName(p.methode)),
                    _buildTableCell('${_formatCurrency(p.montant)} F', align: pw.TextAlign.right, isBold: true),
                    _buildTableCell(
                      statusLabel,
                      color: statusColor,
                      isBold: true,
                      align: pw.TextAlign.center,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Génère une feuille d'émargement / liste de présence A4 Paysage officielle
  static Future<Uint8List> generateAttendanceSheetPDF({
    required Formation formation,
    required List<Inscription> inscriptions,
    required List<User> students,
    List<Seance>? seances,
    String? moduleName,
    String? formateurName,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final ByteData imageData = await rootBundle.load('images/logo.png');
      logoImage = pw.MemoryImage(imageData.buffer.asUint8List());
    } catch (_) {}

    final primaryColor = PdfColor.fromInt(AppTheme.primary.toARGB32());
    final textDark = const PdfColor(0.12, 0.16, 0.23);

    // Récupérer les apprenants valides de cette formation
    final studentMap = {for (final s in students) s.id: s};
    final validInscriptions = inscriptions.where((i) => i.formationId == formation.id && (i.status == InscriptionStatus.acceptee || i.paiementEffectue)).toList();

    // Déterminer le nombre de colonnes de séances (par défaut 6 cases de présence)
    final numCols = seances != null && seances.isNotEmpty ? seances.length.clamp(4, 8) : 6;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(width: 48, height: 48, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logoImage)),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('MALINTIC - CENTRE DE FORMATION', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('FEUILLE D\'ÉMARGEMENT ET DE PRÉSENCE OFFICIELLE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Formation : ${formation.titre}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      if (moduleName != null) pw.Text('Module : $moduleName', style: pw.TextStyle(fontSize: 10, color: textDark)),
                      if (formateurName != null) pw.Text('Formateur : $formateurName', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Imprimé le : ${_formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // Tableau de présence
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28), // N°
                    1: const pw.FlexColumnWidth(3.2), // Nom & Prénom
                    2: const pw.FlexColumnWidth(2.0), // Téléphone
                    for (int c = 0; c < numCols; c++)
                      3 + c: const pw.FlexColumnWidth(1.8), // Colonnes de dates/émargement
                  },
                  children: [
                    // Ligne En-têtes du tableau
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor(0.06, 0.09, 0.16)),
                      children: [
                        _buildTableHeader('N°', align: pw.TextAlign.center),
                        _buildTableHeader('Nom & Prénom de l\'Apprenant'),
                        _buildTableHeader('Contact / Tél'),
                        for (int c = 0; c < numCols; c++)
                          _buildTableHeader(
                            seances != null && c < seances.length
                                ? '${_formatDate(seances[c].date)}\n(${seances[c].heureDebut})'
                                : 'Séance ${c + 1}\nDate: ___/___',
                            align: pw.TextAlign.center,
                          ),
                      ],
                    ),
                    // Lignes apprenants
                    ...List.generate(validInscriptions.isEmpty ? 8 : validInscriptions.length, (index) {
                      if (index < validInscriptions.length) {
                        final insc = validInscriptions[index];
                        final user = studentMap[insc.apprenantId];
                        final nomComplet = user?.nomComplet ?? '${insc.prenom ?? ""} ${insc.nom ?? ""}'.trim();
                        final tel = user?.phone ?? insc.telephone ?? '-';

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: index % 2 == 0 ? PdfColors.white : const PdfColor(0.97, 0.98, 0.98)),
                          children: [
                            _buildTableCell('${index + 1}', align: pw.TextAlign.center),
                            _buildTableCell(nomComplet.isEmpty ? 'Apprenant ${index + 1}' : nomComplet, isBold: true),
                            _buildTableCell(tel),
                            for (int c = 0; c < numCols; c++)
                              pw.Container(height: 26), // Case vide pour signature manuscrite
                          ],
                        );
                      } else {
                        // Ligne vide pour ajout manuel
                        return pw.TableRow(
                          children: [
                            _buildTableCell('${index + 1}', align: pw.TextAlign.center),
                            _buildTableCell(''),
                            _buildTableCell(''),
                            for (int c = 0; c < numCols; c++)
                              pw.Container(height: 26),
                          ],
                        );
                      }
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Signatures bas de page
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Visa & Signature du Formateur :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.SizedBox(height: 24),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Direction Pédagogique Malintic :', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.SizedBox(height: 24),
                      ],
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

  // Helpers de rendu PDF
  static pw.Widget _buildKpiPdfItem(String label, String value, PdfColor color, String sub) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(sub, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isBold = false,
    PdfColor color = PdfColors.black,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
      ),
    );
  }
}
