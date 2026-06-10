import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/data/auth_repository.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

/// État d'authentification de l'application.
enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  static const initial = AuthState(status: AuthStatus.loading);
}

/// Provider du repository (injectable pour les tests).
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

/// Notifier principal — gère login, logout, et restauration de session.
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Tente de restaurer la session au démarrage
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.restoreSession();

    if (user != null) {
      return AuthState(status: AuthStatus.authenticated, user: user);
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login() async {
    state = const AsyncValue.loading();
    final repo = ref.read(authRepositoryProvider);

    state = await AsyncValue.guard(() async {
      final user = await repo.login();
      return AuthState(status: AuthStatus.authenticated, user: user);
    });

    // En cas d'erreur, on repasse en unauthenticated
    if (state.hasError) {
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.unauthenticated,
          error: state.error?.toString(),
        ),
      );
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncValue.data(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
