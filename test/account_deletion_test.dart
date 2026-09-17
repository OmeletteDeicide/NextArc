import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/account/data/account_deletion_service.dart';

void main() {
  test('le mot de confirmation doit correspondre exactement', () {
    expect(deletionConfirmationMatches('SUPPRIMER', 'SUPPRIMER'), isTrue);
    expect(deletionConfirmationMatches('  SUPPRIMER ', 'SUPPRIMER'), isTrue);
    expect(deletionConfirmationMatches('supprimer', 'SUPPRIMER'), isFalse);
    expect(deletionConfirmationMatches('SUPPRIME', 'SUPPRIMER'), isFalse);
    expect(deletionConfirmationMatches('', 'SUPPRIMER'), isFalse);
  });

  test('les étapes serveur envoient les noms attendus par la fonction', () {
    expect(DeletionServerStep.data.name, 'data');
    expect(DeletionServerStep.account.name, 'account');
  });
}
