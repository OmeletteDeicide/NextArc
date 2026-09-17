# Play Console — réponses pour NextArc 2.0.0

Préparé le 17/09/2026 d'après le code de la branche `Espiegle` (Firebase Auth,
Firestore, Storage, Functions, App Check ; **plus de Firebase Analytics**).
À relire avant de valider : c'est toi qui déclares.

Liens publics (après activation de GitHub Pages sur `/docs`) :
- Politique de confidentialité : `https://omelettedeicide.github.io/NextArc/privacy-policy.html`
- Suppression de compte : `https://omelettedeicide.github.io/NextArc/account-deletion.html`

---

## 1. Règles de l'application → Sécurité des données

### Collecte et sécurité
| Question | Réponse |
|---|---|
| L'appli collecte ou partage-t-elle des types de données utilisateur requis ? | **Oui** |
| Toutes les données collectées sont-elles chiffrées en transit ? | **Oui** |
| Quels types de comptes peut-on créer ? | **Nom d'utilisateur et mot de passe** + **Connexion via OAuth** (Google) |
| Proposez-vous un moyen de demander la suppression du compte ? | **Oui** — URL : page `account-deletion.html` |
| Moyen de demander la suppression de certaines données sans supprimer le compte ? | **Non** (un titre retiré de la liste reste marqué « supprimé » pour la synchronisation) |

### Types de données à cocher
Pour toutes : **Partagées : non** (Firebase est un sous-traitant ; les échanges
avec AniList sont faits à la demande de l'utilisateur, ce que Play ne compte pas
comme un partage).

| Catégorie → type | Collecté | Éphémère | Obligatoire ? | Finalités |
|---|---|---|---|---|
| Infos personnelles → **Nom** | Oui | Non | Facultatif (mode invité possible) | Fonctionnalités de l'appli, Gestion du compte |
| Infos personnelles → **Adresse e-mail** | Oui | Non | Facultatif | Gestion du compte |
| Infos personnelles → **ID utilisateur** (compte NextArc, ID AniList lié) | Oui | Non | Facultatif | Fonctionnalités de l'appli, Gestion du compte |
| Photos et vidéos → **Photos** (photo de profil, bannière envoyées) | Oui | Non | Facultatif | Fonctionnalités de l'appli, Personnalisation |
| Activité dans les applis → **Autre contenu généré par l'utilisateur** (liste, notes, ❤️, notes perso) | Oui | Non | Facultatif | Fonctionnalités de l'appli, Personnalisation |
| Activité dans les applis → **Historique des recherches dans l'appli** | Oui | **Oui** | Facultatif | Fonctionnalités de l'appli |

Notes :
- **Recherches** : l'historique reste sur le téléphone, mais le texte tapé part
  vers l'API AniList pour afficher les résultats. Le déclarer comme collecté et
  traité de façon éphémère est le choix prudent.
- **Rien à cocher** pour : localisation, infos financières, santé, messages,
  contacts, agenda, fichiers audio, **infos et performances de l'appli**
  (plus d'Analytics ni de Crashlytics), **identifiants publicitaires**.
- **À vérifier** sur la page officielle de Firebase, qui liste ce que chaque SDK
  collecte (Authentication, Firestore, Storage, App Check) :
  https://firebase.google.com/docs/android/play-data-disclosure
  Si Firebase Authentication y indique des « Identifiants de l'appareil ou
  autres », ajoute ce type (collecté, non partagé, obligatoire pour le compte,
  finalités : Gestion du compte, Prévention des fraudes et sécurité).

---

## 2. Autres déclarations

| Section | Réponse |
|---|---|
| Politique de confidentialité | URL `privacy-policy.html` |
| Accès à l'appli | **Certaines fonctionnalités sont limitées** : fournir un compte de test e-mail + mot de passe (crée-en un dédié, sans AniList) avec la consigne « Profil → Utiliser une adresse e-mail » |
| Annonces | **Non**, l'appli ne contient pas d'annonces |
| Classification du contenu | Questionnaire inchangé (pas de contenu généré public, pas de chat) |
| Public cible | **13 ans et plus** (ne cible pas les enfants) |
| Identifiant publicitaire | **Non** (permission AD_ID retirée, Analytics supprimé) |
| Applis d'actualités / santé / finances | Non |
| Autorisations sensibles | Aucune photo/vidéo en lecture (sélecteur de photos Android) ; `SCHEDULE_EXACT_ALARM` inchangé depuis la 1.2.0 |

---

## 3. Avant de publier

1. **Empreintes de signature** : Play Console → Test et publication → Intégrité
   de l'appli → *Certificat de la clé de signature d'application* : copier
   SHA-1 et SHA-256 dans Firebase → Paramètres du projet → app Android.
   Retélécharger `google-services.json` et mettre à jour le secret de la CI.
   Sans ça, « Continuer avec Google » échoue sur la version Play.
2. **App Check** : lier le projet Cloud dans Intégrité de l'appli (Play
   Integrity API), puis Firebase → App Check → enregistrer l'app Android avec
   Play Integrity (SHA-256 de la clé de signature). Laisser **non appliqué**.
3. **Déployer** : `firebase deploy --only functions,firestore:rules,storage`
4. **Piste Test interne** d'abord : vérifier connexion Google, envoi de photo,
   suppression de compte sur la version signée par Play.
5. **Notes de version** : coller `store/release-notes-2.0.0.txt` tel quel (les
   balises `<fr-FR>` etc. sont reconnues par la Play Console).
6. **Fiche** : nouvelles captures (refonte complète).
