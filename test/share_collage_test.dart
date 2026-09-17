import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/share/domain/share_providers.dart';

void main() {
  test('la mosaïque affiche des lignes complètes de 3 jaquettes', () {
    expect(collageSize(0), 0);
    expect(collageSize(2), 0);
    expect(collageSize(3), 3);
    expect(collageSize(5), 3);
    expect(collageSize(6), 6);
    expect(collageSize(8), 6);
    expect(collageSize(9), 9);
    expect(collageSize(40), 9);
  });
}
