import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:nextarc/features/stats/presentation/user_title_badge.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Thème de test : tokens du design system, sans polices Google (pas de
/// réseau en test).
Widget host(Widget child, {Brightness brightness = Brightness.dark}) {
  final colors =
      brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return MaterialApp(
    theme: ThemeData(brightness: brightness, extensions: [colors]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppButton', () {
    testWidgets('déclenche onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
          host(AppButton(label: 'Partager', onPressed: () => taps++)));
      await tester.tap(find.text('Partager'));
      expect(taps, 1);
    });

    testWidgets('en chargement : indicateur et aucun déclenchement',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(AppButton(
          label: 'Envoyer', loading: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Envoyer'));
      expect(taps, 0);
    });

    testWidgets('respecte la zone tactile de 44 px', (tester) async {
      await tester.pumpWidget(host(AppButton(label: 'OK', onPressed: () {})));
      expect(tester.getSize(find.byType(AppButton)).height,
          greaterThanOrEqualTo(AppSpacing.minTouch));
    });
  });

  testWidgets('GradientProgressBar borne la valeur entre 0 et 1',
      (tester) async {
    await tester.pumpWidget(host(const SizedBox(
      width: 200,
      child: GradientProgressBar(value: 1.8, animate: false),
    )));
    await tester.pumpAndSettle();
    final fill = find.descendant(
      of: find.byType(GradientProgressBar),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(fill).width, 200);
  });

  testWidgets(
      'GradientProgressBar remplit depuis la gauche même dans un Center',
      (tester) async {
    await tester.pumpWidget(host(const SizedBox(
      width: 200,
      child: Center(child: GradientProgressBar(value: 0.5, animate: false)),
    )));
    await tester.pumpAndSettle();
    final bar = find.byType(GradientProgressBar);
    final fill =
        find.descendant(of: bar, matching: find.byType(DecoratedBox));
    // La piste occupe toute la largeur, le remplissage part du bord gauche
    expect(tester.getSize(bar).width, 200);
    expect(tester.getSize(fill).width, 100);
    expect(tester.getTopLeft(fill).dx, tester.getTopLeft(bar).dx);
  });

  testWidgets('StatusChip sélectionnable déclenche onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(StatusChip(
      status: ListStatus.completed,
      selected: false,
      onTap: () => taps++,
    )));
    await tester.tap(find.byType(StatusChip));
    expect(taps, 1);
  });

  testWidgets('SegmentedControl renvoie le segment choisi', (tester) async {
    String? chosen;
    await tester.pumpWidget(host(SizedBox(
      width: 300,
      child: SegmentedControl<String>(
        segments: const [
          (value: 'anime', label: 'Anime'),
          (value: 'manga', label: 'Manga'),
        ],
        selected: 'anime',
        onChanged: (v) => chosen = v,
      ),
    )));
    await tester.tap(find.text('Anime'));
    expect(chosen, isNull, reason: 'le segment déjà actif ne notifie pas');
    await tester.tap(find.text('Manga'));
    expect(chosen, 'manga');
  });

  testWidgets('StatTile affiche la valeur et le libellé', (tester) async {
    await tester.pumpWidget(host(
      const SizedBox(width: 160, child: StatTile(value: '24', label: 'épisodes vus')),
      brightness: Brightness.light,
    ));
    expect(find.text('24'), findsOneWidget);
    expect(find.text('épisodes vus'), findsOneWidget);
  });

  testWidgets('MediaCard : titre, note et action rapide', (tester) async {
    var actions = 0;
    await tester.pumpWidget(host(SizedBox(
      width: 150,
      child: MediaCard(
        title: 'ONE PIECE',
        imageUrl: null,
        score: '8,7',
        meta: '1128 ép.',
        rank: 1,
        onAction: () => actions++,
      ),
    )));
    expect(find.text('ONE PIECE'), findsOneWidget);
    expect(find.text('8,7'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(actions, 1);
  });

  group('UserTitleBadge', () {
    UserTitle title({bool arcer = false}) => UserTitle.from(
          animeCompleted: arcer ? 1500 : 2,
          mangaCompleted: 0,
          watchMinutes: arcer ? 12000 * 60 : 60,
          readMinutes: 0,
        );

    testWidgets('pas de couronne hors Arcer', (tester) async {
      await tester.pumpWidget(host(UserTitleBadge(title: title())));
      expect(find.text('👑'), findsNothing);
    });

    testWidgets('couronne pour un Arcer, masquable', (tester) async {
      await tester.pumpWidget(host(UserTitleBadge(title: title(arcer: true))));
      expect(find.text('👑'), findsOneWidget);

      await tester.pumpWidget(host(
          UserTitleBadge(title: title(arcer: true), showCrown: false)));
      expect(find.text('👑'), findsNothing);
    });
  });
}
