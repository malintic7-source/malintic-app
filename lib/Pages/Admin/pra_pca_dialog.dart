import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Services/pca_pra_service.dart';

/// Modal dialog interactif du Centre de Haute Disponibilité & PRA/PCA
class PraPcaCenterDialog extends StatefulWidget {
  const PraPcaCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PraPcaCenterDialog(),
    );
  }

  @override
  State<PraPcaCenterDialog> createState() => _PraPcaCenterDialogState();
}

class _PraPcaCenterDialogState extends State<PraPcaCenterDialog> {
  final PcaPraService _service = PcaPraService();
  bool _isLoading = false;
  PcaPraReport? _report;
  String? _statusMessage;
  bool _isSuccess = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    try {
      final rep = await _service.checkHealth();
      if (mounted) {
        setState(() {
          _report = rep;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateSnapshot() async {
    final labelCtrl = TextEditingController(text: 'manuel_${DateTime.now().hour}h${DateTime.now().minute}');
    final reasonCtrl = TextEditingController(text: 'Sauvegarde manuelle administrateur');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Créer un Point de Restauration PRA',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Un instantané complet et isolé de toutes les bases de données (formations, utilisateurs, inscriptions, paiements, séances) sera généré.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Label du point (ex: pre_inscriptions_sfp)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Motif / Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Générer le Snapshot'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final ok = await _service.createSnapshot(
      label: labelCtrl.text.trim(),
      reason: reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = ok;
      _statusMessage = ok
          ? 'Snapshot PRA créé avec succès !'
          : 'Échec de création du snapshot (serveur Docker injoignable).';
    });
    _refreshStatus();
  }

  Future<void> _handleForceReconcile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Réconciliation bidirectionnelle Docker <-> Supabase en cours...';
      _isSuccess = true;
    });
    final ok = await _service.forceReconcile();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = ok;
      _statusMessage = ok
          ? 'Réconciliation complète réussie (conflits résolus par horodatage LWW).'
          : 'Échec de la réconciliation. Vérifiez la connectivité réseau.';
    });
    _refreshStatus();
  }

  Future<void> _handleRestoreSnapshot(PraSnapshotInfo snap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Restaurer ce Point PRA ?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.error),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir restaurer le snapshot « ${snap.label} » du ${_formatDateTime(snap.createdAt)} ?\n\nL\'état actuel de la base sera écrasé et automatiquement re-synchronisé vers Supabase.',
          style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer la Restauration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final ok = await _service.restoreSnapshot(snap.filename);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = ok;
      _statusMessage = ok
          ? 'Restauration terminée et propagée avec succès.'
          : 'Erreur lors de la restauration du snapshot.';
    });
    _refreshStatus();
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final yr = dt.year;
    final hr = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$mon/$yr à $hr:$min';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.heroGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Centre PRA / PCA & Haute Disponibilité',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 15 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Réplication Multi-Nœuds (Docker • Supabase • Vercel • Ngrok)',
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 11 : 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feedback banner
              if (_statusMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                        color: _isSuccess ? AppTheme.success : AppTheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Contenu principal scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Grille des 4 Nœuds
                      Text(
                        'ÉTAT DES NŒUDS DE L\'INFRASTRUCTURE',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final count = constraints.maxWidth < 500 ? 1 : 2;
                          final nodeCards = [
                            _buildNodeCard(
                              _report?.dockerNode ?? NodeHealth(
                                name: 'Serveur Docker (LAN)',
                                type: 'docker',
                                isOnline: false,
                                details: 'En attente...',
                                lastChecked: DateTime.now(),
                              ),
                              Icons.storage_rounded,
                            ),
                            _buildNodeCard(
                              _report?.supabaseNode ?? NodeHealth(
                                name: 'Supabase Cloud (PG)',
                                type: 'supabase',
                                isOnline: false,
                                details: 'En attente...',
                                lastChecked: DateTime.now(),
                              ),
                              Icons.cloud_circle_rounded,
                            ),
                            _buildNodeCard(
                              _report?.vercelNode ?? NodeHealth(
                                name: 'Vercel Edge (Frontend Web)',
                                type: 'vercel',
                                isOnline: true,
                                details: 'Multi-utilisateurs actif',
                                lastChecked: DateTime.now(),
                              ),
                              Icons.public_rounded,
                            ),
                            _buildNodeCard(
                              _report?.ngrokNode ?? NodeHealth(
                                name: 'Tunnel Sécurisé (Ngrok)',
                                type: 'ngrok',
                                isOnline: false,
                                details: 'Passerelle WAN/Télétravail',
                                lastChecked: DateTime.now(),
                              ),
                              Icons.vpn_lock_rounded,
                            ),
                          ];

                          if (count == 1) {
                            return Column(children: nodeCards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList());
                          }
                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: isMobile ? 2.2 : 2.5,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: nodeCards,
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // 2. Barre d'actions PRA / PCA
                      Text(
                        'ACTIONS DE CONTINUITÉ & REPRISE D\'ACTIVITÉ (PRA / PCA)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleCreateSnapshot,
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: Text(
                              'Créer un Snapshot PRA',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleForceReconcile,
                            icon: const Icon(Icons.sync_alt_rounded, size: 16),
                            label: Text(
                              'Forcer la Réconciliation 2-Way',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _refreshStatus,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              'Actualiser Statut',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Liste des Snapshots PRA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'POINTS DE RESTAURATION DISPONIBLES (${_report?.snapshots.length ?? 0})',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Rotation auto: 10 derniers',
                            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black45),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_report?.snapshots.isEmpty ?? true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text(
                              'Aucun instantané PRA archivé pour le moment. Cliquez sur « Créer un Snapshot PRA » ci-dessus.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...(_report!.snapshots.map((snap) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          snap.label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${(snap.sizeBytes / 1024).toStringAsFixed(1)} KB',
                                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatDateTime(snap.createdAt)} • ${snap.reason.isNotEmpty ? snap.reason : 'Automatique'}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                    if (snap.counts.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Formations: ${snap.counts['formations'] ?? 0} • Inscriptions: ${snap.counts['inscriptions'] ?? 0} • Utilisateurs: ${snap.counts['users'] ?? 0} • Paiements: ${snap.counts['payments'] ?? 0}',
                                        style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black54),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : () => _handleRestoreSnapshot(snap),
                                icon: const Icon(Icons.restore_rounded, size: 14, color: AppTheme.error),
                                label: Text(
                                  'Restaurer',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFECACA)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ],
                          ),
                        ))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCard(NodeHealth node, IconData icon) {
    final isOnline = node.isOnline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  node.details,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: isOnline ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
