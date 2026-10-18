import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../errors/app_error.dart';
import '../network/api_client.dart';
import '../network/json_data.dart';
import 'session.dart';

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late ApiClient _api;
  bool _verifying = false;
  int _operation = 0;
  @override
  AuthState build() {
    _api = ref.watch(apiProvider);
    _api.onSessionExpired = () async {
      if (!ref.mounted || state.status == AuthStatus.signedOut) return;
      _operation++;
      state = const AuthState(
        AuthStatus.signedOut,
        error: AppError(
          'Sesi berakhir atau akses akun berubah. Silakan masuk kembali.',
          code: 'AUTH_REQUIRED',
          status: 401,
        ),
      );
      ref.read(dataEpochProvider.notifier).advance();
    };
    ref.onDispose(() => _api.onSessionExpired = null);
    return const AuthState(AuthStatus.restoring);
  }

  Future<void> restore() async {
    final operation = ++_operation;
    state = const AuthState(AuthStatus.restoring);
    try {
      if (!await _api.restoreCookie()) {
        if (operation == _operation) {
          state = const AuthState(AuthStatus.signedOut);
        }
        return;
      }
      await _loadSession(operation);
    } catch (error) {
      _failure(error, operation);
    }
  }

  Future<void> login(String email, String password) async {
    final operation = ++_operation;
    final result = await _api.authPost('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    try {
      _accept(result, operation);
      ref.read(dataEpochProvider.notifier).advance();
    } catch (_) {
      await _api.clearSession();
      rethrow;
    }
  }

  Future<void> verify({bool blocking = false}) async {
    if (_verifying || !state.authenticated) return;
    _verifying = true;
    final operation = ++_operation;
    if (blocking) state = const AuthState(AuthStatus.restoring);
    try {
      await _loadSession(operation);
    } catch (error) {
      _failure(error, operation);
    } finally {
      _verifying = false;
    }
  }

  Future<void> _loadSession(int operation) async {
    final result = await _api.get('/auth/me');
    _accept(result, operation);
  }

  void _accept(Object? value, int operation) {
    if (!ref.mounted || operation != _operation) return;
    final data = jsonObject(value);
    final user = SessionUser.parse(data['user']);
    final csrf = data['csrf'];
    if (csrf is! String) throw AppError.malformed();
    if (!user.canOperate) {
      throw const AppError(
        'Gunakan akun organisasi untuk mengakses operasional.',
        code: 'ORG_ACCESS_REQUIRED',
        status: 403,
      );
    }
    _api.setCsrf(csrf);
    state = AuthState(AuthStatus.authenticated, user: user);
  }

  void _failure(Object error, int operation) {
    if (!ref.mounted || operation != _operation) return;
    final mapped = AppError.from(error);
    state = AuthState(
      mapped.sessionExpired ? AuthStatus.signedOut : AuthStatus.unavailable,
      error: mapped,
    );
  }

  Future<void> logout() async {
    await _api.authPost('/auth/logout', const {}, authenticated: true);
    await forget();
  }

  Future<void> forget() async {
    _operation++;
    try {
      await _api.clearSession();
    } finally {
      state = const AuthState(AuthStatus.signedOut);
      ref.read(dataEpochProvider.notifier).advance();
    }
  }
}

void requireAuthenticated(Ref ref) {
  if (!ref.watch(authProvider).authenticated) {
    throw const AppError(
      'Silakan masuk untuk melanjutkan.',
      code: 'AUTH_REQUIRED',
      status: 401,
    );
  }
}
