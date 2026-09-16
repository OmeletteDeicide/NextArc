# Prompt Claude Design — NextArc, 2ᵉ passe (écrans restants)

> À coller dans Claude Design, avec l'export précédent
> (`NextArc Revue Design.dc.html`) et les captures listées en bas.

---

Bonjour ! Tu as déjà fait la revue design de **NextArc** (app Flutter Android de
suivi d'anime et de manga, données AniList) et proposé la direction
**« Arc Nocturne »**. Elle est maintenant **implémentée** dans l'app. Je te
demande une **2ᵉ passe sur les écrans qui n'avaient pas de maquette**, dans la
même direction.

## Ce qui est déjà en place (à respecter, ne pas redessiner)

Écrans faits d'après tes maquettes : Découvrir, fiche anime, fiche d'édition,
Ma liste (+ invité), Profil, Stats (« Ton mois »), Mon titre, les 3 cartes de
partage, carte « Nouveau titre », connexion, déconnexion, onboarding 3 écrans,
Paramètres (d'après « Paramètres invité »).

Design system tel qu'implémenté :
- Tokens sombre / clair de ton §05 (surface base / 1 / 2, accent #6D8BFF →
  violet #8B5CF6, texte accent AA #7C93FF, étoile #FFC145 / #B37700, statuts,
  favori #FF5C72). Dégradé accent réservé : badge de titre, CTA principal,
  barres de progression.
- Typo : Archivo Black (grands chiffres), Sora (titres), Manrope (texte),
  JetBrains Mono (sur-titres en capitales espacées).
- Espacements 4/8/12/16/24/32, marge écran 18, rayons 8/12/14/18, zones
  tactiles ≥ 44 px, motion 120 / 220 / 400 ms.
- Composants : bouton (principal dégradé, secondaire surface 2, destructif
  contour rouge, danger plein rouge), segmenté, chip de statut, carte média
  2:3 avec rang « 01 », tuile de stat, barre de progression dégradée, bouton
  rond 36 px sur surface 2 (en-têtes), boîte de confirmation.
- En-têtes d'onglet : titre h1 à gauche + boutons ronds à droite (Ma liste,
  Pour toi). Découvrir garde logo + « NextArc ». Écrans secondaires : bouton
  retour rond + titre h2.

Décisions produit prises depuis ta revue :
- **Aucun motif de fond** : le zigzag a été essayé puis retiré (« sans, ça rend
  mieux »). Dégradés et halos violets OK.
- Cartes de partage toujours sombres. Jamais de domaine (« nextarc.app »
  n'existe pas) : « Dispo sur Google Play ».
- Couronne 👑 uniquement pour les Arcer.
- Connexion : **Google en principal**, e-mail en secondaire, invité en lien.
  AniList ne sert plus à se connecter : on le **lie** depuis un compte NextArc.
- L'app est en français (EN/ES aussi) : prévois des textes FR réalistes.

## Ce que je te demande

Pour chaque écran : **version sombre ET claire**, artboards 360×760 comme la
1ʳᵉ fois, avec les **états** (chargement, vide avec action, erreur) quand ils
existent, et quelques notes d'implémentation (tailles, tokens, composants
réutilisés). Reste dans ce que les données permettent (liste ci-dessous) :
pas de fonctionnalité qui demanderait un nouveau serveur.

### 1. Explorer + feuille de filtres
Rôle : parcourir tout le catalogue AniList (ouvert depuis Découvrir « Tout
voir » ou l'icône filtres).
Données / filtres disponibles : Anime ou Manga · tri (Popularité, Tendance,
Score, Plus récent, Favoris) · genres (16 en anime : Action, Adventure,
Comedy, Drama, Fantasy, Horror, Mecha, Music, Mystery, Psychological, Romance,
Sci-Fi, Slice of Life, Sports, Supernatural, Thriller ; 14 en manga, sans Mecha
ni Music) · format, anime seulement (TV, Film, OVA, ONA, Spécial) · statut (En
cours, Terminé, À venir, En pause) · année de → à · score minimum. Résultats
paginés (scroll infini), le total de résultats est connu.
Problèmes actuels (captures) : grille à 3 colonnes où les titres sont coupés ;
aucun compteur « X filtres actifs » ; pas de bouton Réinitialiser ; le slider
« Score minimum : Peu importe » occupe 200 px de vide ; bouton « Appliquer »
qui ne dit pas combien de résultats on aura.
Pistes de ta revue : grille 2 colonnes, compteur de filtres actifs, chips
actives remontées en haut, Réinitialiser.

### 2. Recherche
Rôle : recherche texte anime + manga, historique des recherches récentes
(supprimables une à une ou toutes).
Problèmes : écran vide à l'ouverture (juste 2 recherches récentes), grille de
résultats à 3 colonnes, état « aucun résultat » pauvre.
Piste de ta revue : suggestions tendance sous les recherches récentes.

### 3. Pour toi
Rôle : recommandations anime / manga calculées à partir des titres aimés (❤️)
ou bien notés (≥ 8) de l'utilisateur. Chaque reco a une source (« Parce que
tu as aimé X »), une note, un nombre d'épisodes / chapitres, des genres, un
bouton ajouter à la liste. Sans ❤️ ni note : tendances + message d'aide.
J'ai déjà fait une 1ʳᵉ reprise (en-tête titre + segmenté Anime/Manga, cartes
où la reco passe avant la raison) — **améliore-la** : la même source se répète
souvent sur plusieurs cartes (« Parce que tu as aimé DAN DA DAN » ×3). Idées
bienvenues : regrouper par source (rails), varier les sources, mettre en avant
la meilleure reco.

### 4. Calendrier des sorties
Rôle : prochains épisodes (14 jours) des anime de la liste (en cours + prévus),
avec date, heure, n° d'épisode. Les rappels de sortie existent (notification
par anime).
Problèmes : bande de jours qui déborde (« D… » tronqué), rien n'indique quels
jours ont des sorties, « Rien à diffuser ce jour » sans action.
Demande : **regrouper par semaine** (« Cette semaine », « Semaine prochaine »,
jours en sous-titres, seulement les jours qui ont des sorties), mise en avant
d'aujourd'hui, état vide avec action (ex. « Ajouter des anime en cours »).

### 5. À propos
Contenu : logo, nom, version, description de l'app, **crédits AniList
obligatoires** (données + API, « NextArc n'est pas affilié à AniList »),
technologies utilisées, développeur (Espiègle, dév solo) et lien Ko-fi.
Demande : reprise dans le design system, lisible et sobre.

### 6. Versions claires manquantes
Stats (« Ton mois » + tuiles + genres), Mon titre, Connexion (Profil non
connecté) et Ma liste invité.

### 7. Nouveautés à dessiner
- **Bannière de profil** : pouvoir choisir sa bannière dans « Modifier le
  profil » (photo et pseudo sont déjà modifiables). Sans bannière choisie :
  bannière AniList si le compte est lié, sinon le dégradé actuel. Montre
  l'écran « Modifier le profil » complet et le rendu sur l'en-tête du Profil.
- **Suppression de compte** (obligatoire Play Store) : entrée dans
  Paramètres (compte connecté), écran ou feuille qui explique ce qui est
  supprimé (compte, liste, notes, stats, titres, photo) et ce qui ne l'est pas
  (compte AniList lié : intact), confirmation forte (ex. taper « SUPPRIMER »),
  état en cours, écran de fin.
- **Paramètres — compte connecté** : même base que « Paramètres invité », avec
  à la place de la liste locale : compte (e-mail, AniList lié / délier),
  notifications (épisodes, récap du mois) et « Supprimer mon compte ».

## Captures jointes
- `planche_1_decouverte.png` — colonnes **Explorer – filtres**, **Filtres
  (suite)** et **Recherche** (la colonne Découvrir est obsolète).
- `planche_3_pour_toi_liste.png` — colonne **Calendrier** (Pour toi et Ma liste
  sont obsolètes).
- `planche_5_partage_reglages.png` — colonne **À propos** (le reste est
  obsolète).
- Nouvelles captures de l'app actuelle (thème Arc Nocturne) : Découvrir, Pour
  toi, Profil, Stats, Paramètres — pour que tu voies le rendu réel.
