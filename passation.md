# NextArc — Document de passation
> Rédigé le 09/09/2026 — à destination de Claude Code sur un autre poste.
> Projet Flutter (Android) de suivi d'anime/manga. Développé par Simon Barthe (barthesimonpro@gmail.com).

---

## 1. Présentation du projet

**NextArc** est une application mobile Android de suivi d'anime et de manga avec :
- Connexion AniList (OAuth via Cloud Function proxy)
- Connexion Firebase (email/Google — compte NextArc natif)
- Mode invité local (Hive)
- Recommandations personnalisées
- Calendrier de diffusion
- Statistiques de profil
- Notifications de sorties d'épisodes

**Version actuelle** : `1.2.0+5` (branche `Espiegle`, non encore commitée)  
**Repo Git** : sur ce même poste, branche `Espiegle`. Branche principale : `main`.  
**Package** : `com.espiegle.nextarc`

---

## 2. Stack technique

| Technologie | Usage |
|---|---|
| Flutter | Framework UI |
| Riverpod (flutter_riverpod) | State management — `FutureProvider`, `StreamNotifier`, `Provider.family` |
| AniList GraphQL API | Source de données anime/manga (publique + OAuth) |
| Firebase Auth | Authentification email + Google |
| Cloud Firestore | Stockage watchlist + notes des utilisateurs Firebase |
| Hive | Stockage local (mode invité) |
| Workmanager | Tâche de fond toutes les 6h (vérification nouveaux épisodes) |
| flutter_local_notifications | Notifications locales |
| easy_localization | i18n FR/EN/ES |
| go_router | Navigation |

**Firebase** :
- Projet : `nextarc-fdbde`, forfait Blaze, région `europe-west1`
- Cloud Function OAuth proxy : `https://anilisttoken-qgwvvtarwa-ew.a.run.app`
- AniList Client ID : `43258` (secret dans GitHub Secrets : `ANILIST_CLIENT_ID`)
- App Android enregistrée : `com.espiegle.nextarc`

---

## 3. Architecture — Modèle utilisateur

Le routage de toutes les features dépend du type d'utilisateur via `UserModel` :

```dart
class UserModel {
  final String? firebaseUid;  // non null si compte Firebase
  final int id;               // AniList ID (0 si non lié)
  bool get hasAnilist => id > 0;
  bool get hasFirebase => firebaseUid != null;
}
```

**Règle fondamentale** : toujours utiliser `user?.hasAnilist == true` (pas `isAuthenticated`) pour décider si on appelle l'API AniList. Un utilisateur Firebase-only a `isAuthenticated == true` mais `hasAnilist == false`.

**Trois modes** :
1. `hasAnilist == true` → données AniList (watchlist, stats, recos, calendrier via API)
2. `hasFirebase == true && !hasAnilist` → données Firestore (watchlist : `users/{uid}/watchlist/{mediaId}`, notes : `users/{uid}/reviews/{mediaId}`)
3. Invité → données Hive locales

---

## 4. Ce qui a été fait sur cette branche (non committé)

### B1 — Authentification Firebase
- **Nouveaux fichiers** :
  - `lib/features/auth/data/firebase_auth_service.dart` — login email, Google, logout Firebase
  - `lib/features/auth/data/profile_service.dart` — upload photo de profil (Firebase Storage)
  - `lib/features/auth/data/user_profile_repository.dart` — CRUD Firestore `/users/{uid}`
  - `lib/features/auth/presentation/login_screen.dart` — écran login email/Google
  - `lib/features/auth/presentation/profile_edit_screen.dart` — édition nom + photo
  - `lib/core/models/` — modèles partagés
- **Modifiés** : `auth_repository.dart`, `auth_providers.dart`, `user_model.dart`, `profile_screen.dart`, `app_router.dart`, `main.dart`

### B2 — Modèle de données Firestore
- Structure : `users/{uid}/watchlist/{mediaId}` et `users/{uid}/reviews/{mediaId}`
- Règles de sécurité Firestore (à appliquer dans la console Firebase) : voir section 7

### B3 — Watchlist Firestore
- **Nouveaux fichiers** :
  - `lib/features/watchlist/data/firestore_watchlist_repository.dart` — CRUD + stream temps réel
  - `lib/features/watchlist/domain/firestore_watchlist_providers.dart` — `FirestoreWatchlistNotifier` (StreamNotifier), `firestoreWatchlistProvider`, `firestoreListEntryProvider`
  - `lib/features/watchlist/presentation/firestore_watchlist_edit_sheet.dart` — sheet d'édition pour utilisateurs Firebase
- **Modifiés** : `watchlist_sheet_helper.dart`, `watchlist_screen.dart`, `detail_screen.dart`, `anime_card.dart`, `discover_screen.dart`, `browse_screen.dart`, `search_screen.dart`, `recommendations_screen.dart`
- **Migration silencieuse** dans `profile_screen.dart` : si l'utilisateur Firebase-only a une watchlist Hive → copie automatique vers Firestore à la connexion

### B4 — Notes personnelles
- **Nouveaux fichiers** :
  - `lib/features/reviews/data/firestore_review_repository.dart`
  - `lib/features/reviews/domain/review_providers.dart` — `reviewNoteProvider` (StreamProvider.family)
- Widget `_PersonalNoteCard` ajouté dans `detail_screen.dart` — visible uniquement pour les utilisateurs Firebase
- Traductions ajoutées : `detail_note_placeholder`, `detail_note_dialog_title`, `detail_note_hint`, `dialog_save`

### Stats Firebase/invité
- `lib/features/stats/domain/stats_model.dart` — nouveau `StatsModel.computeFromGuestList(List<GuestWatchlistEntry>)` (stats simplifiées : pas de genres, pas de watch time)
- `lib/features/stats/domain/stats_provider.dart` — routing selon le type d'utilisateur (AniList → `compute()`, Firebase → Firestore, invité → Hive)

### Calendrier Firebase/invité
- `lib/features/calendar/domain/calendar_provider.dart` — `AiringEntry` refactoré : `listEntry: MediaListEntry` → `media: MediaModel`. Pour Firebase/invité : requête AniList publique (sans auth) avec les IDs de la watchlist locale
- `lib/features/calendar/presentation/calendar_screen.dart` — `entry.listEntry.media` → `entry.media`

### Notifications améliorées
- `lib/core/services/notification_service.dart` — nouveau `scheduleNextEpisodeNotification()` : programme une notif à l'heure exacte de diffusion AniList (id = `mediaId + 100_000_000`)
- `lib/core/services/episode_checker_task.dart` — query étendue avec `airingAt`, `_fetchCurrentCount` → `_fetchMediaInfo()` retournant `_MediaInfo {currentCount, nextEpisode, nextAiringAt}`

### Fix critique (bug introducted par Firebase)
- `lib/features/recommendations/domain/reco_providers.dart` — `auth.isAuthenticated` → `auth.user?.hasAnilist == true` dans les 3 providers. Un utilisateur Firebase-only tombait dans la branche AniList → erreur réseau
- `lib/features/watchlist/domain/watchlist_providers.dart` — même correction sur `userListProvider`, `userMangaListProvider`, `userFavouritesProvider`

---

## 5. Ce qui reste à faire

### Priorité haute — avant toute publication

#### 5.1 Commit de la branche
Tout ce qui est listé en section 4 n'est pas committé. À faire en premier :
```bash
git add -A
git commit -m "feat: Firebase auth + Firestore watchlist/notes + stats/calendar/notifs pour tous les types d'utilisateurs"
```

#### 5.2 Suppression de compte (RGPD obligatoire)
Le Play Store exige que l'utilisateur puisse supprimer son compte depuis l'app.  
À implémenter :
- Bouton "Supprimer mon compte" dans l'écran profil
- Appel à une **Cloud Function Firebase** (pas côté client) qui :
  1. Supprime les sous-collections Firestore `watchlist` et `reviews` (Firestore ne cascade pas)
  2. Supprime le document `/users/{uid}`
  3. Supprime l'utilisateur Firebase Auth (`admin.auth().deleteUser(uid)`)
- Côté app : déconnexion + retour en mode invité après confirmation

**Pourquoi une Cloud Function ?** Les règles Firestore ont `allow delete: if false` sur `/users/{uid}` pour la sécurité. La suppression doit passer par le SDK Admin qui ignore les règles.

#### 5.3 Hébergement de la politique de confidentialité
Le fichier `docs/privacy-policy.html` existe dans le repo.  
À activer : GitHub Pages sur ce repo (`Settings → Pages → Deploy from branch: main → /docs`).  
URL résultante : `https://[username].github.io/[repo-name]/privacy-policy.html` — à renseigner dans la fiche Play Store.

### Priorité moyenne — Play Store

#### 5.4 Build de production
```bash
flutter build appbundle --release
```
L'AAB signé sera dans `build/app/outputs/bundle/release/app-release.aab`.  
Le keystore et `key.properties` sont déjà configurés localement. La CI GitHub Actions gère le signing en prod.

#### 5.5 Fiche Play Store
À préparer :
- **Titre** : NextArc — Anime & Manga Tracker
- **Description courte** (80 chars max) : Suis tes anime et manga, reçois des alertes de sortie
- **Description longue** (4000 chars max) : à rédiger
- **Captures d'écran** : minimum 2 par appareil téléphone (ratio 9:16 recommandé, 1080×1920 px)
  - Écran Découvrir (tendances)
  - Ma liste (watchlist)
  - Détail d'un anime
  - Statistiques
  - Calendrier
- **Feature graphic** : 1024×500 px (bandeau en haut de la fiche)
- **Icône** : déjà configurée (`assets/icon/icon.png`)
- **Politique de confidentialité** : URL GitHub Pages (voir 5.3)
- **Catégorie** : Divertissement ou Livres et références
- **Public cible** : 13 ans et plus (pas de contenu adulte)
- **Questionnaire données** : l'app n'utilise pas de données personnelles propres (AniList et Firebase uniquement, déclaré dans la privacy policy)

#### 5.6 Version pour le store
Mettre à jour `pubspec.yaml` :
```yaml
version: 1.3.0+6  # ou la version souhaitée
```

### Priorité basse — futures évolutions

#### 5.7 Règles Firestore — suppression de compte
Ajouter une Cloud Function `deleteAccount` appelable depuis l'app (Firebase Functions + Firebase Admin SDK).

#### 5.8 Phase F — Widget écran d'accueil
Afficher les anime "En cours" directement sur l'écran Android sans ouvrir l'app (home screen widget). Dépend de `home_widget` package.

#### 5.9 Phase G2 — Système d'amis
Partage de watchlist entre utilisateurs NextArc. Long terme — nécessite un backend NextArc propre.

---

## 6. Architecture des fichiers clés

```
lib/
├── core/
│   ├── constants/app_constants.dart        ← AniList endpoint, client ID (généré par CI)
│   ├── router/app_router.dart              ← GoRouter, routes protégées
│   ├── services/
│   │   ├── notification_service.dart       ← Notifs locales (immédiate + programmée)
│   │   └── episode_checker_task.dart       ← Workmanager 6h, vérifie nouveaux épisodes
│   └── widgets/anime_card.dart             ← Carte anime avec routing hasAnilist/Firebase/invité
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart        ← Login AniList (OAuth)
│   │   │   ├── firebase_auth_service.dart  ← Login Firebase (email/Google)
│   │   │   ├── profile_service.dart        ← Upload photo Firebase Storage
│   │   │   └── user_profile_repository.dart← CRUD Firestore /users/{uid}
│   │   ├── domain/
│   │   │   ├── auth_providers.dart         ← authProvider (AsyncNotifier)
│   │   │   └── user_model.dart             ← UserModel (hasAnilist, hasFirebase)
│   │   └── presentation/
│   │       ├── login_screen.dart           ← Écran connexion Firebase
│   │       ├── profile_screen.dart         ← Profil + stats + paramètres
│   │       └── profile_edit_screen.dart    ← Édition nom/photo
│   │
│   ├── calendar/
│   │   ├── domain/calendar_provider.dart   ← AiringEntry(media, episode, airingAt) + routing 3 modes
│   │   └── presentation/calendar_screen.dart
│   │
│   ├── reviews/
│   │   ├── data/firestore_review_repository.dart ← CRUD notes /users/{uid}/reviews/{mediaId}
│   │   └── domain/review_providers.dart    ← reviewNoteProvider (StreamProvider.family)
│   │
│   ├── stats/
│   │   ├── domain/
│   │   │   ├── stats_model.dart            ← compute() AniList + computeFromGuestList() Firebase/invité
│   │   │   └── stats_provider.dart         ← routing selon type utilisateur
│   │   └── presentation/stats_screen.dart
│   │
│   └── watchlist/
│       ├── data/
│       │   ├── firestore_watchlist_repository.dart ← CRUD + stream Firestore
│       │   └── guest_watchlist_repository.dart      ← CRUD Hive
│       ├── domain/
│       │   ├── firestore_watchlist_providers.dart   ← firestoreWatchlistProvider (StreamNotifier)
│       │   ├── guest_watchlist_providers.dart
│       │   ├── guest_watchlist_entry.dart   ← Modèle partagé Hive + Firestore
│       │   ├── media_list_entry.dart        ← Modèle AniList + ListStatus enum
│       │   └── watchlist_providers.dart     ← userListProvider (AniList only, guard hasAnilist)
│       └── presentation/
│           ├── firestore_watchlist_edit_sheet.dart ← Sheet édition Firebase
│           ├── guest_watchlist_edit_sheet.dart
│           ├── watchlist_sheet_helper.dart   ← Routing sheet selon type utilisateur
│           └── watchlist_screen.dart
```

---

## 7. Règles de sécurité Firestore (déjà appliquées)

Appliquées le 09/09/2026 dans la console Firebase → Firestore → Rules :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /{document=**} {
      allow read, write: if false;
    }

    match /users/{uid} {
      allow read: if isOwner(uid);
      allow create: if isOwner(uid) && isValidUserProfile();
      allow update: if isOwner(uid) && isValidUserProfile();
      allow delete: if false;

      match /watchlist/{mediaId} {
        allow read: if isOwner(uid);
        allow create, update: if isOwner(uid) && isValidWatchlistEntry();
        allow delete: if isOwner(uid);
      }

      match /reviews/{mediaId} {
        allow read: if isOwner(uid);
        allow create, update: if isOwner(uid) && isValidReview();
        allow delete: if isOwner(uid);
      }
    }

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    function isValidUserProfile() {
      let data = request.resource.data;
      return data.keys().hasOnly(['displayName','email','photoUrl','anilistId','anilistUsername','createdAt','updatedAt'])
        && (data.get('displayName', null) == null || (data.displayName is string && data.displayName.size() <= 100))
        && (data.get('email', null) == null || (data.email is string && data.email.size() <= 200))
        && (data.get('photoUrl', null) == null || data.photoUrl is string);
    }

    function isValidWatchlistEntry() {
      let data = request.resource.data;
      let validStatuses = ['CURRENT', 'COMPLETED', 'PLANNING', 'PAUSED', 'DROPPED'];
      let validTypes = ['ANIME', 'MANGA'];
      return data.keys().hasOnly(['animeId','title','coverImage','status','score','progress','episodes','mediaType','updatedAt'])
          && data.animeId is int && data.animeId > 0
          && data.title is string && data.title.size() > 0 && data.title.size() <= 500
          && data.status is string && data.status in validStatuses
          && data.mediaType is string && data.mediaType in validTypes
          && data.updatedAt == request.time
          && (data.get('score', null) == null || (data.score is number && data.score >= 0 && data.score <= 10))
          && (data.get('progress', null) == null || (data.progress is int && data.progress >= 0 && data.progress <= 50000))
          && (data.get('episodes', null) == null || (data.episodes is int && data.episodes >= 0 && data.episodes <= 50000))
          && (data.get('coverImage', null) == null || data.coverImage is string);
    }

    function isValidReview() {
      let data = request.resource.data;
      return data.keys().hasOnly(['mediaId','note','updatedAt'])
          && data.mediaId is int && data.mediaId > 0
          && data.note is string && data.note.size() > 0 && data.note.size() <= 500
          && data.updatedAt == request.time;
    }
  }
}
```

---

## 8. Règles importantes à ne jamais oublier

1. **Toujours `user?.hasAnilist == true`** (jamais `isAuthenticated`) pour les appels AniList. Un utilisateur Firebase-only a `isAuthenticated = true` mais `id = 0`.

2. **`upsertEntry` Firestore** utilise `SetOptions(merge: true)` + `FieldValue.serverTimestamp()` pour `updatedAt`. Ne jamais écrire `updatedAt` manuellement — les règles Firestore le vérifient.

3. **`GuestWatchlistEntry`** est le modèle partagé entre Hive et Firestore. Son `toJson()`/`fromJson()` est compatible avec les deux.

4. **Providers AniList** (`userListProvider`, `userMangaListProvider`, `userFavouritesProvider`) retournent `[]` si `user?.hasAnilist != true`. Ne pas appeler `.future` sur ces providers pour des utilisateurs Firebase/invité.

5. **`AiringEntry`** utilise maintenant `media: MediaModel` (pas `listEntry: MediaListEntry`). Si une PR modifie le calendrier, ne pas réintroduire `listEntry`.

6. **Notifications** : trois familles d'IDs pour éviter les collisions :
   - `mediaId` → notification immédiate (nouvel épisode/chapitre disponible)
   - `mediaId * 2` / `mediaId * 2 + 1` → notifications J-7 / J-0 (anime "Prévu" avec date de sortie)
   - `mediaId + 100_000_000` → notification précise prochain épisode (depuis `nextAiringEpisode.airingAt`)

---

## 9. Commandes utiles

```bash
# Analyser le code
flutter analyze --no-fatal-infos

# Lancer sur un device connecté
flutter run

# Build release APK (pour tests sur device)
flutter build apk --release

# Build release AAB (pour le Play Store)
flutter build appbundle --release

# Générer app_constants.dart (si pas dans le repo — voir CI)
# Ce fichier est dans .gitignore, il faut le créer manuellement en local :
cat > lib/core/constants/app_constants.dart << 'EOF'
class AppConstants {
  AppConstants._();
  static const String anilistEndpoint = 'https://graphql.anilist.co';
  static const String anilistClientId = '43258';
  static const String anilistRedirectUri = 'nextarc://auth/callback';
  static const String anilistTokenProxyUrl = 'https://anilisttoken-qgwvvtarwa-ew.a.run.app';
  static const int defaultPageSize = 20;
  static const int searchDebounceMs = 400;
}
EOF
```

---

## 10. Prochaine session — Par où commencer

1. **Vérifier** que `flutter analyze` passe (0 erreurs)
2. **Committer** tout ce qui est en attente (voir section 5.1)
3. **Tester sur device** les 3 modes (invité, Firebase, AniList) — vérifier les stats, le calendrier, les notifs
4. **Implémenter la suppression de compte** (section 5.2) — obligatoire Play Store
5. **Héberger la privacy policy** sur GitHub Pages (section 5.3)
6. **Préparer la fiche Play Store** (captures d'écran + descriptions) (section 5.5)
7. **Build AAB release** et soumettre sur Google Play Console
