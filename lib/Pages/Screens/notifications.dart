import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestion_formations/Models/notification.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/notifications_services.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/formatters.dart';
import 'package:gestion_formations/utils/ui_feedback.dart';
// invoice and pdf helper imports removed (unused)

class NotificationsPage extends StatefulWidget {
  final User user;

  const NotificationsPage({super.key, required this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with TickerProviderStateMixin {
  final NotificationsService _notificationsService = NotificationsService();
  late AnimationController _fadeController;
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  bool get _canBroadcast =>
      widget.user.role == UserRole.admin ||
      widget.user.role == UserRole.dg ||
      widget.user.role == UserRole.assistant;

  @override
  Widget build(BuildContext context) {
    return _buildPageWrapper(
      child: FadeTransition(
        opacity: _fadeController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Restez informé des mises à jour, paiements et inscriptions',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canBroadcast)
                  ElevatedButton.icon(
                    onPressed: _showBroadcastDialog,
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Diffuser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Toutes'),
                  selected: !_onlyUnread,
                  onSelected: (selected) {
                    if (selected) setState(() => _onlyUnread = false);
                  },
                  selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: !_onlyUnread ? FontWeight.w700 : FontWeight.w500,
                    color: !_onlyUnread ? AppTheme.primary : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Non lues'),
                  selected: _onlyUnread,
                  onSelected: (selected) {
                    if (selected) setState(() => _onlyUnread = true);
                  },
                  selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: _onlyUnread ? FontWeight.w700 : FontWeight.w500,
                    color: _onlyUnread ? AppTheme.primary : Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _notificationsService.markAllAsReadForUser(
                      userId: widget.user.id,
                      userEmail: widget.user.email,
                      userRole: widget.user.role.toString(),
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Toutes les notifications ont été marquées comme lues.'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primary),
                  label: Text(
                    'Tout marquer comme lu',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStudentNotificationList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPageWrapper({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? fixedWidth,
  }) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = fixedWidth ?? (width > 1200 ? 1100.0 : width * 0.95);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentNotificationList(BuildContext context) {
    final notificationsStream = _notificationsService.watchNotificationsForUser(
      userId: widget.user.id,
      userEmail: widget.user.email,
      userRole: widget.user.role.toString(),
    );

    return StreamBuilder<List<AppNotification>>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        var notifications = snapshot.data ?? [];
        if (_onlyUnread) {
          notifications = notifications.where((n) => !n.readBy.contains(widget.user.id)).toList();
        }

        if (notifications.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 56, color: AppTheme.textSecondary),
                  const SizedBox(height: 14),
                  Text(
                    _onlyUnread ? 'Aucune notification non lue' : 'Aucune notification',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStudentNotificationCard(context, notifications[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentNotificationCard(BuildContext context, AppNotification notification) {
    final isRead = notification.readBy.contains(widget.user.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNotificationDetails(notification),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isRead ? Colors.transparent : AppTheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty)
                Stack(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Image.network(
                        notification.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(Icons.notifications, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                    if (!isRead)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      notification.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    // Bouton Télécharger facture si applicable
                    if (notification.title.contains('Paiement') || notification.title.contains('Inscription'))
                      GestureDetector(
                        onTap: () => _downloadInvoice(notification),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Télécharger facture',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FutureBuilder<User?>(
                          future: _lookupUser(notification.senderId),
                          builder: (context, snapshot) {
                            final senderName = snapshot.data != null
                                ? '${snapshot.data!.prenom} ${snapshot.data!.nom}'
                                : 'Admin';
                            return Text(
                              senderName,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        Text(
                          AppFormat.relativeFromNow(notification.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (!isRead) ...[
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                await _markRead(notification.id);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 9),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Marquer comme lu',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<User?> _lookupUser(String userId) async {
    final users = await AuthProvider().watchUsers().first;
    for (final user in users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  Future<void> _showNotificationDetails(AppNotification notification) async {
    if (!notification.readBy.contains(widget.user.id)) {
      await _notificationsService.markNotificationRead(
        notificationId: notification.id,
        userId: widget.user.id,
      );
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    notification.imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.surfaceVariant,
                      height: 180,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty)
                SizedBox(height: 16),
              Text(
                notification.title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                notification.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 18),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<User?>(
                      future: _lookupUser(notification.senderId),
                      builder: (context, snapshot) {
                        final senderName = snapshot.data != null
                            ? '${snapshot.data!.prenom} ${snapshot.data!.nom}'
                            : 'Admin';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Envoyé par',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              senderName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Date d\'envoi',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${notification.createdAt.day}/${notification.createdAt.month}/${notification.createdAt.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }


  Future<void> _markRead(String notificationId) async {
    await _notificationsService.markNotificationRead(
      notificationId: notificationId,
      userId: widget.user.id,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _downloadInvoice(AppNotification notification) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📄 Génération du reçu en cours...')),
      );
    } catch (e) {
      debugPrint('❌ Erreur facture: $e');
    }
  }

  Future<void> _showBroadcastDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String targetGroup = 'all'; // all, etudiant, formateur, admin

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Diffuser une annonce',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Envoyer une notification instantanée à tous ou à un groupe d\'utilisateurs.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'annonce *',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message / Contenu *',
                      prefixIcon: Icon(Icons.message_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Destinataires :',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: targetGroup,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.groups_rounded)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous les utilisateurs')),
                      DropdownMenuItem(value: 'etudiant', child: Text('Étudiants uniquement')),
                      DropdownMenuItem(value: 'formateur', child: Text('Formateurs uniquement')),
                      DropdownMenuItem(value: 'admin', child: Text('Administration uniquement')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => targetGroup = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                if (title.isEmpty || desc.isEmpty) {
                  context.showSnack('Veuillez renseigner le titre et le message.');
                  return;
                }

                final roles = targetGroup == 'all' ? <String>['all'] : <String>[targetGroup];
                await _notificationsService.createNotification(
                  title: title,
                  description: desc,
                  senderId: widget.user.id,
                  senderEmail: widget.user.email,
                  targetRoles: roles,
                  targetUserIds: [],
                  audience: targetGroup == 'all' ? ['all'] : [targetGroup],
                );

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (mounted) {
                  context.showSuccessSnack('Annonce diffusée avec succès !');
                  setState(() {});
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Publier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
