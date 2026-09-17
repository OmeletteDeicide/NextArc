/// Nettoie un synopsis AniList pour l'affichage : balises HTML, entités,
/// mentions de source et notes éditoriales (souvent en anglais).
String cleanSynopsis(String raw) {
  var text = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#039;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&mdash;', '—');

  text = text
      // « (Source: CD PROJEKT RED) »
      .replaceAll(
          RegExp(r'\(\s*sources?\s*:[^)]*\)', caseSensitive: false), '')
      // « [Written by MAL Rewrite] »
      .replaceAll(RegExp(r'\[\s*written by[^\]]*\]', caseSensitive: false), '')
      // « Note: The first episode received a pre-screening… »
      .replaceAll(
          RegExp(r'^\s*notes?\s*:.*$', caseSensitive: false, multiLine: true),
          '');

  return text
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
