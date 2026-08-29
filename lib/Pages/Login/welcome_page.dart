import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Pages/Login/sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

class PoleItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final Color primaryColor;
  final String? url;
  final bool isFormations;

  const PoleItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.primaryColor,
    this.url,
    this.isFormations = false,
  });

  static List<PoleItem> getPoles() {
    return const [
      PoleItem(
        title: 'Formations',
        description: 'Explorez nos programmes de formation en ligne & présentiel',
        icon: Icons.school_rounded,
        gradientColors: [AppTheme.primary, AppTheme.primaryDark],
        primaryColor: AppTheme.primary,
        isFormations: true,
      ),
      PoleItem(
        title: 'Prestations',
        description: 'Découvrez nos services professionnels sur-mesure',
        icon: Icons.handshake_rounded,
        gradientColors: [AppTheme.orangeAccent, AppTheme.warningDark],
        primaryColor: AppTheme.orangeAccent,
        url: 'https://m-ntic.ml/prestations',
      ),
      PoleItem(
        title: 'e-Commerce',
        description: 'Parcourez notre catalogue complet de matériel et logiciels',
        icon: Icons.shopping_cart_rounded,
        gradientColors: [AppTheme.primaryLight, AppTheme.primary],
        primaryColor: AppTheme.primary,
        url: 'https://malintic.com',
      ),
      PoleItem(
        title: 'Incubator',
        description: 'Accompagnement et accélération de startups et projets innovants',
        icon: Icons.lightbulb_rounded,
        gradientColors: [AppTheme.success, AppTheme.successDark],
        primaryColor: AppTheme.success,
        url: 'https://m-ntic.ml/incubator',
      ),
    ];
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -130,
              left: -100,
              child: _DecorativeOrb(
                size: 310,
                color: AppTheme.logoRed.withValues(alpha: isDark ? 0.08 : 0.05),
              ),
            ),
            Positioned(
              bottom: -170,
              right: -100,
              child: _DecorativeOrb(
                size: 350,
                color: AppTheme.primary.withValues(alpha: isDark ? 0.1 : 0.06),
              ),
            ),
            Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64 : 20,
              vertical: isDesktop ? 48 : 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isDesktop
                  ? _buildDesktopLayout(context, isDark)
                  : _buildMobileLayout(context, isDark),
            ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Big Circular Logo & Heading
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildBrandPill(isDark),
              const SizedBox(height: 20),
              _buildLogoCircle(260, isDark),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'L’univers des technologies — 4 pôles à votre service',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.35,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),

        // Right Column: 4 Rounded Cards
        Expanded(
          flex: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PoleItem.getPoles()
                .map((pole) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _PoleCard(pole: pole, isDark: isDark),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildBrandPill(isDark),
        const SizedBox(height: 18),
        _buildLogoCircle(170, isDark),
        const SizedBox(height: 24),
        Text(
          'L’univers des technologies — 4 pôles à votre service',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.35,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 32),
        ...PoleItem.getPoles().map((pole) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PoleCard(pole: pole, isDark: isDark),
            )),
      ],
    );
  }

  Widget _buildBrandPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.16),
        ),
      ),
      child: Text(
        'M@LI-NTIC  •  UNIVERS NUMÉRIQUE',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? Colors.white : AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildLogoCircle(double diameter, bool isDark) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(diameter * 0.14),
      child: Center(
        child: Image.asset(
          'images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'images/Malintic.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                'M@LI-NTIC',
                style: GoogleFonts.poppins(
                  fontSize: diameter * 0.12,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorativeOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _PoleCard extends StatefulWidget {
  final PoleItem pole;
  final bool isDark;

  const _PoleCard({required this.pole, required this.isDark});

  @override
  State<_PoleCard> createState() => _PoleCardState();
}

class _PoleCardState extends State<_PoleCard> {
  bool _isHovered = false;

  void _onTap(BuildContext context) {
    if (widget.pole.isFormations) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SignInPage(poleName: 'Formations'),
        ),
      );
    } else {
      _showComingSoonDialog(context, widget.pole);
    }
  }

  void _showComingSoonDialog(BuildContext context, PoleItem pole) {
    final isEcommerce = pole.title == 'e-Commerce';
    final isServices = pole.title == 'Prestations';
    final isDark = widget.isDark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String detailMessage = '';
    String poleSubtitle = '';
    if (pole.title == 'Prestations') {
      poleSubtitle = 'Audit, Conseil & Solutions Numériques';
      detailMessage =
          'Découvrez notre catalogue de prestations pour accompagner la transformation numérique, la sécurité et la performance de votre organisation.\n\n'
          'L’ouverture de ce pôle est en cours et sera bientôt accessible depuis l’interface de formation.';
    } else if (pole.title == 'e-Commerce') {
      poleSubtitle = 'Équipements, Logiciels & Accessoires';
      detailMessage =
          'Notre boutique e-commerce est accessible dès maintenant sur malintic.com. Découvrez nos équipements informatiques, ordinateurs, licences et accessoires.\n\n'
          'Le parcours de la plateforme est en cours de finalisation et la redirection vers les formations reste activée pour le moment.';
    } else if (pole.title == 'Incubator') {
      poleSubtitle = 'Accompagnement & Accélération de Startups';
      detailMessage =
          'L’espace Incubateur & Accélérateur M@LI-NTIC structure ses prochains programmes d’immersion, mentorat technologique et accélération pour les porteurs de projets innovants.\n\n'
          'Les inscriptions pour la prochaine session seront ouvertes sous peu. En attendant, l’accès aux formations reste le parcours principal.';
    } else {
      poleSubtitle = 'Module en cours de finalisation';
      detailMessage =
          'Ce service est actuellement en cours de finalisation par nos équipes d’ingénierie et sera déployé prochainement sur la plateforme.';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
          child: SingleChildScrollView(
            child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Badge and Close Icon
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: pole.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: pole.gradientColors.first.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(pole.icon, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pole.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            poleSubtitle,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: pole.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: subtitleColor),
                      splashRadius: 20,
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pole.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: pole.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pole.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Déploiement en cours • Bientôt disponible',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pole.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Professional Message Body
                Text(
                  detailMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    height: 1.55,
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary CTA: e-commerce website, service quote, or Formations portal.
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(
                        isEcommerce
                            ? Icons.open_in_new_rounded
                            : isServices
                                ? Icons.request_quote_rounded
                                : Icons.school_rounded,
                        size: 20,
                      ),
                      label: Text(
                        'Accéder aux Formations (Actif)',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignInPage(poleName: 'Formations'),
                          ),
                        );
                      },
                    ),
                    if (!isServices) const SizedBox(height: 10),

                    // Secondary CTA: Contact / Assistance
                    if (!isServices) OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent_rounded, size: 18),
                      label: Text(
                        'Contacter la Direction / Support',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final uri = Uri.parse('mailto:contact@m-ntic.ml?subject=Demande%20d%27information%20-%20P%C3%B4le%20${Uri.encodeComponent(pole.title)}');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pole = widget.pole;
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final descColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? (_isHovered ? pole.primaryColor : const Color(0xFF334155))
        : (_isHovered ? pole.primaryColor.withValues(alpha: 0.5) : const Color(0xFFF1F5F9));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered ? Matrix4.translationValues(4, 0, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: _isHovered ? 1.5 : 1.0),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? pole.primaryColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: _isHovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: () => _onTap(context),
            borderRadius: BorderRadius.circular(22),
            hoverColor: pole.primaryColor.withValues(alpha: 0.02),
            splashColor: pole.primaryColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Row(
                children: [
                  // Gradient Icon Box
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: pole.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: pole.gradientColors.first.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        pole.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pole.title,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pole.description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: descColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Trailing Chevron
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: _isHovered ? Matrix4.translationValues(3, 0, 0) : Matrix4.identity(),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: pole.primaryColor,
                      size: 26,
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
}
