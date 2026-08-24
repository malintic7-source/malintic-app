import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/pdf_helper.dart';
import 'package:gestion_formations/Services/pdf_service.dart';
import 'package:gestion_formations/config/theme.dart';

class AdminApprenants extends StatefulWidget {
  const AdminApprenants({super.key});

  @override
  State<AdminApprenants> createState() => _AdminApprenantsState();
}

class _AdminApprenantsState extends State<AdminApprenants>
    with TickerProviderStateMixin {
  final LocalDataService _db = LocalDataService();
  final searchController = TextEditingController();
  StreamSubscription<List<User>>? _usersSub;
  StreamSubscription<List<Inscription>>? _inscriptionsSub;
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  Timer? _debounce;
  final int _pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  late AnimationController _fadeController;
  // Table & selection state
  final Set<String> _selected = {};
  bool _tableView = false;
  String _selectedSexeFilter = 'Tous';
  String _selectedStatutFilter = 'Tous';
  String _selectedFormationFilter = 'Toutes';
  String _selectedPeriodeFilter = 'Toutes';
  String _selectedPaiementFilter = 'Tous';
  String _selectedCompletionFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    // Subscribe to users and inscriptions stream and apply initial filter
    _usersSub = _db.watchUsers().listen((users) {
      _allUsers = users;
      _applyFilter();
    });
    _inscriptionsSub = _db.watchInscriptions().listen((_) {
      _applyFilter();
      Future.microtask(() => _db.assignMissingMatriculesToValidatedStudents());
    });
    Future.microtask(() => _db.assignMissingMatriculesToValidatedStudents());
    _applyFilter();

    searchController.addListener(() {
      _onSearchChanged();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    searchController.dispose();
    _usersSub?.cancel();
    _inscriptionsSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1100;
    final hp = isMobile
        ? 12.0
        : isTablet
        ? 16.0
        : 20.0;
    final vp = isMobile ? 12.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: vp, horizontal: hp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildSearchBar(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildApprenantsStream(context),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return FadeTransition(
      opacity: _fadeController,
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gérez les apprenants de votre plateforme',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      tooltip: _tableView ? 'Vue carte' : 'Vue tableau',
                      onPressed: () => setState(() => _tableView = !_tableView),
                      icon: Icon(
                        _tableView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                      ),
                      color: AppTheme.primary,
                      iconSize: 22,
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppTheme.heroShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showCreateApprenantDialog(),
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
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apprenants',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gérez les apprenants de votre plateforme',
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
                IconButton(
                  tooltip: _tableView ? 'Vue carte' : 'Vue tableau',
                  onPressed: () => setState(() => _tableView = !_tableView),
                  icon: Icon(
                    _tableView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                  ),
                  color: AppTheme.primary,
                  iconSize: 24,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.heroShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCreateApprenantDialog(),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    final formations = _db.getFormations();

    // Active filters check
    final bool hasActiveFilters = _selectedSexeFilter != 'Tous' ||
        _selectedStatutFilter != 'Tous' ||
        _selectedFormationFilter != 'Toutes' ||
        _selectedPeriodeFilter != 'Toutes' ||
        _selectedPaiementFilter != 'Tous' ||
        _selectedCompletionFilter != 'Tous';

    // Dropdown helper builder
    Widget buildFilterDd(String val, List<DropdownMenuItem<String>> items, Function(String?) cb, {bool active = false, Color? col}) {
      final color = col ?? AppTheme.primary;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.black12, width: active ? 1.5 : 1.0),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: val,
            icon: Icon(Icons.arrow_drop_down_rounded, size: 20, color: active ? color : Colors.black54),
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w600, color: active ? color : Colors.black87),
            items: items,
            onChanged: cb,
          ),
        ),
      );
    }

    final filterBar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rangée 1 — filtres de base
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            buildFilterDd(
              _selectedSexeFilter,
              const [
                DropdownMenuItem(value: 'Tous', child: Text('👤 Sexe: Tous')),
                DropdownMenuItem(value: 'Homme', child: Text('♂ Homme')),
                DropdownMenuItem(value: 'Femme', child: Text('♀ Femme')),
              ],
              (val) { if (val != null) { setState(() => _selectedSexeFilter = val); _applyFilter(); } },
              active: _selectedSexeFilter != 'Tous', col: AppTheme.primary,
            ),
            buildFilterDd(
              _selectedStatutFilter,
              const [
                DropdownMenuItem(value: 'Tous', child: Text('🔘 Statut: Tous')),
                DropdownMenuItem(value: 'Actif', child: Text('✅ Actif')),
                DropdownMenuItem(value: 'Inactif', child: Text('🚫 Bloqué')),
              ],
              (val) { if (val != null) { setState(() => _selectedStatutFilter = val); _applyFilter(); } },
              active: _selectedStatutFilter != 'Tous', col: AppTheme.success,
            ),
            buildFilterDd(
              _selectedFormationFilter,
              [
                const DropdownMenuItem(value: 'Toutes', child: Text('🎓 Formation: Toutes')),
                ...formations.map((f) => DropdownMenuItem(value: f.id, child: Text(f.titre, overflow: TextOverflow.ellipsis))),
              ],
              (val) { if (val != null) { setState(() => _selectedFormationFilter = val); _applyFilter(); } },
              active: _selectedFormationFilter != 'Toutes', col: AppTheme.accent,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Rangée 2 — filtres avancés
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            buildFilterDd(
              _selectedPeriodeFilter,
              const [
                DropdownMenuItem(value: 'Toutes', child: Text('📅 Période: Toutes')),
                DropdownMenuItem(value: 'Ce mois', child: Text('Ce mois-ci')),
                DropdownMenuItem(value: '3 mois', child: Text('3 derniers mois')),
                DropdownMenuItem(value: '6 mois', child: Text('6 derniers mois')),
                DropdownMenuItem(value: 'Cette année', child: Text('Cette année')),
              ],
              (val) { if (val != null) { setState(() => _selectedPeriodeFilter = val); _applyFilter(); } },
              active: _selectedPeriodeFilter != 'Toutes', col: const Color(0xFF7C3AED),
            ),
            buildFilterDd(
              _selectedPaiementFilter,
              const [
                DropdownMenuItem(value: 'Tous', child: Text('💳 Paiement: Tous')),
                DropdownMenuItem(value: 'Paiement Complet', child: Text('✅ Payé (Complet)')),
                DropdownMenuItem(value: 'Reste à payer', child: Text('⚠️ Reste à payer')),
                DropdownMenuItem(value: 'Non payé', child: Text('❌ Non payé')),
                DropdownMenuItem(value: 'Sans frais', child: Text('ℹ️ Sans frais')),
              ],
              (val) { if (val != null) { setState(() => _selectedPaiementFilter = val); _applyFilter(); } },
              active: _selectedPaiementFilter != 'Tous', col: AppTheme.warningDark,
            ),
            buildFilterDd(
              _selectedCompletionFilter,
              const [
                DropdownMenuItem(value: 'Tous', child: Text('🏁 Complétion: Tous')),
                DropdownMenuItem(value: 'Au moins une terminée', child: Text('✅ Au moins terminée')),
                DropdownMenuItem(value: 'En cours', child: Text('🔄 En cours')),
                DropdownMenuItem(value: 'Aucune terminée', child: Text('⏳ Aucune terminée')),
              ],
              (val) { if (val != null) { setState(() => _selectedCompletionFilter = val); _applyFilter(); } },
              active: _selectedCompletionFilter != 'Tous', col: const Color(0xFF0D9488),
            ),
            if (hasActiveFilters)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedSexeFilter = 'Tous';
                    _selectedStatutFilter = 'Tous';
                    _selectedFormationFilter = 'Toutes';
                    _selectedPeriodeFilter = 'Toutes';
                    _selectedPaiementFilter = 'Tous';
                    _selectedCompletionFilter = 'Tous';
                    searchController.clear();
                  });
                  _applyFilter();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: AppTheme.error),
                label: Text('Réinitialiser', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: AppTheme.error.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Compteur résultats
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredUsers.length} apprenant${_filteredUsers.length != 1 ? "s" : ""} trouvé${_filteredUsers.length != 1 ? "s" : ""}',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 8),
              Text('(filtres actifs)', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Rechercher...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.black38,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              onChanged: (value) => _applyFilter(),
            ),
          ),
          const SizedBox(height: 10),
          filterBar,
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportApprenantsCSV,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.file_download_rounded, size: 18),
              label: Text('Exporter CSV', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
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
                    hintText: 'Rechercher par nom, email, téléphone...',
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) => _applyFilter(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _exportApprenantsCSV,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.file_download_rounded, size: 20),
              label: Text(
                'Exporter CSV',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        filterBar,
      ],
    );
  }

  Future<void> _exportApprenantsCSV() async {
    final apprenants = _filteredUsers
        .where((u) => u.role == UserRole.apprenant)
        .toList();
    if (apprenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Rapport CSV exporté avec succès (12 colonnes) !'),
        backgroundColor: AppTheme.success,
      ),
    );
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.write('\uFEFF');
        final allInscriptions = _db.getInscriptions();
    final allPayments = _db.getPayments();
    csv.writeln(
      'Matricule;Prénom;Nom;Email;Téléphone;Statut;Date Inscription;'
      'Nb Formations;Formations Assignées;Formations Terminées;'
      'Total Payé (FCFA);Solde Restant (FCFA)',
    );

    for (final e in apprenants) {
      final statusStr = e.estActif ? 'Actif' : 'Bloqué';
      final matricule = e.matricule ?? '';
      final assigned = e.assignedFormations;
      final nbFormations = assigned.length;
      final nbTerminees = assigned.where((f) => f['isCompleted'] == true).length;
      final formationTitles = assigned
          .map((f) => f['title']?.toString() ?? f['formationId']?.toString() ?? '?')
          .join(' | ');
      final userInscrips = allInscriptions.where((i) => i.etudiantId == e.id || i.id == e.id);
      final totalDue = userInscrips.fold<double>(0, (s, i) { final f = _db.getFormations().where((fm) => fm.id == i.formationId).firstOrNull; return s + (f?.prix ?? 0); });
      final userPays = allPayments.where((p) => p.etudiantId == e.id && p.status.name == 'effectue');
      final totalPaid = userPays.fold<double>(0, (s, p) => s + p.montant);
      final solde = (totalDue - totalPaid).clamp(0, double.infinity);
      csv.writeln(
        '"$matricule";"${e.prenom}";"${e.nom}";"${e.email}";"${e.phone}";'
        '"$statusStr";"${e.dateCreation.day}/${e.dateCreation.month}/${e.dateCreation.year}";'
        '"$nbFormations";"$formationTitles";"$nbTerminees";'
        '"${totalPaid.toStringAsFixed(0)}";"${solde.toStringAsFixed(0)}"',
      );
    }
    final Uint8List bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    await PdfHelper.downloadCSV(
      bytes,
      fileName: 'Rapport_Apprenants_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Rapport CSV exporté avec succès (12 colonnes) !'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Widget _buildApprenantsStream(BuildContext context) {
    final apprenants = _filteredUsers;
    if (apprenants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(
                Icons.person_off_rounded,
                size: 48,
                color: Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun apprenant inscrit pour le moment',
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

    // Table view
    if (_tableView) {
      final pagedCount = (_currentPage * _pageSize).clamp(0, apprenants.length);
      final pageItems = apprenants.take(pagedCount).toList();
      _hasMore = pagedCount < apprenants.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selected.isNotEmpty) _buildBulkActionBar(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Nom')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Téléphone')),
                DataColumn(label: Text('Compte')),
                DataColumn(label: Text('Statut Paiement')),
                DataColumn(label: Text('Actions')),
              ],
              rows: pageItems.map((u) {
                final data = u.toMap();
                final id = u.id;
                return DataRow(
                  selected: _selected.contains(id),
                  onSelectChanged: (v) => _toggleSelectUser(id, v ?? false),
                  cells: [
                    DataCell(
                      Text(
                        '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim(),
                      ),
                    ),
                    DataCell(Text('${data['email'] ?? ''}')),
                    DataCell(Text('${data['phone'] ?? ''}')),
                    DataCell(
                      Icon(
                        (data['estActif'] ?? true)
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: (data['estActif'] ?? true)
                            ? AppTheme.success
                            : Colors.black54,
                        size: 18,
                      ),
                    ),
                    DataCell(
                      Builder(
                        builder: (context) {
                          final payInfo = _getStudentPaymentInfo(
                            id,
                            (data['email'] ?? '').toString(),
                            (data['assignedFormations'] as List<dynamic>? ?? []),
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: payInfo['bgColor'] as Color,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (payInfo['color'] as Color).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  payInfo['icon'] as IconData,
                                  size: 12,
                                  color: payInfo['color'] as Color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  payInfo['label'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: payInfo['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Détails',
                            onPressed: () => _showApprenantDetail(id, data),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.assignment_rounded,
                              size: 18,
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Affecter formation',
                            onPressed: () => _assignFormationDialog(id),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              (data['estActif'] ?? true)
                                  ? Icons.block_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: (data['estActif'] ?? true)
                                ? 'Bloquer'
                                : 'Activer',
                            onPressed: () => _toggleBlockUser(
                              id,
                              (data['estActif'] ?? true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (_hasMore)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentPage += 1;
                  });
                },
                child: Text('Charger plus'),
              ),
            ),
        ],
      );
    }

    // Card view
    final pagedCount = (_currentPage * _pageSize).clamp(0, apprenants.length);
    final pageItems = apprenants.take(pagedCount).toList();

    _hasMore = pagedCount < apprenants.length;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: pageItems.length,
          itemBuilder: (context, index) {
            final user = pageItems[index];
            final data = user.toMap();
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildApprenantCardPremium(context, user.id, data, index),
            );
          },
        ),
        if (_hasMore)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentPage += 1;
                });
              },
              child: Text('Charger plus'),
            ),
          ),
      ],
    );
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 350), () {
      _applyFilter();
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
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${_selected.length} sélectionné(s)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          Spacer(),
          TextButton.icon(
            onPressed: _exportSelectedCsv,
            icon: Icon(Icons.download_rounded),
            label: Text('Exporter CSV'),
          ),
          SizedBox(width: 8),
          TextButton.icon(
            onPressed: _mailtoSelected,
            icon: Icon(Icons.email_rounded),
            label: Text('Envoyer mail'),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _bulkToggleActive(false),
            child: Text('Bloquer'),
          ),
          SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _bulkToggleActive(true),
            child: Text('Débloquer'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSelectedCsv() async {
    final users = _db
        .getUsers()
        .where((u) => _selected.contains(u.id))
        .toList();
    final buffer = StringBuffer();
    buffer.writeln('id,prenom,nom,email,phone,estActif');
    for (final u in users) {
      buffer.writeln(
        '${u.id},${u.prenom},${u.nom},${u.email},${u.phone},${u.estActif}',
      );
    }
    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV copié dans le presse-papier')));
  }

  Future<void> _mailtoSelected() async {
    final emails = _db
        .getUsers()
        .where((u) => _selected.contains(u.id))
        .map((u) => u.email)
        .where((e) => e.isNotEmpty)
        .join(',');
    if (emails.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aucun email disponible')));
      return;
    }
    final uri = Uri.parse('mailto:$emails');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le client mail')),
      );
    }
  }

  Future<void> _bulkToggleActive(bool activate) async {
    for (final id in _selected) {
      await _db.setUserActive(id, activate);
    }
    _selected.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(activate ? 'Apprenants débloqués' : 'Apprenants bloqués'),
      ),
    );
  }


  Map<String, dynamic> _getStudentPaymentInfo(String userId, String email, List<dynamic> assigned) {
    final allInscriptions = _db.getInscriptions().where((ins) =>
      ins.etudiantId == userId || (email.isNotEmpty && ins.email?.toLowerCase() == email.toLowerCase())
    ).toList();
    
    final allPayments = _db.getPayments().where((p) {
      final isUserMatch = p.etudiantId == userId;
      final isInsMatch = allInscriptions.any((ins) => ins.id == p.inscriptionId);
      return (isUserMatch || isInsMatch) && p.status == PaymentStatus.effectue;
    }).toList();

    final formationIds = <String>{};
    for (final a in assigned) {
      final fId = (a is Map ? a['formationId'] : null)?.toString() ?? '';
      if (fId.isNotEmpty) formationIds.add(fId);
    }
    for (final ins in allInscriptions) {
      if (ins.formationId.isNotEmpty) formationIds.add(ins.formationId);
    }

    double totalDue = 0.0;
    for (final fId in formationIds) {
      final f = _db.getFormationById(fId);
      if (f != null) {
        totalDue += f.prix;
      }
    }

    double totalPaid = allPayments.fold<double>(0.0, (sum, p) => sum + p.montant);
    double remaining = (totalDue - totalPaid).clamp(0.0, double.infinity);

    String statusLabel;
    String filterCategory;
    Color statusColor;
    Color bgColor;
    IconData statusIcon;

    if (totalDue == 0) {
      statusLabel = 'Sans frais';
      filterCategory = 'Sans frais';
      statusColor = Colors.blueGrey;
      bgColor = Colors.blueGrey.withValues(alpha: 0.1);
      statusIcon = Icons.info_outline_rounded;
    } else if (remaining <= 0) {
      statusLabel = 'Payé (100%)';
      filterCategory = 'Paiement Complet';
      statusColor = AppTheme.success;
      bgColor = AppTheme.success.withValues(alpha: 0.1);
      statusIcon = Icons.check_circle_rounded;
    } else if (totalPaid > 0) {
      statusLabel = 'Reste: ${remaining.toStringAsFixed(0)} F';
      filterCategory = 'Reste à payer';
      statusColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFEF3C7);
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusLabel = 'Non Payé (${totalDue.toStringAsFixed(0)} F)';
      filterCategory = 'Non payé';
      statusColor = AppTheme.error;
      bgColor = AppTheme.error.withValues(alpha: 0.1);
      statusIcon = Icons.error_outline_rounded;
    }

    return {
      'totalDue': totalDue,
      'totalPaid': totalPaid,
      'remaining': remaining,
      'label': statusLabel,
      'filterCategory': filterCategory,
      'color': statusColor,
      'bgColor': bgColor,
      'icon': statusIcon,
    };
  }

  void _applyFilter() {
    final query = searchController.text.trim().toLowerCase();
    final inscriptions = _db.getInscriptions();
    final deletedUserIds = _db.getDeletedDocs('users');
    final deletedInscIds = _db.getDeletedDocs('inscriptions');

    // 1. Explicit apprenant users from user accounts (exclude deleted)
    final apprenantUsers = _allUsers
        .where((u) => u.role == UserRole.apprenant && !deletedUserIds.contains(u.id))
        .toList();

    // 2. Only validated applications may enter the apprenant circuit (exclude deleted).
    final List<User> inscriptionApprenants = inscriptions
        .where((ins) =>
            ins.status == InscriptionStatus.acceptee &&
            !deletedInscIds.contains(ins.id) &&
            !deletedUserIds.contains(ins.etudiantId) &&
            !deletedUserIds.contains(ins.id))
        .map((ins) {
          return User(
            id: ins.id,
            email: (ins.email != null && ins.email!.isNotEmpty)
                ? ins.email!
                : 'apprenant@mali-ntic.ml',
            nom: (ins.nom != null && ins.nom!.isNotEmpty)
                ? ins.nom!
                : 'Apprenant',
            prenom: ins.prenom ?? '',
            phone: ins.telephone ?? '',
            role: UserRole.apprenant,
            password: '',
            estActif: ins.status == InscriptionStatus.acceptee,
            dateCreation: ins.dateInscription,
          );
        })
        .toList();

    // Combine both sources and deduplicate by normalized email and full name
    final Map<String, User> apprenantMap = {};
    for (final s in [...apprenantUsers, ...inscriptionApprenants]) {
      final normalizedEmail = s.email.trim().toLowerCase().replaceAll(
        '@mali-ntic.ml',
        '@malintic.ml',
      );
      final cleanName =
          '${s.prenom.trim().toLowerCase()}.${s.nom.trim().toLowerCase()}'
              .replaceAll(RegExp(r'[^a-z0-9.]'), '');

      final key = cleanName.replaceAll('.', '').isNotEmpty
          ? cleanName
          : (normalizedEmail.isNotEmpty ? normalizedEmail : s.id);

      final existing = apprenantMap[key];
      if (existing == null) {
        apprenantMap[key] = User(
          id: s.id,
          email: normalizedEmail.isNotEmpty
              ? normalizedEmail
              : '${s.id}@malintic.ml',
          nom: s.nom,
          prenom: s.prenom,
          phone: s.phone,
          matricule: s.matricule,
          role: s.role,
          password: s.password.isNotEmpty ? s.password : '00000000',
          photoUrl: s.photoUrl,
          assignedFormations: s.assignedFormations,
          estActif: s.estActif,
          dateCreation: s.dateCreation,
          dateModification: s.dateModification,
        );
      } else if (existing.email.contains('@mali-ntic.ml') &&
          normalizedEmail.contains('@malintic.ml')) {
        apprenantMap[key] = User(
          id: existing.id,
          email: normalizedEmail,
          nom: existing.nom.isNotEmpty ? existing.nom : s.nom,
          prenom: existing.prenom.isNotEmpty ? existing.prenom : s.prenom,
          phone: existing.phone.isNotEmpty ? existing.phone : s.phone,
          matricule: existing.matricule,
          role: existing.role,
          password: existing.password.isNotEmpty
              ? existing.password
              : '00000000',
          photoUrl: existing.photoUrl,
          assignedFormations: existing.assignedFormations.isNotEmpty
              ? existing.assignedFormations
              : s.assignedFormations,
          estActif: existing.estActif,
          dateCreation: existing.dateCreation,
          dateModification: DateTime.now(),
        );
      }
    }

    final allCombinedApprenants = apprenantMap.values
        .where((user) => user.role == UserRole.apprenant)
        .toList();

    final filtered = allCombinedApprenants.where((user) {
      if (_selectedSexeFilter != 'Tous' && user.sexe != _selectedSexeFilter) {
        return false;
      }
      if (_selectedStatutFilter == 'Actif' && !user.estActif) return false;
      if (_selectedStatutFilter == 'Inactif' && user.estActif) return false;
      if (_selectedFormationFilter != 'Toutes') {
        final isEnrolled = user.assignedFormations
            .any((f) => f['formationId'] == _selectedFormationFilter);
        if (!isEnrolled) return false;
      }
      // Filtre Période d'inscription
      if (_selectedPeriodeFilter != 'Toutes') {
        final now = DateTime.now();
        final diff = now.difference(user.dateCreation).inDays;
        if (_selectedPeriodeFilter == 'Ce mois' && diff > 31) return false;
        if (_selectedPeriodeFilter == '3 mois' && diff > 92) return false;
        if (_selectedPeriodeFilter == '6 mois' && diff > 183) return false;
        if (_selectedPeriodeFilter == 'Cette année' && user.dateCreation.year != now.year) return false;
      }
      // Filtre Statut paiement précis
      if (_selectedPaiementFilter != 'Tous') {
        final payInfo = _getStudentPaymentInfo(user.id, user.email, user.assignedFormations);
        final category = payInfo['filterCategory'] as String;
        if (_selectedPaiementFilter == 'Paiement Complet' && category != 'Paiement Complet') return false;
        if (_selectedPaiementFilter == 'Reste à payer' && category != 'Reste à payer') return false;
        if (_selectedPaiementFilter == 'Non payé' && category != 'Non payé') return false;
        if (_selectedPaiementFilter == 'Sans frais' && category != 'Sans frais') return false;
      }
      // Filtre Complétion formation
      if (_selectedCompletionFilter != 'Tous') {
        final assigned = user.assignedFormations;
        final completed = assigned.where((f) => f['isCompleted'] == true).length;
        if (_selectedCompletionFilter == 'Au moins une terminée' && completed == 0) return false;
        if (_selectedCompletionFilter == 'Aucune terminée' && completed > 0) return false;
        if (_selectedCompletionFilter == 'En cours' && (assigned.isEmpty || completed == assigned.length)) return false;
      }

      final nomComplet = user.nomComplet.toLowerCase();
      final email = user.email.toLowerCase();
      final phone = user.phone.toLowerCase();
      final matricule = (user.matricule ?? '').toLowerCase();
      if (query.isEmpty) return true;
      return nomComplet.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          matricule.contains(query);
    }).toList();

    setState(() {
      _filteredUsers = filtered;
      _currentPage = 1;
      _hasMore = _filteredUsers.length > _pageSize;
    });
  }

  Widget _buildApprenantCardPremium(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
    int index,
  ) {
    final prenom = (data['prenom'] ?? '').toString().trim();
    final nom = (data['nom'] ?? '').toString().trim();
    final fullName = (prenom.isNotEmpty || nom.isNotEmpty)
        ? '$prenom $nom'
        : 'Apprenant #${userId.substring(0, 6)}';
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? data['telephone'] ?? '').toString();
    final matricule = (data['matricule'] ?? '').toString().trim();

    final estActif = (data['estActif'] ?? true) as bool;
    final assigned = (data['assignedFormations'] as List<dynamic>? ?? []);

    final enrolledFormationTitles = <String>[];
    final enrolledModuleTitles = <String>[];

    for (final a in assigned) {
      final fId = a['formationId']?.toString() ?? '';
      final fTitle = a['title']?.toString() ?? _db.getFormationById(fId)?.titre ?? 'Formation';
      if (!enrolledFormationTitles.contains(fTitle)) {
        enrolledFormationTitles.add(fTitle);
      }
      final modules = (a['modules'] as List<dynamic>? ?? []);
      for (final m in modules) {
        final mTitle = m is Map ? (m['title']?.toString() ?? '') : m.toString();
        if (mTitle.isNotEmpty) {
          enrolledModuleTitles.add('$fTitle · $mTitle');
        }
      }
    }

    if (enrolledFormationTitles.isEmpty) {
      final fallbackInscriptions = _db.getInscriptions().where((ins) =>
          (ins.email?.toLowerCase() == email.toLowerCase() || ins.etudiantId == userId) &&
          ins.status == InscriptionStatus.acceptee).toList();
      for (final ins in fallbackInscriptions) {
        final fTitle = _db.getFormationById(ins.formationId)?.titre ?? 'Formation';
        if (!enrolledFormationTitles.contains(fTitle)) {
          enrolledFormationTitles.add(fTitle);
        }
      }
    }

    // Attestation eligibility check: ONLY if Admin explicitly marked training as completed AND 100% paid
    final userInscriptions = _db.getInscriptions().where((ins) =>
        (ins.email?.toLowerCase() == email.toLowerCase() || ins.etudiantId == userId) &&
        ins.status == InscriptionStatus.acceptee).toList();

    final eligibleAttestations = <Map<String, dynamic>>[];
    for (final ins in userInscriptions) {
      final f = _db.getFormationById(ins.formationId);
      if (f == null) continue;

      // 1. Formation MUST be marked completed by Admin
      final assignedItem = assigned.where((item) => item['formationId'] == f.id).firstOrNull;
      final isCompletedByAdmin = (assignedItem != null && assignedItem['isCompleted'] == true) || f.status == FormationStatus.terminee;
      if (!isCompletedByAdmin) continue;

      // 2. Student MUST be 100% paid (zero debt)
      final balance = _db.getInscriptionBalance(ins.id);
      final payments = _db.getPaymentsForInscription(ins.id);
      final totalPaid = payments.fold<double>(0.0, (s, p) => s + p.montant);
      final isPaid = balance <= 0 && (f.prix == 0 || totalPaid >= f.prix || ins.paiementEffectue);
      if (!isPaid) continue;

      eligibleAttestations.add({'inscription': ins, 'formation': f});
    }

    return SlideInUp(
      delay: Duration(milliseconds: 50 + (index * 40)),
      duration: const Duration(milliseconds: 600),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: eligibleAttestations.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: eligibleAttestations.isNotEmpty ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: eligibleAttestations.isNotEmpty
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header with Avatar, Name, and Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        prenom.isNotEmpty ? prenom[0].toUpperCase() : 'A',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Apprenant',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: estActif
                                    ? AppTheme.success.withValues(alpha: 0.1)
                                    : Colors.black12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estActif ? 'Actif' : 'Inactif',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: estActif ? AppTheme.success : Colors.black54,
                                ),
                              ),
                            ),
                            // Badge Statut de Paiement
                            Builder(
                              builder: (context) {
                                final payInfo = _getStudentPaymentInfo(userId, email, assigned);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: payInfo['bgColor'] as Color,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (payInfo['color'] as Color).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        payInfo['icon'] as IconData,
                                        size: 11,
                                        color: payInfo['color'] as Color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        payInfo['label'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: payInfo['color'] as Color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (eligibleAttestations.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFD97706)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Attestation Prête',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(email, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
                              ],
                            ),
                            if (phone.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
                                ],
                              ),
                            if (matricule.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text('Matricule : $matricule', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Formations & Modules Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Formations & Modules inscrits (${enrolledFormationTitles.length} formation${enrolledFormationTitles.length > 1 ? 's' : ''})',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (enrolledFormationTitles.isEmpty)
                      Text(
                        'Aucune formation assignée pour le moment.',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic),
                      )
                    else ...[
                      // Formations Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: enrolledFormationTitles.map((fTitle) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.book_rounded, size: 13, color: AppTheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  fTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      // Modules Badges (if any)
                      if (enrolledModuleTitles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: enrolledModuleTitles.map((mTitle) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
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
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

                            // Bottom Actions Bar (Fluid & Responsive without overlap)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 15),
                        label: Text('Détails', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        onPressed: () => _showApprenantDetail(userId, data),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.assignment_turned_in_rounded, size: 15, color: AppTheme.primary),
                        label: Text('Affecter formations', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        onPressed: () => _assignFormationDialog(userId),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF0D9488)),
                        label: Text('Fin de formation', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488))),
                        onPressed: () => _showStudentFormationCompletionDialog(userId, data),
                      ),
                      if (eligibleAttestations.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.workspace_premium_rounded, size: 15, color: Color(0xFFFBBF24)),
                          label: Text('Attestation', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            try {
                              final target = eligibleAttestations.first;
                              final pdfBytes = await PdfService().generateAttestationPdf(
                                inscription: target['inscription'],
                                formation: target['formation'],
                              );
                              await PdfService().printOrDownloadPdf(
                                pdfBytes: pdfBytes,
                                filename: 'Attestation_${prenom}_${nom}_${target['formation'].titre}.pdf',
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
                                );
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: estActif ? 'Bloquer' : 'Débloquer',
                        icon: Icon(
                          estActif ? Icons.block_rounded : Icons.check_circle_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        onPressed: () => _toggleBlockUser(userId, estActif),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 20),
                        onPressed: () => _confirmDeleteApprenant(context, userId, fullName),
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

  Future<void> _confirmDeleteApprenant(
    BuildContext context,
    String id,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer l\'apprenant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "$name" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteUser(id);
      await _db.deleteInscription(id);
      final studentInscriptions = _db.getInscriptions().where((ins) =>
          ins.etudiantId == id || ins.id == id
      ).toList();
      for (final ins in studentInscriptions) {
        await _db.deleteInscription(ins.id);
      }
      _applyFilter();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Apprenant supprimé avec succès'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _toggleBlockUser(String userId, bool block) async {
    await _db.setUserActive(userId, !block);
    _applyFilter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(block ? 'Apprenant bloqué' : 'Apprenant débloqué')),
    );
  }

  Future<void> _assignFormationDialog(String userId) async {
    final user = _db.getUserById(userId);
    final formations = _db.getFormations();
    Formation? selected;
    final modulesControllers = <String, TextEditingController>{};

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Affectation Manuelle des Formations',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currently assigned formations list
                      Builder(builder: (context) {
                        final currentAssigned = (user?.assignedFormations ?? []).map((a) => Map<String, dynamic>.from(a as Map)).toList();
                        if (currentAssigned.isEmpty) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Aucune formation assignée actuellement à cet apprenant.',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Formations actuellement assignées (${currentAssigned.length})',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            ...currentAssigned.map((a) {
                              final fId = a['formationId']?.toString() ?? '';
                              final fTitle = a['title']?.toString() ?? _db.getFormationById(fId)?.titre ?? 'Formation';
                              final mods = (a['modules'] as List? ?? []);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.school_rounded, size: 16, color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(fTitle, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                                          if (mods.isNotEmpty)
                                            Text(
                                              '${mods.length} module(s)',
                                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                      tooltip: 'Retirer cette formation',
                                      onPressed: () async {
                                        final targetUser = _db.getUserById(userId);
                                        if (targetUser != null) {
                                          final updatedAssignments = targetUser.assignedFormations
                                              .map((item) => Map<String, dynamic>.from(item as Map))
                                              .where((item) => item['formationId'] != fId)
                                              .toList();
                                          final updatedUser = User(
                                            id: targetUser.id,
                                            email: targetUser.email,
                                            nom: targetUser.nom,
                                            prenom: targetUser.prenom,
                                            phone: targetUser.phone,
                                            matricule: targetUser.matricule,
                                            role: targetUser.role,
                                            password: targetUser.password,
                                            photoUrl: targetUser.photoUrl,
                                            assignedFormations: updatedAssignments,
                                            estActif: targetUser.estActif,
                                            dateCreation: targetUser.dateCreation,
                                            dateModification: DateTime.now(),
                                          );
                                          await _db.addUser(updatedUser);
                                          setState(() {});
                                          this.setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                          ],
                        );
                      }),
                      Text(
                        'Attribuer une nouvelle formation',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Container(
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
                        child: DropdownButtonFormField<Formation>(
                          initialValue:
                              selected != null &&
                                  formations.any((f) => f.id == selected!.id)
                              ? selected
                              : null,
                          items: formations
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f.titre),
                                ),
                              )
                              .toList(),
                          onChanged: (f) {
                            setState(() {
                              selected = f;
                              modulesControllers.clear();
                              if (selected != null) {
                                for (final m in selected!.modules) {
                                  modulesControllers[m] = TextEditingController(
                                    text: '10',
                                  );
                                }
                              }
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Sélectionner une formation',
                            prefixIcon: const Icon(
                              Icons.school_rounded,
                              color: AppTheme.primary,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (selected != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attribuer les heures par module',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...selected!.modules.map((m) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.book_rounded,
                                        color: AppTheme.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          m,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          controller: modulesControllers[m],
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'h',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
                if (selected != null)
                  ElevatedButton(
                    onPressed: () async {
                      if (selected == null) return;
                      final targetUser = user ?? _db.getUserById(userId);
                      if (targetUser != null) {
                        final assignedModules = selected!.modules.map((m) {
                          final hours = int.tryParse(modulesControllers[m]?.text ?? '10') ?? 10;
                          return {
                            'title': m,
                            'assignedHours': hours > 0 ? hours : 10,
                            'doneHours': 0,
                          };
                        }).toList();

                        final existingAssignments = targetUser.assignedFormations
                            .map((a) => Map<String, dynamic>.from(a as Map))
                            .toList();
                        existingAssignments.removeWhere((a) => a['formationId'] == selected!.id);
                        existingAssignments.add({
                          'formationId': selected!.id,
                          'title': selected!.titre,
                          'modules': assignedModules,
                          'isCompleted': false,
                          'dateAssigned': DateTime.now().toIso8601String(),
                        });

                        final updatedUser = User(
                          id: targetUser.id,
                          email: targetUser.email,
                          nom: targetUser.nom,
                          prenom: targetUser.prenom,
                          phone: targetUser.phone,
                          matricule: targetUser.matricule,
                          role: targetUser.role,
                          password: targetUser.password,
                          photoUrl: targetUser.photoUrl,
                          assignedFormations: existingAssignments,
                          estActif: targetUser.estActif,
                          dateCreation: targetUser.dateCreation,
                          dateModification: DateTime.now(),
                        );
                        await _db.addUser(updatedUser);
                        _applyFilter();
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attribution enregistrée avec succès'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    child: const Text('Attribuer cette formation'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateApprenantDialog() {
    final prenomController = TextEditingController();
    final nomController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Créer un apprenant',
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
                gradient: isSubmitting
                    ? null
                    : const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                      ),
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
                              const SnackBar(
                                content: Text('Veuillez remplir tous les champs obligatoires (prénom, nom, email).'),
                              ),
                            );
                            return;
                          }

                          final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
                          if (!emailRegExp.hasMatch(email)) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Veuillez fournir une adresse email valide.',
                                ),
                              ),
                            );
                            return;
                          }

                          final existingUser = _db.getUsers().where((u) => u.email.toLowerCase() == email).firstOrNull;
                          if (existingUser != null) {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(
                                content: Text('Un compte avec cette adresse email existe déjà.'),
                              ),
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
                              role: UserRole.apprenant,
                            );

                            if (!localContext.mounted) return;
                            Navigator.pop(localContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apprenant créé avec succès'),
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

  void _showApprenantDetail(String userId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final matricule = (data['matricule'] ?? '').toString().trim();
        final assignedOriginal =
            (data['assignedFormations'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        final assignedCopy = assignedOriginal
            .map(
              (a) => {
                'formationId': a['formationId'],
                'title': a['title'],
                'dateAssigned': a['dateAssigned'],
                'modeSuivi': a['modeSuivi'],
                'attendance': (a['attendance'] as List<dynamic>? ?? [])
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList(),
                'modules': (a['modules'] as List<dynamic>? ?? [])
                    .map(
                      (m) =>
                          Map<String, dynamic>.from(m as Map<String, dynamic>),
                    )
                    .toList(),
              },
            )
            .toList();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              '${data['prenom'] ?? ''} ${data['nom'] ?? ''}',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['email'] ?? '',
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.badge_rounded,
                          color: AppTheme.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            matricule.isNotEmpty
                                ? 'Matricule : $matricule'
                                : 'Matricule non attribué',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bilan Financier & Statut de Paiement
                  Builder(
                    builder: (context) {
                      final payInfo = _getStudentPaymentInfo(
                        userId,
                        (data['email'] ?? '').toString(),
                        assignedCopy,
                      );
                      final totalDue = payInfo['totalDue'] as double;
                      final totalPaid = payInfo['totalPaid'] as double;
                      final remaining = payInfo['remaining'] as double;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (payInfo['bgColor'] as Color),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (payInfo['color'] as Color).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      payInfo['icon'] as IconData,
                                      size: 16,
                                      color: payInfo['color'] as Color,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Statut Financier :',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: payInfo['color'] as Color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    payInfo['label'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Dû : ${totalDue.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
                                Text('Versé : ${totalPaid.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
                                Text('Reste : ${remaining.toStringAsFixed(0)} FCFA', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: remaining > 0 ? AppTheme.error : Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (assignedCopy.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Aucune formation attribuée',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formations attribuées',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...assignedCopy.map((a) {
                          final formation = _db.getFormationById(
                            (a['formationId'] ?? '').toString(),
                          );
                          final storedMode = (a['modeSuivi'] ?? '')
                              .toString()
                              .trim();
                          final modality = storedMode.isNotEmpty
                              ? storedMode
                              : formation?.type == FormationType.enligne
                              ? 'En ligne'
                              : formation?.type == FormationType.mixte
                              ? 'Mixte'
                              : 'Présentiel';
                          final attendance =
                              (a['attendance'] as List<dynamic>? ?? [])
                                  .whereType<Map>()
                                  .map(
                                    (item) => Map<String, dynamic>.from(item),
                                  )
                                  .toList();
                          final presentCount = attendance
                              .where((item) => item['status'] == 'present')
                              .length;
                          final absentCount = attendance
                              .where((item) => item['status'] == 'absent')
                              .length;
                          final lastAttendance = attendance.isEmpty
                              ? null
                              : attendance.last;
                          final modules = (a['modules'] as List)
                              .cast<Map<String, dynamic>>();
                          int totalAssigned = 0;
                          int totalDone = 0;
                          for (final m in modules) {
                            totalAssigned += (m['assignedHours'] ?? 0) as int;
                            totalDone += (m['doneHours'] ?? 0) as int;
                          }
                          final formationProgress = totalAssigned == 0
                              ? 0.0
                              : (totalDone / totalAssigned).clamp(0.0, 1.0);

                          return Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Chip(
                                    avatar: Icon(
                                      modality == 'En ligne'
                                          ? Icons.laptop_mac_rounded
                                          : Icons.location_on_rounded,
                                      size: 15,
                                      color: AppTheme.primary,
                                    ),
                                    label: Text(
                                      'Suit : $modality',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (attendance.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Présences : $presentCount • Absences : $absentCount${lastAttendance != null ? ' • Dernier : ${lastAttendance['status'] == 'present' ? 'présent' : 'absent'}' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$totalDone / $totalAssigned heures',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: formationProgress,
                                                minHeight: 6,
                                                backgroundColor: Colors.black
                                                    .withValues(alpha: 0.08),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      AppTheme.error,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${(formationProgress * 100).toStringAsFixed(0)}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  ...modules
                                      .where((m) {
                                        final title = (m['title'] ?? '')
                                            .toString()
                                            .trim();
                                        final assignedH =
                                            (m['assignedHours'] ?? 0) as num;
                                        return title.isNotEmpty &&
                                            assignedH > 0;
                                      })
                                      .map((m) {
                                        final assignedH =
                                            (m['assignedHours'] ?? 0) as int;
                                        final doneH =
                                            (m['doneHours'] ?? 0) as int;
                                        final moduleProgress = assignedH == 0
                                            ? 0.0
                                            : (doneH / assignedH).clamp(
                                                0.0,
                                                1.0,
                                              );

                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      m['title'] ?? '',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '$doneH/$assignedH h',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppTheme
                                                                .primary,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value: moduleProgress,
                                                        minHeight: 4,
                                                        backgroundColor: Colors
                                                            .black
                                                            .withValues(
                                                              alpha: 0.08,
                                                            ),
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                              AppTheme.primary,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 60,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () async {
                                                            if (doneH <= 0) {
                                                              return;
                                                            }
                                                            final prev =
                                                                m['doneHours']
                                                                    as int? ??
                                                                0;
                                                            m['doneHours'] =
                                                                (prev - 1)
                                                                    .clamp(
                                                                      0,
                                                                      assignedH,
                                                                    );
                                                            setState(() {});
                                                            try {
                                                              await _updateModuleDoneHours(
                                                                userId,
                                                                a['formationId'],
                                                                m['title'],
                                                                -1,
                                                              );
                                                            } catch (e) {
                                                              m['doneHours'] =
                                                                  prev;
                                                              setState(() {});
                                                            }
                                                          },
                                                          child: Icon(
                                                            Icons
                                                                .remove_rounded,
                                                            size: 16,
                                                            color: AppTheme
                                                                .primary,
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        InkWell(
                                                          onTap: () async {
                                                            if (doneH >=
                                                                assignedH) {
                                                              return;
                                                            }
                                                            final prev =
                                                                m['doneHours']
                                                                    as int? ??
                                                                0;
                                                            m['doneHours'] =
                                                                (prev + 1)
                                                                    .clamp(
                                                                      0,
                                                                      assignedH,
                                                                    );
                                                            setState(() {});
                                                            try {
                                                              await _updateModuleDoneHours(
                                                                userId,
                                                                a['formationId'],
                                                                m['title'],
                                                                1,
                                                              );
                                                            } catch (e) {
                                                              m['doneHours'] =
                                                                  prev;
                                                              setState(() {});
                                                            }
                                                          },
                                                          child: Icon(
                                                            Icons.add_rounded,
                                                            size: 16,
                                                            color: AppTheme
                                                                .primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  SizedBox(height: 20),
                  FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                    future: _getApprenantSchedule(userId, data),
                    builder: (context, scheduleSnapshot) {
                      if (scheduleSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.primary,
                            ),
                            strokeWidth: 2,
                          ),
                        );
                      }

                      final scheduleByDay = scheduleSnapshot.data ?? {};

                      if (scheduleByDay.isEmpty) {
                        return SizedBox.shrink();
                      }

                      final daysOrder = [
                        'Lundi',
                        'Mardi',
                        'Mercredi',
                        'Jeudi',
                        'Vendredi',
                        'Samedi',
                        'Dimanche',
                      ];
                      final scheduleDays = daysOrder
                          .where((d) => scheduleByDay.containsKey(d))
                          .toList();

                      if (scheduleDays.isEmpty) {
                        return SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emploi du temps',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          ...scheduleDays.map((day) {
                            final daySchedules = scheduleByDay[day] ?? [];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    ...daySchedules.map((s) {
                                      final debut = s['heureDebut'] ?? '';
                                      final fin = s['heureFin'] ?? '';
                                      final formateur = s['formateur'] ?? '';
                                      final modules =
                                          s['modules'] as List? ?? [];
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$debut - $fin',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              formateur,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (modules.isNotEmpty)
                                              Text(
                                                'Modules: ${modules.join(", ")}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  color: AppTheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.badge_rounded, size: 16),
                label: const Text('Carte Étudiant'),
                onPressed: () async {
                  try {
                    final pdfBytes = await PdfService().generateStudentCardPdf(
                      prenom: data['prenom'] ?? '',
                      nom: data['nom'] ?? '',
                      email: data['email'] ?? '',
                      telephone: data['phone'] ?? data['telephone'] ?? 'N/A',
                      matricule: data['matricule'],
                    );
                    await PdfService().printOrDownloadPdf(
                      pdfBytes: pdfBytes,
                      filename: 'carte_${data['nom'] ?? 'etudiant'}.pdf',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0D9488)),
                label: const Text('Fin de formation'),
                onPressed: () {
                  Navigator.pop(context);
                  _showStudentFormationCompletionDialog(userId, data);
                },
              ),
              if (_isStudentEligibleForAttestation(userId, data))
                ElevatedButton.icon(
                  icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFFBBF24)),
                  label: const Text('Télécharger Attestation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      final email = (data['email'] ?? '').toString();
                      final userInscriptions = _db.getInscriptions().where((ins) =>
                          (ins.email?.toLowerCase() == email.toLowerCase() || ins.etudiantId == userId) &&
                          ins.status == InscriptionStatus.acceptee).toList();
                      
                      final firstValid = userInscriptions.firstWhere(
                        (ins) => _db.isStudentFormationCompleted(studentId: userId, formationId: ins.formationId) && _db.getInscriptionBalance(ins.id) <= 0,
                        orElse: () => userInscriptions.first,
                      );

                      final formation = _db.getFormationById(firstValid.formationId) ??
                          Formation(
                            id: firstValid.formationId,
                            titre: 'Formation Professionnelle',
                            description: '',
                            modules: [],
                            prix: 0,
                            type: FormationType.presentielle,
                            status: FormationStatus.terminee,
                            dureeSemaines: 12,
                            horaires: const [],
                            dateCreation: DateTime.now(),
                            formateurIds: const [],
                          );

                      final pdfBytes = await PdfService().generateAttestationPdf(
                        inscription: firstValid,
                        formation: formation,
                      );
                      await PdfService().printOrDownloadPdf(
                        pdfBytes: pdfBytes,
                        filename: 'Attestation_${data['prenom'] ?? ''}_${data['nom'] ?? 'etudiant'}_${formation.titre}.pdf',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                      }
                    }
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isStudentEligibleForAttestation(String userId, Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim();
    final assigned = (data['assignedFormations'] as List<dynamic>? ?? []);
    final userInscriptions = _db.getInscriptions().where((ins) =>
        (ins.email?.toLowerCase() == email.toLowerCase() || ins.etudiantId == userId) &&
        ins.status == InscriptionStatus.acceptee).toList();

    for (final ins in userInscriptions) {
      final f = _db.getFormationById(ins.formationId);
      if (f == null) continue;
      final assignedItem = assigned.where((item) => item['formationId'] == f.id).firstOrNull;
      final isCompletedByAdmin = (assignedItem != null && assignedItem['isCompleted'] == true) || f.status == FormationStatus.terminee;
      if (!isCompletedByAdmin) continue;

      final balance = _db.getInscriptionBalance(ins.id);
      final payments = _db.getPaymentsForInscription(ins.id);
      final totalPaid = payments.fold<double>(0.0, (s, p) => s + p.montant);
      final isPaid = balance <= 0 && (f.prix == 0 || totalPaid >= f.prix || ins.paiementEffectue);
      if (isPaid) return true;
    }
    return false;
  }

  /// Boîte de dialogue pour valider individuellement la fin de formation d'un étudiant par l'admin
  Future<void> _showStudentFormationCompletionDialog(String userId, Map<String, dynamic> data) async {
    final prenom = (data['prenom'] ?? '').toString().trim();
    final nom = (data['nom'] ?? '').toString().trim();
    final fullName = (prenom.isNotEmpty || nom.isNotEmpty) ? '$prenom $nom' : 'Apprenant';
    final email = (data['email'] ?? '').toString().trim();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentUser = _db.getUserById(userId);
            final currentAssigned = currentUser?.assignedFormations ?? (data['assignedFormations'] as List? ?? []);
            final allFormations = _db.getFormations();

            final userInscriptions = _db.getInscriptions().where((ins) =>
                (ins.email?.toLowerCase() == email.toLowerCase() || ins.etudiantId == userId) &&
                ins.status == InscriptionStatus.acceptee).toList();

            final distinctFormationIds = <String>{};
            for (final a in currentAssigned) {
              if (a is Map && a['formationId'] != null) {
                distinctFormationIds.add(a['formationId'].toString());
              }
            }
            for (final ins in userInscriptions) {
              distinctFormationIds.add(ins.formationId);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF0D9488), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fin de Formation - Décision Admin', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(fullName, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: distinctFormationIds.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Aucune formation assignée à cet étudiant.',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cochez ou validez la fin de formation pour chaque programme. Si l\'étudiant a également soldé 100% de ses paiements, son attestation officielle sera automatiquement débloquée.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            ...distinctFormationIds.map((fId) {
                              final formation = allFormations.where((f) => f.id == fId).firstOrNull ??
                                  Formation(
                                    id: fId,
                                    titre: 'Formation #$fId',
                                    description: '',
                                    modules: [],
                                    prix: 0,
                                    type: FormationType.presentielle,
                                    status: FormationStatus.enCours,
                                    dureeSemaines: 4,
                                    horaires: const [],
                                    dateCreation: DateTime.now(),
                                    formateurIds: const [],
                                  );

                              final assignedItem = currentAssigned.where((a) => a is Map && a['formationId'] == fId).firstOrNull as Map?;
                              final isCompleted = (assignedItem != null && assignedItem['isCompleted'] == true) || formation.status == FormationStatus.terminee;

                              final inscription = userInscriptions.where((i) => i.formationId == fId).firstOrNull;
                              final balance = inscription != null ? _db.getInscriptionBalance(inscription.id) : 0.0;
                              final payments = inscription != null ? _db.getPaymentsForInscription(inscription.id) : [];
                              final totalPaid = payments.fold<double>(0.0, (s, p) => s + p.montant);
                              final isPaid = balance <= 0 && (formation.prix == 0 || totalPaid >= formation.prix || (inscription?.paiementEffectue ?? false));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCompleted ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                                    width: isCompleted ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                                          color: isCompleted ? const Color(0xFF16A34A) : Colors.orange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            formation.titre,
                                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isCompleted ? 'Statut : Formation Terminée' : 'Statut : En cours',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isPaid ? 'Paiement : 100% Soldé' : 'Paiement : Solde restant ${balance.toStringAsFixed(0)} FCFA',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCompleted ? Colors.grey.shade700 : const Color(0xFF0D9488),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(isCompleted ? Icons.restart_alt_rounded : Icons.check_circle_rounded, size: 16),
                                          label: Text(
                                            isCompleted ? 'Remettre en cours' : 'Marquer comme Terminée',
                                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                          onPressed: () async {
                                            await _db.setStudentFormationCompletion(
                                              studentId: userId,
                                              formationId: fId,
                                              isCompleted: !isCompleted,
                                            );
                                            setDialogState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        if (isCompleted && isPaid) ...[
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E3A8A),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFFFBBF24)),
                                            label: Text('Attestation PDF', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                                            onPressed: () async {
                                              try {
                                                final targetInscription = inscription ??
                                                    Inscription(
                                                      id: 'ins_${userId}_$fId',
                                                      etudiantId: userId,
                                                      formationId: fId,
                                                      status: InscriptionStatus.acceptee,
                                                      dateInscription: DateTime.now(),
                                                      paiementEffectue: true,
                                                      nom: nom,
                                                      prenom: prenom,
                                                      email: email,
                                                      telephone: data['phone'] ?? data['telephone'] ?? '',
                                                      modules: formation.modules,
                                                    );

                                                final pdfBytes = await PdfService().generateAttestationPdf(
                                                  inscription: targetInscription,
                                                  formation: formation,
                                                );

                                                await PdfService().printOrDownloadPdf(
                                                  pdfBytes: pdfBytes,
                                                  filename: 'Attestation_${prenom}_${nom}_${formation.titre}.pdf',
                                                );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
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
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateModuleDoneHours(
    String userId,
    String formationId,
    String moduleTitle,
    int delta,
  ) async {
    await LocalDataService().updateModuleDoneHours(
      userId,
      formationId,
      moduleTitle,
      delta,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getApprenantSchedule(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final formations = LocalDataService().getFormations();
    Map<String, List<Map<String, dynamic>>> scheduleByDay = {};
    final assignments = (data['assignedFormations'] as List? ?? [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    for (var f in formations) {
      final assignment = assignments.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['formationId'] == f.id,
        orElse: () => null,
      );
      if (assignment == null) continue;
      final selectedModules = (assignment['modules'] as List? ?? [])
          .map(
            (item) => item is Map ? item['title']?.toString() : item.toString(),
          )
          .whereType<String>()
          .toSet();
      for (var h in f.horaires) {
        if (h.module?.isNotEmpty == true && !selectedModules.contains(h.module)) {
          continue;
        }
        scheduleByDay.putIfAbsent(h.jour, () => []).add({
          'heureDebut': h.heureDebut,
          'heureFin': h.heureFin,
          'formateur': 'Formateur',
          'modules': h.module?.isNotEmpty == true
              ? [h.module]
              : selectedModules.toList(),
          'groupe': h.groupe,
          'modalite': h.modalite,
          'lieuOuLien': h.lieuOuLien,
        });
      }
    }
    return scheduleByDay;
  }
}
