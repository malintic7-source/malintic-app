import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Pages/INSCRIPTIONS/formulaire.dart';
import 'package:gestion_formations/Pages/home_screen.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/local_storage.dart';
import 'package:gestion_formations/Widgets/first_login_password_dialog.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Import queues localement en arrière-plan après le premier affichage si existantes
  Future.microtask(() async {
    try {
      await _importLocalInscriptionQueue();
    } catch (e) {
      debugPrint('[Malintic] Import queue error: $e');
    }
  });
}

/// Helper to parse and create an inscription from a JSON Map (Task #3)
Future<void> _processInscriptionMap(LocalDataService db, Map<String, dynamic> map) async {
  final etudiantId = map['etudiantId']?.toString() ?? 'web_${DateTime.now().millisecondsSinceEpoch}';
  final prenom = map['prenom']?.toString();
  final nom = map['nom']?.toString();
  final email = map['email']?.toString();
  final telephone = map['telephone']?.toString();
  final formationId = map['formationId']?.toString() ?? '';
  final modules = (map['modules'] as List<dynamic>?)?.map((e) => e.toString()).toList();
  final description = map['description']?.toString();
  final typeFormation = map['typeFormation']?.toString();

  await db.createInscription(
    etudiantId: etudiantId,
    formationId: formationId,
    prenom: prenom,
    nom: nom,
    email: email,
    telephone: telephone,
    description: description,
    modules: modules,
    typeFormation: typeFormation,
  );
}

Future<void> _importLocalInscriptionQueue() async {
  try {
    final storage = LocalStorage();
    const key = 'local_inscriptions';
    final raw = storage.getItem(key);
    if (raw == null || raw.isEmpty) return;

    final List<dynamic> list = jsonDecode(raw);
    final db = LocalDataService();

    for (final item in list) {
      try {
        if (item is Map<String, dynamic>) {
          await _processInscriptionMap(db, item);
        }
      } catch (e) {
        debugPrint('[Malintic] Erreur import local inscription item: $e');
      }
    }

    storage.removeItem(key);
  } catch (e) {
    debugPrint('[Malintic] Erreur import queue locale: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M@LINTIC-APP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _preselectedFormationId;
  bool _showInscriptionPage = false;

  @override
  void initState() {
    super.initState();
    _parseUrlParameters();
  }

  void _parseUrlParameters() {
    try {
      final uri = Uri.base;
      _preselectedFormationId =
          uri.queryParameters['formationId'] ?? uri.queryParameters['id'];
      _showInscriptionPage = uri.queryParameters['inscription'] == 'true' ||
          uri.path.contains('formation') ||
          uri.path.contains('inscription') ||
          (_preselectedFormationId != null && _preselectedFormationId!.isNotEmpty);

      final frag = uri.fragment;
      if (frag.isNotEmpty) {
        final fragPart = frag.contains('?') ? frag.split('?').last : '';
        final fragParams = Uri.splitQueryString(fragPart.isNotEmpty ? fragPart : '');
        if (fragParams['inscription'] == 'true' ||
            frag.contains('formation') ||
            frag.contains('inscription')) {
          _showInscriptionPage = true;
        }
        if (_preselectedFormationId == null || _preselectedFormationId!.isEmpty) {
          _preselectedFormationId =
              fragParams['formationId'] ?? fragParams['id'];
          if (_preselectedFormationId != null && _preselectedFormationId!.isNotEmpty) {
            _showInscriptionPage = true;
          }
        }
      }
    } catch (e) {
      debugPrint('[Malintic] Erreur parsing URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthProvider().watchCurrentUser(),
      initialData: AuthProvider().currentUser,
      builder: (context, snapshot) {
        final activeUser = snapshot.data ?? AuthProvider().currentUser;
        if (activeUser != null) {
          if (activeUser.doitChangerMotDePasse) {
            return _FirstLoginGate(user: activeUser);
          }
          return HomeScreen(user: activeUser);
        }

        if (_showInscriptionPage) {
          return InscriptionPage(formationId: _preselectedFormationId);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Stack(
              children: [
                Positioned(
                  top: -110,
                  right: -90,
                  child: _SplashOrb(
                    size: 250,
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  bottom: -130,
                  left: -100,
                  child: _SplashOrb(
                    size: 270,
                    color: AppTheme.logoRed.withValues(alpha: 0.06),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Image.asset(
                          'images/logo.png',
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school_rounded,
                            size: 64,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'M@LI-NTIC',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 156,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.divider,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Initialisation sécurisée…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return const WelcomePage();
      },
    );
  }
}

class _SplashOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _SplashOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Écran intermédiaire qui force le changement de mot de passe lors de la
/// première connexion ou après un reset admin, avant l'accès au HomeScreen.
class _FirstLoginGate extends StatefulWidget {
  final User user;
  const _FirstLoginGate({required this.user});

  @override
  State<_FirstLoginGate> createState() => _FirstLoginGateState();
}

class _FirstLoginGateState extends State<_FirstLoginGate> {
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FirstLoginPasswordDialog.showIfNeeded(context, widget.user);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écran d'attente sécurisé pendant la définition du mot de passe initial
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
