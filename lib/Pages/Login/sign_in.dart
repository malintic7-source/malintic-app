import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Pages/home_screen.dart';
import 'package:gestion_formations/Services/auth_provider.dart';

class SignInPage extends StatefulWidget {
  final String poleName;
  const SignInPage({super.key, this.poleName = 'Formations'});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomePage()),
              );
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          tooltip: 'Retour',
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomePage()),
              );
            },
            icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
            tooltip: 'Fermer',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -100,
              top: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -80,
              bottom: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: AppTheme.indigoAccent.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isMobile
                      ? _buildMobileLayout()
                      : _buildDesktopLayout(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(height: 20),
        Text(
          'Bienvenue sur l’espace ${widget.poleName}',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Connectez-vous pour accéder à vos outils et services.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _buildForm(isMobile: true),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 24),
              Text(
                'Bienvenue sur l’espace ${widget.poleName}',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour accéder à vos ${widget.poleName.toLowerCase()} et outils de gestion.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(
          child: _buildForm(isMobile: false),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth < 600 ? 145.0 : 170.0;

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            'images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isMobile}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Connexion',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Entrez vos identifiants pour accéder à votre compte.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez contacter votre administrateur pour réinitialiser votre mot de passe.'),
                      backgroundColor: AppTheme.info,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Mot de passe oublié ?',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: const InputDecoration(
        labelText: 'Nom d\'utilisateur ou Email',
        hintText: 'admin@mntic.ml',
        prefixIcon: Icon(
          Icons.person_outline_rounded,
          size: 20,
        ),
      ),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
        hintText: '••••••••',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppTheme.textMuted,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      obscureText: _obscurePassword,
    );
  }

  Widget _buildLoginButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: AppTheme.heroGradient,
        boxShadow: AppTheme.heroShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _handleLogin,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      'Se connecter',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text
        .replaceAll('`', '')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthProvider().loginWithEmail(email, password);

      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identifiants invalides.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'Identifiants invalides.'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Backward compatibility alias
typedef SignIn = SignInPage;


