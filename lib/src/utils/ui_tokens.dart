import 'package:flutter/material.dart';

/// Hiraukan spacing scale shared by ordinary application surfaces.
///
/// The 4/8/12/16/20/24/32 rhythm keeps the light and dark modes structurally
/// identical while leaving enough breathing room for the calmer visual style.
abstract final class UiSpacing {
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double roomy = 20;
  static const double xLarge = 24;
  static const double xxLarge = 32;
}

/// Rounded geometry used across Hiraukan. The values intentionally stay soft
/// without turning every control into an oversized pill.
abstract final class UiRadii {
  static const double tag = 8;
  static const double control = 12;
  static const double list = 16;
  static const double card = 20;
  static const double capsule = 24;
  static const double hero = 24;
}

abstract final class UiControlSize {
  static const double compact = 40;
  static const double standard = 48;
  static const double settingsLeading = 52;
  static const double iconButton = 40;
}

abstract final class UiIconSize {
  static const double small = 16;
  static const double standard = 20;
  static const double large = 24;
}

/// Text roles for ordinary controls. Colors and platform font families remain
/// inherited from ThemeData so multilingual rendering stays intact.
abstract final class UiTextStyles {
  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle supporting = TextStyle(
    fontSize: 12,
    height: 1.5,
  );
  static const TextStyle filterChipLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}
