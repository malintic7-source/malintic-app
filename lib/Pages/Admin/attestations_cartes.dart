import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/utils/app_logger.dart';

class AdminAttestationsCartes extends StatefulWidget {
  final User? user;
  const AdminAttestationsCartes({super.key, this.user});

  @override
  State<AdminAttestationsCartes> createState() => _AdminAttestationsCartesState();
}

class _AdminAttestationsCartesState extends State<AdminAttestationsCartes> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  late AnimationController _fadeController;
  String _selectedMention = 'Très Bien';
  String _searchQuery = '';

  bool get _canDeliverAttestation =>
      widget.user == null ||
      widget.user!.role == UserRole.dg ||
      widget.user!.role == UserRole.admin ||
      widget.user!.role == UserRole.daf ||
      widget.user!.role == UserRole.assistant;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    searchController.addListener(() {
      setState(() => _searchQuery = searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildStudentsList(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gestion des Attestations & Certificats PDF',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Impression et délivrance officielle des attestations de réussite et certificats de formation.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher un apprenant par nom, e-mail, téléphone...',
          hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => searchController.clear(),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStudentsList(bool isMobile) {
    return StreamBuilder<List<Inscription>>(
      stream: _db.watchInscriptions(),
      builder: (context, snapshot) {
        final inscriptions = snapshot.data ?? [];
        final users = _db.getUsers().where((u) => u.role == UserRole.apprenant).toList();

        final Map<String, Map<String, dynamic>> studentsMap = {};

        for (final user in users) {
          final key = user.email.trim().toLowerCase().isNotEmpty ? user.email.trim().toLowerCase() : user.id;
          studentsMap[key] = {
            'id': user.id,
            'prenom': user.prenom,
            'nom': user.nom,
            'email': user.email,
            'phone': user.phone,
            'matricule': user.matricule,
            'formationTitre': 'Formation M@LI-NTIC',
          };
        }

        for (final ins in inscriptions) {
          final key = (ins.email ?? '').trim().toLowerCase().isNotEmpty ? ins.email!.trim().toLowerCase() : ins.id;
          final formation = _db.getFormationById(ins.formationId);

          if (!studentsMap.containsKey(key)) {
            studentsMap[key] = {
              'id': ins.id,
              'prenom': ins.prenom ?? '',
              'nom': ins.nom ?? 'Apprenant',
              'email': ins.email ?? '',
              'phone': ins.telephone ?? '',
              'matricule': 'MAT-${ins.id.substring(ins.id.length - 4)}',
              'formationTitre': formation?.titre ?? 'Formation M@LI-NTIC',
              'inscription': ins,
              'formation': formation,
            };
          } else {
            studentsMap[key]!['formationTitre'] = formation?.titre ?? 'Formation M@LI-NTIC';
            studentsMap[key]!['inscription'] = ins;
            studentsMap[key]!['formation'] = formation;
          }
        }

        final studentsList = studentsMap.values.where((st) {
          final fullName = '${st['prenom']} ${st['nom']}'.toLowerCase();
          final email = (st['email'] as String).toLowerCase();
          final phone = (st['phone'] as String).toLowerCase();
          final matricule = (st['matricule'] ?? '').toString().toLowerCase();
          if (_searchQuery.isEmpty) return true;
          return fullName.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              phone.contains(_searchQuery) ||
              matricule.contains(_searchQuery);
        }).toList();

        if (studentsList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 48, color: Colors.black26),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun apprenant trouvé pour la génération d’attestation.',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: studentsList.length,
          itemBuilder: (context, index) {
            final st = studentsList[index];
            final prenom = st['prenom'] ?? '';
            final nom = st['nom'] ?? '';
            final email = st['email'] ?? '';
            final phone = st['phone'] ?? '';
            final formationTitre = st['formationTitre'] ?? 'Formation M@LI-NTIC';

            return FadeInUp(
              duration: const Duration(milliseconds: 350),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 10 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$prenom $nom'.trim().isNotEmpty ? '$prenom $nom' : 'Apprenant',
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$email ${phone.isNotEmpty ? "• $phone" : ""} • $formationTitre',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButton<String>(
                                value: _selectedMention,
                                underline: const SizedBox(),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                items: ['Très Bien', 'Bien', 'Assez Bien', 'Passable'].map((m) {
                                  return DropdownMenuItem(value: m, child: Text('Mention: $m'));
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedMention = v ?? 'Très Bien'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                                label: Text('Générer Attestation PDF', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                onPressed: () => _printAttestation(st),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Mention : ', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                                  DropdownButton<String>(
                                    value: _selectedMention,
                                    underline: const SizedBox(),
                                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700),
                                    items: ['Très Bien', 'Bien', 'Assez Bien', 'Passable'].map((m) {
                                      return DropdownMenuItem(value: m, child: Text(m));
                                    }).toList(),
                                    onChanged: (v) => setState(() => _selectedMention = v ?? 'Très Bien'),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                                label: Text('Générer Attestation PDF', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                onPressed: () => _printAttestation(st),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _printAttestation(Map<String, dynamic> st) async {
    if (!_canDeliverAttestation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Action non autorisée. Seuls le Directeur Général, l\'Administrateur, le DAF et le Responsable de Scolarité peuvent délivrer les attestations.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      final inscription = st['inscription'] as Inscription? ??
          Inscription(
            id: 'ins_${st['id']}',
            etudiantId: st['id'],
            formationId: 'form_1',
            status: InscriptionStatus.acceptee,
            dateInscription: DateTime.now(),
            paiementEffectue: true,
            nom: st['nom'],
            prenom: st['prenom'],
            email: st['email'],
            telephone: st['phone'],
          );

      final formation = st['formation'] as Formation? ??
          Formation(
            id: 'form_1',
            titre: st['formationTitre'] ?? 'Formation M@LI-NTIC',
            description: '',
            modules: [],
            formateurIds: [],
            prix: 0,
            type: FormationType.presentielle,
            status: FormationStatus.enCours,
            dureeSemaines: 4,
            dureeHeures: '30h',
            horaires: [],
            dateCreation: DateTime.now(),
          );

      final pdfBytes = await PdfService().generateAttestationPdf(
        inscription: inscription,
        formation: formation,
        mention: _selectedMention,
      );

      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'Attestation_${st['prenom']}_${st['nom']}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Attestation officielle de ${st['prenom']} ${st['nom']} générée avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }

      // Safe Audit Log
      try {
        await _db.logAction(
          userNom: widget.user != null ? '${widget.user!.prenom} ${widget.user!.nom}'.trim() : 'Direction',
          userRole: widget.user?.role.name ?? 'dg',
          action: 'Délivrance attestation',
          description: 'Attestation officielle délivrée à ${st['prenom']} ${st['nom']} (${st['formationTitre'] ?? "Formation"})',
        );
      } catch (e, s) {
        logHandledError(
          'Journalisation de la délivrance d’attestation impossible',
          e,
          s,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur génération attestation: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}
