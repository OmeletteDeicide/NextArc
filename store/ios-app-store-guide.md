# Sortir NextArc sur l'App Store

Le code iOS est prêt :
- connexion Apple ;
- App Check (App Attest) ;
- notifications locales ;
- tâche de fond des sorties ;
- permissions photo et caméra ;
- iPhone uniquement ;
- Ko-fi masqué sur iOS ;
- cartes de partage sans mention de store (elles circulent entre Android et iPhone).

Il reste la configuration des comptes (toi) et la compilation sur le Mac (ton ami).

**Pas de clé APNs à créer.** NextArc n'envoie que des notifications *locales*, programmées sur le téléphone. APNs ne sert qu'aux notifications envoyées depuis un serveur (Firebase Cloud Messaging), que l'app n'utilise pas.

---

## 1. Apple Developer (toi, dans le navigateur) — developer.apple.com/account

### 1.1 Identifiant de l'app
Certificates, Identifiers & Profiles → **Identifiers** → `+` → App IDs → App :
- Description : `NextArc`
- Bundle ID : **Explicit**, `com.espiegle.nextarc`
- Capabilities : cocher **Sign In with Apple** et **App Attest**

Si Xcode le crée tout seul à la première compilation (signature automatique), vérifie simplement que les deux cases sont cochées.

### 1.2 Une clé pour Firebase (connexion Apple + App Check)
**Keys** → `+` :
- Nom : `NextArc Firebase`
- Cocher **Sign in with Apple** → Configure → Primary App ID : `com.espiegle.nextarc`
- Cocher **DeviceCheck**
- Continue → Register → **télécharge le fichier `.p8`**. Il n'est téléchargeable qu'une fois, garde-le en lieu sûr et ne le commite jamais.

Note le **Key ID** (10 caractères) et ton **Team ID** (en haut à droite de la page, ou dans Membership).

---

## 2. Firebase (toi) — console.firebase.google.com, projet nextarc-fdbde

### 2.1 Ajouter l'app iOS
Paramètres du projet → Vos applications → **Ajouter une application → iOS** :
- ID du bundle : `com.espiegle.nextarc`
- Surnom : `NextArc iOS`
- App Store ID : laisser vide, à remplir après la création de l'app dans App Store Connect

Télécharge **`GoogleService-Info.plist`** et envoie-le à ton ami, pas par un lien public. Il n'est pas dans Git (`.gitignore`).

### 2.2 Activer la connexion Apple
Authentication → Sign-in method → **Apple** → Activer :
- Services ID : laisser vide (connexion native iOS uniquement)
- Configuration du flux de code OAuth :
  - ID d'équipe Apple = Team ID ;
  - ID de clé = Key ID ;
  - clé privée = contenu du `.p8`.

  C'est ce qui permet de **révoquer** l'accès Apple à la suppression du compte, ce qu'Apple exige.

### 2.3 App Check pour iOS
App Check → Applications → NextArc iOS :
- **App Attest** : Enregistrer (rien à fournir) ;
- **DeviceCheck** : Key ID, fichier `.p8` et Team ID (la même clé que ci-dessus).

L'application reste en mode **surveillance**, comme sur Android, sans imposer App Check.

---

## 3. Le Mac (ton ami)

### 3.1 Outils
- Xcode (dernière version, App Store), puis ouvrir Xcode une fois pour installer les composants.
- Flutter **3.47** (la même version que sur ton PC) : `flutter doctor` doit être vert pour iOS.
- CocoaPods : `brew install cocoapods`.

### 3.2 Récupérer le projet
```bash
git clone https://github.com/OmeletteDeicide/NextArc.git
cd NextArc
git checkout main
```
Ajouter les deux fichiers secrets, à transmettre en privé :
- `lib/core/constants/app_constants.dart` : copie du tien ;
- `ios/Runner/GoogleService-Info.plist` : à glisser dans Xcode, dans le dossier Runner, en cochant « Copy items if needed » et la cible **Runner**.

Le schéma d'URL Google (`REVERSED_CLIENT_ID`) est déjà renseigné dans `ios/Runner/Info.plist`. Si l'app iOS est recréée dans Firebase, remplace-le par la nouvelle valeur de `GoogleService-Info.plist`.

### 3.3 Première compilation
```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
Toujours lancer `flutter pub get` avant d'ouvrir Xcode : il crée `ios/Flutter/Generated.xcconfig`, propre à chaque Mac. Sans lui, Xcode affiche « could not find included file 'Generated.xcconfig' ».

Dans Xcode → cible **Runner** → **Signing & Capabilities** :
- **Team** : ton compte développeur.
  - Un compte individuel ne peut pas ajouter de membres.
  - Le plus simple : **tu te connectes avec ton identifiant Apple** dans Xcode → Settings → Accounts, sur son Mac (validation par code sur ton iPhone).
- « Automatically manage signing » coché.
- Vérifier la présence de **Sign in with Apple**, **App Attest** et **Background Modes** (avec **Background fetch** coché). Sinon, les ajouter avec `+ Capability`.

### 3.4 Tester sur un vrai iPhone
```bash
flutter run --release
```
À vérifier :
- [ ] Continuer avec Apple, se déconnecter, puis se reconnecter ;
- [ ] Continuer avec Google ;
- [ ] lier AniList depuis le profil ;
- [ ] activer un rappel : la permission de notification est demandée, et la notification arrive ;
- [ ] changer la photo de profil (galerie et caméra) ;
- [ ] partager une carte de stats : aucune mention de Google Play ;
- [ ] le Profil ne montre pas « Soutenir NextArc » ;
- [ ] suppression d'un compte de test créé avec Apple : Face ID est redemandé (révocation), puis le compte disparaît.

### 3.5 Envoyer la version
Version et numéro de build : ceux de `pubspec.yaml` (`2.0.1+7`). Pour renvoyer un build, augmente le `+7`.
```bash
flutter build ipa --release
```
Puis ouvrir `build/ios/archive/Runner.xcarchive` dans Xcode → **Distribute App → App Store Connect → Upload**. L'app **Transporter** avec le `.ipa` de `build/ios/ipa/` fonctionne aussi.

---

## 4. App Store Connect (toi) — appstoreconnect.apple.com

### 4.1 Créer l'app
Apps → `+` → Nouvelle app :
- Plateforme : iOS
- Nom : NextArc (s'il est pris, « NextArc — Anime & Manga »)
- Langue principale : français
- Bundle ID : `com.espiegle.nextarc`
- SKU : `nextarc`

Recopie ensuite l'**Apple ID** de l'app (App Information) dans Firebase → app iOS → App Store ID.

### 4.2 Informations
- **Catégorie** : Divertissement (secondaire : Style de vie ou Livres).
- **Droits sur le contenu** : l'app affiche du contenu tiers (données et images AniList). Réponds oui, et que tu as les droits nécessaires (API AniList).
- **Classification par âge** : remplis le questionnaire honnêtement. Les jaquettes d'anime peuvent montrer de la violence légère ou de fiction. Il n'y a ni contenu généré par les utilisateurs partagé (les notes sont privées), ni chat, ni achats.
- **Statut de commerçant (DSA, UE)** : obligatoire pour être distribué dans l'UE. Sans vente ni pub, tu peux te déclarer **non commerçant**.
- **URL de confidentialité** : ta page GitHub Pages `docs/privacy-policy.html`.
- **URL d'assistance** : une page ou ton adresse de contact. Jamais nextarc.app.

### 4.3 Confidentialité de l'app (étiquette « nutrition »)
Données collectées, toutes **liées à l'identité** et **sans suivi publicitaire** :

| Type | Usage |
|---|---|
| Adresse e-mail | Fonctionnalité de l'app (compte) |
| Nom (pseudo) | Fonctionnalité de l'app |
| Photos (photo de profil, bannière) | Fonctionnalité de l'app |
| Identifiant utilisateur | Fonctionnalité de l'app |
| Autre contenu utilisateur (liste, notes) | Fonctionnalité de l'app |

« Suivi » : **non**, donc pas de fenêtre de transparence du suivi (ATT).

### 4.4 Captures d'écran
Obligatoire : **iPhone 6,9"** (1320 × 2868 ou 1290 × 2796).

Ne réutilise pas les captures Android : la barre du bas et la barre d'état Android risquent un refus (captures non conformes à l'app iOS). Le plus simple :
1. sur le Mac, simulateur **iPhone 16 Pro Max** ;
2. `flutter run` ;
3. mode démo ;
4. **⌘S** dans le simulateur pour enregistrer une capture à la bonne taille.

La même liste de 10 écrans que pour le Play Store fait l'affaire.

Les visuels Claude Design générés par IA peuvent être utilisés (Apple n'impose pas de déclaration IA). Ils doivent refléter l'app réelle.

### 4.5 Soumission
- Build : choisir celui envoyé depuis le Mac, après environ 15 min de traitement.
- **Informations pour la vérification** :
  - un compte de démo e-mail et mot de passe (le compte test que tu as créé pour Google Play) ;
  - en note : « Guest mode available without an account. AniList linking is optional. Notifications are local reminders for new episodes. »
- Chiffrement : déjà déclaré dans l'app (`ITSAppUsesNonExemptEncryption = false`), aucune question.
- Envoyer pour vérification. Compte généralement 24 à 48 h.

---

## Ce qui diffère sur iOS
- **Connexion Apple** en premier sur l'écran de connexion. Apple l'exige dès qu'une connexion Google est proposée (règle 4.8).
- **Ko-fi masqué** : un lien de don vers un développeur individuel hors achats intégrés est refusé (règle 3.1.1). Il reste sur Android.
- **Cartes de partage** : plus aucune mention de store, sur les deux plateformes. Mentionner Google Play dans une app iOS est refusé (règle 2.3.10).
- **Rappels en arrière-plan** : iOS choisit lui-même quand lancer la vérification (souvent quelques fois par jour, selon l'usage). Les rappels déjà programmés arrivent à l'heure.
