import 'package:flutter/material.dart';

/// Référence unique — un audit antérieur en avait inventé une autre par erreur.
/// Voir docs/restructuration_claude.md, chapitre 08.
///
/// Contraste vérifié :
/// - `accent` sur `lightBg` ≈ 5,0:1 → passe WCAG AA texte normal (seuil 4.5:1)
/// - `accent` sur `darkBg`  ≈ 3,8:1 → ne passe PAS pour texte normal (passe pour
///   UI/texte large, seuil 3:1)
///
/// Règle d'usage : `accent` pour tout élément non-textuel sur les deux thèmes ;
/// `accentTextOnDark` uniquement pour du texte sur fond sombre.
class AppColors {
  static const accent = Color(0xFFD71921); // rouge dot-matrix — boutons, badges, icônes
  static const accentTextOnDark = Color(0xFFFF4D4D); // texte/erreur SUR FOND SOMBRE uniquement
  static const lightBg = Color(0xFFFAFAFA);
  static const darkBg = Color(0xFF0A0A0A);

  // Sépia (chapitre 12, NF-078) — thème de lecture dédié, au-delà de clair/sombre.
  static const sepiaBg = Color(0xFFF4ECD8);
  static const sepiaText = Color(0xFF3B2A1A);
}
