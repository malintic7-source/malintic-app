import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/user.dart';

User buildUser(UserRole role) => User(
      id: 'user_${role.name}',
      email: '${role.name}@example.com',
      nom: 'Doe',
      prenom: 'John',
      phone: '770000000',
      role: role,
    );

void main() {
  group('User role helpers', () {
    test('exposes one boolean getter per role', () {
      expect(buildUser(UserRole.admin).isAdmin, isTrue);
      expect(buildUser(UserRole.dg).isDg, isTrue);
      expect(buildUser(UserRole.daf).isDaf, isTrue);
      expect(buildUser(UserRole.comptable).isComptable, isTrue);
      expect(buildUser(UserRole.assistant).isAssistant, isTrue);
      expect(buildUser(UserRole.it).isIt, isTrue);
      expect(buildUser(UserRole.formateur).isFormateur, isTrue);
      expect(buildUser(UserRole.apprenant).isApprenant, isTrue);
      expect(buildUser(UserRole.apprenant).isAdmin, isFalse);
    });

    test('grants admin rights to admin, dg and it only', () {
      final allowed = UserRole.values
          .where((role) => buildUser(role).hasAdminRights)
          .toSet();

      expect(allowed, {UserRole.admin, UserRole.dg, UserRole.it});
    });

    test('grants finance rights to the financial roles', () {
      final allowed = UserRole.values
          .where((role) => buildUser(role).hasFinanceRights)
          .toSet();

      expect(allowed, {
        UserRole.admin,
        UserRole.dg,
        UserRole.daf,
        UserRole.comptable,
        UserRole.it,
      });
    });

    test('grants pedagogie rights to the pedagogical roles', () {
      final allowed = UserRole.values
          .where((role) => buildUser(role).hasPedagogieRights)
          .toSet();

      expect(allowed, {
        UserRole.admin,
        UserRole.dg,
        UserRole.assistant,
        UserRole.it,
      });
    });

    test('treats every role except apprenant as staff', () {
      expect(buildUser(UserRole.apprenant).isStaff, isFalse);
      expect(buildUser(UserRole.apprenant).isEmployee, isFalse);
      expect(buildUser(UserRole.apprenant).isEtudiant, isTrue);
      expect(buildUser(UserRole.formateur).isStaff, isTrue);
      expect(buildUser(UserRole.comptable).isEmployee, isTrue);
    });
  });

  group('User.fromMap', () {
    test('parses each role from its enum string', () {
      for (final role in UserRole.values) {
        final user = User.fromMap({'role': role.toString()}, 'user_1');
        expect(user.role, role, reason: 'role ${role.name}');
      }
    });

    test('falls back to apprenant for an unknown role', () {
      expect(User.fromMap(const {'role': 'inconnu'}, 'u').role, UserRole.apprenant);
      expect(User.fromMap(const {}, 'u').role, UserRole.apprenant);
    });

    test('applies defaults when the payload is empty', () {
      final user = User.fromMap(const {}, 'user_2');

      expect(user.id, 'user_2');
      expect(user.email, '');
      expect(user.nom, '');
      expect(user.prenom, '');
      expect(user.phone, '');
      expect(user.matricule, isNull);
      expect(user.sexe, 'Homme');
      expect(user.estActif, isTrue);
      expect(user.doitChangerMotDePasse, isFalse);
      expect(user.assignedFormations, isEmpty);
      expect(user.dateModification, isNull);
    });

    test('never rehydrates a password from the payload', () {
      final user = User.fromMap(const {'password': 'secret'}, 'user_3');

      expect(user.password, '');
    });

    test('accepts the legacy mustChangePassword flag', () {
      expect(
        User.fromMap(const {'mustChangePassword': true}, 'u').doitChangerMotDePasse,
        isTrue,
      );
      expect(
        User.fromMap(const {'doitChangerMotDePasse': true}, 'u').doitChangerMotDePasse,
        isTrue,
      );
    });

    test('keeps only map entries in assignedFormations', () {
      final user = User.fromMap(const {
        'assignedFormations': [
          {'formationId': 'form_1'},
          'invalid',
          42,
        ],
      }, 'user_4');

      expect(user.assignedFormations, hasLength(1));
      expect(user.assignedFormations.first['formationId'], 'form_1');
    });

    test('parses dates from strings and DateTime values', () {
      final user = User.fromMap({
        'dateCreation': '2024-01-05T09:00:00.000',
        'dateModification': DateTime(2024, 2, 6),
      }, 'user_5');

      expect(user.dateCreation, DateTime(2024, 1, 5, 9));
      expect(user.dateModification, DateTime(2024, 2, 6));
    });
  });

  test('fromFirestore reads the id from the map payload', () {
    final user = User.fromFirestore(<String, dynamic>{
      'id': 'user_6',
      'email': 'admin@example.com',
      'role': 'UserRole.admin',
    });

    expect(user.id, 'user_6');
    expect(user.isAdmin, isTrue);
  });

  group('serialization', () {
    test('toMap never exposes the password', () {
      final user = User(
        id: 'user_7',
        email: 'new@example.com',
        nom: 'Diallo',
        prenom: 'Aminata',
        phone: '770000001',
        role: UserRole.apprenant,
        password: 'temporaire',
      );

      final data = user.toMap();

      expect(data.containsKey('password'), isFalse);
      expect(data['role'], 'UserRole.apprenant');
      expect(data['dateCreation'], user.dateCreation.toIso8601String());
      expect(user.toFirestore(), data);
    });

    test('toMapWithPassword includes a non empty password only', () {
      final withPassword = User(
        id: 'user_8',
        email: 'new2@example.com',
        nom: 'Traore',
        prenom: 'Moussa',
        phone: '770000002',
        role: UserRole.apprenant,
        password: 'temporaire',
      );
      final withoutPassword = withPassword.copyWith(password: '');

      expect(withPassword.toMapWithPassword()['password'], 'temporaire');
      expect(withoutPassword.toMapWithPassword().containsKey('password'), isFalse);
    });
  });

  group('User.copyWith', () {
    test('overrides only the provided fields', () {
      final user = User(
        id: 'user_9',
        email: 'user9@example.com',
        nom: 'Kone',
        prenom: 'Awa',
        phone: '770000003',
        role: UserRole.apprenant,
        dateCreation: DateTime(2024, 1, 1),
      );

      final promoted = user.copyWith(
        role: UserRole.formateur,
        specialite: 'Flutter',
        estActif: false,
      );

      expect(promoted.id, 'user_9');
      expect(promoted.email, 'user9@example.com');
      expect(promoted.role, UserRole.formateur);
      expect(promoted.specialite, 'Flutter');
      expect(promoted.estActif, isFalse);
      expect(user.role, UserRole.apprenant);
      expect(user.estActif, isTrue);
    });

    test('keeps existing values when no override is given', () {
      final user = User(
        id: 'user_10',
        email: 'user10@example.com',
        nom: 'Cisse',
        prenom: 'Mariam',
        phone: '770000004',
        role: UserRole.comptable,
        matricule: 'MAT-10',
        dateCreation: DateTime(2024, 1, 1),
      );

      expect(user.copyWith().toMap(), user.toMap());
    });
  });

  test('nomComplet joins the first and last name', () {
    final user = User(
      id: 'user_11',
      email: 'user11@example.com',
      nom: 'Sidibe',
      prenom: 'Fatoumata',
      phone: '770000005',
      role: UserRole.apprenant,
    );

    expect(user.nomComplet, 'Fatoumata Sidibe');
  });

  test('dateCreation defaults to now when omitted', () {
    final before = DateTime.now().subtract(const Duration(seconds: 1));
    final user = buildUser(UserRole.admin);

    expect(user.dateCreation.isAfter(before), isTrue);
  });
}
