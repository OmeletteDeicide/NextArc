import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/detail/domain/synopsis.dart';

void main() {
  test('retire balises et entités, garde les retours à la ligne', () {
    expect(
      cleanSynopsis('Rudeus &amp; Roxy<br><br><i>arrivent</i> à l&#039;école.'),
      "Rudeus & Roxy\n\narrivent à l'école.",
    );
  });

  test('retire la source, les notes éditoriales et « Written by »', () {
    const raw = 'Cyberpunk: Edgerunners tells a standalone story.<br><br>'
        '(Source: CD PROJEKT RED)<br><br>'
        'Note: The first episode received a pre-screening.<br>'
        '[Written by MAL Rewrite]';
    expect(
      cleanSynopsis(raw),
      'Cyberpunk: Edgerunners tells a standalone story.',
    );
  });

  test('un texte déjà propre reste identique', () {
    expect(cleanSynopsis('Une histoire simple.'), 'Une histoire simple.');
  });

  test('ne supprime pas le mot « note » au milieu d\'une phrase', () {
    expect(
      cleanSynopsis('Il prend note de tout.'),
      'Il prend note de tout.',
    );
  });
}
