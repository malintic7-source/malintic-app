import 'package:flutter/material.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Pages/Admin/dashboard.dart';
import 'package:gestion_formations/Pages/Admin/formations.dart';
import 'package:gestion_formations/Pages/Admin/formateurs.dart';
import 'package:gestion_formations/Pages/Admin/inscriptions.dart';
import 'package:gestion_formations/Pages/Admin/paiements.dart';
import 'package:gestion_formations/Pages/Admin/apprenants.dart';
import 'package:gestion_formations/Pages/Admin/users.dart';
import 'package:gestion_formations/Pages/Admin/planning.dart';
import 'package:gestion_formations/Pages/Admin/attestations_cartes.dart';
import 'package:gestion_formations/Pages/Admin/audit_logs.dart';
import 'package:gestion_formations/Pages/Common/profile.dart';
import 'package:gestion_formations/Pages/Formateur/dashboard.dart';
import 'package:gestion_formations/Pages/Formateur/apprenants.dart';
import 'package:gestion_formations/Pages/Formateur/schedule.dart';
import 'package:gestion_formations/Pages/Screens/notifications.dart';
import 'package:gestion_formations/Pages/Screens/payments.dart';
import 'package:gestion_formations/Pages/Student/dashboard.dart';
import 'package:gestion_formations/Pages/Student/formations.dart';
import 'package:gestion_formations/Pages/Student/schedule.dart';
import 'package:gestion_formations/Widgets/main_layout.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  List<NavigationItem> get navigationItems => _getNavigationItems();

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: _getPageTitle(),
      selectedIndex: _selectedIndex,
      navigationItems: navigationItems,
      user: widget.user,
      onNavigationChanged: (index) {
        setState(() => _selectedIndex = index);
      },
      child: _buildSelectedPage(),
    );
  }

  List<NavigationItem> _getNavigationItems() {
    switch (widget.user.role) {
      case UserRole.admin:
        return [
          NavigationItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
          NavigationItem(label: 'Formations', icon: Icons.school_rounded),
          NavigationItem(label: 'Formateurs', icon: Icons.people_alt_rounded),
          NavigationItem(label: 'Inscriptions', icon: Icons.receipt_long_rounded),
          NavigationItem(label: 'Stagiaires / Apprenants', icon: Icons.badge_rounded),
          NavigationItem(label: 'Paiements', icon: Icons.payments_rounded),
          NavigationItem(label: 'Utilisateurs & Rôles', icon: Icons.manage_accounts_rounded),
          NavigationItem(label: 'Planning', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Attestations & Diplômes', icon: Icons.workspace_premium_rounded),
          NavigationItem(label: 'Logs & Audit', icon: Icons.history_edu_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.dg:
        return [
          NavigationItem(label: 'Dashboard Direction', icon: Icons.analytics_rounded),
          NavigationItem(label: 'Formations', icon: Icons.school_rounded),
          NavigationItem(label: 'Formateurs', icon: Icons.people_alt_rounded),
          NavigationItem(label: 'Inscriptions', icon: Icons.receipt_long_rounded),
          NavigationItem(label: 'Stagiaires / Apprenants', icon: Icons.badge_rounded),
          NavigationItem(label: 'Paiements & Caisse', icon: Icons.payments_rounded),
          NavigationItem(label: 'Utilisateurs & Rôles', icon: Icons.manage_accounts_rounded),
          NavigationItem(label: 'Planning', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Attestations & Diplômes', icon: Icons.workspace_premium_rounded),
          NavigationItem(label: 'Logs & Audit', icon: Icons.history_edu_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.daf:
      case UserRole.comptable:
        return [
          NavigationItem(label: 'Dashboard Financier', icon: Icons.account_balance_wallet_rounded),
          NavigationItem(label: 'Inscriptions', icon: Icons.receipt_long_rounded),
          NavigationItem(label: 'Paiements & Encaissements', icon: Icons.payments_rounded),
          NavigationItem(label: 'Stagiaires / Apprenants', icon: Icons.badge_rounded),
          NavigationItem(label: 'Attestations & Soldes', icon: Icons.workspace_premium_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.assistant:
        return [
          NavigationItem(label: 'Dashboard Accueil', icon: Icons.dashboard_rounded),
          NavigationItem(label: 'Inscriptions', icon: Icons.receipt_long_rounded),
          NavigationItem(label: 'Stagiaires / Apprenants', icon: Icons.badge_rounded),
          NavigationItem(label: 'Formations', icon: Icons.school_rounded),
          NavigationItem(label: 'Planning', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.it:
        return [
          NavigationItem(label: 'Dashboard Système', icon: Icons.terminal_rounded),
          NavigationItem(label: 'Utilisateurs & Rôles', icon: Icons.manage_accounts_rounded),
          NavigationItem(label: 'Formations', icon: Icons.school_rounded),
          NavigationItem(label: 'Logs & Audit', icon: Icons.history_edu_rounded),
          NavigationItem(label: 'Planning', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.formateur:
        return [
          NavigationItem(label: 'Dashboard Formateur', icon: Icons.dashboard_rounded),
          NavigationItem(label: 'Mes Apprenants', icon: Icons.people_alt_rounded),
          NavigationItem(label: 'Mon Emploi du temps', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];

      case UserRole.apprenant:
        return [
          NavigationItem(label: 'Mon Espace', icon: Icons.dashboard_rounded),
          NavigationItem(label: 'Mes Formations', icon: Icons.school_rounded),
          NavigationItem(label: 'Mon Emploi du temps', icon: Icons.calendar_month_rounded),
          NavigationItem(label: 'Mes Paiements', icon: Icons.payment_rounded),
          NavigationItem(label: 'Notifications', icon: Icons.notifications_rounded),
          NavigationItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ];
    }
  }

  String _getPageTitle() {
    if (_selectedIndex >= 0 && _selectedIndex < navigationItems.length) {
      return navigationItems[_selectedIndex].label;
    }
    return 'M@LI-NTIC';
  }

  Widget _buildSelectedPage() {
    if (_selectedIndex < 0 || _selectedIndex >= navigationItems.length) {
      return const SizedBox();
    }
    final label = navigationItems[_selectedIndex].label;

    switch (widget.user.role) {
      case UserRole.admin:
        return _buildAdminPageByLabel(label);

      case UserRole.dg:
        return _buildDgPageByLabel(label);

      case UserRole.daf:
      case UserRole.comptable:
        return _buildAccountingPageByLabel(label);

      case UserRole.assistant:
        return _buildAssistantPageByLabel(label);

      case UserRole.it:
        return _buildItPageByLabel(label);

      case UserRole.formateur:
        return _buildFormateurPage();

      case UserRole.apprenant:
        return _buildApprenantPage();
    }
  }

  Widget _buildAdminPageByLabel(String label) {
    switch (label) {
      case 'Dashboard':
        return AdminDashboard(
          user: widget.user,
          onNavigateTab: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index.clamp(0, navigationItems.length - 1));
          },
        );
      case 'Formations':
        return const AdminFormations();
      case 'Formateurs':
        return const AdminFormateurs();
      case 'Inscriptions':
        return const AdminInscriptions();
      case 'Stagiaires / Apprenants':
        return const AdminApprenants();
      case 'Paiements':
      case 'Paiements & Caisse':
        return const AdminPaiements();
      case 'Utilisateurs & Rôles':
        return const AdminUsers();
      case 'Planning':
        return const AdminPlanning();
      case 'Attestations & Diplômes':
        return AdminAttestationsCartes(user: widget.user);
      case 'Logs & Audit':
        return const AdminAuditLogs();
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildDgPageByLabel(String label) {
    switch (label) {
      case 'Dashboard Direction':
        return AdminDashboard(
          user: widget.user,
          onNavigateTab: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index.clamp(0, navigationItems.length - 1));
          },
        );
      case 'Formations':
        return const AdminFormations();
      case 'Formateurs':
        return const AdminFormateurs();
      case 'Inscriptions':
        return const AdminInscriptions();
      case 'Stagiaires / Apprenants':
        return const AdminApprenants();
      case 'Paiements & Caisse':
        return const AdminPaiements();
      case 'Utilisateurs & Rôles':
        return const AdminUsers();
      case 'Planning':
        return const AdminPlanning();
      case 'Attestations & Diplômes':
        return AdminAttestationsCartes(user: widget.user);
      case 'Logs & Audit':
        return const AdminAuditLogs();
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildAccountingPageByLabel(String label) {
    switch (label) {
      case 'Dashboard Financier':
        return AdminDashboard(
          user: widget.user,
          onNavigateTab: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index.clamp(0, navigationItems.length - 1));
          },
        );
      case 'Inscriptions':
        return const AdminInscriptions();
      case 'Paiements & Encaissements':
        return const AdminPaiements();
      case 'Stagiaires / Apprenants':
        return const AdminApprenants();
      case 'Attestations & Soldes':
        return AdminAttestationsCartes(user: widget.user);
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildAssistantPageByLabel(String label) {
    switch (label) {
      case 'Dashboard Accueil':
        return AdminDashboard(
          user: widget.user,
          onNavigateTab: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index.clamp(0, navigationItems.length - 1));
          },
        );
      case 'Inscriptions':
        return const AdminInscriptions();
      case 'Stagiaires / Apprenants':
        return const AdminApprenants();
      case 'Formations':
        return const AdminFormations();
      case 'Planning':
        return const AdminPlanning();
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildItPageByLabel(String label) {
    switch (label) {
      case 'Dashboard Système':
        return AdminDashboard(
          user: widget.user,
          onNavigateTab: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index.clamp(0, navigationItems.length - 1));
          },
        );
      case 'Utilisateurs & Rôles':
        return const AdminUsers();
      case 'Formations':
        return const AdminFormations();
      case 'Logs & Audit':
        return const AdminAuditLogs();
      case 'Planning':
        return const AdminPlanning();
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildFormateurPage() {
    final label = navigationItems[_selectedIndex].label;
    switch (label) {
      case 'Dashboard Formateur':
        return FormateurDashboard(user: widget.user);
      case 'Mes Apprenants':
        return FormateurApprenants(user: widget.user);
      case 'Mon Emploi du temps':
        return FormateurSchedule(user: widget.user);
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }

  Widget _buildApprenantPage() {
    final label = navigationItems[_selectedIndex].label;
    switch (label) {
      case 'Mon Espace':
        return StudentDashboard(user: widget.user);
      case 'Mes Formations':
        return StudentFormations(user: widget.user);
      case 'Mon Emploi du temps':
        return StudentSchedule(user: widget.user);
      case 'Mes Paiements':
        return PaymentsPage(user: widget.user);
      case 'Notifications':
        return NotificationsPage(user: widget.user);
      case 'Profil':
        return ProfilePage(user: widget.user);
      default:
        return const SizedBox();
    }
  }
}
