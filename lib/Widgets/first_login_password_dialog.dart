import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/config/theme.dart';

class FirstLoginPasswordDialog extends StatefulWidget {
  final User user;
  final VoidCallback? onPasswordSet;

  const FirstLoginPasswordDialog({
    super.key,
    required this.user,
    this.onPasswordSet,
  });

  static bool _isShowing = false;

  static Future<void> showIfNeeded(BuildContext context, User user, {VoidCallback? onPasswordSet}) async {
    if (!user.doitChangerMotDePasse || _isShowing) return;
    _isShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FirstLoginPasswordDialog(
          user: user,
          onPasswordSet: onPasswordSet,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<FirstLoginPasswordDialog> createState() => _FirstLoginPasswordDialogState();
}

class _FirstLoginPasswordDialogState extends State<FirstLoginPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_newPasswordController.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_newPasswordController.text);

  Widget _buildFormationThumbnail(Formation formation, {double size = 32}) {
    final imageUrl = formation.imageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64Part = imageUrl.split(',').last;
          final bytes = base64Decode(base64Part);
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildFallbackIcon(size),
            ),
          );
        } catch (_) {}
      } else if (imageUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildFallbackIcon(size),
          ),
        );
      }
    }
    return _buildFallbackIcon(size);
  }

  Widget _buildFallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.school_rounded, color: AppTheme.primary, size: size * 0.55),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthProvider().changePassword(
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      widget.onPasswordSet?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Mot de passe enregistré ! Accès accordé.',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _logout() async {
    await AuthProvider().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    final allFormations = LocalDataService().getFormations();
    final assignedIds = widget.user.assignedFormations
        .map((a) => a['formationId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final userFormations = allFormations.where((f) => assignedIds.contains(f.id)).toList();

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: cardBg,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Padlock Badge
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary,
                            AppTheme.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Première connexion',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'Bienvenue ${widget.user.prenom} ${widget.user.nom} ! Pour sécuriser votre compte, veuillez définir votre mot de passe personnel.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assigned Formations preview if present
                  if (userFormations.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Vos formations assignées :',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: userFormations.map((formation) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildFormationThumbnail(formation, size: 22),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 160),
                                      child: Text(
                                        formation.titre,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Nouveau mot de passe
                  Text(
                    'Nouveau mot de passe',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Minimum 8 caractères',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Veuillez saisir un mot de passe';
                      if (val.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Requirements indicators
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildCheckBadge('8+ caractères', _hasMinLength, isDark),
                      _buildCheckBadge('Une lettre', _hasLetter, isDark),
                      _buildCheckBadge('Un chiffre', _hasDigit, isDark),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Confirmation
                  Text(
                    'Confirmer le mot de passe',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Répétez votre mot de passe',
                      prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Veuillez confirmer votre mot de passe';
                      if (val != _newPasswordController.text) return 'Les mots de passe ne correspondent pas';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Enregistrer et accéder à mon compte',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Logout option
                  TextButton.icon(
                    onPressed: _isLoading ? null : _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.grey),
                    label: Text(
                      'Se déconnecter',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckBadge(String label, bool isOk, bool isDark) {
    final color = isOk ? AppTheme.success : (isDark ? Colors.white38 : Colors.black38);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOk ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isOk ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
