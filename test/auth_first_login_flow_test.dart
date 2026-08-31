import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Services/auth_provider.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/supabase_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication & First-Login Password Change Flow', () {
    late LocalDataService db;
    late AuthProvider auth;

    setUp(() async {
      db = LocalDataService();
      auth = AuthProvider();
      await auth.logout();
    });

    test('SupabaseMapper correctly round-trips must_change_password', () {
      final initialRow = {
        'id': 'stg_2026_01',
        'email': 'apprenant1@malintic.ml',
        'nom': 'Traore',
        'prenom': 'Fatou',
        'phone': '70000002',
        'role': 'apprenant',
        'must_change_password': true,
        'est_actif': true,
        'assigned_formations': [],
      };

      final user = SupabaseMapper.userFromRow(initialRow);
      expect(user.doitChangerMotDePasse, isTrue);

      final row = SupabaseMapper.toRow('users', user.toMap());
      expect(row['must_change_password'], isTrue);
    });

    test('First login password change updates credentials and triggers clean auto-logout', () async {
      final testStudent = User(
        id: 'user_first_login_test',
        email: 'stagiaire.test@malintic.ml',
        nom: 'Coulibaly',
        prenom: 'Amadou',
        phone: '77000001',
        role: UserRole.apprenant,
        password: '00000000',
        estActif: true,
        doitChangerMotDePasse: true,
        dateCreation: DateTime.now(),
      );

      await db.addUser(testStudent);

      // 1. Connexion initiale avec mot de passe temporaire
      final loggedInUser = await auth.loginWithEmail('stagiaire.test@malintic.ml', '00000000');
      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.doitChangerMotDePasse, isTrue);
      expect(auth.isAuthenticated, isTrue);

      // 2. Définition du mot de passe personnel avec isFirstLogin: true
      final updatedUser = await auth.changePassword(
        newPassword: 'MonSuperMotDePasse2026!',
        isFirstLogin: true,
      );

      expect(updatedUser.doitChangerMotDePasse, isFalse);

      // 3. Déconnexion automatique vérifiée : la session courante est purgée
      expect(auth.currentUser, isNull);
      expect(auth.isAuthenticated, isFalse);

      // 4. L'ancien mot de passe '00000000' est désormais strictement rejeté
      expect(
        () async => await auth.loginWithEmail('stagiaire.test@malintic.ml', '00000000'),
        throwsException,
      );

      // 5. Reconnexion réussie avec le nouveau mot de passe défini
      final reconnectedUser = await auth.loginWithEmail('stagiaire.test@malintic.ml', 'MonSuperMotDePasse2026!');
      expect(reconnectedUser, isNotNull);
      expect(reconnectedUser!.doitChangerMotDePasse, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 'user_first_login_test');
    });
  });
}
