import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';

class FormateurApprenants extends StatefulWidget {
  final User user;

  const FormateurApprenants({super.key, required this.user});

  @override
  State<FormateurApprenants> createState() => _FormateurApprenantsState();
}

class _FormateurApprenantsState extends State<FormateurApprenants> with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  StreamSubscription<List<User>>? _usersSub;
  List<User> _allUsers = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  Map<String, List<String>> _formateurModulesByFormation = {};
  Timer? _debounce;
  final int _pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  late AnimationController _fadeController;
  final Set<String> _selected = {};
  bool _tableView = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _loadFormateurModules();
    _allUsers = _db.getStudentsForFormateur(widget.user.id);
    _applyFilterFormateur();
    _usersSub = _db.watchStudentsForFormateur(widget.user.id).listen((users) {
      _allUsers = users;
      _applyFilterFormateur();
    });
    searchController.addListener(() {
      _onSearchChanged();
    });
  }

  Future<void> _exportAttendancePdf() async {
    if (_filteredDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun apprenant dans la liste.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final formateurName = '${widget.user.prenom} ${widget.user.nom}'.trim();
      final formationTitle = _formateurModulesByFormation.keys.isNotEmpty
          ? (_db.getFormationById(_formateurModulesByFormation.keys.first)?.titre ?? 'Formations M@LI-NTIC')
          : 'Formations M@LI-NTIC';

      final pdfBytes = await PdfService().generateAttendanceSheetPdf(
        formationTitre: formationTitle,
        formateurNom: formateurName.isNotEmpty ? formateurName : 'Formateur M@LI-NTIC',
        apprenants: _filteredDocs,
      );

      await PdfService().printOrDownloadPdf(
        pdfBytes: pdfBytes,
        filename: 'emargement_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feuille d\'émargement générée avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    searchController.dispose();
    _usersSub?.cancel();
    _debounce?.cancel();
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
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
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
                _buildApprenantsStream(context),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes Apprenants',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apprenants inscrits à vos formations',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: _isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(
              isMobile ? 'Émargement' : 'Feuille d\'émargement',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isExporting ? null : _exportAttendancePdf,
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: _tableView ? 'Vue carte' : 'Vue tableau',
            onPressed: () => setState(() => _tableView = !_tableView),
            icon: Icon(_tableView ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
            color: AppTheme.primary,
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

  Widget _buildApprenantsStream(BuildContext context) {
    if (_formateurModulesByFormation.isEmpty) {
      _loadFormateurModules();
      _applyFilterFormateur();
    }

    if (_allUsers.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppTheme.primary),
        ),
      );
    }

    if (_filteredDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.person_off_rounded, size: 48, color: Colors.black12),
              const SizedBox(height: 16),
              Text(
                'Aucun apprenant',
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

    final pagedCount = (_currentPage * _pageSize).clamp(0, _filteredDocs.length);
    final pageItems = _filteredDocs.take(pagedCount).toList();
    _hasMore = pagedCount < _filteredDocs.length;

    if (_tableView) {
      final apprenants = _filteredDocs.map((d) => d).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selected.isNotEmpty) _buildBulkActionBar(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Checkbox(value: _selected.length == apprenants.length && apprenants.isNotEmpty, onChanged: (v) => _toggleSelectAll(v ?? false, apprenants))),
                const DataColumn(label: Text('Nom')),
                const DataColumn(label: Text('Email')),
                const DataColumn(label: Text('Téléphone')),
                const DataColumn(label: Text('Actif')),
                const DataColumn(label: Text('Actions')),
              ],
              rows: pageItems.map((data) {
                final id = (data['id'] ?? data['uid'] ?? '') as String;
                return DataRow(
                  selected: _selected.contains(id),
                  onSelectChanged: (v) => _toggleSelectUser(id, v ?? false),
                  cells: [
                    DataCell(Checkbox(value: _selected.contains(id), onChanged: (v) => _toggleSelectUser(id, v ?? false))),
                    DataCell(Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}')),
                    DataCell(Text('${data['email'] ?? ''}')),
                    DataCell(Text('${data['phone'] ?? ''}')),
                    DataCell(Icon((data['estActif'] ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded, color: (data['estActif'] ?? true) ? const Color(0xFF10B981) : Colors.black54, size: 18)),
                    DataCell(Row(children: [
                      IconButton(icon: const Icon(Icons.visibility_rounded), onPressed: () => _showApprenantDetail(id, data, [])),
                      if ((data['phone'] ?? '').toString().isNotEmpty) IconButton(icon: const Icon(Icons.call_rounded), onPressed: () => _callApprenant(data['phone'] ?? '')),
                      IconButton(icon: Icon((data['estActif'] ?? true) ? Icons.block_rounded : Icons.check_circle_rounded), onPressed: () => _toggleBlockApprenant(id, (data['estActif'] ?? true))),
                    ])),
                  ],
                );
              }).toList(),
            ),
          ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentPage += 1;
                  });
                },
                child: const Text('Charger plus'),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pageItems.length,
          itemBuilder: (context, index) {
            final data = pageItems[index];
            final userId = (data['id'] ?? data['uid'] ?? '') as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildApprenantCard(context, userId, data, index, _formateurModulesByFormation),
            );
          },
        ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentPage += 1;
                });
              },
              child: const Text('Charger plus'),
            ),
          ),
      ],
    );
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _applyFilterFormateur();
    });
  }

  void _toggleSelectAll(bool select, List<Map<String, dynamic>> apprenants) {
    setState(() {
      if (select) {
        _selected.addAll(apprenants.map((e) => (e['id'] ?? e['uid'] ?? '') as String));
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleSelectUser(String id, bool select) {
    setState(() {
      if (select) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Text('${_selected.length} sélectionné(s)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(onPressed: _exportSelectedCsv, icon: const Icon(Icons.download_rounded), label: const Text('Exporter CSV')),
          const SizedBox(width: 8),
          TextButton.icon(onPressed: _mailtoSelected, icon: const Icon(Icons.email_rounded), label: const Text('Envoyer mail')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: () => _bulkToggleActive(false), child: const Text('Bloquer')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => _bulkToggleActive(true), child: const Text('Débloquer')),
        ],
      ),
    );
  }

  Future<void> _exportSelectedCsv() async {
    final users = _db.getUsers().where((u) => _selected.contains(u.id)).toList();
    final buffer = StringBuffer();
    buffer.writeln('id,prenom,nom,email,phone,estActif');
    for (final u in users) {
      buffer.writeln('${u.id},${u.prenom},${u.nom},${u.email},${u.phone},${u.estActif}');
    }
    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copié dans le presse-papier')));
  }

  Future<void> _mailtoSelected() async {
    final emails = _db.getUsers().where((u) => _selected.contains(u.id)).map((u) => u.email).where((e) => e.isNotEmpty).join(',');
    if (emails.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun email disponible')));
      return;
    }
    final uri = Uri.parse('mailto:$emails');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le client mail')));
    }
  }

  Future<void> _bulkToggleActive(bool activate) async {
    for (final id in _selected) {
      await _db.setUserActive(id, activate);
    }
    _selected.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(activate ? 'Apprenants débloqués' : 'Apprenants bloqués')));
  }

  void _loadFormateurModules() {
    _formateurModulesByFormation = _getFormateurFormationsWithModules();
  }

  void _applyFilterFormateur() {
    final query = searchController.text.trim().toLowerCase();
    final docs = _allUsers.where((u) => u.role == UserRole.apprenant).map((u) => u.toMap()).toList();

    final filtered = docs.where((doc) {
      final data = doc;
      final assigned = data['assignedFormations'] as List<dynamic>? ?? [];

      bool hasCommonModules = false;
      for (final a in assigned) {
        final formationId = a['formationId'] ?? '';
        final etudiantModules = a['modules'] as List<dynamic>? ?? [];

        if (_formateurModulesByFormation.containsKey(formationId)) {
          final formateurModules = _formateurModulesByFormation[formationId] ?? [];

          for (final m in etudiantModules) {
            final moduleTitle = m['title'] ?? '';
            if (formateurModules.contains(moduleTitle)) {
              hasCommonModules = true;
              break;
            }
          }
        }
        if (hasCommonModules) break;
      }

      if (!hasCommonModules) return false;

      final nom = (data['prenom'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final nomComplet = ('$nom ${data['nom'] ?? ''}').toLowerCase();

      if (query.isEmpty) return true;
      return nomComplet.contains(query) || email.contains(query);
    }).toList();

    setState(() {
      _filteredDocs = filtered;
      _currentPage = 1;
      _hasMore = _filteredDocs.length > _pageSize;
    });
  }

  Widget _buildApprenantCard(BuildContext context, String userId, Map<String, dynamic> data, int index, Map<String, List<String>> formateurModulesByFormation) {
    final prenom = data['prenom'] ?? '';
    final nom = data['nom'] ?? '';
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final isActif = data['estActif'] ?? true;
    final assigned = data['assignedFormations'] as List<dynamic>? ?? [];

    List<Map<String, dynamic>> commonFormations = [];
    int totalAssignedHours = 0;
    int totalDoneHours = 0;

    for (final a in assigned) {
      final formationId = a['formationId'] ?? '';
      final etudiantModules = a['modules'] as List<dynamic>? ?? [];

      if (formateurModulesByFormation.containsKey(formationId)) {
        final formateurModules = formateurModulesByFormation[formationId] ?? [];

        List<Map<String, dynamic>> commonModules = [];
        int formAssigned = 0;
        int formDone = 0;

        for (final m in etudiantModules) {
          final moduleTitle = m['title'] ?? '';
          if (formateurModules.contains(moduleTitle)) {
            final assignedH = (m['assignedHours'] ?? 0) as int;
            final doneH = (m['doneHours'] ?? 0) as int;
            formAssigned += assignedH;
            formDone += doneH;
            commonModules.add({
              'title': moduleTitle,
              'assignedHours': assignedH,
              'doneHours': doneH,
            });
          }
        }

        if (commonModules.isNotEmpty) {
          totalAssignedHours += formAssigned;
          totalDoneHours += formDone;
          commonFormations.add({
            'formationId': formationId,
            'title': a['title'] ?? 'Formation',
            'modules': commonModules,
            'dateAssigned': a['dateAssigned'],
          });
        }
      }
    }

    final progress = totalAssignedHours == 0 ? 0.0 : (totalDoneHours / totalAssignedHours).clamp(0.0, 1.0);

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        prenom.isNotEmpty ? prenom[0].toUpperCase() : 'A',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                          '$prenom $nom',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalDoneHours / $totalAssignedHours heures (${(progress * 100).toStringAsFixed(0)}%) • ${commonFormations.length} formation${commonFormations.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
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
                        if (commonFormations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: commonFormations.expand<Widget>((form) {
                              final fTitle = form['title'] ?? 'Formation';
                              final modules = (form['modules'] as List<dynamic>? ?? []);
                              return [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    fTitle,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                ...modules.map((m) {
                                  final mTitle = m is Map ? (m['title']?.toString() ?? '') : m.toString();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      mTitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  );
                                }),
                              ];
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showApprenantDetail(userId, data, commonFormations),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: Text('Détails', style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (phone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call_rounded, color: AppTheme.primary, size: 20),
                          onPressed: () => _callApprenant(phone),
                        ),
                      IconButton(
                        icon: Icon(isActif ? Icons.block_rounded : Icons.check_circle_rounded, color: isActif ? Colors.orange : AppTheme.success, size: 20),
                        onPressed: () => _toggleBlockApprenant(userId, isActif),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<String>> _getFormateurFormationsWithModules() {
    final Map<String, List<String>> result = {};
    final formations = _db.getFormationsForFormateur(widget.user.id);

    for (final formation in formations) {
      final formateurModules = _db.getModulesForFormateur(formation, widget.user.id);
      if (formateurModules.isNotEmpty) {
        result[formation.id] = formateurModules;
      }
    }
    return result;
  }

  void _showApprenantDetail(String userId, Map<String, dynamic> data, List<Map<String, dynamic>> commonFormations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${data['email'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Téléphone: ${data['phone'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(height: 16),
              Text('Formations suivies :', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ...commonFormations.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('• ${f['title']}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _callApprenant(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _toggleBlockApprenant(String userId, bool isActif) async {
    await _db.setUserActive(userId, !isActif);
    _applyFilterFormateur();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(!isActif ? 'Apprenant débloqué' : 'Apprenant bloqué')),
    );
  }
}
