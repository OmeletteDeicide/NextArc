/// Découpe [text] en morceaux, en marquant ceux qui correspondent à [query]
/// (sans tenir compte de la casse), pour surligner le terme recherché.
List<({String text, bool match})> highlightParts(String text, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty || text.isEmpty) return [(text: text, match: false)];

  final haystack = text.toLowerCase();
  final parts = <({String text, bool match})>[];
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) break;
    if (index > start) {
      parts.add((text: text.substring(start, index), match: false));
    }
    parts.add((text: text.substring(index, index + needle.length), match: true));
    start = index + needle.length;
  }
  if (start < text.length) {
    parts.add((text: text.substring(start), match: false));
  }
  return parts;
}
