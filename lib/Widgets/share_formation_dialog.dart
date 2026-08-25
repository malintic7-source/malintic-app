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
import 'package:gestion_formations/utils/app_logger.dart';
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
  int _selectedMode = 0; // 0 = Public (Internet / WAN), 1 = Local (Wi-Fi / LAN)
  String _publicBase = 'https://boil-prude-curry.ngrok-free.dev';
  String _localBase = 'http://192.168.1.10:8080';
  final TextEditingController _customIpController = TextEditingController();

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
    // 1. Détection depuis l'URL du navigateur actuel si disponible
    try {
      final currentOrigin = Uri.base.origin;
      final currentHost = Uri.base.host.toLowerCase();
      final currentPort = Uri.base.port;

      if (currentOrigin.startsWith('http')) {
        if (currentHost.contains('ngrok') || currentHost.contains('cloudflare') || (!currentHost.contains('localhost') && !currentHost.startsWith('127.') && !currentHost.startsWith('192.168.') && !currentHost.startsWith('10.') && !currentHost.endsWith('.local') && !currentHost.contains('vercel.app'))) {
          _publicBase = currentOrigin;
        } else {
          _localBase = currentOrigin;
        }
      }

      // 2. Interroger l'API pour récupérer les configurations réseau réelles
      final response = await http.get(
        Uri.parse('/api/system/network-info'),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => http.Response('{}', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final apiPublicUrl = data['publicUrl'] as String?;
        if (apiPublicUrl != null && apiPublicUrl.trim().isNotEmpty) {
          _publicBase = apiPublicUrl.trim();
        }
        final detectedIps = data['detectedIps'] as List<dynamic>?;
        if (detectedIps != null && detectedIps.isNotEmpty) {
          final realIps = detectedIps.map((e) => e.toString()).where((ip) => !ip.startsWith('172.') && !ip.startsWith('127.')).toList();
          if (realIps.isNotEmpty) {
            final firstIp = realIps.first;
            final portSuffix = (currentPort != 80 && currentPort != 443 && currentPort != 0) ? ':$currentPort' : ':8080';
            _localBase = 'http://$firstIp$portSuffix';
            _customIpController.text = firstIp;
          }
        }
      }
    } catch (e, s) {
      // Fallback gracieux sur les valeurs par défaut
      logHandledError(
        'Détection réseau impossible, URL locale par défaut',
        e,
        s,
      );
    }

    if (mounted) {
      setState(() {});
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
        '👉 *Inscrivez-vous ici:*\n$_publicUrl';
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
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
        await saveFile(bytes, 'qr_formation_${widget.formation.titre.toLowerCase().replaceAll(' ', '_')}_$modeName.png');
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

  Widget _buildFormationPhoto({double size = 46, double radius = 12}) {
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
        } catch (e, s) {
          logHandledError('Photo base64 illisible', e, s);
        }
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      title: Row(
        children: [
          _buildFormationPhoto(size: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partager la formation',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  widget.formation.titre,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black45),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Formation Snapshot Card with Photo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildFormationPhoto(size: 52, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.formation.titre,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${widget.formation.prix} FCFA',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.formation.dureeSemaines} sem.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Segmented Control (Public vs Local)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = 0),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedMode == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 16,
                                color: _selectedMode == 0 ? const Color(0xFF16A34A) : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lien Public (Internet)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: _selectedMode == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: _selectedMode == 0 ? const Color(0xFF16A34A) : Colors.black54,
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
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedMode == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lan_rounded,
                                size: 16,
                                color: _selectedMode == 1 ? AppTheme.primary : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Lien Local (Wi-Fi / LAN)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: _selectedMode == 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: _selectedMode == 1 ? AppTheme.primary : Colors.black54,
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
              const SizedBox(height: 16),
              // QR Code View
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMode == 0 ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
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
                    children: [
                      QrImageView(
                        data: _activeUrl,
                        version: QrVersions.auto,
                        size: isMobile ? 180 : 200,
                        backgroundColor: Colors.white,
                        embeddedImage: const AssetImage('images/Malintic.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(28, 28),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _selectedMode == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedMode == 0 ? '🌐 Scan pour inscription en ligne' : '🏢 Scan pour inscription sur le Wi-Fi local',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _selectedMode == 0 ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 1. Encadré Lien Public
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedMode == 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMode == 0 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                    width: _selectedMode == 0 ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.public_rounded, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          'Lien Public (Internet / WhatsApp) :',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _copyLink(_publicUrl, 'Lien Public'),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(
                                  'Copier',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _publicUrl,
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF15803D), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 2. Encadré Lien Local
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedMode == 1 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMode == 1 ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                    width: _selectedMode == 1 ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lan_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Lien Local Bureau (Wi-Fi / LAN) :',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _copyLink(_localUrl, 'Lien Local Wi-Fi'),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.copy_rounded, size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Copier',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _localUrl,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                    if (_selectedMode == 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: TextField(
                                controller: _customIpController,
                                style: GoogleFonts.poppins(fontSize: 11),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 192.168.1.10 ou 10.0.0.5',
                                  labelText: 'IP / Port du réseau local',
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
                                      } else if (clean.contains(':')) {
                                        _localBase = 'http://$clean';
                                      } else {
                                        _localBase = 'http://$clean:8080';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primary),
                            tooltip: 'Redétecter le réseau',
                            onPressed: _initUrls,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        // WhatsApp button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            elevation: 0,
          ),
          icon: const Icon(Icons.chat_rounded, size: 18),
          label: Text('WhatsApp', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
          onPressed: _shareWhatsApp,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Download QR code
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('QR Code', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
              onPressed: _downloadQrCode,
            ),
            const SizedBox(width: 8),
            // Test / Open in browser
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Ouvrir', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
              onPressed: () async {
                final uri = Uri.parse(_activeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
