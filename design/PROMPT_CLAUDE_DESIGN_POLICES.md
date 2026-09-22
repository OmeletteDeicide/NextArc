# Prompt Claude Design — test de polices NextArc

À coller dans Claude Design avec, en pièces jointes :
- les polices : `RACING HARD.ttf`, `Delight-*.ttf` (Regular, Medium, SemiBold, Bold, ExtraBold), `ChakraPetch-*.ttf` (Regular, Italic, Medium, SemiBold, Bold) ;
- les captures : `03-ma-liste-favoris.png`, `04-fiche.png`, `06-stats.png` (dossier `store/screenshots/fr-sombre/`).

---

Tu travailles sur **NextArc**, une app Android de suivi d'anime et de manga (thème sombre « Arc Nocturne »). Je veux comparer deux nouvelles combinaisons de polices sur trois écrans existants, **sans rien changer d'autre** : même mise en page, mêmes couleurs, mêmes tailles, mêmes contenus. Seules les polices changent.

## Les écrans (captures jointes, à reproduire fidèlement)

1. **Ma liste** (`03-ma-liste-favoris.png`) : titre « Ma liste », sélecteur Anime · 28 / Manga · 3, onglets En cours / Prévu / ♥ Favoris / Terminé avec compteurs, cartes d'œuvres (jaquette, titre, « ★ 10 · Terminé », cœur), barre de navigation en bas.
2. **Fiche d'une œuvre** (`04-fiche.png`) : bannière floutée, jaquette, titre « Cyberpunk: Edgerunners », sous-titre, « ★ 8,5 · 10 ép. · ● Terminé », carte « Dans ma liste · Terminé » avec barre de progression 10/10 et bouton « Modifier », pastilles de genres, section « Synopsis », « Lire plus », section « Ma note perso » avec champ en italique.
3. **Statistiques** (`06-stats.png`) : titre « Mes statistiques » + bouton « Partager », carte « TON SEPTEMBRE » avec le grand chiffre « 6 H 48 » et l'histogramme des mois, tuiles « 612 Épisodes vus », « 8,4 note moyenne », « 22 Anime terminés », « Voir le détail », section « Genres favoris » avec barres.

## Règle commune aux deux variantes

**RACING HARD** (la police du logo) pour :
- les titres d'écran (« Ma liste », « Mes statistiques ») ;
- les titres de section (« Synopsis », « Ma note perso », « Genres favoris ») ;
- les grands chiffres (« 6 H 48 », « 612 », « 8,4 », « 22 »).

Attention :
- RACING HARD n'a que des capitales : les minuscules s'affichent en capitales, c'est normal.
- Elle est plus large et moins haute que la police actuelle : compense avec une taille environ 15 % plus grande, un interligne d'environ 1,2 et un léger espacement positif.
- Si un titre passe sur deux lignes, garde-le lisible, sans chevauchement.

**Tout le reste** dans la police testée : titres des œuvres, textes, méta (« ★ 10 · Terminé »), boutons, onglets, pastilles, sur-titres en capitales (« TON SEPTEMBRE », mois), barre de navigation.

## Les deux variantes à produire

- **Variante A — Delight** : RACING HARD + Delight.
  - Graisses : titres d'œuvres et boutons en Bold/ExtraBold ; texte courant en Regular ; méta en Medium.
  - Delight n'a pas d'italique : pour le champ « Ajouter une note personnelle… », utilise Regular sans italique.
- **Variante B — Chakra Petch** : RACING HARD + Chakra Petch.
  - Graisses : mêmes équivalences.
  - Italique réelle pour le champ de note.

## Correspondance avec l'échelle actuelle (1 px = 1 dp)

| Rôle | Actuel | Taille |
|---|---|---|
| Titre d'écran | Sora 800 | 24 (28 pour « Ma liste ») |
| Titre de section | Sora 700 | 17 |
| Grand chiffre | Archivo Black | 36 (28 dans les tuiles) |
| Titre d'œuvre / carte | Manrope 700 | 14 |
| Texte courant | Manrope 400 | 13, interligne 21 |
| Méta | Manrope 500 | 11 |
| Boutons, onglets | Manrope 700–800 | 12–14 |
| Sur-titre en capitales | JetBrains Mono 600 | 10, espacement +14 % |

Pour les sur-titres, remplace JetBrains Mono par la police testée en SemiBold capitales, espacement +14 %.

## Couleurs (inchangées)

Fond `#060A15` · surface `#0B1226` · surface 2 `#131C36` · accent `#6D8BFF` → violet `#8B5CF6` · texte `#EDF1FF` / `#94A1C4` / `#66739A` · étoile `#FFC145` · favori `#FF5C72`.

## Livrable

- Une planche : **3 lignes (écrans) × 3 colonnes (Actuelle, A — Delight, B — Chakra Petch)**, maquettes de téléphone de 360 × 760.
- Sous chaque variante, 2–3 lignes d'avis :
  - lisibilité des petits textes (11 px) ;
  - cohérence avec le logo ;
  - titres trop larges ;
  - chiffres ambigus (la virgule de « 8,4 » en RACING HARD).
- Pas de nouveau motif de fond, pas de changement de mise en page ni de couleur.
