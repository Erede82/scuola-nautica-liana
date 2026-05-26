import 'package:flutter/material.dart';

/// Customer-facing branding and **single source of truth** for school / contact data.
///
/// Con WhatsApp, social e link: evita valori duplicati nelle pagine.
abstract final class AppBranding {
  // --- App identity --------------------------------------------------------

  /// Nome completo mostrato nell’app (AppBar, dashboard, contatti).
  static const String schoolName = 'Scuola Nautica Liana';

  /// Alias storico / compatibile con il codice esistente.
  static const String inAppName = schoolName;

  /// Nome sotto l’icona sul launcher (configurato anche a livello di piattaforma).
  static const String launcherDisplayName = 'Nautica Liana';

  /// Marchio in UI (testo + tint logo simbolo) — RGB(23, 161, 200).
  static const Color brandAqua = Color(0xFF17A1C8);

  // --- Recapiti ------------------------------------------------------------

  /// Telefono / segreteria (visualizzato anche come recapito WhatsApp).
  static const String supportPhone = '081 870 1132';

  /// WhatsApp: **solo cifre**, prefisso internazionale senza `+` (+39 081…).
  static const String whatsAppNumber = '390818701132';

  /// Email segreteria per `mailto:`.
  static const String supportEmail = '';

  /// Profilo Instagram — *scuola nautica liana* → handle @scuolanauticaliana.
  static const String instagramUrl = 'https://www.instagram.com/scuolanauticaliana/';

  /// Indirizzo sede (allineato al link Maps).
  static const String schoolAddressLine =
      'Via Amato, 4, 80053 Castellammare di Stabia NA';

  /// Riga breve orari (sottotitoli, tile compatte).
  static const String officeHoursLine =
      'Segreteria: lun–ven 9:00–13:00 e 14:15–21:00';

  /// Orari completi per pagina Contatti / testi informativi.
  static const String officeAndCourseHoursDetail =
      'Segreteria — dal lunedì al venerdì:\n'
      '9:00–13:00 · 14:15–21:00\n\n'
      'Orari lezioni in aula:\n'
      '• 14:30–15:30\n'
      '• 19:00–20:00\n'
      '• 20:00–21:00';

  // --- Link esterni --------------------------------------------------------

  /// Scheda Google Maps (place ufficiale scuola).
  static const String schoolMapSearchUrl =
      'https://www.google.com/maps/place/Autoscuola+%26+Scuola+Nautica+Liana/@40.7004698,14.4850357,17z/data=!4m15!1m8!3m7!1s0x133bbd463dd3b227:0xe10349edf9c1d79c!2sVia+Amato,+4,+80053+Castellammare+di+Stabia+NA!3b1!8m2!3d40.7004698!4d14.4850357!16s%2Fg%2F11y_k5pty9!3m5!1s0x133bbd46395dd29b:0xfbb561a0e3e0986a!8m2!3d40.7004698!4d14.4850357!16s%2Fg%2F1tdqw_hs?entry=ttu&g_ep=EgoyMDI2MDQyMS4wIKXMDSoASAFQAw%3D%3D';

  static const String schoolReviewsUrl =
      'https://www.google.com/search?q=Scuola+Nautica+Liana+recensioni';

  // --- Helpers -------------------------------------------------------------

  static bool get hasSupportPhone => supportPhone.trim().isNotEmpty;
  static bool get hasWhatsApp =>
      whatsAppNumber.trim().replaceAll(RegExp(r'\D'), '').isNotEmpty;
  static bool get hasSupportEmail => supportEmail.trim().isNotEmpty;
  static bool get hasInstagramUrl => instagramUrl.trim().isNotEmpty;
  static bool get hasSchoolAddress => schoolAddressLine.trim().isNotEmpty;
  static bool get hasMapUrl => schoolMapSearchUrl.trim().isNotEmpty;
  static bool get hasReviewsUrl => schoolReviewsUrl.trim().isNotEmpty;

  static String get supportPhoneDisplay =>
      hasSupportPhone ? supportPhone.trim() : 'Non configurato';

  static String get supportEmailDisplay =>
      hasSupportEmail ? supportEmail.trim() : 'Non configurato';

  // --- Asset immagini (`pubspec`: assets/images/branding/) ---------------

  static const String logoScuolaNauticaLianaWhite =
      'assets/images/branding/logo_scuola_nautica_liana_white.png';
  static const String logoScuolaNauticaLianaCapri =
      'assets/images/branding/logo_scuola_nautica_liana_capri.png';
  static const String logoScuolaNauticaLianaBlue =
      'assets/images/branding/logo_scuola_nautica_liana_blue.png';

  // --- Logo mark (simbolo senza scritta; `pubspec`: assets/branding/) -----
  // white: top bar blu, hero, overlay | aqua: sfondi chiari standalone |
  // blue: raro, secondario.

  static const String logoMarkWhite = 'assets/branding/logo_mark_white.png';
  static const String logoMarkAqua = 'assets/branding/logo_mark_aqua.png';
  static const String logoMarkBlue = 'assets/branding/logo_mark_blue.png';

  static String pathForMark(AppLogoMarkVariant variant) {
    switch (variant) {
      case AppLogoMarkVariant.white:
        return logoMarkWhite;
      case AppLogoMarkVariant.aqua:
        return logoMarkAqua;
      case AppLogoMarkVariant.blue:
        return logoMarkBlue;
    }
  }

  static const String welcomeBoatJpg =
      'assets/images/welcome/welcome_boat.jpg';
  static const String welcomeClassroomJpg =
      'assets/images/welcome/welcome_classroom.jpg';

  /// Video hero schermata benvenuto (`pubspec`: assets/videos/).
  static const String welcomeHeroVideo = 'assets/videos/welcome_hero.mp4';
}

/// Variante file PNG del marchio (solo simbolo).
enum AppLogoMarkVariant {
  /// Top bar blu, hero scura, overlay foto/video.
  white,

  /// Sfondi chiari, schermate istituzionali, empty state.
  aqua,

  /// Raro, non come marchio principale.
  blue,
}
