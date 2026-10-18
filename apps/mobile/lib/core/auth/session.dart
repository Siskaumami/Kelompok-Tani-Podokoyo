import '../errors/app_error.dart';
import '../network/json_data.dart';

enum UserRole { owner, admin, superAdmin }

class SessionUser {
  const SessionUser({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.email,
    required this.role,
  });
  factory SessionUser.parse(Object? value) {
    final data = RecordData(value)
        .validate(strings: ['id', 'org_id', 'name', 'email', 'role']);
    final role = switch (data.s('role')) {
      'OWNER' => UserRole.owner,
      'ADMIN' => UserRole.admin,
      'SUPER_ADMIN' => UserRole.superAdmin,
      _ => throw AppError.malformed(),
    };
    return SessionUser(
      id: data.id,
      organizationId: data.s('org_id'),
      name: data.s('name'),
      email: data.s('email'),
      role: role,
    );
  }
  final String id;
  final String organizationId;
  final String name;
  final String email;
  final UserRole role;
  bool get isOwner => role == UserRole.owner;
  bool get canOperate => role != UserRole.superAdmin;
  String get roleLabel => isOwner
      ? 'Pengelola Utama'
      : role == UserRole.admin
      ? 'Admin'
      : 'Super Admin';
}

enum AuthStatus { restoring, authenticated, signedOut, unavailable }

class AuthState {
  const AuthState(this.status, {this.user, this.error});
  final AuthStatus status;
  final SessionUser? user;
  final AppError? error;
  bool get authenticated => status == AuthStatus.authenticated && user != null;
}
