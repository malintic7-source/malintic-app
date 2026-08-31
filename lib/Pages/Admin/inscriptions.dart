import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_helper.dart';


Map<String, dynamic> resolveInscriptionUserData(
  Map<dynamic, dynamic>? userData,
  Map<dynamic, dynamic> inscription,
) {
  final fallback = {
    'prenom': (inscription['prenom'] ?? '').toString(),
    'nom': (inscription['nom'] ?? '').toString(),
    'email': (inscription['email'] ?? '').toString(),
    'telephone': (inscription['telephone'] ?? '').toString(),
  };

  if (userData == null || userData.isEmpty) {
    return fallback;
  }

  return {
    'prenom': (userData['prenom'] ?? fallback['prenom']).toString(),
    'nom': (userData['nom'] ?? fallback['nom']).toString(),
    'email': (userData['email'] ?? fallback['email']).toString(),
    'telephone': (userData['telephone'] ?? fallback['telephone']).toString(),
  };
}

Map<String, dynamic> resolveInscriptionFormationData(
  Map<dynamic, dynamic>? formationData,
  Map<dynamic, dynamic> inscription,
) {
  final inscriptionPrice = inscription['montant'] ?? inscription['prix'] ?? 0;
  final fallback = {
    'titre': (inscription['formationTitle'] ?? inscription['formation_title'] ?? 'Formation').toString(),
    'description': (inscription['description'] ?? '').toString(),
    'prix': inscriptionPrice,
    'prixEnLigne': inscriptionPrice,
    'type': (inscription['typeFormation'] ?? inscription['type_formation'] ?? 'presentiel').toString(),
  };

  if (formationData == null || formationData.isEmpty) {
    return fallback;
  }

  return {
    'titre': (formationData['titre'] ?? fallback['titre']).toString(),
    'description': (formationData['description'] ?? fallback['description']).toString(),
    'prix': formationData['prix'] ?? fallback['prix'],
    'prixEnLigne': formationData['prixEnLigne'] ?? fallback['prixEnLigne'],
    'type': (formationData['type'] ?? fallback['type']).toString(),
  };
}

String normalizeInscriptionEmail(String? email) {
  return (email ?? '').trim().toLowerCase();
}

Map<String, dynamic> buildStudentUserDataFromInscription(
  Map<dynamic, dynamic> inscription,
  String userId,
) {
  final prenom = (inscription['prenom'] ?? '').toString().trim();
  final nom = (inscription['nom'] ?? '').toString().trim();
  final email = (inscription['email'] ?? '').toString().trim();
  final phone = (inscription['telephone'] ?? '').toString().trim();

  return {
    'id': userId,
    'email': email,
    'nom': nom,
    'prenom': prenom,
    'phone': phone,
    'role': UserRole.apprenant.toString(),
    'estActif': true,
    'doitChangerMotDePasse': true,
    'dateCreation': DateTime.now(),
    'dateModification': DateTime.now(),
  };
}

class AdminInscriptions extends StatefulWidget {
  const AdminInscriptions({super.key});

  @override
  State<AdminInscriptions> createState() => _AdminInscriptionsState();
}

class _AdminInscriptionsState extends State<AdminInscriptions> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  late AnimationController _fadeController;
  String filterStatus = 'en_attente';
  StreamSubscription<void>? _dataSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Mise à jour automatique instantanée des cartes statistiques et des inscriptions
    _dataSub = _db.watchAllDataChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final hp = isMobile ? 12.0 : 16.0;
    final vp = isMobile ? 12.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: vp, horizontal: hp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: isMobile ? 16 : 24),
          _buildInscriptionsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.heroShadow,
        ),
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Gestion des Inscriptions',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    tooltip: 'Actualiser les inscriptions',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    onPressed: () {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 Liste des inscriptions actualisée !'),
                          backgroundColor: AppTheme.primary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Validez, rejetez ou mettez en attente les inscriptions reçues',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showCreateInscriptionDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Nouvelle', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _exportInscriptionsCSV,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.file_download_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text('Export CSV', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      await _db.refreshFromServer();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Liste des inscriptions actualisée !'), backgroundColor: AppTheme.success),
                      );
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Rafraîchir les inscriptions',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInscriptionsCSV() async {
    final inscriptions = _db.getInscriptions();
    if (inscriptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune inscription à exporter')),
      );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.write('\uFEFF');
    csv.writeln('ID;Prénom;Nom;Email;Téléphone;Formation;Statut;Paiement Effectué;Date Inscription');

    for (final ins in inscriptions) {
      final student = _db.getUsers().where((u) => u.id == ins.etudiantId).firstOrNull;
      final formation = _db.getFormationById(ins.formationId);

      final prenom = student?.prenom ?? ins.prenom ?? '';
      final nom = student?.nom ?? ins.nom ?? '';
      final email = student?.email ?? ins.email ?? '';
      final tel = student?.phone ?? ins.telephone ?? '';
      final formationTitre = formation?.titre ?? 'Formation';
      final statusStr = _getStatusLabel(ins.status.name);
      final payeStr = ins.paiementEffectue ? 'Oui' : 'Non';
      final dateStr = '${ins.dateInscription.day}/${ins.dateInscription.month}/${ins.dateInscription.year}';

      csv.writeln('"${ins.id}";"$prenom";"$nom";"$email";"$tel";"$formationTitre";"$statusStr";"$payeStr";"$dateStr"');
    }

    final Uint8List bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    await PdfHelper.downloadCSV(bytes, fileName: 'Liste_Inscriptions_${DateTime.now().millisecondsSinceEpoch}');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Liste des inscriptions exportée en CSV avec succès !'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _showCreateInscriptionDialog() async {
    final localContext = context;
    final prenomController = TextEditingController();
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final formations = _db.getFormations();
    Formation? selectedFormation = formations.isNotEmpty ? formations.first : null;
    final selectedModules = <String>{
      if (selectedFormation?.estStage != true) ...?selectedFormation?.modules,
    };
    final created = await showDialog<bool>(
      context: localContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'Nouvelle inscription',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: prenomController,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Formation>(
                      initialValue: selectedFormation,
                      decoration: const InputDecoration(labelText: 'Formation'),
                      items: formations
                          .map((formation) => DropdownMenuItem(
                                value: formation,
                                child: Text(formation.titre),
                              ))
                          .toList(),
                      onChanged: (formation) {
                        if (formation == null) return;
                        setDialogState(() {
                          selectedFormation = formation;
                          selectedModules
                            ..clear()
                            ..addAll(formation.estStage ? const <String>[] : formation.modules);
                        });
                      },
                    ),
                    if (selectedFormation != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedFormation!.estStage
                              ? 'Modules SFP à sélectionner (exactement ${selectedFormation!.maxModulesParEtudiant ?? 3})'
                              : 'Modules de la formation',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ...selectedFormation!.modules.map(
                        (module) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedModules.contains(module),
                          title: Text(module),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                final limit = selectedFormation!.estStage
                                    ? selectedFormation!.maxModulesParEtudiant ?? 3
                                    : selectedFormation!.maxModulesParEtudiant;
                                if (limit != null && selectedModules.length >= limit) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Vous pouvez sélectionner au maximum $limit modules.')),
                                  );
                                  return;
                                }
                                selectedModules.add(module);
                              } else {
                                selectedModules.remove(module);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Inscrire'),
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (selectedFormation == null ||
                      prenomController.text.trim().isEmpty ||
                      nomController.text.trim().isEmpty ||
                      email.isEmpty ||
                      selectedModules.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Complétez l’identité, la formation et au moins un module.')),
                    );
                    return;
                  }

                  if (!email.contains('@') || email.length < 5) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Veuillez fournir une adresse email valide.')),
                    );
                    return;
                  }

                  if (selectedFormation!.estStage &&
                      selectedModules.length != (selectedFormation!.maxModulesParEtudiant ?? 3)) {
                    final required = selectedFormation!.maxModulesParEtudiant ?? 3;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Pour ce stage SFP, sélectionnez exactement $required modules.')),
                    );
                    return;
                  }

                  try {
                    await _db.createInscription(
                      etudiantId: 'admin_${DateTime.now().millisecondsSinceEpoch}',
                      formationId: selectedFormation!.id,
                      prenom: prenomController.text,
                      nom: nomController.text,
                      email: email,
                      telephone: phoneController.text,
                      modules: selectedModules.toList(),
                      typeFormation: selectedFormation!.type.toString(),
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    prenomController.dispose();
    nomController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (created == true && localContext.mounted) {
      setState(() => filterStatus = 'en_attente');
      ScaffoldMessenger.of(localContext).showSnackBar(
        SnackBar(
          content: const Text('✅ Dossier créé. Il sera transféré vers Étudiants après validation.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Widget _buildFilterButtons(List<Inscription> allInscriptions) {
    final deletedInscIds = _db.getDeletedDocs('inscriptions');
    final deletedUserIds = _db.getDeletedDocs('users');
    final deletedUserEmails = _db.getDeletedDocs('user_emails');

    final validInscriptions = allInscriptions.where((i) {
      final email = i.email?.trim().toLowerCase() ?? '';
      return !deletedInscIds.contains(i.id) &&
          !deletedUserIds.contains(i.etudiantId) &&
          !deletedUserIds.contains(i.id) &&
          (email.isEmpty || !deletedUserEmails.contains(email));
    }).toList();

    final pendingCount = validInscriptions.where((i) => i.status == InscriptionStatus.enAttente).length;
    final rejectedCount = validInscriptions.where((i) => i.status == InscriptionStatus.rejetee).length;

    return SlideInUp(
      duration: const Duration(milliseconds: 600),
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton('À Valider ($pendingCount)', 'en_attente', AppTheme.warningDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterButton('Rejetées ($rejectedCount)', 'rejete', AppTheme.error),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String status, Color color) {
    final isSelected = filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => filterStatus = status),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: color, width: isSelected ? 0 : 2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildInscriptionsList() {
    return StreamBuilder<List<Inscription>>(
      stream: _db.watchInscriptions(),
      builder: (context, snapshot) {
        final allInscriptions = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterButtons(allInscriptions),
            const SizedBox(height: 24),
            if (snapshot.connectionState == ConnectionState.waiting && allInscriptions.isEmpty)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              )
            else
              _buildInscriptionsBody(allInscriptions),
          ],
        );
      },
    );
  }

  Widget _buildInscriptionsBody(List<Inscription> allInscriptions) {
    final deletedInscIds = _db.getDeletedDocs('inscriptions');
    final deletedUserIds = _db.getDeletedDocs('users');
    final deletedUserEmails = _db.getDeletedDocs('user_emails');

    final filteredInscriptions = allInscriptions.where((i) {
      final email = i.email?.trim().toLowerCase() ?? '';
      if (deletedInscIds.contains(i.id) ||
          deletedUserIds.contains(i.etudiantId) ||
          deletedUserIds.contains(i.id) ||
          (email.isNotEmpty && deletedUserEmails.contains(email))) {
        return false;
      }
      if (filterStatus == 'rejete' || filterStatus == 'rejetee') {
        return i.status == InscriptionStatus.rejetee;
      }
      return i.status == InscriptionStatus.enAttente;
    }).toList();

        if (filteredInscriptions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.inbox_rounded, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune inscription',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
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
            return _buildInscriptionCard(ins.id, ins.toMap(), index);
          },
        );
  }

  Widget _buildInscriptionCard(String inscriptionId, Map<String, dynamic> inscription, int index) {
    final userDocId = (inscription['etudiantId'] ?? '').toString();
    final formationDocId = (inscription['formationId'] ?? '').toString();

    final user = _db.getUserById(userDocId);
    final formation = _db.getFormationById(formationDocId);

    final userData = user?.toMap() ?? {};
    final formationData = formation?.toMap() ?? {};

    final displayUserData = resolveInscriptionUserData(userData, inscription);
    final displayFormationData = resolveInscriptionFormationData(formationData, inscription);
    final statusStr = (inscription['status'] ?? inscription['statut'] ?? '').toString().toLowerCase();

                return GestureDetector(
                  onTap: () => _showDetailDialog(
                    inscriptionId,
                    inscription,
                    resolveInscriptionUserData(userData, inscription),
                    resolveInscriptionFormationData(formationData, inscription),
                  ),
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
                                    '${displayUserData['prenom']} ${displayUserData['nom']}'.trim(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    displayFormationData['titre'] ?? 'Formation',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(inscription['status'] ?? inscription['statut']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStatusLabel(inscription['status'] ?? inscription['statut']),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColor(inscription['status'] ?? inscription['statut']),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.email_rounded, size: 14, color: Colors.black54),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayUserData['email'] ?? 'N/A',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 14, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              displayUserData['telephone'] ?? 'N/A',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 10),
                        // Quick Action Buttons Bar
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showDetailDialog(
                                inscriptionId,
                                inscription,
                                resolveInscriptionUserData(userData, inscription),
                                resolveInscriptionFormationData(formationData, inscription),
                              ),
                              icon: const Icon(Icons.visibility_outlined, size: 15),
                              label: Text(
                                'Détails',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (!statusStr.contains('valide') && !statusStr.contains('accepte') && !statusStr.contains('rejet')) ...[
                              OutlinedButton.icon(
                                onPressed: () => _updateStatus(inscriptionId, 'rejete'),
                                icon: const Icon(Icons.close_rounded, size: 15, color: AppTheme.error),
                                label: Text(
                                  'Rejeter',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.error,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _updateStatus(inscriptionId, 'valide'),
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                                label: Text(
                                  'Valider & Enrôler',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
  }

  void _showDetailDialog(
    String inscriptionId,
    Map<String, dynamic> inscription,
    Map<String, dynamic> userData,
    Map<String, dynamic> formationData,
  ) {
    final prenom = (userData['prenom'] ?? inscription['prenom'] ?? '').toString().trim();
    final nom = (userData['nom'] ?? inscription['nom'] ?? '').toString().trim();
    final fullName = (prenom.isNotEmpty || nom.isNotEmpty) ? '$prenom $nom' : 'Stagiaire / Étudiant';
    final email = (userData['email'] ?? inscription['email'] ?? 'N/A').toString();
    final phone = (userData['telephone'] ?? userData['phone'] ?? inscription['telephone'] ?? 'N/A').toString();

    final isStage = formationData['estStage'] == true;
    final rawModules = (inscription['modules'] as List<dynamic>?) ??
        (isStage ? <dynamic>[] : (formationData['modules'] as List<dynamic>?) ?? []);
    final modulesList = rawModules.isEmpty
        ? [isStage ? '• Aucun module SFP sélectionné' : '• Tous les modules de la formation']
        : rawModules.map((m) => '• $m').toList();
    final currentStatusStr = (inscription['status'] ?? inscription['statut'] ?? '').toString();
    final statusLower = currentStatusStr.toLowerCase();
    final isPending = !statusLower.contains('valide') && !statusLower.contains('accepte') && !statusLower.contains('rejet');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Détails de l\'Inscription',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(currentStatusStr).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(currentStatusStr).withValues(alpha: 0.3)),
              ),
              child: Text(
                _getStatusLabel(currentStatusStr),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _getStatusColor(currentStatusStr),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogSection('Étudiant / Stagiaire', [
                fullName,
                email,
                phone,
              ]),
              const SizedBox(height: 16),
              _buildDialogSection('Formation', [
                formationData['titre'] ?? 'N/A',
                formationData['description'] ?? '',
                'Type: ${_getFormationTypeLabel(formationData['type'] ?? 'presentiel')}',
                'Prix: ${_getFormationPrice(formationData, inscription)} FCFA',
              ]),
              const SizedBox(height: 16),
              _buildDialogSection('Modules Sélectionnés', modulesList),
              if (inscription['description']?.toString().isNotEmpty ?? false)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildDialogSection('Description', [
                      inscription['description'].toString(),
                    ]),
                  ],
                ),
              const SizedBox(height: 20),
              _buildStatusSection(inscriptionId, currentStatusStr, dialogContext),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 18),
            label: Text('Supprimer', style: GoogleFonts.poppins(color: AppTheme.error, fontWeight: FontWeight.w700)),
            onPressed: () => _confirmDeleteInscription(context, inscriptionId, '${userData['prenom']} ${userData['nom']}'),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (isPending) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
                  label: Text('Rejeter', style: GoogleFonts.poppins(color: AppTheme.error, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus(inscriptionId, 'rejete', dialogContext),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: Text('Valider & Enrôler', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  onPressed: () => _updateStatus(inscriptionId, 'valide', dialogContext),
                ),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                label: Text('Fermer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteInscription(BuildContext context, String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
            const SizedBox(width: 10),
            Text('Supprimer l\'inscription', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer l\'inscription de "$name" ? Cette action est irréversible.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteInscription(id);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Inscription supprimée avec succès'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildStatusSection(String inscriptionId, dynamic currentStatusInput, [BuildContext? dialogCtx]) {
    final currentStatusStr = (currentStatusInput is Map)
        ? (currentStatusInput['status'] ?? currentStatusInput['statut'] ?? '').toString()
        : (currentStatusInput ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUT',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statut Actuel: ${_getStatusLabel(currentStatusStr)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      'En Attente',
                      'en_attente',
                      Colors.amber,
                      currentStatusStr,
                      () => _updateStatus(inscriptionId, 'en_attente', dialogCtx),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      'Validée',
                      'valide',
                      AppTheme.success,
                      currentStatusStr,
                      () => _updateStatus(inscriptionId, 'valide', dialogCtx),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      'Rejetée',
                      'rejete',
                      AppTheme.error,
                      currentStatusStr,
                      () => _updateStatus(inscriptionId, 'rejete', dialogCtx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(
    String label,
    String status,
    Color color,
    String currentStatus,
    VoidCallback onTap,
  ) {
    final isActive = _getStatusLabel(status) == _getStatusLabel(currentStatus);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
        SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                      item,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _updateStatus(String inscriptionId, String newStatus, [BuildContext? dialogCtx]) async {
    final inscription = _db.getInscriptionById(inscriptionId);
    if (newStatus == 'valide') {
      if (inscription != null && inscription.status == InscriptionStatus.acceptee) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Cette inscription est déjà validée et enregistrée parmi les apprenants.'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
        return;
      }
      await _showValidationDialog(inscriptionId, dialogCtx);
    } else {
      try {
        await _db.updateInscriptionStatus(inscriptionId, newStatus);
        if (dialogCtx != null && dialogCtx.mounted) {
          Navigator.pop(dialogCtx, true);
        } else if (mounted) {
          Navigator.pop(context, true);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == 'rejete' ? '🚫 Inscription marquée comme Rejetée' : '✅ Statut mis à jour avec succès'),
              backgroundColor: newStatus == 'rejete' ? AppTheme.error : AppTheme.success,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showValidationDialog(String inscriptionId, [BuildContext? parentDialogCtx]) async {
    final inscription = _db.getInscriptionById(inscriptionId);
    if (inscription == null) return;

    final form = _db.getFormationById(inscription.formationId);
    final selectedModules = inscription.modules
            ?.where((module) => module.trim().isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    
    final modules = selectedModules.isNotEmpty
        ? selectedModules
        : (form?.estStage == true ? const <String>[] : form?.modules ?? const <String>[]);
    
    if (modules.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun module choisi sur cette inscription SFP. Corrigez le dossier avant validation.')),
      );
      return;
    }

    int initialDefaultHours = 1;
    if (form != null) {
      final dureeStr = form.dureeHeures ?? '';
      final match = RegExp(r'\d+').firstMatch(dureeStr);
      if (match != null) {
        final totalHours = int.tryParse(match.group(0)!) ?? 0;
        if (totalHours > 0 && modules.isNotEmpty) {
          initialDefaultHours = (totalHours / modules.length).round();
          if (initialDefaultHours < 1) initialDefaultHours = 1;
        }
      }
    }

    final moduleHours = <String, int>{};
    for (final module in modules) {
      moduleHours[module] = initialDefaultHours;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final totalAssigned = moduleHours.values.fold(0, (acc, h) => acc + h);

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.all(20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valider l\'Inscription',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Assignation des heures par module (Min. 1h)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Heures établies par module (Minimum 1h requis). Total : ${totalAssigned}h',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...modules.map((module) {
                    final hours = moduleHours[module] ?? 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Heures attribuées',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Boutons de contrôle + et -
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Bouton - (Minimum 1h)
                                InkWell(
                                  onTap: hours > 1
                                      ? () {
                                          setDialogState(() {
                                            moduleHours[module] = hours - 1;
                                          });
                                        }
                                      : null,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(9),
                                    bottomLeft: Radius.circular(9),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: hours > 1 ? AppTheme.accent.withValues(alpha: 0.06) : AppTheme.surfaceVariant,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(9),
                                        bottomLeft: Radius.circular(9),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                      color: hours > 1 ? AppTheme.accent : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                // Affichage du nombre d'heures
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  child: Text(
                                    '$hours h',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                // Bouton +
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      moduleHours[module] = hours + 1;
                                    });
                                  },
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(9),
                                    bottomRight: Radius.circular(9),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.06),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(9),
                                        bottomRight: Radius.circular(9),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2)),
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
              (() {
                bool isValidating = false;
                return StatefulBuilder(
                  builder: (context, setBtnState) {
                    return ElevatedButton.icon(
                      icon: isValidating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValidating ? Colors.grey.shade400 : AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 2,
                      ),
                      label: Text(isValidating ? 'Validation...' : 'Valider', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      onPressed: isValidating
                          ? null
                          : () async {
                              setBtnState(() => isValidating = true);
                              try {
                                final student = await _db.acceptInscription(
                                  inscriptionId,
                                  moduleHours: moduleHours,
                                  formationOverride: form,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx, true); // Close sub-dialog with success signal
                                if (parentDialogCtx != null && parentDialogCtx.mounted) {
                                  Navigator.pop(parentDialogCtx, true); // Close parent details dialog
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ Inscription validée ! Stagiaire: ${student.prenom} ${student.nom} (${student.matricule ?? 'Sans matricule'})'),
                                      backgroundColor: AppTheme.success,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                  setState(() {});
                                }
                              } catch (error) {
                                if (!ctx.mounted) return;
                                setBtnState(() => isValidating = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('❌ Validation impossible : $error'), backgroundColor: AppTheme.error),
                                );
                              }
                            },
                    );
                  },
                );
              })(),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(dynamic statusInput) {
    final status = (statusInput ?? '').toString().toLowerCase();
    if (status.contains('valide') || status.contains('accepte')) {
      return AppTheme.success;
    } else if (status.contains('rejet')) {
      return AppTheme.error;
    } else {
      return Colors.amber;
    }
  }

  String _getStatusLabel(dynamic statusInput) {
    final status = (statusInput ?? '').toString().toLowerCase();
    if (status.contains('valide') || status.contains('accepte')) {
      return 'Validée';
    } else if (status.contains('rejet')) {
      return 'Rejetée';
    } else {
      return 'En Attente';
    }
  }

  String _getFormationTypeLabel(String type) {
    switch (type) {
      case 'enligne':
        return 'En ligne';
      case 'presentiel':
        return 'Présentiel';
      case 'mixte':
        return 'Mixte';
      default:
        return 'Présentiel';
    }
  }

  String _getFormationPrice(Map<String, dynamic> formationData, Map<String, dynamic> inscription) {
    final type = (inscription['typeFormation'] ?? formationData['type'] ?? 'presentiel')
        .toString()
        .toLowerCase();
    if (type.contains('enligne') && formationData['prixEnLigne'] != null) {
      return formationData['prixEnLigne'].toString();
    }
    return formationData['prix']?.toString() ?? '0';
  }
}

