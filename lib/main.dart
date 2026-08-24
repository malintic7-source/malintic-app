import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Pages/Login/welcome_page.dart';
import 'package:gestion_formations/Pages/INSCRIPTIONS/formulaire.dart';
import 'package:gestion_formations/Pages/home_screen.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/local_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Import queues asynchronously in background after first paint
  Future.microtask(() async {
    try {
      await _importLocalInscriptionQueue();
      await _importFromApi();
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

Future<void> _importFromApi() async {
  try {
    if (!kIsWeb) return;
    final db = LocalDataService();
    if (!Uri.base.hasAuthority) return;
    final origin = Uri.base.origin;
    if (origin.isEmpty || !origin.startsWith('http')) return;

    final response = await http.get(
      Uri.parse('$origin/api/inscriptions'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) {
      debugPrint('[Malintic] Import API inscriptions refusé: HTTP ${response.statusCode}');
      return;
    }
    final text = response.body;
    if (text.isEmpty) return;

    final List<dynamic> list = jsonDecode(text);
    for (final item in list) {
      try {
        if (item is Map<String, dynamic>) {
          await _processInscriptionMap(db, item);
        }
      } catch (e) {
        debugPrint('[Malintic] Erreur import API inscription item: $e');
      }
    }
  } catch (e) {
    debugPrint('[Malintic] API inscriptions non joignable: $e');
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
      _showInscriptionPage = uri.queryParameters['inscription'] == 'true';

      if (!_showInscriptionPage) {
        final frag = uri.fragment;
        if (frag.isNotEmpty && frag.contains('inscription')) {
          final fragPart = frag.contains('?') ? frag.split('?').last : '';
          final fragParams = Uri.splitQueryString(fragPart.isNotEmpty ? fragPart : '');
          if (fragParams['inscription'] == 'true' || frag.contains('inscription')) {
            _showInscriptionPage = true;
          }
          if (_preselectedFormationId == null || _preselectedFormationId!.isEmpty) {
            _preselectedFormationId =
                fragParams['formationId'] ?? fragParams['id'];
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
          return HomeScreen(user: activeUser);
        }

        if (_showInscriptionPage) {
          return InscriptionPage(formationId: _preselectedFormationId);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/logo.png',
                    width: 120,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const WelcomePage();
      },
    );
  }
}
