import 'package:flutter/material.dart';
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
        gradientColors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        primaryColor: Color(0xFF2563EB),
        isFormations: true,
      ),
      PoleItem(
        title: 'Prestations',
        description: 'Découvrez nos services professionnels sur-mesure',
        icon: Icons.handshake_rounded,
        gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
        primaryColor: Color(0xFFF97316),
        url: 'https://m-ntic.ml/prestations',
      ),
      PoleItem(
        title: 'e-Commerce',
        description: 'Parcourez notre catalogue complet de matériel et logiciels',
        icon: Icons.shopping_cart_rounded,
        gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        primaryColor: Color(0xFF6366F1),
        url: 'https://m-ntic.ml/ecommerce',
      ),
      PoleItem(
        title: 'Incubator',
        description: 'Accompagnement et accélération de startups et projets innovants',
        icon: Icons.lightbulb_rounded,
        gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
        primaryColor: Color(0xFF10B981),
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
        child: Center(
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
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

  void _onTap(BuildContext context) async {
    if (widget.pole.isFormations) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SignInPage(poleName: 'Formations'),
        ),
      );
    } else if (widget.pole.url != null && widget.pole.url!.isNotEmpty) {
      final uri = Uri.parse(widget.pole.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showInfoDialog(context);
      }
    } else {
      _showInfoDialog(context);
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: widget.pole.gradientColors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.pole.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              widget.pole.title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          widget.pole.description,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Fermer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
