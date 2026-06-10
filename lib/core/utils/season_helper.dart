/// Helper pour déterminer la saison anime en cours.
class SeasonHelper {
  SeasonHelper._();

  /// Retourne la saison AniList correspondant au mois donné.
  /// WINTER = Jan-Mar, SPRING = Apr-Jun, SUMMER = Jul-Sep, FALL = Oct-Dec.
  static String getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'WINTER';
    if (month >= 4 && month <= 6) return 'SPRING';
    if (month >= 7 && month <= 9) return 'SUMMER';
    return 'FALL';
  }

  static int getCurrentYear() => DateTime.now().year;
}
