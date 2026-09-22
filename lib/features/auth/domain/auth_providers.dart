import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/data/auth_repository.dart';
import 'package:nextarc/features/auth/data/firebase_auth_service.dart';
import 'package:nextarc/features/auth/data/user_profile_repository.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/watchlist/data/watchlist_sync_service.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';

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

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (_) => FirebaseAuthService(),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (_) => UserProfileRepository(),
);

/// Notifier principal — gère Firebase (email/Google) + AniList (optionnel).
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // 1. Firebase d'abord
    final fbUser = ref.read(firebaseAuthServiceProvider).currentUser;
    if (fbUser != null) {
      final user = await _restoreFirebaseUser(fbUser);
      _syncInBackground(user);
      return AuthState(status: AuthStatus.authenticated, user: user);
    }

    // 2. Retombe sur AniList si token présent
    final repo = ref.read(authRepositoryProvider);
    final anilistUser = await repo.restoreSession();
    if (anilistUser != null) {
      return AuthState(status: AuthStatus.authenticated, user: anilistUser);
    }

    return const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Firebase — email / password ──────────────────────────────────────────

  Future<void> loginWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    final svc = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final fbUser = await svc.signInWithEmail(email, password);
      return AuthState(
        status: AuthStatus.authenticated,
        user: await _upsertFirestore(UserModel.fromFirebase(fbUser)),
      );
    });
    _handleError();
    _syncInBackground(state.value?.user);
  }

  Future<void> createAccount(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncValue.loading();
    final svc = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final fbUser = await svc.createAccount(email, password, displayName);
      return AuthState(
        status: AuthStatus.authenticated,
        user: await _upsertFirestore(
          // Pseudo tapé à l'inscription = choisi : AniList ne le remplacera pas
          UserModel.fromFirebase(fbUser).copyWith(customName: true),
        ),
      );
    });
    _handleError();
    _syncInBackground(state.value?.user);
  }

  // ── Firebase — Google ────────────────────────────────────────────────────

  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    final svc = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final fbUser = await svc.signInWithGoogle();
      return AuthState(
        status: AuthStatus.authenticated,
        user: await _upsertFirestore(UserModel.fromFirebase(fbUser)),
      );
    });
    _handleError();
    _syncInBackground(state.value?.user);
  }

  // ── Firebase — Apple (iOS) ────────────────────────────────────────────────

  Future<void> loginWithApple() async {
    state = const AsyncValue.loading();
    final svc = ref.read(firebaseAuthServiceProvider);
    state = await AsyncValue.guard(() async {
      final fbUser = await svc.signInWithApple();
      return AuthState(
        status: AuthStatus.authenticated,
        user: await _upsertFirestore(UserModel.fromFirebase(fbUser)),
      );
    });
    _handleError();
    _syncInBackground(state.value?.user);
  }

  // ── AniList — OAuth (standalone ou liaison à un compte Firebase) ──────────

  Future<void> login() async {
    final previousState = state.value;
    final firebaseUid = previousState?.user?.firebaseUid;

    // Si déjà connecté Firebase, on ne passe pas en loading (évite le flash)
    if (firebaseUid == null) state = const AsyncValue.loading();

    final repo = ref.read(authRepositoryProvider);
    try {
      final anilistUser = await repo.login();

      if (firebaseUid != null) {
        // Mode liaison : on garde le compte Firebase (uid, email) et on ajoute AniList
        final merged = _withAnilist(previousState!.user!, anilistUser);
        try {
          await ref.read(userProfileRepositoryProvider).linkAnilist(
                uid: firebaseUid,
                anilistId: anilistUser.id,
                anilistName: anilistUser.name,
                anilistAvatar: anilistUser.avatar,
              );
        } catch (_) {
          // Firestore hors ligne : on continue quand même
        }
        state = AsyncValue.data(
          AuthState(status: AuthStatus.authenticated, user: merged),
        );
        _syncInBackground(merged);
      } else {
        // Mode standalone AniList (sans Firebase)
        state = AsyncValue.data(
          AuthState(status: AuthStatus.authenticated, user: anilistUser),
        );
      }
    } catch (e) {
      if (firebaseUid != null) {
        // Échec liaison AniList → on reste connecté Firebase, on ne déconnecte pas
        state = AsyncValue.data(previousState!);
      } else {
        state = AsyncValue.data(
          AuthState(
            status: AuthStatus.unauthenticated,
            error: _mapAnilistError(e),
          ),
        );
      }
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    final svc = ref.read(firebaseAuthServiceProvider);
    await repo.logout();
    try {
      await svc.signOut();
    } catch (_) {}
    state = const AsyncValue.data(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }

  /// Reconstruit l'utilisateur au démarrage : Firebase + profil Firestore
  /// (liaison AniList persistée) + session AniList si le token est encore là.
  Future<UserModel> _restoreFirebaseUser(fb.User fbUser) async {
    var user = UserModel.fromFirebase(fbUser);
    try {
      final profile =
          await ref.read(userProfileRepositoryProvider).getProfile(fbUser.uid);
      if (profile != null) user = profile.toUserModel();
    } catch (_) {
      // Firestore hors ligne → on garde les infos Firebase Auth
    }

    final anilistUser = await ref.read(authRepositoryProvider).restoreSession();
    if (anilistUser != null) user = _withAnilist(user, anilistUser);
    return user;
  }

  /// Pseudo et photo choisis sur NextArc restent prioritaires sur AniList.
  UserModel _withAnilist(UserModel base, UserModel anilist) =>
      base.linkedTo(anilist);

  /// Relit le compte (profil Firestore + AniList) après une modification.
  Future<void> refreshUser() async {
    final fbUser = ref.read(firebaseAuthServiceProvider).currentUser;
    if (fbUser == null) return;
    final user = await _restoreFirebaseUser(fbUser);
    state = AsyncValue.data(
      AuthState(status: AuthStatus.authenticated, user: user),
    );
  }

  /// Délie AniList d'un compte NextArc : la liste NextArc (déjà fusionnée)
  /// est conservée, elle n'est simplement plus mise à jour depuis AniList.
  /// Le pseudo et la photo reviennent à ceux du compte NextArc.
  Future<void> unlinkAnilist() async {
    final uid = state.valueOrNull?.user?.firebaseUid;
    if (uid == null) return;
    await ref.read(authRepositoryProvider).logout();
    try {
      await ref.read(userProfileRepositoryProvider).unlinkAnilist(uid);
    } catch (_) {
      // Hors ligne : le jeton AniList est supprimé, la liaison sera retirée du
      // profil à la prochaine tentative
    }
    await refreshUser();
  }

  /// Fusionne dans Firestore la liste invité puis la liste AniList, sans
  /// bloquer l'UI. En cas d'échec (hors ligne…), on réessaiera au prochain
  /// lancement : la fusion ne supprime rien et peut être rejouée.
  void _syncInBackground(UserModel? user) {
    final uid = user?.firebaseUid;
    if (user == null || uid == null) return;
    final sync = ref.read(watchlistSyncServiceProvider);

    unawaited(() async {
      try {
        if (await sync.mergeGuestIntoFirestore(uid)) {
          ref.invalidate(guestWatchlistProvider);
        }
      } catch (_) {}
      try {
        // Journal du récap mensuel tenu en invité → compte NextArc
        await sync.activity.mergeGuestIntoFirestore(uid);
      } catch (_) {}
      if (user.hasAnilist) {
        try {
          await sync.mergeAnilistIntoFirestore(uid, user.id);
        } catch (_) {}
      }
      try {
        await sync.migrateFavouritesFromScores(uid);
      } catch (_) {}
    }());
  }

  /// Crée ou met à jour le document Firestore et retourne l'UserModel enrichi.
  Future<UserModel> _upsertFirestore(UserModel user) async {
    try {
      final repo = ref.read(userProfileRepositoryProvider);
      final profile = await repo.upsertProfile(user);
      return profile.toUserModel();
    } catch (_) {
      // Firestore inaccessible (hors ligne) → retourne l'user Firebase tel quel
      return user;
    }
  }

  /// Rafraîchit l'utilisateur en mémoire (après édition de profil).
  void updateUser(UserModel user) {
    state = AsyncValue.data(
      AuthState(status: AuthStatus.authenticated, user: user),
    );
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  void _handleError() {
    if (state.hasError) {
      final err = state.error;
      String message;
      if (err is fb.FirebaseAuthException) {
        message = _mapFirebaseError(err.code);
      } else {
        message = err?.toString() ?? 'Erreur inconnue';
      }
      state = AsyncValue.data(
        AuthState(status: AuthStatus.unauthenticated, error: message),
      );
    }
  }

  String _mapFirebaseError(String code) => isCanceledAuthError(code)
      ? 'auth_error_canceled'
      : switch (code) {
        'user-not-found' => 'auth_error_user_not_found',
        'wrong-password' => 'auth_error_wrong_password',
        'invalid-credential' => 'auth_error_invalid_credential',
        'email-already-in-use' => 'auth_error_email_in_use',
        'weak-password' => 'auth_error_weak_password',
        'invalid-email' => 'auth_error_invalid_email',
        'account-exists-with-different-credential' =>
          'auth_error_account_exists',
        _ => 'auth_error_generic',
      };

  String _mapAnilistError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('annul') || msg.contains('cancel')) {
      return 'auth_error_canceled';
    }
    return 'auth_error_generic';
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
