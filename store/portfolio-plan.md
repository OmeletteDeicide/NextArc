# NextArc — plan de présentation portfolio (Behance, Malt, Upwork, LinkedIn)

Objectif : une seule présentation qui parle à trois publics.
- **Behance** : on regarde les images, on lit peu. Les visuels doivent tenir seuls.
- **Recruteur** : cherche le rôle exact, les technologies, la capacité à finir.
- **PME / client Malt-Upwork** : cherche « est-ce que cette personne peut résoudre mon problème, dans les délais, sans me perdre en jargon ».

Règle pour chaque slide : **un titre qui affirme quelque chose** (pas « Écran d'accueil » mais « Trouver quoi regarder en 3 secondes »), **une phrase d'explication**, **une image qui prouve**.

Format : 1920 × 1080, 14 slides. Compte 10 à 12 minutes de lecture, pas plus.

---

## 1. Couverture *(faite)*
NextArc, UI/UX Design & App Development, Simon Barthe.
À ajouter en bas : **« Flutter · Firebase · Play Store · App Store »** et l'année. Un lecteur doit savoir en 2 secondes de quoi il s'agit.

## 2. Le projet en 30 secondes
Le résumé que tout le monde lira, même en diagonale.
- Une phrase : *« Une app mobile pour suivre ses anime et manga, ne rater aucune sortie et recevoir des recommandations personnelles. »*
- 4 chiffres en gros : **1 personne**, **~6 mois**, **3 langues**, **2 plateformes**.
- Mention : *conçue, développée et publiée seul.*

## 3. Le problème
Pourquoi l'app existe. C'est la slide qui distingue un projet d'école d'un vrai produit.
- Les listes existantes sont austères, pensées pour les habitués.
- On oublie quand sort le prochain épisode.
- Les recommandations sont génériques, jamais liées à ce qu'on a aimé.
- Formule : *« Les outils existants gèrent des données. Ils n'aident pas à choisir quoi regarder ce soir. »*

## 4. Mon rôle
Une PME veut savoir ce que tu sais faire seul.
Trois colonnes : **Design** (recherche, design system, maquettes) · **Développement** (Flutter, back Firebase, notifications, tâches de fond) · **Publication** (fiches store, confidentialité, RGPD, conformité Apple et Google).
Une ligne honnête : *données anime fournies par l'API publique AniList.*

## 5. Le design system « Arc Nocturne »
La slide qui prouve la rigueur, celle que les recruteurs design regardent le plus.
- Palette (fonds, accents, états), échelle typographique **Audiowide + Chakra Petch**, rayons, espacements.
- Les composants : boutons, cartes, pastilles de statut, barres de progression.
- Une phrase : *« 1 fichier de tokens, 0 couleur en dur : le thème clair et le thème sombre sortent de la même source. »*

## 6. Avant / après
Très fort visuellement et très parlant pour un client.
- Les captures de l'ancienne version à gauche, la refonte à droite.
- 3 puces de ce qui a changé : hiérarchie, contraste, densité.
- Si tu as un chiffre (temps pour ajouter un titre, nombre de touches), mets-le.

## 7. Les parcours clés
Behance adore : 3 colonnes de téléphones, un parcours par colonne.
- **Découvrir → fiche → ajouter à ma liste**
- **Avancer d'un épisode** (+1, appui long, saisie directe)
- **Calendrier → activer un rappel**

## 8. Une décision de design expliquée
La slide qui fait la différence sur Malt : elle montre comment tu réfléchis.
Sujet idéal : **la suppression d'un titre**.
- Le constat : un testeur a supprimé un titre par erreur.
- Les options : fenêtre de confirmation (lourde, à chaque geste) ou annulation.
- Le choix : retrait immédiat + « Annuler », puis un historique « Récemment retirés » de 30 jours.
- Le résultat : plus aucune perte possible, et un geste qui reste rapide.

## 9. Sous le capot (architecture)
Pour les recruteurs et les devs, sans noyer un non-technicien.
- Un schéma simple : **App Flutter → Firebase (Auth, Firestore, Storage, Functions) → API AniList**.
- 4 points : hors ligne d'abord (mode invité), synchronisation, notifications locales programmées, vérification d'intégrité de l'app.
- Une phrase pour les non-techniques : *« Tout fonctionne sans compte ; le compte sert à retrouver sa liste sur un autre téléphone. »*

## 10. Qualité et fiabilité
Rassure un client qui craint de payer pour un prototype.
- **154 tests automatisés**, analyse statique sans erreur.
- Intégration continue : chaque fusion produit une version signée.
- Trois langues maintenues en parallèle (fr, en, es).
- Accessibilité : contrastes vérifiés, zones tactiles de 44 px, libellés pour les lecteurs d'écran.

## 11. Confidentialité et conformité
Rare dans un portfolio, très regardé par une PME européenne.
- Données hébergées dans l'Union européenne.
- Politique de confidentialité, suppression du compte en un écran, aucun traqueur publicitaire.
- Conformité Play Store et App Store : connexion Apple, déclarations de confidentialité, statut DSA.

## 12. Publier, pour de vrai
Ce qui sépare un projet fini d'un projet montrable.
- Les visuels du store, la fiche, les captures, la gestion des versions.
- Une phrase : *« Publié sur le Play Store, puis porté sur iOS. »*
- Le lien Play Store, en gros, avec un QR code.

## 13. Ce que j'en retire
Court, honnête, sans fausse modestie.
- 3 apprentissages concrets (par exemple : concevoir pour les deux thèmes dès le départ ; tester sur un vrai téléphone très tôt ; les règles des stores se préparent avant la fin).
- Ce que je ferais différemment.

## 14. Travaillons ensemble
La slide qui transforme un lecteur en client.
- Ce que tu proposes : *applications mobiles Flutter, du design à la publication.*
- Pour qui : *PME, indépendants, startups qui ont besoin d'une app finie, pas d'une maquette.*
- Contact : e-mail, lien Malt, lien LinkedIn. Et **une invitation claire** : *« Un projet d'app ? Écrivez-moi, je réponds sous 24 h. »*

---

## Slides à ajouter plus tard
- **Chiffres réels** après quelques semaines : téléchargements, note moyenne, taux de rétention. C'est l'argument le plus convaincant, garde-lui une place.
- **Un avis d'utilisateur**, même informel, capture à l'appui.
- **Une courte vidéo** (15 s) de navigation dans l'app : Behance la met en avant.

## Erreurs à éviter
- **Pas de slide « À propos de moi » en deuxième position** : le lecteur veut d'abord voir le produit.
- **Pas de pavés de texte** : 40 mots par slide au maximum.
- **Pas de jargon non expliqué** (Riverpod, Hive, CI/CD). Garde les noms des technologies pour la slide architecture, et explique le bénéfice à côté.
- **Pas de faux chiffres.** « 154 tests » est vérifiable, « +200 % d'engagement » ne l'est pas.
- **Les jaquettes d'anime** appartiennent aux studios. Elles sont acceptables dans des captures d'app, mais évite d'en faire une affiche pleine page ou l'image de couverture du projet.
- **RACING HARD** (la police du titre sur ta couverture) est « personal use only ». Un portfolio sert à décrocher des missions : soit tu prends la licence Standard à 44 $, soit tu passes les titres en **Audiowide**, la police des titres de l'app.

## Version française pour Malt
Même plan, mais :
- remplace le vocabulaire anglais du titre de couverture par « Design UI/UX et développement d'application » ;
- ajoute une ligne de disponibilité et de tarif indicatif sur la dernière slide, que Malt met en avant ;
- garde les termes techniques en anglais (Flutter, Firebase), ils sont attendus.
