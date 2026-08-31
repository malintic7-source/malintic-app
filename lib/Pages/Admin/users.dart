import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  String selectedRole = 'Tous';
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

    // Mise à jour automatique instantanée des utilisateurs
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
    final hp = isMobile ? 10.0 : 16.0;
    final vp = isMobile ? 10.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 28),
          _buildSearchAndFilters(isMobile),
          SizedBox(height: isMobile ? 16 : 28),
          _buildUsersStream(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utilisateurs',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 20 : 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gérez les comptes et permissions des utilisateurs',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 11 : 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isMobile)
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.heroShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCreateUserDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ajouter',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (isMobile)
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.heroShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCreateUserDialog(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Ajouter',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.softShadow,
          ),
          child: TextField(
            controller: searchController,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Rechercher par nom, email...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textMuted,
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
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tous', 'Tous'),
              const SizedBox(width: 8),
              _buildFilterChip('Admin', 'admin'),
              const SizedBox(width: 8),
              _buildFilterChip('Formateur', 'formateur'),
              const SizedBox(width: 8),
              _buildFilterChip('Apprenant', 'apprenant'),
              const SizedBox(width: 8),
              _buildFilterChip('DG', 'dg'),
              const SizedBox(width: 8),
              _buildFilterChip('DAF', 'daf'),
              const SizedBox(width: 8),
              _buildFilterChip('Comptable', 'comptable'),
              const SizedBox(width: 8),
              _buildFilterChip('Assistant', 'assistant'),
              const SizedBox(width: 8),
              _buildFilterChip('IT', 'it'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildUsersStream(BuildContext context, bool isMobile) {
    return StreamBuilder<List<User>>(
      stream: AuthProvider().watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
          );
        }

        final users = _filterUsers(snapshot.data ?? []);

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.person_off_rounded, size: 48, color: Colors.black12),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun utilisateur',
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
          itemCount: users.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildUserCardPremium(context, users[index], index),
            );
          },
        );
      },
    );
  }

  Widget _buildUserCardPremium(BuildContext context, User user, int index) {
    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: const Duration(milliseconds: 600),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getRoleGradient(user.role),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getRoleGradient(user.role)[0].withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _getRoleIcon(user.role),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nomComplet,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        InkWell(
                          onTap: () => _showAssignRoleDialog(context, user),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getRoleGradient(user.role)[0].withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getRoleGradient(user.role)[0].withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _roleLabel(user.role),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getRoleGradient(user.role)[0],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 13,
                                  color: _getRoleGradient(user.role)[0],
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            final localContext = context;
                            AuthProvider()
                                .setUserActive(user.id, !user.estActif)
                                .then((_) {
                              if (!localContext.mounted) return;
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                SnackBar(
                                  content: Text(user.estActif
                                      ? 'Utilisateur désactivé'
                                      : 'Utilisateur activé'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: user.estActif
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user.estActif
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 12,
                                  color: user.estActif
                                      ? const Color(0xFF10B981)
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.estActif ? 'Actif' : 'Inactif',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: user.estActif
                                        ? const Color(0xFF10B981)
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: Colors.white,
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                onSelected: (value) {
                  if (value == 'assign_role') {
                    _showAssignRoleDialog(context, user);
                  } else if (value == 'modifier') {
                    _showEditUserDialog(context, user);
                  } else if (value == 'reset_password') {
                    _resetUserPassword(context, user);
                  } else if (value == 'toggle') {
                    final localContext = context;
                    AuthProvider()
                        .setUserActive(user.id, !user.estActif)
                        .then((_) {
                      if (!localContext.mounted) return;
                      ScaffoldMessenger.of(localContext).showSnackBar(
                        SnackBar(
                          content: Text(user.estActif
                              ? 'Utilisateur désactivé'
                              : 'Utilisateur activé'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    });
                  } else if (value == 'delete') {
                    _confirmDeleteUser(context, user);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'assign_role',
                    child: Row(
                      children: [
                        const Icon(Icons.manage_accounts_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text('Affecter / Changer Rôle', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'modifier',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0D9488)),
                        const SizedBox(width: 8),
                        Text('Modifier', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          user.estActif
                              ? Icons.block_rounded
                              : Icons.check_circle_rounded,
                          size: 18,
                          color: user.estActif ? const Color(0xFFD97706) : AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Text(user.estActif ? 'Désactiver' : 'Activer', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        const Icon(Icons.key_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text('Modifier mot de passe', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 8),
                        Text('Supprimer', style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.black54,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<User> _filterUsers(List<User> users) {
    final query = searchController.text.trim().toLowerCase();
    final deletedUserIds = LocalDataService().getDeletedDocs('users');
    final deletedUserEmails = LocalDataService().getDeletedDocs('user_emails');
    return users.where((user) {
      final email = user.email.trim().toLowerCase();
      if (deletedUserIds.contains(user.id)) return false;
      if (email.isNotEmpty && deletedUserEmails.contains(email)) return false;
      final matchesSearch = query.isEmpty ||
          user.nom.toLowerCase().contains(query) ||
          user.prenom.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.phone.toLowerCase().contains(query) ||
          (user.matricule ?? '').toLowerCase().contains(query);
      final roleStr = user.role.toString().split('.').last.toLowerCase();
      final matchesRole = selectedRole == 'Tous' || roleStr == selectedRole.toLowerCase() || (selectedRole.toLowerCase() == 'apprenant' && roleStr == 'etudiant');
      return matchesSearch && matchesRole;
    }).toList();
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin: return 'Administrateur';
      case UserRole.dg: return 'Directeur Général (DG)';
      case UserRole.daf: return 'DAF';
      case UserRole.comptable: return 'Comptable';
      case UserRole.assistant: return 'Assistant(e)';
      case UserRole.it: return 'Responsable IT';
      case UserRole.formateur: return 'Formateur';
      case UserRole.apprenant: return 'Stagiaire / Apprenant';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.formateur:
        return Icons.school_rounded;
      case UserRole.apprenant:
        return Icons.person_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  List<Color> _getRoleGradient(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return [AppTheme.primary, AppTheme.primaryDark];
      case UserRole.formateur:
        return [AppTheme.primary, AppTheme.primaryDark];
      case UserRole.apprenant:
        return [AppTheme.accent, AppTheme.accent];
      default:
        return [AppTheme.primary, AppTheme.primaryDark];
    }
  }

  void _showCreateUserDialog(BuildContext context) {
    final prenomController = TextEditingController();
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    UserRole selectedUserRole = UserRole.apprenant;
    final formations = LocalDataService().getFormations();
    final Map<String, Set<String>> selectedModulesByFormation = {
      for (final f in formations) f.id: <String>{},
    };
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Créer un utilisateur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prenomController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
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
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedUserRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  items: UserRole.values
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedUserRole = value);
                    }
                  },
                ),
                if (selectedUserRole == UserRole.formateur) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Affectations formations et modules',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cochez les modules dispensés. Une formation est attribuée dès qu’un module est sélectionné.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  ...formations.map((formation) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formation.titre, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                        ...formation.modules.map((module) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedModulesByFormation[formation.id]!.contains(module),
                          title: Text(module, style: GoogleFonts.poppins(fontSize: 12)),
                          onChanged: (checked) => setDialogState(() {
                            if (checked == true) {
                              selectedModulesByFormation[formation.id]!.add(module);
                            } else {
                              selectedModulesByFormation[formation.id]!.remove(module);
                            }
                          }),
                        )),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Un mot de passe temporaire sera généré automatiquement.',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: isSubmitting ? null : AppTheme.primaryGradient,
                color: isSubmitting ? Colors.grey.shade400 : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final localContext = context;
                          final prenom = prenomController.text.trim();
                          final nom = nomController.text.trim();
                          final email = emailController.text.trim().toLowerCase();
                          final phone = phoneController.text.trim();

                          if (prenom.isEmpty || nom.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires (prénom, nom, email).')),
                            );
                            return;
                          }

                          final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
                          if (!emailRegExp.hasMatch(email)) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(content: Text('Veuillez fournir une adresse email valide.')),
                            );
                            return;
                          }

                          final existingUser = LocalDataService().getUsers().where((u) => u.email.toLowerCase() == email).firstOrNull;
                          if (existingUser != null) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(content: Text('Un compte avec cette adresse email existe déjà.')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await AuthProvider().createUserByAdmin(
                              email: email,
                              nom: nom,
                              prenom: prenom,
                              phone: phone,
                              role: selectedUserRole,
                            );

                            if (selectedUserRole == UserRole.formateur) {
                              final hasManualAssignments = selectedModulesByFormation.values
                                  .any((modules) => modules.isNotEmpty);
                              if (hasManualAssignments) {
                                final formateur = LocalDataService().getUsers().firstWhere(
                                  (user) => user.email.toLowerCase() == email,
                                );
                                await LocalDataService().replaceFormateurAssignments(
                                  formateur.id,
                                  selectedModulesByFormation.map(
                                    (id, modules) => MapEntry(id, modules.toList()),
                                  ),
                                );
                              }
                            }

                            if (!localContext.mounted) return;
                            Navigator.pop(localContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Utilisateur créé avec succès'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!localContext.mounted) return;
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: ${e.toString()}'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      isSubmitting ? 'Création...' : 'Créer',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, User user) {
    final prenomController = TextEditingController(text: user.prenom);
    final nomController = TextEditingController(text: user.nom);
    final phoneController = TextEditingController(text: user.phone);
    UserRole selectedUserRole = user.role;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Modifier l\'utilisateur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prenomController,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
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
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedUserRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  items: UserRole.values
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(_roleLabel(role)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedUserRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: isSubmitting ? null : AppTheme.primaryGradient,
                color: isSubmitting ? Colors.grey.shade400 : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final localContext = context;
                          final prenom = prenomController.text.trim();
                          final nom = nomController.text.trim();
                          final phone = phoneController.text.trim();

                          if (prenom.isEmpty || nom.isEmpty) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(content: Text('Veuillez remplir le prénom et le nom.')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final updatedUser = User(
                              id: user.id,
                              email: user.email,
                              nom: nom,
                              prenom: prenom,
                              phone: phone,
                              role: selectedUserRole,
                              estActif: user.estActif,
                              dateCreation: user.dateCreation,
                              dateModification: DateTime.now(),
                            );

                            await AuthProvider().updateUser(updatedUser);

                            if (!localContext.mounted) return;
                            Navigator.pop(localContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Utilisateur modifié avec succès'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!localContext.mounted) return;
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: ${e.toString()}'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      isSubmitting ? 'Modification...' : 'Modifier',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetUserPassword(BuildContext context, User user) {
    _showChangeOrResetPasswordDialog(context, user);
  }

  void _showChangeOrResetPasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController(text: '00000000');
    bool obscurePassword = true;
    bool mustChangeOnNextLogin = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modifier le mot de passe',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      user.nomComplet,
                      style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En tant qu\'administrateur, vous pouvez définir un mot de passe personnalisé ou réinitialiser à la valeur par défaut.',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nouveau mot de passe',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Minimum 6 caractères',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('Valeur standard (00000000)'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            passwordController.text = '00000000';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      setDialogState(() => mustChangeOnNextLogin = !mustChangeOnNextLogin);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: mustChangeOnNextLogin,
                            onChanged: (val) {
                              setDialogState(() => mustChangeOnNextLogin = val ?? true);
                            },
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Forcer le changement à la 1ère connexion',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'L\'utilisateur devra choisir un nouveau mot de passe dès qu\'il se connectera.',
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(isSubmitting ? 'Enregistrement...' : 'Appliquer le mot de passe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final newPass = passwordController.text.trim();
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le mot de passe doit contenir au moins 6 caractères.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await AuthProvider().adminChangeUserPassword(
                          user.id,
                          newPassword: newPass,
                          mustChangePassword: mustChangeOnNextLogin,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(dialogContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mot de passe de ${user.nomComplet} mis à jour avec succès.'),
                            backgroundColor: AppTheme.success,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
                            backgroundColor: AppTheme.error,
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

  void _confirmDeleteUser(BuildContext context, User user) {
    final currentUserId = AuthProvider().currentUser?.id;
    final currentUserEmail = AuthProvider().currentUser?.email.trim().toLowerCase();

    if (user.id == currentUserId || (currentUserEmail != null && user.email.trim().toLowerCase() == currentUserEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Action impossible : vous ne pouvez pas supprimer votre propre compte administrateur connecté.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Supprimer l\'utilisateur',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer définitivement le compte de :',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nomComplet,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.black87),
                  ),
                  Text(
                    '${user.email} • ${_roleLabel(user.role)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ Cette action est irréversible. Les inscriptions liées seront archivées dans le journal d\'audit.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFFD97706), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
            label: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final localContext = context;
              final email = user.email.trim().toLowerCase();
              if (email.isNotEmpty) {
                LocalDataService().recordDeletedDoc('user_emails', email);
              }
              await AuthProvider().deleteUser(user.id);
              if (!localContext.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(localContext).showSnackBar(
                  SnackBar(
                    content: Text('Le compte de ${user.nomComplet} a été supprimé avec succès.'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAssignRoleDialog(BuildContext context, User user) {
    UserRole selectedRole = user.role;

    final rolesInfo = <UserRole, Map<String, dynamic>>{
      UserRole.admin: {
        'label': 'Administrateur Principal',
        'desc': 'Accès total à tous les modules, gestion des utilisateurs, logs système et configurations.',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFF4F46E5),
      },
      UserRole.dg: {
        'label': 'Directeur Général (DG)',
        'desc': 'Supervision globale, validation finale des attestations, rapports stratégiques et financiers.',
        'icon': Icons.account_balance_rounded,
        'color': const Color(0xFF0284C7),
      },
      UserRole.daf: {
        'label': 'Directeur Admin & Financier (DAF)',
        'desc': 'Gestion de la comptabilité, encaissements, validation des soldes et des attestations.',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF0D9488),
      },
      UserRole.comptable: {
        'label': 'Comptable',
        'desc': 'Gestion de la caisse, encaissements, reçus de paiement et suivi des dettes apprenants.',
        'icon': Icons.point_of_sale_rounded,
        'color': const Color(0xFF059669),
      },
      UserRole.assistant: {
        'label': 'Assistant(e) / Secrétariat',
        'desc': 'Accueil, inscriptions, gestion des fiches apprenants et suivi des plannings.',
        'icon': Icons.support_agent_rounded,
        'color': const Color(0xFFD97706),
      },
      UserRole.it: {
        'label': 'Responsable Informatique (IT)',
        'desc': 'Maintenance système, journal d\'audit (logs), sécurité et gestion technique des comptes.',
        'icon': Icons.terminal_rounded,
        'color': const Color(0xFF7C3AED),
      },
      UserRole.formateur: {
        'label': 'Formateur',
        'desc': 'Espace formateur : consultation de ses modules assignés, planning et liste de ses apprenants.',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF2563EB),
      },
      UserRole.apprenant: {
        'label': 'Stagiaire / Apprenant',
        'desc': 'Espace apprenant : cours, progression, paiements, emploi du temps et attestations.',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF6B7280),
      },
    };

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Affecter un rôle système', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(user.nomComplet, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélectionnez le nouveau rôle et niveau d\'accès pour cet utilisateur :',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  ...UserRole.values.map((role) {
                    final info = rolesInfo[role] ?? {};
                    final isSelected = selectedRole == role;
                    final color = (info['color'] as Color?) ?? AppTheme.primary;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedRole = role),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Radio<UserRole>(
                                value: role,
                                // ignore: deprecated_member_use
                                groupValue: selectedRole,
                                activeColor: color,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => selectedRole = val);
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(info['icon'] as IconData? ?? Icons.person, color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      info['label']?.toString() ?? role.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? color : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      info['desc']?.toString() ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Enregistrer le rôle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final updatedUser = User(
                  id: user.id,
                  email: user.email,
                  nom: user.nom,
                  prenom: user.prenom,
                  phone: user.phone,
                  matricule: user.matricule,
                  role: selectedRole,
                  password: user.password,
                  photoUrl: user.photoUrl,
                  specialite: user.specialite,
                  sexe: user.sexe,
                  assignedFormations: user.assignedFormations,
                  estActif: user.estActif,
                  dateCreation: user.dateCreation,
                  dateModification: DateTime.now(),
                );

                await AuthProvider().updateUser(updatedUser);
                final adminUser = AuthProvider().currentUser;
                LocalDataService().logAction(
                  userNom: adminUser?.nomComplet ?? 'Administration',
                  userRole: adminUser?.role.name ?? 'admin',
                  action: 'Modification de rôle',
                  description: 'Rôle de ${user.nomComplet} modifié : ${_roleLabel(user.role)} -> ${_roleLabel(selectedRole)}',
                );

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Rôle de ${user.nomComplet} mis à jour : ${_roleLabel(selectedRole)}'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
