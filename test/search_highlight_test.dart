import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/search/domain/search_highlight.dart';

void main() {
  test('surligne le terme sans tenir compte de la casse', () {
    final parts = highlightParts('Cyberpunk: Edgerunners', 'cyber');
    expect(parts.map((p) => p.text), ['Cyber', 'punk: Edgerunners']);
    expect(parts.map((p) => p.match), [true, false]);
  });

  test('plusieurs occurrences', () {
    final parts = highlightParts('One or one', 'ONE');
    expect(parts.where((p) => p.match).length, 2);
    expect(parts.map((p) => p.text).join(), 'One or one');
  });

  test('aucune correspondance ou recherche vide → texte intact', () {
    expect(highlightParts('Akudama Drive', 'cyber'),
        [(text: 'Akudama Drive', match: false)]);
    expect(highlightParts('Akudama Drive', '  '),
        [(text: 'Akudama Drive', match: false)]);
  });
}
