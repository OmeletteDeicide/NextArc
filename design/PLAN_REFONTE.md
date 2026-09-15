# Refonte design NextArc — plan de suivi

> Fichier de reprise : si une session s'arrête, repartir d'ici.
> Source du design : `design/NextArc Revue Design.dc.html` (export Claude Design,
> direction **Arc Nocturne**). Lire les sections §05 (design system), §04/§06
> (maquettes sombre/clair), §07 (cartes de partage), §08 (titres), §09 (invité,
> déconnexion, onboarding).

## Décisions validées (15/09/2026)

- Direction **Arc Nocturne** (reprise du design de base). ❌ Encre & Vermillon,
  ❌ direction 1b.
- Écrans retenus : fiche anime, Découvrir, menus/navigation, fiche d'édition,
  Ma liste, Profil, Stats, cartes de partage.
- **Motif zigzag** à la place des hachures. Angle / opacité / activation
  réglables en un seul endroit (le design utilise rotate 25° — à juger sur
  téléphone ; en clair le design ne le met que sur les fonds accentués, peut-être
  à retirer complètement en clair).
- **Cartes de partage : toujours en sombre**, quel que soit le thème.
- Pied de carte : « NextArc — Dispo sur Google Play ». ❌ jamais `nextarc.app`.
  Pas de mention Apple tant que l'app n'y est pas.
- **Couronne 👑 uniquement pour les Arcer** (la maquette la montre sur « Petit
  Curieux » juste pour illustration). Design de couronne à redessiner plus tard.
- **Connexion** : Google mis en avant (principal), e-mail secondaire. AniList
  **uniquement proposé une fois connecté** à un compte NextArc (liaison /
  import), plus en connexion autonome. Garder la restauration des sessions
  « AniList seul » existantes.
- Déconnexion : « Ta liste reste sauvegardée sur ton compte NextArc » (pas
  « sur AniList » : la synchro est AniList → NextArc uniquement).
- Progression Arcer : **heures de visionnage + lecture**.
- Comparaison au mois précédent (Stats « Ton mois ») : masquée si le mois
  précédent a < 3 h ; % affiché si hausse ou baisse ≤ 10 % ; sinon phrase neutre
  (« Un mois plus calme »).
- Écrans non dessinés (Pour toi, Explorer/Filtres, Recherche, Calendrier,
  Paramètres connecté, À propos, versions claires de Stats / Mon titre /
  Connexion / Ma liste invité) : **à redemander à Claude Design** (l'utilisateur
  s'en charge). Ne pas les implémenter avant d'avoir ses maquettes.

## Design system (résumé du §05)

| Token | Sombre | Clair |
|---|---|---|
| surface/base | #060A15 | #F3F6FD |
| surface/1 (cartes) | #0B1226 | #FFFFFF |
| surface/2 (chips) | #131C36 | #E6ECFA |
| accent/500 | #6D8BFF | #4560E0 |
| accent/texte (AA) | #7C93FF | #3A52C9 |
| accent/violet | #8B5CF6 | #7040E8 |
| note/étoile | #FFC145 | #B37700 |
| statut/en cours | #3DD68C | #0E8F58 |
| favori / destructif | #FF5C72 | #D32444 |
| texte/1 | #EDF1FF | #0C1226 |
| texte/2 | #94A1C4 | #5A6480 |

- Dégradé accent (500 → violet) **réservé** : badge de titre, CTA primaire,
  barres de progression. Jamais en fond de carte.
- Typo : display Archivo Black 36/40 (grands nombres, cartes de partage) ·
  h1 Sora 800 24/28 · h2 Sora 700 17/22 · title Manrope 700 14/18 ·
  body Manrope 400 13/21 · meta Manrope 500 11/16 · overline JetBrains Mono 600
  10, tracking +14 %.
- Espacements 4/8/12/16/24/32, marge écran 18. Rayons : 8 chips · 12 jaquette ·
  14 carte · 18 hero/feuille · full boutons ronds & badges. Cible tactile 44.
- Motion : 120 ms état pressé · 220 ms transition · 400 ms barres.

## Tâches

### Lot 1 — Fondations ✅ (code, à valider sur téléphone)
- [x] Tokens sombre/clair en `ThemeExtension` → `lib/core/theme/app_tokens.dart`
      (`AppColors.of(context)`, `AppSpacing`, `AppRadius`, `AppMotion`)
- [x] Typographie → `lib/core/theme/app_typography.dart` (package `google_fonts`,
      polices téléchargées au 1er lancement ; à intégrer en assets plus tard pour
      éviter le flash hors ligne)
- [x] Espacements / rayons / durées en constantes
- [x] Motif zigzag → `lib/core/theme/zigzag_background.dart`
      (`ZigzagBackground`, réglages dans `ZigzagConfig`)
- [x] `ThemeData` sombre et clair branchés sur les tokens → `app_theme.dart`

### Lot 2 — Composants ✅ (dans `lib/core/widgets/ds/`, import `ds.dart`)
- [x] Carte média → `MediaCover` / `MediaCard` (jaquette 2:3, n° de classement,
      titre 2 lignes, note, bouton d'action 44 px)
- [x] Chips de statut → `StatusChip` (badge coloré ou sélectionnable)
- [x] Boutons → `AppButton` (primaire dégradé / secondaire / destructif, loading)
- [x] Onglets : soulignés via `TabBarThemeData` + `SegmentedControl` + `IconTab`
- [x] Tuile de stat → `StatTile`
- [x] Badge de titre → `UserTitleBadge` repris (dégradé ; doré pour Arcer ;
      couronne réservée aux Arcer)
- [x] Barre de progression → `GradientProgressBar` · en-tête → `SectionHeader`
- [x] Émojis d'onglets → icônes (Pour toi, Ma liste) ; drapeaux → FR/EN/ES
- Note : les composants ne sont pas encore branchés dans les écrans (lot 3).

### Lot 3 — Écrans retenus
- [x] Découvrir → `discover_screen.dart` : en-tête logo + boutons ronds, hero
      (`discover_hero.dart` : média de la liste diffusé sous 7 j > épisode le plus
      proche > n°1 tendances ; étiquette « Épisode du jour / Prochain épisode /
      Tendance n°1 »), rails à ~2 cartes visibles avec `MediaCard`, rang sur les
      tendances, « Tout voir » → Explorer pré-filtré (écrase le filtre mémorisé),
      zigzag en fond (sombre uniquement). Requêtes : `bannerImage` +
      `nextAiringEpisode` ajoutés. `HorizontalAnimeList` supprimé ; `AnimeCard`
      gardé pour la Recherche (en attente de maquette).
- [ ] Fiche anime (hero ≤ 38 %, pastilles sur icônes, carte « Dans ma liste »,
      synopsis replié 3 lignes, prochain épisode + Rappel)
- [ ] Fiche d'édition (reprise visuelle, note en 10 segments)
- [ ] Ma liste (segmenté Anime/Manga + un seul niveau d'onglets, bouton +1,
      carte « sorties cette semaine »)
- [ ] Profil (en-tête zigzag + halo, badge de titre centré, carte « Route vers
      Arcer », menus)
- [ ] Stats (récap narratif « Ton mois », tuiles, genres)
- [ ] Écran « Mon titre » (2 jauges + Arcer doré + échelle des noms)
- [ ] Cartes de partage (3 cartes, sombres, zone de sécurité 9:16)
- [ ] Moment du palier (carte plein écran au passage de titre → Partager)

### Lot 4 — Comptes
- [ ] Connexion : Google principal, e-mail secondaire, « Continuer en invité »
- [ ] Liaison AniList seulement une fois connecté (retirer la connexion AniList
      autonome, garder la restauration des sessions existantes)
- [ ] Déconnexion : titre en question, action rouge, message rassurant
- [ ] Mode invité : bandeau discret, états vides avec action,
      « dernière sauvegarde : il y a X j » sur l'export
- [ ] Onboarding 3 écrans (promesse · anime/manga/les deux · compte), « Passer »
      dès le 1er écran, pas de demande de notifications

### Lot 5 — Écrans non dessinés (⏳ en attente des maquettes Claude Design)
- [ ] Pour toi · Explorer & filtres · Recherche · Calendrier · Paramètres
      connecté · À propos
- [ ] Versions claires : Stats, Mon titre, Connexion, Ma liste invité

## Hors refonte — à faire / en attente

- [ ] **Connexion Apple** (quand le compte Apple Developer à 99 €/an sera créé)
- [x] **Facturation Firebase** : forfait Blaze réactivé le 15/09 (Cloud Function
      `anilistToken` = liaison AniList). Conseillé : alerte de budget à 1 €.
- [ ] Suppression de compte (obligatoire Play Store) — Cloud Function possible
      maintenant que Blaze est actif
- [ ] Publier `firestore.rules` (règle `activity` ajoutée)
- [ ] Version incohérente : Paramètres « 1.0.0 » vs À propos « 1.2.0 »
- [ ] ASO + captures Play Store (après la refonte)

## Journal

- 15/09 — Plan créé, export Claude Design copié dans `design/`.
- 15/09 — Blaze réactivé : Cloud Function `anilistToken` répond de nouveau
  (400 sur faux code au lieu de « billing disabled »).
- 15/09 — Lot 1 (fondations) codé : analyse OK, 29 tests OK. Toute l'app prend
  les nouvelles couleurs/polices ; les écrans sont repris aux lots 2–4.
- 15/09 — Lot 2 (composants) codé : analyse OK, 39 tests OK (dont
  `test/ds_components_test.dart`). Prochaine étape : lot 3, écrans retenus,
  en commençant par Découvrir.
- 15/09 — Lot 3 : Découvrir refait (analyse OK, 45 tests OK dont
  `test/discover_hero_test.dart`). À valider sur téléphone (hero, zigzag).
  Prochain écran : fiche anime.
