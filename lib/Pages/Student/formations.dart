import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Widgets/share_formation_dialog.dart';
import 'package:gestion_formations/Pages/Student/discover_formations.dart';

class StudentFormations extends StatefulWidget {
  final User user;

  const StudentFormations({super.key, required this.user});

  @override
  State<StudentFormations> createState() => _StudentFormationsState();
}

class _StudentFormationsState extends State<StudentFormations> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  late GlobalKey qrKey;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    qrKey = GlobalKey();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 1200 ? 1100.0 : width * 0.95;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 28),
                _buildFormationsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mes Formations',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez vos formations et votre progression',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiscoverFormationsPage(user: widget.user),
                ),
              );
            },
            icon: const Icon(Icons.explore_rounded, size: 18, color: Colors.white),
            label: Text(
              'Découvrir d\'autres formations',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationsList() {
    return StreamBuilder<List<Formation>>(
      stream: _db.watchFormations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        final allFormations = snapshot.data ?? [];
        if (allFormations.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.school_rounded, size: 48, color: Colors.black12),
                SizedBox(height: 16),
                Text(
                  'Aucune formation inscrite',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final currentUser = _db.getUserById(widget.user.id) ?? widget.user;
        final userAssigned = currentUser.assignedFormations;
        final userAssignedIds = userAssigned.map((item) => item['formationId']?.toString()).toSet();
        final userInscriptions = _db.getInscriptions().where((i) {
          final isSameUser = i.etudiantId == currentUser.id || (i.email != null && i.email!.trim().toLowerCase() == currentUser.email.trim().toLowerCase());
          return isSameUser && i.status == InscriptionStatus.acceptee;
        }).map((i) => i.formationId).toSet();

        final enrolledIds = {...userAssignedIds, ...userInscriptions}.whereType<String>().toSet();

        // STRICT: Seules les formations affectées manuellement par l'admin ou inscrites
        final filteredFormations = allFormations.where((f) => enrolledIds.contains(f.id)).toList();

        final formations = filteredFormations.map((f) {
          final assignedItem = userAssigned.firstWhere(
            (item) => item['formationId'] == f.id,
            orElse: () => <String, dynamic>{},
          );
          final assignedModulesList = assignedItem['modules'] as List<dynamic>?;

          final modulesData = (assignedModulesList != null && assignedModulesList.isNotEmpty)
              ? assignedModulesList.map((m) {
                  final map = m as Map<String, dynamic>;
                  final done = (map['doneHours'] ?? 0) as num;
                  final assigned = (map['assignedHours'] ?? 1) as num;
                  return {
                    'title': map['title']?.toString() ?? '',
                    'completed': done >= assigned && done > 0,
                  };
                }).toList()
              : f.modules.map((m) => {'title': m, 'completed': false}).toList();

          return {
            'title': f.titre,
            'type': f.type.name,
            'formationId': f.id,
            'modules': modulesData,
          };
        }).toList();

        if (formations.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.school_rounded, size: 48, color: Colors.black12),
                SizedBox(height: 16),
                Text(
                  'Aucune formation inscrite',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: formations.length,
          itemBuilder: (context, index) {
            final formation = formations[index] as Map<String, dynamic>;
            return _buildFormationCard(formation, index);
          },
        );
      },
    );
  }

  Widget _buildFormationCard(Map<String, dynamic> formationData, int index) {
    final formationId = formationData['formationId'] ?? '';
    final formationTitle = formationData['title'] ?? 'Formation';
    final modules = formationData['modules'] as List<dynamic>? ?? [];
    final modulesWithHours = modules.map((m) {
      return {
        'title': m['title'] ?? '',
        'assignedHours': (m['assignedHours'] as int?) ?? 0,
        'doneHours': (m['doneHours'] as int?) ?? 0,
      };
    }).toList();

    if (modulesWithHours.isEmpty) {
      return SizedBox.shrink();
    }

    final totalAssignedHours = modulesWithHours.fold<int>(0, (acc, m) {
      return acc + (m['assignedHours'] as int? ?? 0);
    });

    final totalDoneHours = modulesWithHours.fold<int>(0, (acc, m) {
      return acc + (m['doneHours'] as int? ?? 0);
    });

    final progressPercent = totalAssignedHours > 0 ? (totalDoneHours / totalAssignedHours * 100).toStringAsFixed(1) : '0';

    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: Duration(milliseconds: 600),
      child: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formationTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '$totalDoneHours / $totalAssignedHours heures',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'partager') {
                          _showFormationQrDialog(context, formationTitle, formationId);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'partager',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 18, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text('Partager'),
                            ],
                          ),
                        ),
                      ],
                      icon: Icon(Icons.more_vert_rounded, color: AppTheme.primary),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalAssignedHours > 0 ? totalDoneHours / totalAssignedHours : 0,
                          minHeight: 8,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$progressPercent%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Modules (${modulesWithHours.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: modulesWithHours.map((m) {
                    final moduleTitle = m['title'] ?? '';
                    final assignedHours = m['assignedHours'] ?? 0;
                    final doneHours = m['doneHours'] ?? 0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        padding: EdgeInsets.all(10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              moduleTitle,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '$doneHours/$assignedHours h',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                _buildFormateurs(formationId, modulesWithHours),
                SizedBox(height: 16),
                _buildAttestationSection(
                  _db.getFormationById(formationId) ??
                      Formation(
                        id: formationId,
                        titre: formationTitle,
                        description: '',
                        modules: modulesWithHours.map((m) => m['title']?.toString() ?? '').toList(),
                        formateurIds: [],
                        prix: 0,
                        type: FormationType.presentielle,
                        status: FormationStatus.enCours,
                        dureeSemaines: 4,
                        horaires: [],
                        dateCreation: DateTime.now(),
                      ),
                  modulesWithHours,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttestationSection(Formation formation, List<dynamic> modulesWithHours) {
    final inscription = _db.getInscriptions().where((i) {
      final isUser = i.etudiantId == widget.user.id ||
          (i.email != null && i.email!.trim().toLowerCase() == widget.user.email.trim().toLowerCase());
      return isUser && i.formationId == formation.id && i.status == InscriptionStatus.acceptee;
    }).firstOrNull;

    final balance = inscription != null ? _db.getInscriptionBalance(inscription.id) : 999999.0;
    final isPaid = inscription != null && (inscription.paiementEffectue || balance <= 0);

    final isCompleted = _db.isStudentFormationCompleted(
      studentId: widget.user.id,
      formationId: formation.id,
    );

    if (isPaid && isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attestation Officielle Disponible !',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Formation terminée et soldée à 100%. Vous pouvez télécharger votre attestation signée.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  'Télécharger mon Attestation PDF',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  try {
                    final targetInscription = inscription;

                    final pdfBytes = await PdfService().generateAttestationPdf(
                      inscription: targetInscription,
                      formation: formation,
                    );

                    await PdfService().printOrDownloadPdf(
                      pdfBytes: pdfBytes,
                      filename: 'Attestation_${widget.user.prenom}_${widget.user.nom}_${formation.titre}.pdf',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Attestation téléchargée avec succès !', style: GoogleFonts.poppins()),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      );
    } else if (isCompleted && !isPaid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF97316)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Formation terminée. Solde restant : ${balance.toStringAsFixed(0)} FCFA pour débloquer votre attestation.',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9A3412)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFormateurs(String formationId, List<dynamic> studentModules) {
    return StreamBuilder<List<User>>(
      stream: _db.watchUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final formateurs = <String, Map<String, dynamic>>{};
        final formateursList = snapshot.data!.where((u) => u.role == UserRole.formateur).toList();

        for (var formateur in formateursList) {
          formateurs[formateur.nomComplet] = {
            'prenom': formateur.prenom,
            'nom': formateur.nom,
            'email': formateur.email,
          };
        }

        if (formateurs.isEmpty) {
          return SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formateurs',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: formateurs.entries.map((entry) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFormationQrDialog(BuildContext context, String formationTitle, String formationId) async {
    final formation = _db.getFormationById(formationId) ?? Formation(
      id: formationId,
      titre: formationTitle,
      description: 'Formation professionnelle $formationTitle',
      prix: 0,
      dureeSemaines: 4,
      dateDebut: DateTime.now(),
      status: FormationStatus.programmee,
      type: FormationType.presentielle,
      formateurIds: const [],
      horaires: const [],
      dateCreation: DateTime.now(),
      modules: const [],
    );
    await ShareFormationDialog.show(context, formation);
  }
}
