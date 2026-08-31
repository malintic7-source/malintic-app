import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Services/local_storage.dart';
import 'package:gestion_formations/utils/file_saver.dart';

class ShareFormationDialog extends StatefulWidget {
  final Formation formation;

  const ShareFormationDialog({
    super.key,
    required this.formation,
  });

  static Future<void> show(BuildContext context, Formation formation) async {
    await showDialog(
      context: context,
      builder: (context) => ShareFormationDialog(formation: formation),
    );
  }

  @override
  State<ShareFormationDialog> createState() => _ShareFormationDialogState();
}

class _ShareFormationDialogState extends State<ShareFormationDialog> {
  final GlobalKey _qrKey = GlobalKey();
  int _selectedMode = 0; // 0 = Vercel (Internet), 1 = Local (Wi-Fi / LAN)
  
  static const String _defaultVercelBase = 'https://malintic-app.vercel.app';
  String _publicBase = _defaultVercelBase;
  String _localBase = 'http://localhost';
  final TextEditingController _customIpController = TextEditingController();
  bool _isLoadingNetwork = false;
  final LocalStorage _storage = LocalStorage();

  @override
  void initState() {
    super.initState();
    _initUrls();
  }

  @override
  void dispose() {
    _customIpController.dispose();
    super.dispose();
  }

  Future<void> _initUrls() async {
    setState(() => _isLoadingNetwork = true);
    try {
      final currentHost = Uri.base.host.toLowerCase();
      final currentPort = Uri.base.port;

      // 1. Détection base Vercel / Internet
      if (currentHost.contains('vercel.app')) {
        _publicBase = Uri.base.origin;
      } else {
        _publicBase = _defaultVercelBase;
      }

      // 2. Récupérer l'IP LAN préférée enregistrée en local (si existante)
      final rawSavedLanIp = _storage.getItem('preferred_lan_ip')?.trim() ?? '';
      // Nettoyer tout port 8080 (réservé à Apache) ou 5001 pour garantir que le scan mobile tape sur Docker Nginx port 80
      final savedLanIp = rawSavedLanIp.replaceAll(':8080', '').replaceAll(':5001', '');
      if (savedLanIp != rawSavedLanIp) {
        _storage.setItem('preferred_lan_ip', savedLanIp);
      }

      // 3. Détection base locale / LAN
      String detectedLocalHost = currentHost.isNotEmpty ? currentHost : 'localhost';
      String portSuffix = '';
      if (currentPort != 80 && currentPort != 443 && currentPort != 0 && currentPort != 8080 && currentPort != 5001) {
        portSuffix = ':$currentPort';
      }

      if (savedLanIp.isNotEmpty) {
        final withHttp = savedLanIp.startsWith('http://') || savedLanIp.startsWith('https://')
            ? savedLanIp
            : 'http://$savedLanIp';
        _localBase = withHttp;
        _customIpController.text = savedLanIp.replaceFirst(RegExp(r'^https?:\/\/'), '');
      } else if (!detectedLocalHost.startsWith('127.') &&
          detectedLocalHost != 'localhost' &&
          !detectedLocalHost.startsWith('172.')) {
        _localBase = 'http://$detectedLocalHost$portSuffix';
        _customIpController.text = '$detectedLocalHost$portSuffix';
        _storage.setItem('preferred_lan_ip', '$detectedLocalHost$portSuffix');
      } else {
        _localBase = 'http://$detectedLocalHost$portSuffix';
        _customIpController.text = '$detectedLocalHost$portSuffix';
      }

      // Si nous sommes sur localhost ou 127.0.0.1, interroger l'API pour obtenir la vraie IP LAN Wi-Fi de l'hôte Windows
      if (detectedLocalHost == 'localhost' ||
          detectedLocalHost.startsWith('127.') ||
          detectedLocalHost.startsWith('172.')) {
        try {
          final apiUri = Uri.parse('/api/system/network-info');
          final response = await http.get(apiUri).timeout(
            const Duration(seconds: 2),
            onTimeout: () => http.Response('{}', 408),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final primaryIp = data['primaryIp']?.toString();
            final detectedIps = (data['detectedIps'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [];

            // Filtrer les IP internes Docker et APIPA
            final realIps = detectedIps
                .where((ip) =>
                    !ip.startsWith('172.') &&
                    !ip.startsWith('127.') &&
                    !ip.startsWith('169.254.') &&
                    ip != '0.0.0.0')
                .toList();

            final chosenIp = (primaryIp != null &&
                    !primaryIp.startsWith('172.') &&
                    !primaryIp.startsWith('127.') &&
                    !primaryIp.startsWith('169.254.'))
                ? primaryIp
                : (realIps.isNotEmpty ? realIps.first : null);

            if (chosenIp != null && chosenIp.isNotEmpty) {
              final finalPort = (currentPort != 80 && currentPort != 443 && currentPort != 0 && currentPort != 8080 && currentPort != 5001)
                  ? ':$currentPort'
                  : '';
              _localBase = 'http://$chosenIp$finalPort';
              _customIpController.text = '$chosenIp$finalPort';
              _storage.setItem('preferred_lan_ip', '$chosenIp$finalPort');
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingNetwork = false);
    }
  }

  String get _publicUrl => '$_publicBase/formation.html?id=${widget.formation.id}';
  String get _localUrl => '$_localBase/formation.html?id=${widget.formation.id}';
  String get _activeUrl => _selectedMode == 0 ? _publicUrl : _localUrl;

  Future<void> _shareWhatsApp() async {
    final text = '📚 *${widget.formation.titre}*\n\n'
        '${widget.formation.description}\n\n'
        '💰 *Tarif:* ${widget.formation.prix} FCFA\n'
        '⏱️ *Durée:* ${widget.formation.dureeSemaines} semaine(s)\n\n'
        '👉 *Inscrivez-vous ici:*\n$_activeUrl';
    final whatsappUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyLink(String url, String label) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('📋 $label copié dans le presse-papier !')),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadQrCode() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes != null) {
        final modeName = _selectedMode == 0 ? 'public' : 'local';
        await saveFile(
          bytes,
          'qr_formation_${widget.formation.titre.toLowerCase().replaceAll(' ', '_')}_$modeName.png',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📥 QR Code téléchargé avec succès !'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur téléchargement QR: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Widget _buildFormationPhoto({double size = 42, double radius = 10}) {
    final imageUrl = widget.formation.imageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64Part = imageUrl.split(',').last;
          final bytes = base64Decode(base64Part);
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildFallbackPhoto(size, radius),
            ),
          );
        } catch (_) {}
      } else if (imageUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildFallbackPhoto(size, radius),
          ),
        );
      }
    }
    return _buildFallbackPhoto(size, radius);
  }

  Widget _buildFallbackPhoto(double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.school_rounded, color: AppTheme.primary, size: size * 0.52),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppTheme.textSecondary;
    final isOnlineMode = _selectedMode == 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: cardBg,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. En-tête compact
              Row(
                children: [
                  _buildFormationPhoto(size: 40, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partager la formation',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          widget.formation.titre,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subtextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Sélecteur de Mode (Vercel vs LAN)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = 0),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isOnlineMode
                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isOnlineMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 15,
                                color: isOnlineMode ? const Color(0xFF16A34A) : subtextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lien Public (WAN)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: isOnlineMode ? FontWeight.w700 : FontWeight.w500,
                                  color: isOnlineMode ? const Color(0xFF16A34A) : subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = 1),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isOnlineMode
                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: !isOnlineMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_rounded,
                                size: 15,
                                color: !isOnlineMode ? AppTheme.primary : subtextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Wi-Fi Bureau (LAN)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: !isOnlineMode ? FontWeight.w700 : FontWeight.w500,
                                  color: !isOnlineMode ? AppTheme.primary : subtextColor,
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
              const SizedBox(height: 14),

              // 3. QR Code Centré & Responsive
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOnlineMode ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: _activeUrl,
                          version: QrVersions.auto,
                          size: 170,
                          backgroundColor: Colors.white,
                          embeddedImage: const AssetImage('images/Malintic.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(26, 26),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOnlineMode ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnlineMode ? Icons.public_rounded : Icons.wifi_rounded,
                                size: 12,
                                color: isOnlineMode ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOnlineMode
                                    ? 'Scan pour inscription en ligne'
                                    : 'Scan pour inscription sur le Wi-Fi local',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isOnlineMode ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Carte Unique du Lien Actif (sans redondance ni scroll forcé)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOnlineMode
                      ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4))
                      : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnlineMode ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOnlineMode ? Icons.public_rounded : Icons.wifi_rounded,
                          size: 15,
                          color: isOnlineMode ? const Color(0xFF16A34A) : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnlineMode ? 'Lien Inscription En Ligne :' : 'Lien Bureau (Wi-Fi / LAN) :',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOnlineMode ? const Color(0xFF166534) : AppTheme.primaryDark,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _copyLink(_activeUrl, isOnlineMode ? 'Lien En Ligne' : 'Lien Wi-Fi'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOnlineMode
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                  : AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: isOnlineMode ? const Color(0xFF16A34A) : AppTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copier',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isOnlineMode ? const Color(0xFF16A34A) : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      _activeUrl,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isOnlineMode ? const Color(0xFF15803D) : AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isOnlineMode) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: TextField(
                                controller: _customIpController,
                                style: GoogleFonts.poppins(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 192.168.1.15 ou localhost',
                                  labelText: 'IP / Hôte du réseau local',
                                  labelStyle: GoogleFonts.poppins(fontSize: 10),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                 onChanged: (val) {
                                   final clean = val.trim();
                                   if (clean.isNotEmpty) {
                                     setState(() {
                                       if (clean.startsWith('http://') || clean.startsWith('https://')) {
                                         _localBase = clean;
                                       } else {
                                         _localBase = 'http://$clean';
                                       }
                                     });
                                     _storage.setItem('preferred_lan_ip', clean);
                                   }
                                 },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: _isLoadingNetwork
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 17, color: AppTheme.primary),
                            tooltip: 'Détecter automatiquement l\'IP Wi-Fi',
                            onPressed: _initUrls,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Boutons d'actions principaux
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: Text(
                        'WhatsApp',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      onPressed: _shareWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: Text(
                        'QR Code',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11.5),
                      ),
                      onPressed: _downloadQrCode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: Text(
                        'Ouvrir',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11.5),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(_activeUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
