# NextArc

**Suivi d'anime et de manga : ta liste, les sorties d'épisodes et des recommandations construites sur ce que tu aimes.**
*Anime & manga tracker built with Flutter — available on Google Play.*

[Télécharger sur Google Play](https://play.google.com/store/apps/details?id=com.espiegle.nextarc) · [Politique de confidentialité](https://omelettedeicide.github.io/NextArc/privacy-policy.html) · [Supprimer son compte](https://omelettedeicide.github.io/NextArc/account-deletion.html)

Application Flutter conçue, développée et publiée en solo : design, développement, back-end et mise en ligne sur les stores. Version iOS en préparation.

---

## Fonctionnalités

**Ta liste**
- Anime et manga dans la même app, avec cinq statuts (en cours, terminé, prévu, en pause, abandonné)
- Progression épisode par épisode, note sur 10, favoris
- Bouton +1, appui long pour avancer vite, saisie directe pour les longues séries
- Retrait annulable, et historique « Récemment retirés » pendant 30 jours
- Mode invité : tout fonctionne sans compte, les données restent sur l'appareil

**Sorties**
- Calendrier semaine par semaine, avec l'heure de diffusion
- Rappel par notification au moment où l'épisode sort
- Vérification périodique en tâche de fond

**Recommandations**
- Une reco quotidienne, choisie parmi les titres aimés
- Des rails « Parce que tu as aimé… », construits sur les favoris et les notes
- Un rail selon les genres dominants, sans jamais proposer un titre déjà dans la liste

**Profil et statistiques**
- Temps passé, épisodes vus, genres favoris
- Titres à débloquer, de Spectateur à Arcer
- Cartes de partage générées dans l'app
- Photo, pseudo et bannière personnalisables

**Comptes**
- Compte NextArc avec Apple, Google ou e-mail : liste sauvegardée et synchronisée
- Compte AniList à lier : la liste existante est importée et tenue à jour
- Suppression du compte et de toutes ses données en un écran

Interface en **français, anglais et espagnol**, en thème clair comme en thème sombre.

---

## Stack technique

| Domaine | Choix |
|---|---|
| Framework | Flutter (Dart) |
| État | Riverpod |
| Navigation | go_router |
| Local | Hive (liste invité, cache, historique) |
| Back-end | Firebase Auth, Cloud Firestore, Storage, Cloud Functions (hébergement UE) |
| Sécurité | App Check (Play Integrity sur Android, App Attest sur iOS), règles Firestore et Storage |
| Données | API GraphQL publique [AniList](https://anilist.co) |
| Notifications | flutter_local_notifications + workmanager |
| Traductions | easy_localization (fr, en, es) |
| CI | GitHub Actions : analyse, tests et build signé à chaque fusion |

**Design system « Arc Nocturne »** : couleurs, typographie (Audiowide et Chakra Petch), rayons et espacements sont centralisés dans `lib/core/theme/`. Aucune couleur en dur dans les écrans : les deux thèmes viennent de la même source.

**Qualité** : 154 tests automatisés, analyse statique sans avertissement.

```
lib/
├── core/         thème, routeur, services (notifications, App Check), widgets partagés
└── features/     un dossier par domaine : auth, watchlist, discover, calendar, stats, share…
    └── <feature>/{data,domain,presentation}
```

---

## Lancer le projet

```bash
flutter pub get
flutter run
```

Deux fichiers de configuration ne sont pas versionnés :

- `lib/core/constants/app_constants.dart` — à créer depuis `app_constants.dart.example` (identifiants de l'application AniList) ;
- `android/app/google-services.json` et `ios/Runner/GoogleService-Info.plist` — à télécharger depuis ta propre console Firebase.

Sans eux, l'app compile mais la connexion et la synchronisation ne fonctionnent pas.

```bash
flutter analyze
flutter test
```

---

## Données et vie privée

Les données sur les anime et les manga proviennent de l'**API publique AniList**. Ce projet n'est pas affilié à AniList.

Les données de compte sont hébergées dans l'Union européenne (Firestore `eur3`, Cloud Functions `europe-west1`). L'application ne contient ni publicité, ni traqueur, ni identifiant publicitaire. Tout est détaillé dans la [politique de confidentialité](https://omelettedeicide.github.io/NextArc/privacy-policy.html).

---

## Licence

© 2026 Simon Barthe. Tous droits réservés.

Le code est public pour consultation, dans le cadre de mon portfolio. Il n'est pas redistribuable ni réutilisable sans mon accord écrit. Pour toute question : barthesimonpro@gmail.com
