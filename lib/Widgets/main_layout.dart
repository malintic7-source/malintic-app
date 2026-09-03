import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Pages/Screens/notifications.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/notifications_services.dart';
import 'package:gestion_formations/Widgets/first_login_password_dialog.dart';
import 'package:gestion_formations/config/theme.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final int? selectedIndex;
  final Function(int)? onNavigationChanged;
  final List<NavigationItem> navigationItems;
  final User? user;
  final bool showPageHeader;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    this.selectedIndex = 0,
    this.onNavigationChanged,
    required this.navigationItems,
    this.user,
    this.showPageHeader = false,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _notificationAnimationController;
  late AnimationController _announcementAnimationController;
  static const _announcements = [
    'Bienvenue sur M@LI-NTIC — votre espace numérique de formation.',
    'Découvrez nos nouvelles formations et développez vos compétences.',
    'Besoin d’aide ? Notre équipe reste disponible pour vous accompagner.',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex ?? 0;
    _notificationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    _announcementAnimationController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = widget.user ?? AuthProvider().currentUser;
      if (user != null && user.doitChangerMotDePasse && mounted) {
        FirstLoginPasswordDialog.showIfNeeded(context, user);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != null &&
        widget.selectedIndex != _selectedIndex) {
      setState(() => _selectedIndex = widget.selectedIndex!);
    }
    final user = widget.user ?? AuthProvider().currentUser;
    if (user != null && user.doitChangerMotDePasse && mounted) {
      FirstLoginPasswordDialog.showIfNeeded(context, user);
    }
  }

  @override
  void dispose() {
    _notificationAnimationController.dispose();
    _announcementAnimationController.dispose();
    super.dispose();
  }

  // Bottom nav items for mobile: 3 priority tabs + drawer "Plus"
  static const _adminBottomNavIndices = [
    0,
    1,
    3,
  ]; // Dashboard, Formations, Inscriptions
  static const _adminBottomNavLabels = [
    'Accueil',
    'Formations',
    'Inscriptions',
  ];
  static const _adminBottomNavIcons = [
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.receipt_long_rounded,
  ];

  int? _getBottomNavSelected() {
    final idx = _adminBottomNavIndices.indexOf(_selectedIndex);
    return idx >= 0 ? idx : null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isSmallTablet = size.width >= 600 && size.width < 768;
    final isMobileOrSmall = isMobile || isSmallTablet;
    final isTablet = size.width >= 768 && size.width < 1100;
    final isAdminRole = widget.navigationItems.length >= 8;
    final useBottomNav = isMobileOrSmall && isAdminRole;
    final bottomNavSelected = _getBottomNavSelected();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: null,
      drawer: isMobileOrSmall ? _buildDrawer(context) : null,
      bottomNavigationBar: useBottomNav
          ? _buildBottomNav(context, bottomNavSelected)
          : null,
      body: SafeArea(
        bottom: !useBottomNav,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobileOrSmall) _buildSidebar(context, isTablet: isTablet),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isMobile
                      ? 8
                      : isSmallTablet
                      ? 10
                      : 16,
                  right: isMobile
                      ? 8
                      : isSmallTablet
                      ? 10
                      : 16,
                  top: isMobile ? 8 : 12,
                  bottom: isMobile ? 4 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnnouncementTicker(),
                    if (isMobileOrSmall) _buildMobileTopBar(context, isMobile),
                    if (widget.showPageHeader)
                      _buildPageHeader(isMobileOrSmall),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMobile
                              ? Colors.transparent
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(
                            isMobile ? 12 : 24,
                          ),
                          border: isMobile
                              ? null
                              : Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.5,
                                ),
                          boxShadow: isMobile ? null : AppTheme.cardShadow,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementTicker() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.heroShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final message = _announcements.join('   •   ');
                  final textStyle = GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  );
                  return AnimatedBuilder(
                    animation: _announcementAnimationController,
                    builder: (context, child) {
                      final distance = constraints.maxWidth;
                      return Transform.translate(
                        offset: Offset(
                          distance -
                              (distance *
                                  2 *
                                  _announcementAnimationController.value),
                          0,
                        ),
                        child: SizedBox(
                          width: distance * 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message,
                                maxLines: 1,
                                softWrap: false,
                                style: textStyle,
                              ),
                              const SizedBox(width: 56),
                              Text(
                                message,
                                maxLines: 1,
                                softWrap: false,
                                style: textStyle,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar(BuildContext context, bool isMobile) {
    return Builder(
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildNotificationBell(context),
            const SizedBox(width: 8),
            // Logo mini
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: AppTheme.softShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset('images/logo.png', fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int? selected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              ...List.generate(_adminBottomNavLabels.length, (i) {
                final isSelected = selected == i;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final pageIdx = _adminBottomNavIndices[i];
                      setState(() => _selectedIndex = pageIdx);
                      widget.onNavigationChanged?.call(pageIdx);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : null,
                          child: Icon(
                            _adminBottomNavIcons[i],
                            size: 20,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _adminBottomNavLabels[i],
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Builder(
                builder: (ctx) => Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          decoration: selected == null
                              ? BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : null,
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: selected == null
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Plus',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: selected == null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected == null
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final db = LocalDataService();
    final notifService = NotificationsService();

    return Drawer(
      backgroundColor: AppTheme.surface,
      child: Column(
        children: [
          // 1. Header Officiel M@LI-NTIC avec Logo et Profil Harmonieux
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ligne Supérieure : Logo M@LI-NTIC + Badge Rôle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'images/logo.png',
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.user?.role.toString().split('.').last.toUpperCase() ?? 'ROLE',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 12),

                // Ligne Utilisateur : Avatar + Nom + Email
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            child: Text(
                              widget.user?.nomComplet.isNotEmpty == true
                                  ? widget.user!.nomComplet[0].toUpperCase()
                                  : 'U',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.user?.nomComplet ?? 'Utilisateur',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.user?.email.isNotEmpty == true) ...[
                            const SizedBox(height: 1),
                            Text(
                              widget.user!.email,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Liste des Éléments de Navigation (Rendu Direct et Fiable)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: widget.navigationItems.length,
              itemBuilder: (context, index) {
                final item = widget.navigationItems[index];
                final isSelected = _selectedIndex == index;

                Widget? trailingWidget;
                if (item.label.toLowerCase().contains('inscription')) {
                  trailingWidget = StreamBuilder<List<Inscription>>(
                    stream: db.watchInscriptions(),
                    initialData: db.getInscriptions(),
                    builder: (context, snapshot) {
                      final count = (snapshot.data ?? db.getInscriptions())
                          .where((i) => i.status == InscriptionStatus.enAttente)
                          .length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  );
                } else if (item.label.toLowerCase().contains('notification')) {
                  trailingWidget = StreamBuilder<int>(
                    stream: notifService.watchUnreadCountForUser(
                      userId: widget.user?.id ?? '',
                      userEmail: widget.user?.email ?? '',
                      userRole: widget.user?.role.name ?? '',
                    ),
                    initialData: 0,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? const Border(
                              left: BorderSide(color: AppTheme.primary, width: 3.5),
                            )
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        leading: Icon(
                          item.icon,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                        title: Text(
                          item.label,
                          style: GoogleFonts.poppins(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primary
                                : const Color(0xFF1E293B),
                            fontSize: 13,
                          ),
                        ),
                        trailing: trailingWidget,
                        selected: isSelected,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onNavigationChanged?.call(index);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Pied du Drawer avec Déconnexion
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              children: [
                Material(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await AuthProvider().logout();
                      if (!mounted) return;
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const WelcomePage(),
                        ),
                        (route) => false,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.error,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Déconnexion',
                            style: GoogleFonts.poppins(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'v2.5 Pro',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(bool isMobile) {
    final description = 'Interface claire et structurée pour chaque section.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            _buildNotificationBell(context),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: NotificationsService().watchUnreadCountForUser(
        userId: widget.user!.id,
        userEmail: widget.user!.email,
        userRole: widget.user!.role.toString(),
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: Text(
                            'Centre de notifications',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          backgroundColor: AppTheme.surface,
                          elevation: 0,
                          iconTheme: const IconThemeData(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        body: NotificationsPage(user: widget.user!),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: unreadCount > 0
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    unreadCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: unreadCount > 0 ? AppTheme.primary : Colors.black54,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isTablet}) {
    final width = MediaQuery.of(context).size.width;
    final sidebarWidth = width < 900
        ? 72.0
        : width < 1150
        ? 80.0
        : 230.0;
    final showLabel = sidebarWidth >= 180;
    final showUserInfo = sidebarWidth >= 180;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: Column(
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: showUserInfo ? 160 : 90),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: showLabel ? 100 : 54,
                  height: showLabel ? 100 : 54,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(showLabel ? 16 : 12),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(showLabel ? 10 : 8),
                    child: Image.asset('images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                if (showUserInfo) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.user?.role
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase() ??
                          'ROLE',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: widget.navigationItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemBuilder: (context, index) {
                final item = widget.navigationItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Tooltip(
                    message: item.label,
                    child: Ink(
                      decoration: isSelected
                          ? BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      child: ListTile(
                        dense: true,
                        contentPadding: showLabel
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              )
                            : const EdgeInsets.symmetric(horizontal: 8),
                        minLeadingWidth: 0,
                        leading: Icon(
                          item.icon,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.8),
                          size: showLabel ? 18 : 22,
                        ),
                        title: showLabel
                            ? Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        selected: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          widget.onNavigationChanged?.call(index);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Tooltip(
              message: 'Déconnexion',
              child: Material(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    await AuthProvider().logout();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const WelcomePage(),
                      ),
                      (route) => false,
                    );
                  },
                  child: ListTile(
                    dense: true,
                    contentPadding: showLabel
                        ? const EdgeInsets.symmetric(horizontal: 10)
                        : const EdgeInsets.symmetric(horizontal: 8),
                    minLeadingWidth: 0,
                    leading: Icon(
                      Icons.logout_rounded,
                      color: AppTheme.error,
                      size: showLabel ? 20 : 22,
                    ),
                    title: showLabel
                        ? Text(
                            'Déconnexion',
                            style: GoogleFonts.poppins(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

class NavigationItem {
  final String label;
  final IconData icon;

  NavigationItem({required this.label, required this.icon});
}
