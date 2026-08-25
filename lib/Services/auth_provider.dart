import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/local_storage.dart';
import 'package:gestion_formations/Services/tab_session_lifecycle.dart';

class AuthProvider {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  AuthProvider._internal() {
    _loadFromStorage();
  }

  // Load persisted user if any (sessionStorage preserves F5 refresh, clears on tab close)
  Future<User?> _loadFromStorage() async {
    final sessionUserId = _localStorage.getSessionItem('currentUserId');
    final sessionUserJson = _localStorage.getSessionItem('currentUserJson');

    // 1. Instantly restore cached session if present (0ms UI paint)
    if (sessionUserJson != null && sessionUserJson.isNotEmpty) {
      try {
        final map = jsonDecode(sessionUserJson) as Map<String, dynamic>;
        final user = User.fromMap(map, sessionUserId ?? map['id']?.toString() ?? '');
        _currentUser = user;
        TabSessionLifecycle.activate();
        _authController.add(user);
      } catch (_) {}
    }

    // 2. Validate session with the backend asynchronously
    try {
      final response = await http
          .get(
            Uri.base.resolve('/api/auth/session'),
            headers: const {'ngrok-skip-browser-warning': 'true'},
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromMap(map, map['id']?.toString() ?? '');
        _currentUser = user;
        _db.setServerSessionActive(true);
        TabSessionLifecycle.activate();
        _authController.add(user);
        return user;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Session invalid on server
        _currentUser = null;
        _db.setServerSessionActive(false);
        _localStorage.removeSessionItem('currentUserId');
        _localStorage.removeSessionItem('currentUserJson');
        _localStorage.removeItem('currentUserId');
        _localStorage.removeItem('currentUserJson');
        _authController.add(null);
        return null;
      }
    } catch (_) {}

    return _currentUser;
  }

  final LocalDataService _db = LocalDataService();
  final LocalStorage _localStorage = LocalStorage();
  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  UserRole? get userRole => _currentUser?.role;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isFormateur => _currentUser?.role == UserRole.formateur;
  bool get isApprenant => _currentUser?.role == UserRole.apprenant;
  bool get isEtudiant => isApprenant;

  Stream<User?> get authStateChanges async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  Stream<User?> watchCurrentUser() => authStateChanges;

  Future<User?> loadCurrentUser() async {
    return _loadFromStorage();
  }

  Future<User?> loginWithEmail(String email, String password) async {
    final rawInput = email
        .replaceAll('`', '')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim()
        .toLowerCase();
    final cleanPassword = password.trim();

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.base.resolve('/api/auth/login'),
            headers: const {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'email': rawInput,
              'identifier': rawInput,
              'password': cleanPassword,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw Exception('Serveur injoignable. Vérifiez votre connexion et réessayez.');
    }

    if (response.statusCode != 200) {
      var serverMessage = 'Identifiants incorrects.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = data['error']?.toString() ?? serverMessage;
      } catch (_) {}
      throw Exception(serverMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final serverUser = User.fromMap(data, data['id']?.toString() ?? '');
    _currentUser = serverUser;
    TabSessionLifecycle.activate();
    _authController.add(_currentUser);
    _localStorage.setSessionItem('currentUserId', serverUser.id);
    _localStorage.setSessionItem(
      'currentUserJson',
      jsonEncode(serverUser.toMap()),
    );
    await _db.refreshFromServer();
    return serverUser;
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      _db.logAction(
        userNom: '${_currentUser!.prenom} ${_currentUser!.nom}'.trim().isNotEmpty ? '${_currentUser!.prenom} ${_currentUser!.nom}'.trim() : 'Utilisateur',
        userRole: _currentUser!.role.name,
        action: 'Déconnexion',
        description: 'Déconnexion de la session (${_currentUser!.email})',
      );
    }
    try {
      await http.post(Uri.base.resolve('/api/auth/logout'));
    } catch (_) {
      // The local state must still be cleared if the network is unavailable.
    }
    TabSessionLifecycle.deactivate();
    _db.setServerSessionActive(false);
    _currentUser = null;
    _authController.add(null);
    try {
      _localStorage.removeSessionItem('currentUserId');
      _localStorage.removeSessionItem('currentUserJson');
      _localStorage.removeItem('currentUserId');
      _localStorage.removeItem('currentUserJson');
    } catch (_) {}
  }

  Future<User?> updateCurrentUser({
    required String nom,
    required String prenom,
    required String phone,
  }) async {
    if (_currentUser == null) {
      throw Exception('Aucun utilisateur connecté.');
    }

    final updated = User(
      id: _currentUser!.id,
      email: _currentUser!.email,
      nom: nom,
      prenom: prenom,
      phone: phone,
      role: _currentUser!.role,
      // #1 — Ne pas copier le mot de passe entre objets User
      photoUrl: _currentUser!.photoUrl,
      assignedFormations: _currentUser!.assignedFormations,
      estActif: _currentUser!.estActif,
      doitChangerMotDePasse: _currentUser!.doitChangerMotDePasse,
      dateCreation: _currentUser!.dateCreation,
      dateModification: DateTime.now(),
    );

    await _db.addUser(updated);
    _currentUser = updated;
    _authController.add(_currentUser);
    return _currentUser;
  }

  Stream<List<User>> watchUsers() {
    return _db.watchUsers();
  }

  String _normalizeEmail(String input) {
    var email = input.trim().toLowerCase();
    if (email.isNotEmpty && !email.contains('@')) {
      email = '$email@malintic.ml';
    }
    return email;
  }

  Future<User> updateUser(User user) async {
    final cleanEmail = _normalizeEmail(user.email);
    if (cleanEmail.isEmpty) {
      throw Exception('MISSING_EMAIL');
    }
    final duplicate = _db.getUsers().any(
      (existing) =>
          existing.id != user.id &&
          existing.email.trim().toLowerCase() == cleanEmail,
    );
    if (duplicate) {
      throw Exception('EMAIL_ALREADY_EXISTS');
    }
    final normalizedUser = User(
      id: user.id,
      email: cleanEmail,
      nom: user.nom.trim(),
      prenom: user.prenom.trim(),
      phone: user.phone.trim(),
      role: user.role,
      // #1 — Ne pas copier le mot de passe entre objets User
      photoUrl: user.photoUrl,
      assignedFormations: user.assignedFormations,
      estActif: user.estActif,
      doitChangerMotDePasse: user.doitChangerMotDePasse,
      dateCreation: user.dateCreation,
      dateModification: user.dateModification,
    );
    final updated = await _db.addUser(normalizedUser);
    if (_currentUser?.id == normalizedUser.id) {
      _currentUser = updated;
      _authController.add(_currentUser);
    }
    return updated;
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _db.setUserActive(userId, isActive);
  }

  Future<void> deleteUser(String userId) async {
    await _db.deleteUser(userId);
  }

  Future<User> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      throw Exception('Aucun utilisateur connecté.');
    }

    if (newPassword.trim().length < 8) {
      throw Exception('Le nouveau mot de passe doit contenir au moins 8 caractères.');
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.base.resolve('/api/auth/change-password'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
          'newPassword': newPassword.trim(),
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      throw Exception('Serveur injoignable. Réessayez plus tard.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var serverMessage = 'Impossible de modifier le mot de passe.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        serverMessage = body['error']?.toString() ?? serverMessage;
      } catch (_) {}
      throw Exception(serverMessage);
    }

    User updatedUser = _currentUser!.copyWith(
      doitChangerMotDePasse: false,
      dateModification: DateTime.now(),
    );
    _currentUser = updatedUser;
    _authController.add(_currentUser);
    _localStorage.setSessionItem('currentUserJson', jsonEncode(_currentUser!.toMap()));
    await _db.refreshFromServer();

    return updatedUser;
  }

  /// #2 — Génère un mot de passe temporaire aléatoire sécurisé à 12 caractères.
  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#!';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<User?> createUserByAdmin({
    required String email,
    required String nom,
    required String prenom,
    required String phone,
    required UserRole role,
    String? password, // #2 — null = génère un mot de passe temporaire aléatoire
    String sexe = 'Homme',
    String? photoUrl,
    String? specialite,
    bool doitChangerMotDePasse = true,
  }) async {
    final cleanEmail = _normalizeEmail(email);
    if (cleanEmail.isEmpty) {
      throw Exception('Veuillez fournir une adresse e-mail valide.');
    }
    if (_db.getUsers().any(
      (user) => user.email.trim().toLowerCase() == cleanEmail,
    )) {
      throw Exception('Un utilisateur avec cette adresse e-mail existe déjà.');
    }
    // #2 — Mot de passe temporaire aléatoire si non fourni
    final effectivePassword = (password != null && password.isNotEmpty)
        ? password
        : _generateTempPassword();

    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';

    final newUser = User(
      id: userId,
      email: cleanEmail,
      nom: nom.trim(),
      prenom: prenom.trim(),
      phone: phone.trim(),
      role: role,
      password: effectivePassword,
      sexe: sexe,
      photoUrl: photoUrl,
      specialite: specialite,
      estActif: true,
      doitChangerMotDePasse: doitChangerMotDePasse,
      dateCreation: DateTime.now(),
    );

    await _db.addUser(newUser);
    return newUser;
  }

  Future<String> adminChangeUserPassword(
    String userId, {
    required String newPassword,
    bool mustChangePassword = true,
  }) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.length < 6) {
      throw Exception('Le mot de passe doit contenir au moins 6 caractères.');
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.base.resolve('/api/admin/users/$userId/password'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'newPassword': cleanPassword,
          'mustChangePassword': mustChangePassword,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      throw Exception('Serveur injoignable. Réessayez plus tard.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var errMsg = 'Erreur lors de la mise à jour du mot de passe.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errMsg = body['error']?.toString() ?? errMsg;
      } catch (_) {}
      throw Exception(errMsg);
    }

    await _db.refreshFromServer();
    return cleanPassword;
  }

  Future<String> resetUserPassword(
    String userId, {
    String? password, // #2 — null = génère un mot de passe temporaire aléatoire
    bool doitChangerMotDePasse = true,
  }) async {
    final newPassword = (password != null && password.isNotEmpty)
        ? password
        : _generateTempPassword();

    return adminChangeUserPassword(
      userId,
      newPassword: newPassword,
      mustChangePassword: doitChangerMotDePasse,
    );
  }
}
