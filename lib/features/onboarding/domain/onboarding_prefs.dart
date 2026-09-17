import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Réponse à « Anime, manga, ou les deux ? » de l'onboarding.
enum ContentChoice { anime, manga, both }

/// Préférences de l'onboarding, lues une fois au démarrage (`main.dart`) puis
/// injectées dans les providers ci-dessous.
abstract final class OnboardingPrefs {
  static const _storage = FlutterSecureStorage();
  static const _doneKey = 'onboarding_done';
  static const _choiceKey = 'content_choice';

  static Future<({bool done, ContentChoice? choice})> load() async {
    try {
      final done = await _storage.read(key: _doneKey);
      final choice = await _storage.read(key: _choiceKey);
      return (
        done: done != null,
        choice: ContentChoice.values.asNameMap()[choice],
      );
    } catch (_) {
      // Stockage illisible : on ne bloque jamais l'app sur l'onboarding
      return (done: true, choice: null);
    }
  }

  static Future<void> saveDone() =>
      _storage.write(key: _doneKey, value: 'done');

  static Future<void> saveChoice(ContentChoice choice) =>
      _storage.write(key: _choiceKey, value: choice.name);
}

/// Onboarding déjà vu (ou passé).
final onboardingDoneProvider = StateProvider<bool>((_) => true);

/// Contenu préféré déclaré à l'onboarding (null = pas répondu).
final contentChoiceProvider = StateProvider<ContentChoice?>((_) => null);

/// L'onboarding ne s'adresse qu'aux nouveaux venus : un compte connecté ou
/// une liste locale déjà remplie (mise à jour de l'app) le passent.
bool shouldShowOnboarding({
  required bool done,
  required bool isAuthenticated,
  required bool hasLocalEntries,
}) =>
    !done && !isAuthenticated && !hasLocalEntries;

/// Onglet ouvert par défaut : la liste décide quand elle penche d'un côté,
/// sinon la réponse de l'onboarding ('ANIME' par défaut).
String resolveContentPreference({
  required int animeCount,
  required int mangaCount,
  ContentChoice? choice,
}) {
  if (mangaCount > animeCount) return 'MANGA';
  if (animeCount > mangaCount) return 'ANIME';
  return choice == ContentChoice.manga ? 'MANGA' : 'ANIME';
}
