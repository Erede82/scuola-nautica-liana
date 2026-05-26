import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_branding.dart';

/// Apre telefono, email, WhatsApp, mappe e link in modo sicuro con fallback UX.
abstract final class SchoolContactLauncher {
  static void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> _tryLaunch(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      final ok = await launchUrl(uri, mode: mode);
      if (!ok && context.mounted) {
        _snack(context, 'Impossibile completare l’azione. Riprova più tardi.');
      }
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Impossibile aprire il collegamento.');
      }
    }
  }

  /// Normalizza per schema `tel:` (conserva `+` iniziale, solo numeri dopo).
  static String normalizePhoneForTel(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('00')) {
      s = '+${s.substring(2)}';
    }
    final buf = StringBuffer();
    for (final c in s.split('')) {
      if (c == '+' && buf.isEmpty) {
        buf.write(c);
      } else if (RegExp(r'\d').hasMatch(c)) {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  static Future<void> dialSupportPhone(BuildContext context) async {
    if (!AppBranding.hasSupportPhone) {
      _snack(
        context,
        'Numero di telefono non ancora configurato nella app.',
      );
      return;
    }
    final tel = normalizePhoneForTel(AppBranding.supportPhone);
    if (tel.isEmpty) {
      _snack(context, 'Numero di telefono non valido.');
      return;
    }
    await _tryLaunch(context, Uri.parse('tel:$tel'));
  }

  static Future<void> openWhatsApp(BuildContext context) async {
    final digits =
        AppBranding.whatsAppNumber.replaceAll(RegExp(r'\D'), '');
    if (!AppBranding.hasWhatsApp || digits.isEmpty) {
      _snack(
        context,
        'WhatsApp non ancora configurato in app.',
      );
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    await _tryLaunch(context, uri);
  }

  static Future<void> sendSupportEmail(BuildContext context) async {
    if (!AppBranding.hasSupportEmail) {
      _snack(
        context,
        'Indirizzo email non ancora configurato nella app.',
      );
      return;
    }
    final email = AppBranding.supportEmail.trim();
    final subject = Uri.encodeComponent('Richiesta da app - ${AppBranding.schoolName}');
    final uri = Uri.parse('mailto:$email?subject=$subject');
    await _tryLaunch(context, uri);
  }

  static Future<void> openMap(BuildContext context) async {
    if (!AppBranding.hasMapUrl) {
      _snack(context, 'Link alla mappa non configurato.');
      return;
    }
    final uri = Uri.tryParse(AppBranding.schoolMapSearchUrl.trim());
    if (uri == null || !uri.hasScheme) {
      _snack(context, 'Link alla mappa non valido.');
      return;
    }
    await _tryLaunch(context, uri);
  }

  static Future<void> openReviews(BuildContext context) async {
    if (!AppBranding.hasReviewsUrl) {
      _snack(context, 'Link alle recensioni non configurato.');
      return;
    }
    final uri = Uri.tryParse(AppBranding.schoolReviewsUrl.trim());
    if (uri == null || !uri.hasScheme) {
      _snack(context, 'Link alle recensioni non valido.');
      return;
    }
    await _tryLaunch(context, uri);
  }

  static Future<void> openInstagram(BuildContext context) async {
    if (!AppBranding.hasInstagramUrl) {
      _snack(context, 'Profilo Instagram non ancora configurato.');
      return;
    }
    final uri = Uri.tryParse(AppBranding.instagramUrl.trim());
    if (uri == null || !uri.hasScheme) {
      _snack(context, 'Link Instagram non valido.');
      return;
    }
    await _tryLaunch(context, uri);
  }

  /// Apre un URL https generico (validazione minima).
  static Future<void> openHttpUrl(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _snack(context, 'Collegamento non disponibile.');
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      _snack(context, 'Collegamento non valido.');
      return;
    }
    await _tryLaunch(context, uri);
  }
}
