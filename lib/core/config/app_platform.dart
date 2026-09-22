import 'package:flutter/foundation.dart';

/// Version iOS de l'app : connexion Apple, pas de lien de don externe, mention
/// de l'App Store au lieu de Google Play.
bool get isIosApp => defaultTargetPlatform == TargetPlatform.iOS;
