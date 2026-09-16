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
- **Aucun motif de fond** (ni hachures ni zigzag) : essayé puis retiré le 16/09
  à la demande de Simon (« sans ça sort mieux »). Dégradés et halos conservés.
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
- [x] ~~Motif zigzag~~ retiré le 16/09 (widget, test et token supprimés)
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
- [x] Fiche anime (hero ≤ 38 %, pastilles sur icônes, carte « Dans ma liste »,
      synopsis replié 3 lignes, prochain épisode + Rappel)
- [x] Fiche d'édition (reprise visuelle, note en 10 segments)
- [x] Ma liste (segmenté Anime/Manga + un seul niveau d'onglets, bouton +1,
      carte « sorties cette semaine »)
- [x] Profil (en-tête zigzag + halo, badge de titre centré, carte « Route vers
      Arcer », menus)
- [x] Stats (récap narratif « Ton mois », tuiles, genres)
- [x] Écran « Mon titre » (2 jauges + Arcer doré + échelle des noms)
- [x] Cartes de partage (3 cartes, sombres, zone de sécurité 9:16)
- [x] Moment du palier (carte plein écran au passage de titre → Partager)

### Lot 4 — Comptes ✅ (code, à valider sur téléphone)
- [x] Connexion : Google principal, e-mail secondaire, « Continuer en invité »
- [x] Liaison AniList seulement une fois connecté (retirer la connexion AniList
      autonome, garder la restauration des sessions existantes)
- [x] Déconnexion : titre en question, action rouge, message rassurant
- [x] Mode invité : bandeau discret, états vides avec action,
      « dernière sauvegarde : il y a X j » sur l'export
- [x] Onboarding 3 écrans (promesse · anime/manga/les deux · compte), « Passer »
      dès le 1er écran, pas de demande de notifications

### Lot 5 — Écrans non dessinés (⏳ en attente des maquettes Claude Design)
- [ ] Calendrier : **regrouper par semaine** (« Cette semaine », « Semaine
      prochaine », jours en sous-titres) — idée de Simon du 16/09, à donner à
      Claude Design avec la demande de maquette
- [x] Paramètres (maquette « Paramètres invité ») : thème en segmenté, langues
      côte à côte, liste locale en carte + « Passer sur un compte ? », version
      unique (`app_version.dart`) — fait le 16/09, aussi pour les comptes connectés
- [x] « Modifier le profil » aligné sur le design system (pas de maquette)
- [ ] Pour toi · Explorer & filtres · Recherche · Calendrier · À propos
- [ ] Versions claires : Stats, Mon titre, Connexion, Ma liste invité

### Lot 6 — Revue 2 de Claude Design (`design/NextArc Revue 2 - Ecrans restants.dc.html`)
Ordre conseillé par la revue. Remarques de Simon (16/09) : la cloche de rappel
n'est **pas jaune** mais celle des fiches d'édition (notifications, accent) ;
**Ko-fi reste dans le Profil** au-dessus d'À propos (pas dans À propos), avec la
nouvelle couleur de la maquette.
- [x] Suppression de compte (bloqueur Play Store) : Paramètres « Zone
      sensible », écran explication supprimé / conservé + export, feuille
      « taper SUPPRIMER », écran en cours (3 étapes réelles), écran de fin
      (invité / nouveau compte). Cloud Function `deleteAccount` (Firestore
      récursif + Storage + Auth). Seul bouton **plein rouge** de l'app :
      Déconnexion / Retirer passent en **contour**.
- [x] Paramètres compte connecté : Compte (e-mail + fournisseur, AniList lié /
      Délier), Notifications (sorties d'épisodes, récap du mois), Application
      (À propos + version)
- [ ] Explorer : grille 2 colonnes, barre d'état (N résultats · N filtres ·
      Réinitialiser), chips actives avec ×, « Voir N résultats », score en
      segments, bouton + 44 px en bas à droite, squelettes, état vide qui
      nomme le filtre
- [ ] Calendrier : liste groupée par semaine, jours avec sorties seulement,
      pastille date 44 px, cloche 2 états, états vides
- [ ] Recherche : tendances à l'ouverture, lignes d'historique 44 px, résultats
      en liste (terme surligné, « dans ta liste »), aucun résultat / hors ligne
- [ ] Pour toi en rails : reco mise en avant, rails par source (≤ 2 par
      source, rotation quotidienne, ordre ❤️ > 10 > ≥ 8), rail « Dans tes
      genres », carte d'aide avec action
- [ ] À propos : bloc logo, paragraphe, carte AniList accentuée, technologies
      en chips, liens Confidentialité / Conditions / Licences (Ko-fi : non)
- [ ] Bannière de profil : feuille de choix, cascade (choisie > AniList >
      dégradé), scrim, en-tête 230 px, « Modifier le profil » refait
- [ ] Versions claires : Stats (mois vides = trait 3 px), Mon titre,
      Connexion (AniList en carte d'info en pied), Ma liste invité

## Hors refonte — à faire / en attente

- [ ] **Activer Firebase Storage** (console → Storage → Commencer) puis
      `firebase deploy --only storage` : le bucket n'existe pas encore, d'où
      l'erreur « object-not-found » à l'envoi d'une photo (16/09)
- [ ] **Changer sa bannière de profil** (la photo et le pseudo sont déjà
      modifiables) — pas de bannière choisie = bannière AniList si liée
- [ ] **Republier `firestore.rules`** : champs `customName` / `customPhoto`
      ajoutés le 16/09 (sinon l'édition du profil est refusée)
- [ ] **Connexion Apple** (quand le compte Apple Developer à 99 €/an sera créé)
- [x] **Facturation Firebase** : forfait Blaze réactivé le 15/09 (Cloud Function
      `anilistToken` = liaison AniList). Conseillé : alerte de budget à 1 €.
- [ ] Suppression de compte (obligatoire Play Store) — Cloud Function possible
      maintenant que Blaze est actif
- [x] Publier `firestore.rules` (règle `activity` ajoutée) — fait, Stats OK le 16/09
- [x] Version incohérente : 1.2.0 partout via `lib/core/constants/app_version.dart`
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
- 15/09 — Lot 3 : fiche anime refaite (bannière + jaquette 84 px, FAB retiré,
  carte « Dans ma liste », synopsis nettoyé/replié, note perso, prochain
  épisode + Rappel ; requête détail + `nextAiringEpisode`). Analyse OK,
  49 tests OK dont `test/synopsis_test.dart`. À valider sur téléphone.
  Prochain écran : fiche d'édition.
- 15/09 — Lot 3 : fiches d'édition (AniList, NextArc, invité) refaites sur
  des briques communes `edit_sheet_parts.dart` : statuts en pastilles,
  −/+ 44 px + barre glissable, note en 10 segments (toucher la note l'efface,
  glisser possible), carte notifications, Retirer / Mettre à jour. Logique
  d'enregistrement inchangée. Analyse OK, 56 tests OK dont
  `test/edit_sheet_parts_test.dart`. À valider sur téléphone.
  Prochain écran : Ma liste.
- 15/09 — Lot 3 : Ma liste refaite pour les 3 sources (AniList, NextArc,
  invité) via `ListItem` (`list_items.dart`) : titre + calendrier, segmenté
  Anime · N / Manga · N, un seul niveau d'onglets (En cours, Prévu, Favoris,
  En pause, Terminé, Abandonné ; vides masqués sauf Favoris), cartes avec
  +1 (atteindre le total → Terminé) ou « Démarrer », carte « sorties cette
  semaine » (réutilise `airingCalendarProvider`), bandeau invité discret.
  Glisser : retirer avec confirmation (NextArc/invité) ou modifier (AniList) ;
  appui long → fiche d'édition. Boutons grille/tri de la maquette non repris
  (pas de fonction derrière). Analyse OK, 66 tests OK dont
  `test/list_items_test.dart`. À valider sur téléphone.
  Prochain écran : Profil.
- 15/09 — Lot 3 : Profil connecté refait : en-tête dégradé + zigzag (violet
  en sombre avec halo, blanc en clair), boutons ronds modifier/déconnexion,
  avatar 84 px (photo ou initiale), nom, e-mail (ou ID AniList), badge de
  titre centré (`UserTitleBadge(onAccent:)` en clair), couronne Arcer seulement.
  Carte « Route vers Arcer » : titres terminés /1 500 et heures visionnage +
  lecture /12 000, « Palier n/7 » = qualificatif atteint (7/7 pour Arcer),
  tap → Stats (en attendant l'écran « Mon titre »). Menus : stats (résumé
  total), AniList connecté / « Lier », paramètres, Soutenir (doré), À propos.
  Connexion, migration invité et dialogue de déconnexion inchangés (Lot 4).
  Analyse OK, 70 tests OK dont `test/arcer_road_test.dart`. À valider sur
  téléphone. Prochain écran : Stats.
- 15/09 — Lot 3 : Stats refaites : en-tête retour + « Partager » ; carte
  « Ton mois » (zigzag, temps visionnage + lecture en grand, phrase
  « N épisodes et N chapitres, surtout des **genre**. Soit **+X %** par
  rapport à <mois> », barres des 7 derniers mois). Règle de comparaison
  (`month_story.dart`) : masquée si mois précédent < 3 h, % si hausse ou
  baisse ≤ 10 %, « autant » à 0 %, sinon « un mois plus calme ». Carte du mois
  masquée pour AniList seul (pas de journal). Tuiles cumul (épisodes, note
  moyenne, anime terminés, « Voir le détail » qui déplie manga/chapitres/
  temps/meilleures notes), genres en dégradé estompé, carte titre restylée.
  7 lectures `activity/{mois}` par ouverture. Analyse OK, 79 tests OK dont
  `test/month_story_test.dart`. À valider sur téléphone.
  Prochain : écran « Mon titre ».
- 15/09 — Lot 3 : écran « Mon titre » (`/my-title`, ouvert depuis la carte
  « Route vers Arcer » du Profil et la section titre des Stats) : en-tête
  « Mon titre actuel » (dégradé + zigzag + halo, pastilles « Petit · 9 h » /
  « Curieux · 2 »), jauge du nom (« Prochain : Spectateur 2/10 », « Encore 8
  anime terminés »), jauge du qualificatif (« 9/100 h », « Encore 91 h : tu
  perds le « Petit » et deviens Curieux »), carte Arcer dorée séparée (2
  jauges), échelle des noms repliée (atteint ✓, prochain pointillé, suivant,
  « N paliers jusqu'à Légende » dépliable). Getters purs ajoutés à
  `UserTitle` (rankIndex, nextRankThreshold, qualifierIndex,
  nextQualifierDropsWord…). Mots de qualificatif en/es à relire (Little,
  Pequeño…). Analyse OK, 85 tests OK dont `test/my_title_gauges_test.dart`.
  À valider sur téléphone. Prochain : cartes de partage.
- 15/09 — Lot 3 : cartes de partage refaites (toujours sombres, `AppColors.dark`
  même en thème clair) : fond dégradé + zigzag violet + halo, en-tête logo ·
  NextArc · repère (« SEPT. 2026 » / « TOTAL »), contenu dans la zone de
  sécurité 9:16 (9,4 % haut/bas ≈ 180 px sur 1920), pied avec identité selon
  les interrupteurs (photo + pseudo, titre violet ou doré Arcer, couronne
  Arcer seulement) et pastille blanche « Dispo sur Google Play » (aucun
  domaine). Récap : « MON SEPTEMBRE / 9 H 36 DE VIE EN PLUS. », épisodes ·
  note moy. · terminés, top 3 du mois numéroté. Stats : même gabarit en cumul,
  meilleures notes (ou genres). Préférés : « N COUPS DE CŒUR. » + mosaïque.
  Écran : retour + titre, points, interrupteurs, `AppButton`. Textes en/es des
  accroches à relire. Analyse OK, 89 tests OK dont
  `test/share_card_data_test.dart`. À valider sur téléphone (capture PNG).
  Prochain : moment du palier.
- 15/09 — Lot 3 : moment du palier. `MainShell` écoute `statsProvider` et
  compare l'ancien et le nouveau titre (`title_promotion.dart`, pur) : Arcer >
  nouveau nom > nouveau qualificatif ; jamais sur une baisse, jamais une fois
  Arcer, jamais au démarrage ni lors d'un changement de compte (propriétaire
  du titre mémorisé). Carte plein écran toujours sombre (zigzag + halo, doré
  pour Arcer avec 👑), « Nouveau titre », phrase selon le palier, un seul CTA
  « Partager » → carrousel, bouton fermer. Non repris : pulsation du badge du
  profil (le profil n'est pas affiché à ce moment-là). Un palier franchi
  pendant que l'app est fermée (synchro AniList) n'est pas célébré. Analyse
  OK, 95 tests OK dont `test/title_promotion_test.dart`.
  **Lot 3 terminé** — tout reste à valider sur téléphone avant le Lot 4.
- 15/09 — Correctif : écran rouge sur Stats (`permission-denied` sur
  `activity/{mois}`). `AsyncValue.value` relance l'erreur en Riverpod 2 →
  toujours `valueOrNull` dans le nouveau code. Cause côté serveur : règle
  `activity` de `firestore.rules` pas encore publiée.
- 16/09 — Validé sur téléphone : Stats OK après publication des règles,
  Blaze réactivé. **Zigzag retiré partout** (Découvrir, hero, Profil, Stats,
  Mon titre, cartes de partage, moment du palier) : `zigzag_background.dart`,
  `test/zigzag_painter_test.dart` et le token `AppColors.zigzag` supprimés.
  Dégradés et halos gardés. Analyse OK, 93 tests OK. Prochain : Lot 4.
- 16/09 — Lot 4 (1/3) : écran de connexion (Profil non connecté) refait :
  logo, « Retrouve ta liste, où que tu sois. », 3 bénéfices, **Google en
  bouton principal**, e-mail en secondaire, « Continuer en invité » + rappel
  que la liste reste sur l'appareil, mention « compte AniList ? à lier une fois
  connecté », Paramètres / À propos. Bouton de connexion AniList autonome
  retiré (restauration des sessions AniList existantes inchangée). Écran
  e-mail restylé (retour rond, titre, champs du thème, `AppButton`, erreur en
  rouge discret, autofill). Nouveau `showConfirmDialog` (ds) : « Se
  déconnecter ? », message selon le compte (NextArc / AniList seul), action
  en rouge plein (`AppButtonVariant.danger`) ; aussi utilisé pour « Retirer de
  la liste ». Analyse OK, 93 tests OK.
- 16/09 — Lot 4 (2/3) : mode invité. Bandeau de Ma liste « Mode invité — ta
  liste est gardée sur cet appareil » + Connexion + croix (masqué pour la
  session, `guestBannerDismissedProvider`). État vide avec promesse et actions :
  « Explorer les tendances » (→ Découvrir) et, en invité, « Importer une liste
  .json » (→ Paramètres). Paramètres : sous-titre de l'export = « Dernière
  sauvegarde : aujourd'hui / hier / il y a N j » ou « Jamais sauvegardée »
  (`guest_backup.dart`, date écrite après le partage du JSON). L'écran
  Paramètres lui-même reste à restyler (Lot 5, maquette invité claire dispo).
  Analyse OK, 97 tests OK dont `test/guest_backup_test.dart`.
- 16/09 — Lot 4 (3/3) : onboarding `/onboarding` (`features/onboarding`).
  3 écrans (01 promesse avec logo + halo · 02 anime / manga / les deux en
  cartes · 03 compte : Google principal, e-mail, « Continuer en invité »),
  « Passer » en haut de chaque écran, points + « Suivant », aucune demande de
  notifications. Déclenché par `MainShell` au 1er lancement, avant le message
  de récap ; un utilisateur existant (connecté ou liste locale non vide) est
  marqué « vu » en silence. Préférences en stockage sécurisé, lues dans
  `main.dart` (`OnboardingPrefs.load` → overrides). La réponse 02 sert
  d'onglet par défaut quand la liste est à égalité (vide) :
  `resolveContentPreference`. Pour le revoir : effacer les données de l'app.
  Analyse OK, 101 tests OK dont `test/onboarding_prefs_test.dart`.
  **Lot 4 terminé** — reste le Lot 5 (maquettes à venir) et le hors refonte.
- 16/09 — Retours de test de Simon, corrigés :
  - Barres de progression qui grandissaient depuis le centre (piste réduite au
    remplissage dans un `Center`) → piste toujours pleine largeur, test ajouté.
  - Note : demi-points possibles (moitié gauche d'un segment = ,5).
  - Vrai logo Google multicolore dessiné (`google_logo.dart`) sur la connexion
    et l'onboarding.
  - Carte « Nouveau titre » : palier le plus haut mémorisé **par compte**
    (`title_level_<compte>`), comparaison après 3 s de stabilité. Plus de
    carte à chaque reconnexion ; un utilisateur existant ne voit qu'une carte,
    celle de son titre actuel.
  - Pseudo / photo : ceux choisis dans NextArc (`customName`/`customPhoto`,
    ou photo envoyée dans Storage pour les anciens profils, ou pseudo tapé à
    l'inscription e-mail) ne sont jamais remplacés par AniList ; sinon AniList
    les remplace. **Délier AniList** depuis la ligne AniList du profil (liste
    NextArc conservée).
  - Onboarding écran 1 : éventail des 3 anime tendance du moment (n°1 devant).
  - Ancien texte « synchroniser avec AniList » du bandeau invité remplacé.
  Analyse OK, 112 tests OK.
- 16/09 — Pour toi : en-tête titre + segmenté, cartes reco d'abord / raison
  en petit, bouton rond partagé (`RoundIconButton`) ; pulsation du badge de
  titre sur le Profil après un palier. Lot 5 : brief rédigé pour Claude Design
  (`design/PROMPT_CLAUDE_DESIGN_2.md`) — Explorer + filtres, Recherche, Pour
  toi, Calendrier par semaine, À propos, versions claires, bannière de profil,
  suppression de compte, Paramètres connecté. **Attendre ses maquettes.**
- 16/09 — Lot 6 (1) : suppression de compte + Paramètres connecté.
  Cloud Function `deleteAccount` (onRequest, jeton Firebase vérifié,
  étapes `data` = Firestore récursif et `account` = Storage puis Auth) —
  **à déployer** : `firebase deploy --only functions:deleteAccount`. Écran
  `/delete-account` : explication supprimé / conservé (AniList seulement si
  lié) + export JSON, feuille « taper SUPPRIMER » (DELETE / ELIMINAR), 3 étapes
  réelles (liaison AniList locale, données, compte), reprise après échec,
  écran de fin invité / nouveau compte. Paramètres connecté : Compte (e-mail
  + Google/e-mail, AniList lié → Délier ou Lier), Notifications (sorties
  d'épisodes, récap du mois — réglages globaux Hive, respectés par la tâche
  de fond et le message de début de mois), Application (À propos + version),
  Zone sensible. Confirmations destructives en contour ; plein rouge réservé
  à la suppression. Analyse OK, 117 tests OK.
