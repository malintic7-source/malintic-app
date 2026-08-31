import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/imagekit_service.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';

class AdminFormateurs extends StatefulWidget {
  const AdminFormateurs({super.key});

  @override
  State<AdminFormateurs> createState() => _AdminFormateursState();
}

class _AdminFormateursState extends State<AdminFormateurs> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  late AnimationController _fadeController;
  StreamSubscription<void>? _dataSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Mise à jour automatique instantanée des cartes et formateurs
    _dataSub = _db.watchAllDataChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dataSub?.cancel();
    searchController.dispose();
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
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 12 : 20,
            horizontal: isMobile ? 10 : 16,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFormateursStream(context),
                  ],
                )
              : Container(
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
                      _buildSearchBar(),
                      const SizedBox(height: 28),
                      _buildFormateursStream(context),
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
      child: isMobile
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formateurs',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gérez les formateurs et les affectations',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddFormateurDialog(),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: Text(
                    'Nouveau',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Formateurs',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérez les formateurs et les affectations manuelles',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddFormateurDialog(),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'Nouveau Formateur',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Rechercher par nom, email...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black38,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildFormateursStream(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: _db.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        final allUsers = snapshot.data ?? [];
        final deletedUserIds = _db.getDeletedDocs('users');
        final deletedUserEmails = _db.getDeletedDocs('user_emails');
        final formateurs = allUsers.where((u) {
          final email = u.email.trim().toLowerCase();
          return u.role == UserRole.formateur &&
              !deletedUserIds.contains(u.id) &&
              (email.isEmpty || !deletedUserEmails.contains(email));
        }).toList();

        final filtered = formateurs.where((user) {
          final nomComplet = user.nomComplet.toLowerCase();
          final email = user.email.toLowerCase();
          final phone = user.phone.toLowerCase();
          final query = searchController.text.trim().toLowerCase();

          if (query.isEmpty) return true;
          return nomComplet.contains(query) || email.contains(query) || phone.contains(query);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.person_off_rounded, size: 48, color: Colors.black12),
                  SizedBox(height: 16),
                  Text(
                    'Aucun formateur',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final user = filtered[index];
            final data = user.toMap();
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildFormateurCardPremium(context, user.id, data, index),
            );
          },
        );
      },
    );
  }

  Widget _buildFormateurCardPremium(BuildContext context, String userId, Map<String, dynamic> data, int index) {
    final prenom = data['prenom'] ?? '';
    final nom = data['nom'] ?? '';
    final email = data['email'] ?? '';
    final assigned = data['assignedFormations'] as List<dynamic>? ?? [];
    final assignedFormations = _db.getFormationsForFormateur(userId);
    final assignedModules = assignedFormations
        .expand((formation) {
          final mods = _db.getModulesForFormateur(formation, userId);
          if (formation.modules.isEmpty && mods.isNotEmpty) {
            return [formation.titre];
          }
          return mods.map((module) => '${formation.titre} · $module');
        })
        .toList();

    int totalAssignedHours = 0;
    int totalDoneHours = 0;

    for (final a in assigned) {
      final modules = a['modules'] as List<dynamic>? ?? [];
      for (final m in modules) {
        final assignedH = (m['assignedHours'] ?? 0) as num;
        final doneH = (m['doneHours'] ?? 0) as num;
        totalAssignedHours += assignedH.toInt();
        totalDoneHours += doneH.toInt();
      }
    }

    if (totalAssignedHours == 0) {
      for (final f in assignedFormations) {
        final match = RegExp(r'\d+').firstMatch(f.dureeHeures ?? '');
        final h = int.tryParse(match?.group(0) ?? '') ?? (f.dureeSemaines * 10 > 0 ? f.dureeSemaines * 10 : 30);
        totalAssignedHours += h;
      }
    }

    final progress = totalAssignedHours == 0 ? 0.0 : (totalDoneHours / totalAssignedHours).clamp(0.0, 1.0);

    final phone = (data['phone'] ?? '').toString();
    final specialite = (data['specialite'] ?? '').toString();
    final matricule = (data['matricule'] ?? '').toString();

    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: const Duration(milliseconds: 600),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    prenom.isNotEmpty ? prenom[0].toUpperCase() : 'F',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Status Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$prenom $nom',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Formateur',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (data['estActif'] ?? true)
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (data['estActif'] ?? true)
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 12,
                                color: (data['estActif'] ?? true)
                                    ? AppTheme.success
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (data['estActif'] ?? true) ? 'Actif' : 'Inactif',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: (data['estActif'] ?? true)
                                      ? AppTheme.success
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Specialty Highlight Badge
                    if (specialite.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 5),
                            Text(
                              'Spécialité : $specialite',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Contacts & Identifiers
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (phone.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (matricule.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Matricule : $matricule',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Hours & Progression
                    Text(
                      '$totalDoneHours / $totalAssignedHours heures (${(progress * 100).toStringAsFixed(0)}%) • ${assignedFormations.length} formation${assignedFormations.length > 1 ? 's' : ''} · ${assignedModules.length} module${assignedModules.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.black.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),

                    // Assigned Modules Tags
                    if (assignedModules.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: assignedModules.map((mod) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              mod,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Aucune formation affectée pour le moment.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final isMob = MediaQuery.of(context).size.width < 768;
                        if (isMob) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showFormateurDetail(userId, data),
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: Text('Détails', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        side: const BorderSide(color: AppTheme.primary),
                                        foregroundColor: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showHonorairesDialog(userId, data),
                                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFFD97706)),
                                      label: Text('Honoraires', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: const BorderSide(color: Color(0xFFFDE68A)),
                                        backgroundColor: const Color(0xFFFFFBEB),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _scheduleDialog(userId, data),
                                      icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF0D9488)),
                                      label: Text('Planning', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: const BorderSide(color: Color(0xFF99F6E4)),
                                        backgroundColor: const Color(0xFFF0FDFA),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _assignFormationDialog(userId),
                                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.white),
                                      label: Text('Affectations', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showFormateurDetail(userId, data),
                              icon: const Icon(Icons.visibility_outlined, size: 14),
                              label: Text('Détails', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showHonorairesDialog(userId, data),
                              icon: const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFFD97706)),
                              label: Text('Honoraires', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                backgroundColor: const Color(0xFFFFFBEB),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _scheduleDialog(userId, data),
                              icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF0D9488)),
                              label: Text('Planning', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                side: const BorderSide(color: Color(0xFF99F6E4)),
                                backgroundColor: const Color(0xFFF0FDFA),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _assignFormationDialog(userId),
                              icon: const Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.white),
                              label: Text('Affectations', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'voir') {
                    _showFormateurDetail(userId, data);
                  } else if (value == 'honoraires') {
                    _showHonorairesDialog(userId, data);
                  } else if (value == 'modifier') {
                    final user = _db.getUserById(userId);
                    if (user != null) _showEditFormateurDialog(user);
                  } else if (value == 'attribuer') {
                    await _assignFormationDialog(userId);
                  } else if (value == 'emploi') {
                    await _scheduleDialog(userId, data);
                  } else if (value == 'bloquer') {
                    final currentActive = (data['estActif'] ?? true) as bool;
                    await _toggleBlockUser(userId, currentActive);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'voir',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Voir'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'honoraires',
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text('Bulletin d\'Honoraires'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'modifier',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'attribuer',
                    child: Row(
                      children: [
                        Icon(Icons.assignment_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Affectations'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'emploi',
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Emploi du temps'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bloquer',
                    child: Row(
                      children: [
                        Icon(
                          (data['estActif'] ?? true)
                              ? Icons.block_rounded
                              : Icons.check_circle_rounded,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text((data['estActif'] ?? true) ? 'Bloquer' : 'Débloquer'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBlockUser(String userId, bool block) async {
    await _db.setUserActive(userId, !block);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(block ? 'Formateur bloqué' : 'Formateur débloqué')),
    );
  }

  Future<void> _assignFormationDialog(String userId) async {
    if (!mounted) return;
    final formations = _db.getFormations();
    final selectedModulesByFormation = <String, Set<String>>{
      for (final formation in formations)
        formation.id: _db.getModulesForFormateur(formation, userId).toSet(),
    };
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Affecter formations et modules', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cochez les formations et modules dispensés par ce formateur. Toutes les formations (SFP ou standard) sont sélectionnables.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  ...formations.map((formation) {
                    final selected = selectedModulesByFormation[formation.id] ?? <String>{};
                    final hasModules = formation.modules.isNotEmpty;
                    final isAllSelected = hasModules
                        ? formation.modules.every((m) => selected.contains(m))
                        : selected.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAllSelected || selected.isNotEmpty
                            ? AppTheme.primary.withValues(alpha: 0.04)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAllSelected || selected.isNotEmpty
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isAllSelected ? true : (selected.isNotEmpty ? null : false),
                                tristate: hasModules && selected.isNotEmpty && !isAllSelected,
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    if (hasModules) {
                                      selectedModulesByFormation[formation.id] = formation.modules.toSet();
                                    } else {
                                      selectedModulesByFormation[formation.id] = {formation.titre};
                                    }
                                  } else {
                                    selectedModulesByFormation[formation.id] = <String>{};
                                  }
                                }),
                              ),
                              Expanded(
                                child: Text(
                                  formation.titre,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              if (formation.estStage)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Stage SFP', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFC2410C), fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          if (hasModules) ...[
                            const SizedBox(height: 4),
                            ...formation.modules.map((module) => CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 28),
                              value: selected.contains(module),
                              title: Text(module, style: GoogleFonts.poppins(fontSize: 12)),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selectedModulesByFormation.putIfAbsent(formation.id, () => <String>{}).add(module);
                                } else {
                                  selectedModulesByFormation[formation.id]?.remove(module);
                                }
                              }),
                            )),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            (() {
              bool isSaving = false;
              return StatefulBuilder(
                builder: (context, setBtnState) {
                  return ElevatedButton.icon(
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(isSaving ? 'Enregistrement...' : 'Enregistrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSaving ? Colors.grey.shade400 : AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setBtnState(() => isSaving = true);
                            try {
                              await _db.replaceFormateurAssignments(
                                userId,
                                selectedModulesByFormation.map((id, modules) => MapEntry(id, modules.toList())),
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Affectations du formateur enregistrées avec succès.'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                                setState(() {});
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              setBtnState(() => isSaving = false);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
                              );
                            }
                          },
                  );
                },
              );
            })(),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddFormateurDialog() async {
    final prenomController = TextEditingController();
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final specialiteController = TextEditingController();
    final passwordController = TextEditingController(text: '00000000');
    String selectedSexe = 'Homme';
    String? uploadedPhotoUrl;
    bool isUploadingPhoto = false;
    final formations = _db.getFormations();
    final selectedModulesByFormation = <String, Set<String>>{
      for (final formation in formations) formation.id: <String>{},
    };

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Créer un formateur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(
                    'Informations personnelles',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                TextField(
                  controller: prenomController,
                  decoration: const InputDecoration(
                      labelText: 'Prénom *',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                      labelText: 'Nom *',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialiteController,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité',
                      prefixIcon: Icon(Icons.school_rounded),
                      helperText: 'Ex: Web Development, Flutter, Réseaux, Design Graphique, etc.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSexe,
                    decoration: const InputDecoration(
                      labelText: 'Sexe *',
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Homme', child: Text('Homme')),
                      DropdownMenuItem(value: 'Femme', child: Text('Femme')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedSexe = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe initial',
                      prefixIcon: Icon(Icons.lock_rounded),
                      helperText: 'Par défaut : 00000000',
                    ),
                    obscureText: true,
                  ),
                const SizedBox(height: 16),
                  Text(
                    'Photo de profil',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        backgroundImage: uploadedPhotoUrl != null
                            ? NetworkImage(uploadedPhotoUrl!)
                            : null,
                        child: uploadedPhotoUrl == null
                            ? Icon(Icons.person_rounded, color: AppTheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: isUploadingPhoto
                            ? null
                            : () async {
                                setDialogState(() => isUploadingPhoto = true);
                                try {
                                  final url = await ImageKitService()
                                      .pickAndUploadImage(folder: 'formateurs');
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    uploadedPhotoUrl = url;
                                    isUploadingPhoto = false;
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setDialogState(() => isUploadingPhoto = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur photo : $e')),
                                  );
                                }
                              },
                        icon: isUploadingPhoto
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_rounded, size: 18),
                        label: Text(uploadedPhotoUrl == null ? 'Ajouter' : 'Changer'),
                      ),
                      if (uploadedPhotoUrl != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setDialogState(() => uploadedPhotoUrl = null),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          tooltip: 'Supprimer la photo',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Affectations formations & modules',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez les modules que ce formateur dispensera. Vous pourrez les modifier plus tard.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  ...formations.map((formation) {
                    final selected = selectedModulesByFormation[formation.id] ?? <String>{};
                    final hasModules = formation.modules.isNotEmpty;
                    final isAllSelected = hasModules
                        ? formation.modules.every((m) => selected.contains(m))
                        : selected.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAllSelected || selected.isNotEmpty
                            ? AppTheme.primary.withValues(alpha: 0.04)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAllSelected || selected.isNotEmpty
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isAllSelected ? true : (selected.isNotEmpty ? null : false),
                                tristate: hasModules && selected.isNotEmpty && !isAllSelected,
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    if (hasModules) {
                                      selectedModulesByFormation[formation.id] = formation.modules.toSet();
                                    } else {
                                      selectedModulesByFormation[formation.id] = {formation.titre};
                                    }
                                  } else {
                                    selectedModulesByFormation[formation.id] = <String>{};
                                  }
                                }),
                              ),
                              Expanded(
                                child: Text(
                                  formation.titre,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              if (formation.estStage)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Stage SFP', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFC2410C), fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          if (hasModules) ...[
                            const SizedBox(height: 4),
                            ...formation.modules.map((module) => CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 28),
                              value: selected.contains(module),
                              title: Text(module, style: GoogleFonts.poppins(fontSize: 12)),
                              onChanged: (checked) => setDialogState(() {
                                if (checked == true) {
                                  selectedModulesByFormation.putIfAbsent(formation.id, () => <String>{}).add(module);
                                } else {
                                  selectedModulesByFormation[formation.id]?.remove(module);
                                }
                              }),
                            )),
                          ],
                        ],
                      ),
                    );
                  }),
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
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Créer le formateur'),
              onPressed: () async {
                    final prenom = prenomController.text.trim();
                    final nom = nomController.text.trim();
                    final email = emailController.text.trim().toLowerCase();
                    final phone = phoneController.text.trim();
                final password = passwordController.text.trim().isEmpty
                    ? '00000000'
                    : passwordController.text.trim();

                    if (prenom.isEmpty || nom.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Veuillez remplir tous les champs obligatoires (prénom, nom, email).',
                      ),
                    ),
                      );
                      return;
                    }

                    final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
                    if (!emailRegExp.hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez fournir une adresse email valide.'),
                    ),
                      );
                      return;
                    }

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le mot de passe doit contenir au moins 6 caractères.'),
                    ),
                  );
                  return;
                }

                final existingUser = _db
                    .getUsers()
                    .where((u) => u.email.toLowerCase() == email)
                    .firstOrNull;
                    if (existingUser != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Un compte avec cette adresse email existe déjà.'),
                    ),
                      );
                      return;
                    }

                    try {
                      final formateur = await AuthProvider().createUserByAdmin(
                        email: email,
                        nom: nom,
                        prenom: prenom,
                        phone: phone,
                        role: UserRole.formateur,
                    sexe: selectedSexe,
                    password: password,
                    photoUrl: uploadedPhotoUrl,
                    specialite: specialiteController.text.trim().isEmpty 
                        ? null 
                        : specialiteController.text.trim(),
                  );

                  if (formateur == null) return;

                  final hasManualAssignments = selectedModulesByFormation.values
                      .any((modules) => modules.isNotEmpty);

                  if (hasManualAssignments) {
                    await _db.replaceFormateurAssignments(
                      formateur.id,
                      selectedModulesByFormation.map(
                        (id, modules) => MapEntry(id, modules.toList()),
                      ),
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hasManualAssignments
                              ? 'Formateur créé avec ses affectations manuelles.'
                              : 'Formateur créé avec succès.',
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    setState(() {});
                  }
                    } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur : $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            ),
          ],
        ),
      ),
    );
  }

  void _showFormateurDetail(String userId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final assignedOriginal = (data['assignedFormations'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        final assignedCopy = assignedOriginal
            .map((a) => {
                  'formationId': a['formationId'],
                  'title': a['title'],
                  'dateAssigned': a['dateAssigned'],
                  'modules': (a['modules'] as List<dynamic>? ?? [])
                      .map((m) => Map<String, dynamic>.from(m as Map<String, dynamic>))
                      .toList(),
                })
            .toList();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              '${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_rounded, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['email'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((data['phone'] ?? '').toString().trim().isNotEmpty) ...[
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_rounded, color: Colors.black54, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['phone'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInfoChip(Icons.wc_rounded, data['sexe'] ?? 'Homme'),
                      SizedBox(width: 8),
                      _buildInfoChip(
                        (data['estActif'] ?? true) ? Icons.check_circle_rounded : Icons.block_rounded,
                        (data['estActif'] ?? true) ? 'Actif' : 'Inactif',
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  if (assignedCopy.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Aucune formation attribuée',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formations attribuées',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...assignedCopy.map((a) {
                          final modules = (a['modules'] as List).cast<Map<String, dynamic>>();
                          int totalAssigned = 0;
                          int totalDone = 0;
                          for (final m in modules) {
                            totalAssigned += (m['assignedHours'] ?? 0) as int;
                            totalDone += (m['doneHours'] ?? 0) as int;
                          }
                          final formationProgress = totalAssigned == 0 ? 0.0 : (totalDone / totalAssigned).clamp(0.0, 1.0);

                          return Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: formationProgress,
                                                minHeight: 6,
                                                backgroundColor: Colors.black.withValues(alpha: 0.08),
                                                valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${(formationProgress * 100).toStringAsFixed(0)}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  ...modules
                                      .where((m) {
                                        final title = (m['title'] ?? '').toString().trim();
                                        final assignedH = (m['assignedHours'] ?? 0) as num;
                                        return title.isNotEmpty && assignedH > 0;
                                      })
                                      .map((m) {
                                    final assignedH = (m['assignedHours'] ?? 0) as int;
                                    final doneH = (m['doneHours'] ?? 0) as int;
                                    final moduleProgress = assignedH == 0 ? 0.0 : (doneH / assignedH).clamp(0.0, 1.0);

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  m['title'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$doneH/$assignedH h',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: LinearProgressIndicator(
                                                    value: moduleProgress,
                                                    minHeight: 4,
                                                    backgroundColor: Colors.black.withValues(alpha: 0.08),
                                                    valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              SizedBox(
                                                width: 60,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () async {
                                                        if (doneH <= 0) return;
                                                        final prev = m['doneHours'] as int? ?? 0;
                                                        m['doneHours'] = (prev - 1).clamp(0, assignedH);
                                                        setState(() {});
                                                        try {
                                                          await _updateModuleDoneHours(userId, a['formationId'], m['title'], -1);
                                                        } catch (e) {
                                                          m['doneHours'] = prev;
                                                          setState(() {});
                                                        }
                                                      },
                                                      child: Icon(Icons.remove_rounded, size: 16, color: AppTheme.primary),
                                                    ),
                                                    SizedBox(width: 4),
                                                    InkWell(
                                                      onTap: () async {
                                                        if (doneH >= assignedH) return;
                                                        final prev = m['doneHours'] as int? ?? 0;
                                                        m['doneHours'] = (prev + 1).clamp(0, assignedH);
                                                        setState(() {});
                                                        try {
                                                          await _updateModuleDoneHours(userId, a['formationId'], m['title'], 1);
                                                        } catch (e) {
                                                          m['doneHours'] = prev;
                                                          setState(() {});
                                                        }
                                                      },
                                                      child: Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  SizedBox(height: 20),
                  StreamBuilder<List<Formation>>(
                    stream: _db.watchFormations(),
                    builder: (context, scheduleSnapshot) {
                      if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                            strokeWidth: 2,
                          ),
                        );
                      }

                      final schedules = (scheduleSnapshot.data ?? [])
                          .where((formation) =>
                              _db.getModulesForFormateur(formation, userId).isNotEmpty)
                          .toList();

                      if (schedules.isEmpty) {
                        return SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emplois du temps',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          ...schedules.map((formation) {
                            final scheduleTitle = formation.titre;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppTheme.primary.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scheduleTitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    ..._db.getModulesForFormateur(formation, userId).map((moduleName) {
                                      final horaires = formation.horaires.where((h) {
                                        return h.module?.isEmpty != false ||
                                            h.module == moduleName;
                                      });
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                                            Text(
                                              moduleName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            if (horaires.isEmpty)
                                              Text(
                                                'Horaires non définis',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color: Colors.black45,
                                                ),
                                              )
                                            else
                                              ...horaires.map(
                                                (h) => Text(
                                                  '${h.jour} : ${h.heureDebut} - ${h.heureFin}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                        ),
                      ],
                    ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1D447A)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF1D447A)),
                label: Text(
                  'Calculer Honoraires PDF',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1D447A)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showHonorairesDialog(userId, data);
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
                      children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
                        Text(
            label,
                          style: GoogleFonts.poppins(
              fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
        ],
      ),
    );
  }

  Future<void> _scheduleDialog(String userId, Map<String, dynamic> data) async {
    final formateur = _db.getUserById(userId);
    if (formateur == null) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final formations = _db.getFormationsForFormateur(userId);
        return AlertDialog(
          title: Text(
            'Emploi du temps — ${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 560,
            child: formations.isEmpty
                ? Text(
                    'Aucune formation ou module assigné pour le moment.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: formations.map((formation) {
                        final modules = _db.getModulesForFormateur(formation, userId);
                        final horaires = formation.horaires.where((h) {
                          return h.module?.isEmpty != false ||
                              modules.contains(h.module);
                        }).toList();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                      Text(
                                formation.titre,
                                        style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Modules : ${modules.join(', ')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (horaires.isEmpty)
                                Text(
                                  'Aucun horaire planifié',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.black45,
                                  ),
                                )
                              else
                                ...horaires.map(
                                  (h) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${h.jour} • ${h.heureDebut} - ${h.heureFin}'
                                      '${h.module?.isNotEmpty == true ? ' (${h.module})' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                          color: Colors.black87,
                                      ),
                                    ),
                                        ),
                                      ),
                                    ],
                                  ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFormateurDialog(User user) {
    final prenomController = TextEditingController(text: user.prenom);
    final nomController = TextEditingController(text: user.nom);
    final phoneController = TextEditingController(text: user.phone);
    final specialiteController = TextEditingController(text: user.specialite ?? '');
    String selectedSexe = user.sexe;
    String? uploadedPhotoUrl = user.photoUrl;
    bool isUploadingPhoto = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Modifier le formateur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                                      children: [
                  TextField(
                    controller: prenomController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialiteController,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité',
                      prefixIcon: Icon(Icons.school_rounded),
                      helperText: 'Ex: Web Development, Flutter, Réseaux, Design Graphique, etc.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSexe,
                    decoration: const InputDecoration(
                      labelText: 'Sexe',
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Homme', child: Text('Homme')),
                      DropdownMenuItem(value: 'Femme', child: Text('Femme')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedSexe = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        backgroundImage: uploadedPhotoUrl != null
                            ? NetworkImage(uploadedPhotoUrl!)
                            : null,
                        child: uploadedPhotoUrl == null
                            ? Icon(Icons.person_rounded, color: AppTheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: isUploadingPhoto
                            ? null
                            : () async {
                                setDialogState(() => isUploadingPhoto = true);
                                try {
                                  final url = await ImageKitService()
                                      .pickAndUploadImage(folder: 'formateurs');
                                  if (!context.mounted) return;
                                  setDialogState(() {
                                    uploadedPhotoUrl = url;
                                    isUploadingPhoto = false;
                                  });
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setDialogState(() => isUploadingPhoto = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur photo : $e')),
                                  );
                                }
                              },
                        icon: const Icon(Icons.photo_camera_rounded, size: 18),
                        label: const Text('Photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              ),
            ),
            actions: [
              TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prenom = prenomController.text.trim();
                final nom = nomController.text.trim();
                if (prenom.isEmpty || nom.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le prénom et le nom sont obligatoires.')),
                  );
                  return;
                }

                try {
                  await AuthProvider().updateUser(
                    User(
                      id: user.id,
                      email: user.email,
                      nom: nom,
                      prenom: prenom,
                      phone: phoneController.text.trim(),
                      specialite: specialiteController.text.trim().isEmpty
                          ? null
                          : specialiteController.text.trim(),
                      matricule: user.matricule,
                      role: user.role,
                      password: user.password,
                      photoUrl: uploadedPhotoUrl,
                      assignedFormations: user.assignedFormations,
                      sexe: selectedSexe,
                      estActif: user.estActif,
                      dateCreation: user.dateCreation,
                      dateModification: DateTime.now(),
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Formateur modifié avec succès'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateModuleDoneHours(
    String userId,
    String formationId,
    String moduleTitle,
    int delta,
  ) async {
    await _db.updateModuleDoneHours(userId, formationId, moduleTitle, delta);
    if (!mounted) return;
    setState(() {});
  }

  void _showHonorairesDialog(String userId, Map<String, dynamic> data) {
    final prenom = data['prenom'] ?? '';
    final nom = data['nom'] ?? '';
    final nomComplet = '$prenom $nom'.trim();
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final matricule = data['matricule']?.toString();
    final specialite = data['specialite']?.toString();

    final assignedFormations = _db.getFormationsForFormateur(userId);
    final assigned = data['assignedFormations'] as List<dynamic>? ?? [];
    int calculatedHours = 0;
    final List<Map<String, dynamic>> modulesBreakdown = [];

    for (final a in assigned) {
      final fId = a['formationId']?.toString() ?? '';
      final formation = _db.getFormationById(fId);
      final fTitle = formation?.titre ?? 'Formation';
      final modules = a['modules'] as List<dynamic>? ?? [];
      for (final m in modules) {
        final mTitle = m['title']?.toString() ?? 'Module';
        final doneH = (m['doneHours'] ?? m['assignedHours'] ?? 0) as num;
        final h = doneH.toDouble();
        if (h > 0) {
          calculatedHours += h.toInt();
          modulesBreakdown.add({
            'formation': fTitle,
            'module': mTitle,
            'heures': h,
          });
        }
      }
    }

    if (calculatedHours == 0) {
      for (final f in assignedFormations) {
        final mods = _db.getModulesForFormateur(f, userId);
        final defaultH = f.dureeSemaines > 0 ? (f.dureeSemaines * 5).toDouble() : 20.0;
        calculatedHours += defaultH.toInt();
        modulesBreakdown.add({
          'formation': f.titre,
          'module': mods.isNotEmpty ? mods.join(', ') : 'Tronc Commun',
          'heures': defaultH,
        });
      }
    }

    final heuresController = TextEditingController(text: '$calculatedHours');
    final tauxController = TextEditingController(text: '5000');
    final acompteController = TextEditingController(text: '0');
    final primesController = TextEditingController(text: '0');
    final periodeController = TextEditingController(text: 'Mois de ${_getCurrentMonthName()} ${DateTime.now().year}');
    final noteController = TextEditingController();

    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final hours = double.tryParse(heuresController.text.trim()) ?? 0.0;
          final rate = double.tryParse(tauxController.text.trim()) ?? 5000.0;
          final acompte = double.tryParse(acompteController.text.trim()) ?? 0.0;
          final primes = double.tryParse(primesController.text.trim()) ?? 0.0;
          final totalBrut = (hours * rate) + primes;
          final netPayable = (totalBrut - acompte) > 0 ? (totalBrut - acompte) : 0.0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D447A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1D447A), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculateur d\'Honoraires',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1D447A)),
                      ),
                      Text(
                        nomComplet,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial summary banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D447A), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NET À VERSER (FCFA)',
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${netPayable.toStringAsFixed(0)} FCFA',
                                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Brut : ${totalBrut.toStringAsFixed(0)} F',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                              ),
                              if (acompte > 0)
                                Text(
                                  'Acomptes : -${acompte.toStringAsFixed(0)} F',
                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFFCA5A5)),
                                ),
                              Text(
                                'Taux : ${rate.toStringAsFixed(0)} F/h',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inputs Row 1: Période
                    TextField(
                      controller: periodeController,
                      decoration: const InputDecoration(
                        labelText: 'Période de prestation *',
                        prefixIcon: Icon(Icons.date_range_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Inputs Row 2: Heures & Taux
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: heuresController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Heures effectuées *',
                              suffixText: 'heures',
                              prefixIcon: Icon(Icons.timer_outlined, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: tauxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Taux Horaire (FCFA) *',
                              suffixText: 'F/h',
                              prefixIcon: Icon(Icons.monetization_on_outlined, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Inputs Row 3: Primes & Acomptes
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: primesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Primes / Bonus (FCFA)',
                              prefixIcon: Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF10B981)),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: acompteController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Acomptes Déjà Versés (FCFA)',
                              prefixIcon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Note
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Observations / Note interne (optionnel)',
                        hintText: 'Ex. Règlements par virement Orange Money',
                        prefixIcon: Icon(Icons.notes_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  isGenerating ? 'Génération...' : 'Générer Fiche d\'Honoraires PDF',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: isGenerating
                    ? null
                    : () async {
                        setModalState(() => isGenerating = true);
                        try {
                          final pdfBytes = await PdfService().generateTrainerHonorariumSlipPdf(
                            formateurNom: nomComplet,
                            email: email,
                            telephone: phone,
                            matricule: matricule,
                            specialite: specialite,
                            periode: periodeController.text.trim(),
                            tauxHoraire: rate,
                            totalHeures: hours,
                            acompteVerse: acompte,
                            primesOuBonus: primes,
                            modulesEnseignes: modulesBreakdown,
                            note: noteController.text.trim(),
                          );

                          final safeName = nomComplet.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                          await PdfService().printOrDownloadPdf(
                            pdfBytes: pdfBytes,
                            filename: 'Honoraires_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📄 Bulletin d\'honoraires PDF généré avec succès !'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isGenerating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur génération honoraires : $e'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  String _getCurrentMonthName() {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[DateTime.now().month - 1];
  }
}
