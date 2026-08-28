import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/audit_log.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/utils/file_saver.dart';

class AdminAuditLogs extends StatefulWidget {
  const AdminAuditLogs({super.key});

  @override
  State<AdminAuditLogs> createState() => _AdminAuditLogsState();
}

class _AdminAuditLogsState extends State<AdminAuditLogs> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  late AnimationController _fadeController;
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _selectedUserNom = 'Tous';

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Tous', 'icon': Icons.all_inclusive_rounded},
    {'label': 'Authentification', 'icon': Icons.login_rounded},
    {'label': 'Sécurité & Mots de passe', 'icon': Icons.key_rounded},
    {'label': 'Inscriptions', 'icon': Icons.how_to_reg_rounded},
    {'label': 'Paiements & Caisse', 'icon': Icons.payments_rounded},
    {'label': 'Formations & Modules', 'icon': Icons.menu_book_rounded},
    {'label': 'Présences & Séances', 'icon': Icons.co_present_rounded},
    {'label': 'Staff & Admin', 'icon': Icons.admin_panel_settings_rounded},
    {'label': 'Alertes & Suppr.', 'icon': Icons.delete_sweep_rounded},
  ];

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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 20),
          _buildKpiSummary(),
          const SizedBox(height: 20),
          _buildSearchAndUserFilter(isMobile),
          const SizedBox(height: 14),
          _buildCategoryFilters(),
          const SizedBox(height: 20),
          _buildLogsList(isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003882), Color(0xFF0066CC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
          boxShadow: AppTheme.heroShadow,
        ),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 22, vertical: isMobile ? 12 : 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Journal d\'Audit & Traçabilité',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 15 : 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Suivi en temps réel de toutes les actions système.',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.white.withValues(alpha: 0.9),
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
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(
                  'Vider les logs',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: _confirmClearLogs,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(
                  'Exporter CSV',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: _exportLogsCsv,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSummary() {
    return StreamBuilder<List<AuditLog>>(
      stream: _db.watchAuditLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final now = DateTime.now();
        final todayLogs = logs.where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day).length;
        final financeLogs = logs.where((l) =>
            l.action.toLowerCase().contains('paiement') ||
            l.description.toLowerCase().contains('fcfa')).length;
        final deleteLogs = logs.where((l) =>
            l.action.toLowerCase().contains('suppr') ||
            l.action.toLowerCase().contains('rejet') ||
            l.action.toLowerCase().contains('bloc')).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 36) / 4;
            final isCompact = constraints.maxWidth < 600;

            if (isCompact) {
              final w = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildKpiCard('Total des Logs', '${logs.length}', Icons.history_rounded, AppTheme.primary, w),
                  _buildKpiCard('Aujourd\'hui', '$todayLogs', Icons.bolt_rounded, AppTheme.success, w),
                  _buildKpiCard('Finances', '$financeLogs', Icons.payments_rounded, const Color(0xFFD97706), w),
                  _buildKpiCard('Alertes/Suppr.', '$deleteLogs', Icons.warning_amber_rounded, AppTheme.error, w),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: _buildKpiCard('Total des Logs', '${logs.length}', Icons.history_rounded, AppTheme.primary, cardWidth)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Aujourd\'hui', '$todayLogs', Icons.bolt_rounded, AppTheme.success, cardWidth)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Finances', '$financeLogs', Icons.payments_rounded, const Color(0xFFD97706), cardWidth)),
                const SizedBox(width: 12),
                Expanded(child: _buildKpiCard('Alertes/Suppr.', '$deleteLogs', Icons.warning_amber_rounded, AppTheme.error, cardWidth)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndUserFilter(bool isMobile) {
    return StreamBuilder<List<AuditLog>>(
      stream: _db.watchAuditLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        final userNames = <String>{'Tous'};
        for (final l in logs) {
          if (l.userNom.trim().isNotEmpty) userNames.add(l.userNom.trim());
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par auteur, action ou détails...',
                        hintStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: userNames.contains(_selectedUserNom) ? _selectedUserNom : 'Tous',
                        isExpanded: true,
                        icon: const Icon(Icons.person_search_rounded, color: AppTheme.primary, size: 20),
                        items: userNames.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name == 'Tous' ? '👤 Tous les utilisateurs' : '👤 $name',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: name == _selectedUserNom ? FontWeight.w700 : FontWeight.w500,
                                color: name == _selectedUserNom ? AppTheme.primary : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedUserNom = val);
                        },
                      ),
                    ),
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    tooltip: 'Exporter CSV',
                    onPressed: _exportLogsCsv,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedCategory = cat['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 15,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogsList(bool isMobile) {
    return StreamBuilder<List<AuditLog>>(
      stream: _db.watchAuditLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        final filteredLogs = logs.where((log) {
          // 1. User Filter
          if (_selectedUserNom != 'Tous' && log.userNom.trim().toLowerCase() != _selectedUserNom.trim().toLowerCase()) {
            return false;
          }

          // 2. Text Search filter
          final text = '${log.userNom} ${log.userRole} ${log.action} ${log.description}'.toLowerCase();
          final matchesSearch = _searchQuery.isEmpty || text.contains(_searchQuery);
          if (!matchesSearch) return false;

          // 3. Category filter
          if (_selectedCategory == 'Tous') return true;
          final act = log.action.toLowerCase();
          final desc = log.description.toLowerCase();
          final role = log.userRole.toLowerCase();

          if (_selectedCategory == 'Authentification') {
            return act.contains('connexion') || act.contains('déconnexion') || act.contains('login') || act.contains('logout');
          } else if (_selectedCategory == 'Sécurité & Mots de passe') {
            return act.contains('mot de passe') || act.contains('password') || act.contains('rôle') || act.contains('role') || act.contains('désactiv');
          } else if (_selectedCategory == 'Inscriptions') {
            return act.contains('inscript') || act.contains('accept') || act.contains('rejet') || desc.contains('inscript');
          } else if (_selectedCategory == 'Paiements & Caisse') {
            return act.contains('paiement') || desc.contains('fcfa') || desc.contains('paiement') || act.contains('caisse') || act.contains('versement');
          } else if (_selectedCategory == 'Formations & Modules') {
            return act.contains('formation') || act.contains('module') || desc.contains('formation') || desc.contains('module');
          } else if (_selectedCategory == 'Présences & Séances') {
            return act.contains('présence') || act.contains('pointage') || act.contains('séance') || act.contains('émargement') || desc.contains('présen');
          } else if (_selectedCategory == 'Staff & Admin') {
            return role.contains('admin') || role.contains('daf') || role.contains('dg') || role.contains('comptable') || role.contains('assistant') || role.contains('it');
          } else if (_selectedCategory == 'Alertes & Suppr.') {
            return act.contains('suppr') || act.contains('rejet') || act.contains('bloc') || desc.contains('supprim') || log.severity == AuditSeverity.warning || log.severity == AuditSeverity.critical;
          }
          return true;
        }).toList();

        // Sort descending (most recent first)
        filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (filteredLogs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.manage_search_rounded, size: 38, color: Colors.black38),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun log correspondant aux filtres sélectionnés.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredLogs.length,
          itemBuilder: (context, index) {
            final log = filteredLogs[index];
            final dateStr = _formatTimestamp(log.timestamp);
            final actionColor = _getActionColor(log.action, log.description);
            final actionIcon = _getActionIcon(log.action, log.description);

            return FadeInUp(
              duration: const Duration(milliseconds: 250),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(actionIcon, color: actionColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _selectedUserNom = log.userNom.trim()),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        log.userNom.trim().isNotEmpty ? log.userNom : 'Utilisateur Système',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedUserNom == log.userNom.trim() ? AppTheme.primary : Colors.black87,
                                          decoration: _selectedUserNom == log.userNom.trim() ? TextDecoration.underline : null,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.filter_alt_rounded, size: 13, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatRoleBadge(log.userRole),
                                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.primary),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: '${log.action} : ',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: log.description,
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) {
      return 'Aujourd\'hui à $timeStr';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $timeStr';
  }

  Color _getActionColor(String action, String description) {
    final combined = '$action $description'.toLowerCase();
    if (combined.contains('suppr') || combined.contains('rejet') || combined.contains('bloc') || combined.contains('erreur')) {
      return AppTheme.error;
    }
    if (combined.contains('paiement') || combined.contains('encaiss') || combined.contains('fcfa') || combined.contains('caisse')) {
      return const Color(0xFFD97706);
    }
    if (combined.contains('valida') || combined.contains('accept') || combined.contains('créa') || combined.contains('ajout')) {
      return AppTheme.success;
    }
    if (combined.contains('connexion') || combined.contains('login') || combined.contains('auth')) {
      return const Color(0xFF0284C7);
    }
    return AppTheme.primary;
  }

  IconData _getActionIcon(String action, String description) {
    final combined = '$action $description'.toLowerCase();
    if (combined.contains('suppr')) return Icons.delete_forever_rounded;
    if (combined.contains('rejet') || combined.contains('bloc')) return Icons.block_rounded;
    if (combined.contains('paiement') || combined.contains('caisse') || combined.contains('fcfa')) return Icons.payments_rounded;
    if (combined.contains('valida') || combined.contains('accept')) return Icons.check_circle_rounded;
    if (combined.contains('créa') || combined.contains('ajout')) return Icons.add_circle_outline_rounded;
    if (combined.contains('connexion') || combined.contains('auth')) return Icons.login_rounded;
    return Icons.history_rounded;
  }

  Future<void> _exportLogsCsv() async {
    try {
      final logs = _db.getAuditLogs();
      if (logs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun log à exporter.')),
        );
        return;
      }

      final csvContent = StringBuffer();
      csvContent.writeln('Date;Utilisateur;Role;Action;Description');

      for (final log in logs) {
        final d = log.timestamp;
        final date = '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute}';
        csvContent.writeln('"$date";"${log.userNom}";"${log.userRole}";"${log.action}";"${log.description.replaceAll('"', '""')}"');
      }

      final bytes = utf8.encode(csvContent.toString());
      await saveFile(
        Uint8List.fromList(bytes),
        'audit_logs_malintic_${DateTime.now().millisecondsSinceEpoch}.csv',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export CSV généré avec succès !'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export CSV : $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _confirmClearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: AppTheme.error, size: 24),
            const SizedBox(width: 10),
            Text('Vider le journal d\'audit', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment effacer tous les logs système pour libérer de l\'espace ? Cette action est irréversible.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Vider les logs', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.clearAuditLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Journal d\'audit vidé avec succès !'),
          backgroundColor: AppTheme.success,
        ),
      );
      setState(() {});
    }
  }

  String _formatRoleBadge(String role) {
    final clean = role.replaceAll('UserRole.', '').toLowerCase().trim();
    switch (clean) {
      case 'admin':
        return 'ADMIN';
      case 'formateur':
        return 'FORMATEUR';
      case 'apprenant':
      case 'etudiant':
        return 'APPRENANT';
      case 'dg':
        return 'DG';
      case 'daf':
        return 'DAF';
      case 'comptable':
        return 'COMPTABLE';
      case 'assistant':
        return 'ASSISTANT';
      case 'it':
        return 'IT';
      default:
        return clean.isNotEmpty ? clean.toUpperCase() : 'SYSTÈME';
    }
  }
}
