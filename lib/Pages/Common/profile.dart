import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/config/theme.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  bool isEditing = false;
  late User currentUser;
  late TextEditingController nomController;
  late TextEditingController prenomController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    nomController = TextEditingController(text: currentUser.nom);
    prenomController = TextEditingController(text: currentUser.prenom);
    phoneController = TextEditingController(text: currentUser.phone);
    emailController = TextEditingController(text: currentUser.email);
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    nomController.dispose();
    prenomController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 20,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 960),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isEditing) _buildProfileHeader(),
                  const SizedBox(height: 28),
                  if (!isEditing) _buildProfileCard() else _buildEditCard(),
                  const SizedBox(height: 28),
                  if (!isEditing) _buildSettingsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mon Profil',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Gérez vos informations',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final isVeryCompact = screenWidth < 480;

    if (isVeryCompact) {
      // Very compact horizontal summary for small mobile screens
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Text(
                  currentUser.nomComplet.isNotEmpty
                      ? currentUser.nomComplet[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.nomComplet,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentUser.role
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: currentUser.estActif
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentUser.estActif ? 'Actif' : 'Bloqué',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: currentUser.estActif
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 18, color: AppTheme.primary),
              onPressed: () => setState(() => isEditing = true),
              tooltip: 'Modifier',
            ),
          ],
        ),
      );
    }

    // Default compact card (for larger screens) — keep earlier compact layout
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 18,
        vertical: isCompact ? 14 : 18,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircleAvatar(
              radius: isCompact ? 36 : 40,
              backgroundColor: Colors.white,
              child: Text(
                currentUser.nomComplet.isNotEmpty
                    ? currentUser.nomComplet[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 28 : 30,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            currentUser.nomComplet,
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: AppTheme.primary,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      currentUser.role.toString().split('.').last.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentUser.estActif
                      ? Color(0xFF10B981).withValues(alpha: 0.1)
                      : Color(0xFFEF4444).withValues(alpha: 0.1),
                  border: Border.all(
                    color: currentUser.estActif
                        ? Color(0xFF10B981).withValues(alpha: 0.2)
                        : Color(0xFFEF4444).withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentUser.estActif
                          ? Icons.check_circle_rounded
                          : Icons.block_rounded,
                      color: currentUser.estActif
                          ? Color(0xFF10B981)
                          : Color(0xFFEF4444),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      currentUser.estActif ? 'Actif' : 'Bloqué',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: currentUser.estActif
                            ? Color(0xFF10B981)
                            : Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
            height: 1,
          ),
          SizedBox(height: 12),
          _buildInfoRow(Icons.mail_rounded, 'Email', currentUser.email),
          SizedBox(height: 12),
          _buildInfoRow(
            Icons.phone_rounded,
            'Téléphone',
            currentUser.phone.isEmpty ? 'Non renseigné' : currentUser.phone,
          ),
          SizedBox(height: 10),
          _buildInfoRow(
            Icons.calendar_month_rounded,
            'Inscrit',
            '${currentUser.dateCreation.day}/${currentUser.dateCreation.month}/${currentUser.dateCreation.year}',
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => isEditing = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Modifier le profil',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      children: [
        _buildSettingButton(
          icon: Icons.lock_rounded,
          label: 'Changer le mot de passe',
          color: Color(0xFFEF4444),
          onTap: _showChangePasswordDialog,
        ),
      ],
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations Personnelles',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 16),
        _buildFormField('Prénom', prenomController),
        SizedBox(height: 14),
        _buildFormField('Nom', nomController),
        SizedBox(height: 14),
        _buildFormField('Email', emailController, enabled: false),
        SizedBox(height: 14),
        _buildFormField('Téléphone', phoneController),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => isEditing = false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.success,
                      AppTheme.success.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      try {
                        final updatedUser = await AuthProvider()
                            .updateCurrentUser(
                              nom: nomController.text.trim(),
                              prenom: prenomController.text.trim(),
                              phone: phoneController.text.trim(),
                            );
                        if (!mounted) return;
                        setState(() {
                          currentUser = updatedUser!;
                          isEditing = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Profil mis à jour')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('❌ Erreur: $e')));
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sauvegarder',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.surfaceVariant),
            ),
            filled: !enabled,
            fillColor: !enabled
                ? AppTheme.surfaceVariant.withValues(alpha: 0.3)
                : Colors.white,
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showOldPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Changer le mot de passe',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sécurisez votre compte',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22),
                _buildPasswordField(
                  'Ancien mot de passe',
                  Icons.lock_outline_rounded,
                  oldPasswordController,
                  showOldPassword,
                  (val) => setDialogState(() => showOldPassword = val),
                ),
                SizedBox(height: 12),
                _buildPasswordField(
                  'Nouveau mot de passe',
                  Icons.lock_outline_rounded,
                  newPasswordController,
                  showNewPassword,
                  (val) => setDialogState(() => showNewPassword = val),
                ),
                SizedBox(height: 12),
                _buildPasswordField(
                  'Confirmer',
                  Icons.lock_outline_rounded,
                  confirmPasswordController,
                  showConfirmPassword,
                  (val) => setDialogState(() => showConfirmPassword = val),
                ),
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final localContext = context;
                          if (oldPasswordController.text.isEmpty) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Veuillez saisir votre ancien mot de passe',
                                ),
                              ),
                            );
                            return;
                          }
                          if (newPasswordController.text.length < 8) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le nouveau mot de passe doit contenir au moins 8 caractères',
                                ),
                              ),
                            );
                            return;
                          }
                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Les mots de passe ne correspondent pas',
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            await AuthProvider().changePassword(
                              currentPassword: oldPasswordController.text,
                              newPassword: newPasswordController.text,
                            );
                            if (!localContext.mounted) return;
                            Navigator.pop(localContext);
                            await showDialog<void>(
                              context: localContext,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Mot de passe mis à jour'),
                                content: const Text(
                                  'Votre nouveau mot de passe est enregistré pour tous vos appareils. '
                                  'Pour appliquer la modification, vous allez être déconnecté. '
                                  'Reconnectez-vous avec ce nouveau mot de passe.',
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('Se déconnecter'),
                                  ),
                                ],
                              ),
                            );
                            if (!localContext.mounted) return;
                            await AuthProvider().logout();
                            if (!localContext.mounted) return;
                            Navigator.of(
                              localContext,
                              rootNavigator: true,
                            ).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const WelcomePage(),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            if (!localContext.mounted) return;
                            ScaffoldMessenger.of(
                              localContext,
                            ).showSnackBar(SnackBar(content: Text('❌ $e')));
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Mettre à jour',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    IconData icon,
    TextEditingController controller,
    bool showPassword,
    Function(bool) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                icon,
                color: AppTheme.primary.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: AppTheme.primary.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () => onToggle(!showPassword),
            ),
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }
}
