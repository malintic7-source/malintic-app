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
    // Nettoyage de sécurité de tout résidu persistant dans localStorage
    _localStorage.removeItem('currentUserId');
    _localStorage.removeItem('currentUserJson');

    final sessionUserId = _localStorage.getSessionItem('currentUserId');
    final sessionUserJson = _localStorage.getSessionItem('currentUserJson');

    // 1. Si aucun utilisateur n'est en sessionStorage pour cet onglet :
    // L'onglet ou le navigateur vient d'être ouvert/réouvert suite à une fermeture.
    // Déconnexion automatique : on ne restaure aucune session et on purge les cookies résiduels.
    if (sessionUserJson == null || sessionUserJson.isEmpty) {
      _currentUser = null;
      _db.setServerSessionActive(false);
      TabSessionLifecycle.deactivate();
      _authController.add(null);
      try {
        await http
            .post(Uri.base.resolve('/api/auth/logout'))
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
      return null;
    }

    // 2. L'onglet actuel possède une session active (ex: rafraîchissement F5 dans le même onglet)
    try {
      final map = jsonDecode(sessionUserJson) as Map<String, dynamic>;
      final user = User.fromMap(map, sessionUserId ?? map['id']?.toString() ?? '');
      _currentUser = user;
      TabSessionLifecycle.activate();
      _authController.add(user);
    } catch (_) {}

    // 3. Validation asynchrone auprès du serveur
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
        // Session invalidée côté serveur
        _currentUser = null;
        _db.setServerSessionActive(false);
        _localStorage.removeSessionItem('currentUserId');
        _localStorage.removeSessionItem('currentUserJson');
        TabSessionLifecycle.deactivate();
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

  User? _fallbackOfflineLogin(String rawInput, String cleanPassword) {
    final users = _db.getUsers();
    for (final user in users) {
      final userEmail = user.email.trim().toLowerCase();
      final userPhone = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final cleanInputPhone = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
      final userMatricule = (user.matricule ?? '').trim().toLowerCase();
      final emailPrefix = userEmail.split('@').first;

      final isMatch = userEmail == rawInput ||
          emailPrefix == rawInput ||
          (userMatricule.isNotEmpty && userMatricule == rawInput) ||
          (cleanInputPhone.length >= 8 && userPhone.contains(cleanInputPhone)) ||
          userEmail == '$rawInput@mntic.ml' ||
          userEmail == '$rawInput@malintic.ml';

      if (isMatch) {
        if (!user.estActif) {
          throw Exception('Ce compte est désactivé. Veuillez contacter un administrateur.');
        }

        final savedOfflinePw = _localStorage.getItem('user_pw_${user.id}')?.trim();
        final effectivePw = (savedOfflinePw != null && savedOfflinePw.isNotEmpty)
            ? savedOfflinePw
            : (user.password.isNotEmpty ? user.password : null);

        if (effectivePw != null && effectivePw.isNotEmpty && effectivePw != '00000000') {
          // Ce compte a un mot de passe personnalisé : 00000000 est STRICTEMENT EXPIRÉ ET REJETÉ
          if (cleanPassword == '00000000') return null;
          if (cleanPassword == effectivePw) return user.copyWith(doitChangerMotDePasse: false);
          return null;
        } else {
          // Première connexion uniquement : 00000000 est temporairement accepté
          if (cleanPassword == '00000000') {
            return user.copyWith(doitChangerMotDePasse: true);
          }
          return null;
        }
      }
    }

    String? adminId;
    User? fallbackAdmin;
    if (rawInput == 'mamadou@malintic.ml' || rawInput == 'mamadou@mntic.ml' || rawInput == 'mamadou' || rawInput == 'adm-2026-001' || rawInput == 'ADM-2026-001') {
      adminId = 'admin_mamadou';
      fallbackAdmin = User(
        id: 'admin_mamadou',
        nom: 'TOURE',
        prenom: 'Mamadou',
        email: 'mamadou@malintic.ml',
        phone: '+223 70 00 00 01',
        role: UserRole.admin,
        matricule: 'ADM-2026-001',
      );
    } else if (rawInput == 'soulbico@malintic.ml' || rawInput == 'soulbico@mntic.ml' || rawInput == 'soulbico' || rawInput == 'souleymane') {
      adminId = 'dg_souleymane';
      fallbackAdmin = User(
        id: 'dg_souleymane',
        nom: 'TRAORE',
        prenom: 'SOULEYMANE',
        email: 'soulbico@malintic.ml',
        phone: '+223 76 00 00 01',
        role: UserRole.admin,
      );
    } else if (rawInput == 'admin@malintic.ml' || rawInput == 'admin') {
      adminId = 'admin_malintic';
      fallbackAdmin = User(
        id: 'admin_malintic',
        nom: 'M@LI-NTIC',
        prenom: 'Admin',
        email: 'admin@malintic.ml',
        phone: '+223 70 00 00 00',
        role: UserRole.admin,
      );
    }

    if (fallbackAdmin != null && adminId != null) {
      final savedPw = _localStorage.getItem('user_pw_$adminId')?.trim();
      final dbUser = _db.getUserById(adminId);
      final effectiveAdminPw = (savedPw != null && savedPw.isNotEmpty)
          ? savedPw
          : (dbUser != null && dbUser.password.isNotEmpty ? dbUser.password : null);

      if (effectiveAdminPw != null && effectiveAdminPw.isNotEmpty && effectiveAdminPw != '00000000') {
        // Après validation de changement de mot de passe, 00000000 est STRICTEMENT EXPIRÉ ET REJETÉ
        if (cleanPassword == '00000000') return null;
        if (cleanPassword == effectiveAdminPw) return fallbackAdmin.copyWith(doitChangerMotDePasse: false);
        return null;
      } else {
        // Première connexion uniquement
        if (cleanPassword == '00000000') {
          return fallbackAdmin.copyWith(doitChangerMotDePasse: true);
        }
        return null;
      }
    }

    return null;
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

    try {
      final response = await http
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
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
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
    } catch (_) {
      // Le backend Docker/ngrok est éteint : passage transparent en mode hors-ligne
    }

    // Mode Zéro-Interruption : Vérification locale directe (Docker éteint)
    final offlineUser = _fallbackOfflineLogin(rawInput, cleanPassword);
    if (offlineUser != null) {
      _currentUser = offlineUser;
      TabSessionLifecycle.activate();
      _authController.add(_currentUser);
      _localStorage.setSessionItem('currentUserId', offlineUser.id);
      _localStorage.setSessionItem('currentUserJson', jsonEncode(offlineUser.toMap()));
      return offlineUser;
    }

    throw Exception('Identifiants incorrects.');
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
    bool isFirstLogin = false,
  }) async {
    if (_currentUser == null) {
      throw Exception('Aucun utilisateur connecté.');
    }

    if (newPassword.trim().length < 8) {
      throw Exception('Le nouveau mot de passe doit contenir au moins 8 caractères.');
    }

    try {
      final response = await http.post(
        Uri.base.resolve('/api/auth/change-password'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'userId': _currentUser!.id,
          'email': _currentUser!.email,
          'identifier': _currentUser!.email,
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
          'newPassword': newPassword.trim(),
          'isFirstLogin': isFirstLogin,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 400 || response.statusCode == 401) {
        String serverMessage = 'Impossible de modifier le mot de passe.';
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          serverMessage = body['error']?.toString() ?? serverMessage;
        } catch (_) {}
        throw Exception(serverMessage);
      }
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('mot de passe') || e.toString().contains('caractères'))) {
        rethrow;
      }
      // Offline mode: non-blocking server error, continue with local update
    }

    User updatedUser = _currentUser!.copyWith(
      doitChangerMotDePasse: false,
      dateModification: DateTime.now(),
    );
    _currentUser = updatedUser;
    _authController.add(_currentUser);
    _localStorage.setSessionItem('currentUserJson', jsonEncode(_currentUser!.toMap()));
    _localStorage.setItem('user_pw_${_currentUser!.id}', newPassword.trim());
    _localStorage.setItem('user_pw_changed_${_currentUser!.id}', 'true');

    final localUser = _db.getUserById(updatedUser.id);
    if (localUser != null) {
      await _db.addUser(localUser.copyWith(
        doitChangerMotDePasse: false,
        dateModification: DateTime.now(),
      ));
    }

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

    _localStorage.setItem('user_pw_$userId', effectivePassword);
    _localStorage.setItem('user_pw_changed_$userId', (!doitChangerMotDePasse).toString());
    await _db.addUser(newUser);
    return newUser;
  }

  Future<String> adminChangeUserPassword(
    String userId, {
    String newPassword = '00000000',
    bool mustChangePassword = true,
  }) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.length < 6) {
      throw Exception('Le mot de passe doit contenir au moins 6 caractères.');
    }

    try {
      await http.post(
        Uri.base.resolve('/api/admin/users/$userId/password'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'newPassword': cleanPassword,
          'mustChangePassword': mustChangePassword,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // Mise à jour locale en mémoire et synchronisation
    final user = _db.getUserById(userId);
    if (user != null) {
      final updated = User(
        id: user.id,
        email: user.email,
        nom: user.nom,
        prenom: user.prenom,
        phone: user.phone,
        matricule: user.matricule,
        role: user.role,
        password: cleanPassword,
        photoUrl: user.photoUrl,
        specialite: user.specialite,
        sexe: user.sexe,
        assignedFormations: user.assignedFormations,
        estActif: user.estActif,
        doitChangerMotDePasse: mustChangePassword,
        dateCreation: user.dateCreation,
        dateModification: DateTime.now(),
      );
      await _db.addUser(updated);
    }
    _localStorage.setItem('user_pw_$userId', cleanPassword);
    _localStorage.setItem('user_pw_changed_$userId', (!mustChangePassword).toString());
    await _db.refreshFromServer();
    return cleanPassword;
  }

  Future<String> resetUserPassword(
    String userId, {
    String? password, // null = génère un mot de passe temporaire aléatoire sécurisé
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
