import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_auth_gate.dart';
import 'app_root_navigator.dart';
import 'pages/forgot_password_page.dart';
import 'pages/login_page.dart';
import 'pages/student_registration_page.dart';
import 'theme/app_visual_tokens.dart';

class ScuolaNauticaLianaApp extends StatelessWidget {
  const ScuolaNauticaLianaApp({super.key});

  /// Ovo + Montserrat. Palette: [AppVisual] (beige + inchiostro + blu logo).

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: AppVisual.ink,
      displayColor: AppVisual.ink,
    );

    /// Corpo / UI: Montserrat (sito carica weight 500).
    var appTextTheme = GoogleFonts.montserratTextTheme(baseTextTheme);

    /// Titoli grandi: Ovo regular (unico peso su Google Fonts per Ovo).
    appTextTheme = appTextTheme.copyWith(
      displayLarge: GoogleFonts.ovo(
        textStyle: appTextTheme.displayLarge?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w400,
          height: 1.15,
          color: AppVisual.ink,
        ),
      ),
      displayMedium: GoogleFonts.ovo(
        textStyle: appTextTheme.displayMedium?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          height: 1.18,
          color: AppVisual.ink,
        ),
      ),
      displaySmall: GoogleFonts.ovo(
        textStyle: appTextTheme.displaySmall?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w400,
          height: 1.2,
          color: AppVisual.ink,
        ),
      ),
      headlineLarge: GoogleFonts.ovo(
        textStyle: appTextTheme.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w400,
          height: 1.22,
          color: AppVisual.ink,
        ),
      ),
      headlineMedium: GoogleFonts.ovo(
        textStyle: appTextTheme.headlineMedium?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w400,
          height: 1.24,
          color: AppVisual.ink,
        ),
      ),
      headlineSmall: GoogleFonts.ovo(
        textStyle: appTextTheme.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          height: 1.26,
          color: AppVisual.ink,
        ),
      ),
      titleLarge: GoogleFonts.montserrat(
        textStyle: appTextTheme.titleLarge,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.28,
        color: AppVisual.ink,
      ),
      titleMedium: GoogleFonts.montserrat(
        textStyle: appTextTheme.titleMedium,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppVisual.ink,
      ),
      titleSmall: GoogleFonts.montserrat(
        textStyle: appTextTheme.titleSmall,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppVisual.ink,
      ),
      bodyLarge: GoogleFonts.montserrat(
        textStyle: appTextTheme.bodyLarge,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppVisual.ink,
      ),
      bodyMedium: GoogleFonts.montserrat(
        textStyle: appTextTheme.bodyMedium,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppVisual.ink,
      ),
      bodySmall: GoogleFonts.montserrat(
        textStyle: appTextTheme.bodySmall,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppVisual.ink,
      ),
      labelLarge: GoogleFonts.montserrat(
        textStyle: appTextTheme.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppVisual.ink,
      ),
      labelMedium: GoogleFonts.montserrat(
        textStyle: appTextTheme.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppVisual.ink,
      ),
      labelSmall: GoogleFonts.montserrat(
        textStyle: appTextTheme.labelSmall,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppVisual.ink,
      ),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppVisual.logoBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppVisual.logoBlue,
      onPrimary: Colors.white,
      secondary: AppVisual.brandAzure,
      onSecondary: Colors.white,
      surface: AppVisual.surface,
      onSurface: AppVisual.ink,
      error: AppVisual.error,
      onError: Colors.white,
      outline: AppVisual.border,
      outlineVariant: AppVisual.chipFill,
    );

    final theme = ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.montserrat().fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppVisual.canvas,
      textTheme: appTextTheme,
      primaryTextTheme: appTextTheme,
      dividerTheme: DividerThemeData(color: AppVisual.border.withValues(alpha: 0.65)),
      appBarTheme: AppBarTheme(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppVisual.surface,
        elevation: 0,
        shadowColor: AppVisual.ink.withValues(alpha: 0.12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppVisual.border.withValues(alpha: 0.85), width: 1),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppVisual.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppVisual.logoBlue,
        textColor: AppVisual.ink,
        titleTextStyle: appTextTheme.titleMedium,
        subtitleTextStyle: appTextTheme.bodySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppVisual.ivory,
        labelStyle: TextStyle(color: AppVisual.inkMuted, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(color: AppVisual.logoBlue, fontWeight: FontWeight.w700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppVisual.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppVisual.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppVisual.logoBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppVisual.error.withValues(alpha: 0.85)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppVisual.logoBlue,
          foregroundColor: Colors.white,
          textStyle: appTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppVisual.logoBlue,
          textStyle: appTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: AppVisual.logoBlue.withValues(alpha: 0.55)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: appTextTheme.labelSmall ?? const TextStyle(),
        backgroundColor: AppVisual.chipFill,
        deleteIconColor: AppVisual.inkMuted,
        disabledColor: AppVisual.ivoryDeep,
        selectedColor: AppVisual.logoBlue.withValues(alpha: 0.18),
        secondarySelectedColor: AppVisual.brandAzure.withValues(alpha: 0.16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        side: BorderSide(color: AppVisual.border.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppVisual.logoBlue,
          textStyle: appTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppVisual.logoBlue,
        contentTextStyle: GoogleFonts.montserrat(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppVisual.logoBlue,
      ),
    );

    return MaterialApp(
      navigatorKey: appRootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Scuola Nautica Liana',
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const StudentRegistrationPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
      home: const AppAuthGate(),
    );
  }
}
