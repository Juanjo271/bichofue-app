import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar idioma
  await LanguageService.init();

  // Inicializar notificaciones locales
  await NotificationService.initialize();

  // TODO: Reemplazar con tu token de Mapbox real antes de compilar
  MapboxOptions.setAccessToken(
    'TU_MAPBOX_ACCESS_TOKEN_AQUI',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const BichofueApp());
}

/// Paleta de colores oficial de Bichofué Cali
/// Basada en el manual de marca y los colores naturales del ave Pitangus sulphuratus
class BichofueColors {
  static const Color amarillo = Color(0xFFF4C400); // Panza del ave, CTAs
  static const Color verde = Color(0xFF2F7D32);    // Tropical, AppBar, éxito
  static const Color negro = Color(0xFF111111);    // Texto principal, antifaz
  static const Color cafe = Color(0xFF7A4A1E);     // Alas, iconos, gastronomía
  static const Color beige = Color(0xFFF6E7D8);    // Fondos cálidos
  static const Color blanco = Color(0xFFFFFFFF);   // Texto sobre oscuro
  static const Color gris = Color(0xFFBDBDBD);     // Estados deshabilitados
  static const Color grisClaro = Color(0xFFF0F0F0); // Inputs, tarjetas

  /// Gradientes de marca
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [verde, negro],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amarillo, cafe],
  );

  /// Sombras suaves según manual
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: negro.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}

class BichofueApp extends StatefulWidget {
  const BichofueApp({super.key});

  /// Notificador de cambio de tema para modo oscuro global.
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  @override
  State<BichofueApp> createState() => _BichofueAppState();
}

class _BichofueAppState extends State<BichofueApp> {
  @override
  void initState() {
    super.initState();
    ApiService.sessionExpiredNotifier.addListener(_onSessionExpired);
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final dark = await PreferencesService.isNightModeEnabled();
    BichofueApp.themeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  void dispose() {
    ApiService.sessionExpiredNotifier.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onSessionExpired() {
    if (ApiService.sessionExpiredNotifier.value && mounted) {
      ApiService.sessionExpiredNotifier.value = false;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BichofueApp.themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'Bichofué',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: BichofueApp.themeNotifier.value,
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);
    final montserrat = GoogleFonts.montserratTextTheme(base.textTheme);

    return base.copyWith(
      // Esquema de color
      colorScheme: const ColorScheme.light(
        primary: BichofueColors.verde,
        onPrimary: BichofueColors.blanco,
        secondary: BichofueColors.amarillo,
        onSecondary: BichofueColors.negro,
        surface: BichofueColors.blanco,
        onSurface: BichofueColors.negro,
        error: BichofueColors.cafe,
        onError: BichofueColors.blanco,
        tertiary: BichofueColors.cafe,
      ),
      // Fondos
      scaffoldBackgroundColor: BichofueColors.beige,
      // Tipografía: Poppins para headlines, Montserrat para body
      textTheme: poppins.copyWith(
        headlineLarge: poppins.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: BichofueColors.negro,
        ),
        headlineMedium: poppins.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: BichofueColors.negro,
        ),
        headlineSmall: poppins.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BichofueColors.negro,
        ),
        titleLarge: poppins.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: BichofueColors.negro,
        ),
        bodyLarge: montserrat.bodyLarge?.copyWith(
          fontSize: 16,
          color: BichofueColors.negro,
          height: 1.5,
        ),
        bodyMedium: montserrat.bodyMedium?.copyWith(
          fontSize: 14,
          color: BichofueColors.negro.withValues(alpha: 0.87),
          height: 1.4,
        ),
        bodySmall: montserrat.bodySmall?.copyWith(
          fontSize: 12,
          color: BichofueColors.cafe,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: montserrat.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: BichofueColors.verde,
        foregroundColor: BichofueColors.blanco,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      // Botones elevados (CTA principal)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BichofueColors.amarillo,
          foregroundColor: BichofueColors.negro,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 2,
          shadowColor: BichofueColors.negro.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BichofueColors.verde,
          side: const BorderSide(color: BichofueColors.verde, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BichofueColors.cafe,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BichofueColors.blanco,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.gris.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.gris.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BichofueColors.amarillo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.cafe.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BichofueColors.cafe, width: 2),
        ),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.cafe,
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: BichofueColors.gris,
        ),
        errorStyle: GoogleFonts.montserrat(
          fontSize: 12,
          color: BichofueColors.cafe,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Tarjetas
      cardTheme: CardThemeData(
        color: BichofueColors.blanco,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadowColor: BichofueColors.negro.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: BichofueColors.grisClaro,
        selectedColor: BichofueColors.amarillo,
        labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BichofueColors.amarillo,
        foregroundColor: BichofueColors.negro,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      // IconButton
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: BichofueColors.negro,
        ),
      ),
      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BichofueColors.negro,
        ),
        subtitleTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.cafe,
        ),
      ),
      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BichofueColors.amarillo,
        circularTrackColor: BichofueColors.grisClaro,
      ),
      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: BichofueColors.blanco,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: BichofueColors.negro,
        ),
        contentTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.negro.withValues(alpha: 0.87),
        ),
      ),
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BichofueColors.negro,
        contentTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.blanco,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: BichofueColors.gris.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);
    final montserrat = GoogleFonts.montserratTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: BichofueColors.verde,
        onPrimary: BichofueColors.blanco,
        secondary: BichofueColors.amarillo,
        onSecondary: BichofueColors.negro,
        surface: Color(0xFF1B3A1E),
        onSurface: BichofueColors.blanco,
        error: BichofueColors.cafe,
        onError: BichofueColors.blanco,
        tertiary: BichofueColors.cafe,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A1F0C),
      textTheme: poppins.copyWith(
        headlineLarge: poppins.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: BichofueColors.blanco,
        ),
        headlineMedium: poppins.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: BichofueColors.blanco,
        ),
        headlineSmall: poppins.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: BichofueColors.blanco,
        ),
        titleLarge: poppins.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: BichofueColors.blanco,
        ),
        bodyLarge: montserrat.bodyLarge?.copyWith(
          fontSize: 16,
          color: BichofueColors.blanco,
          height: 1.5,
        ),
        bodyMedium: montserrat.bodyMedium?.copyWith(
          fontSize: 14,
          color: BichofueColors.blanco.withValues(alpha: 0.87),
          height: 1.4,
        ),
        bodySmall: montserrat.bodySmall?.copyWith(
          fontSize: 12,
          color: BichofueColors.beige,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: montserrat.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B3A1E),
        foregroundColor: BichofueColors.blanco,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BichofueColors.amarillo,
          foregroundColor: BichofueColors.negro,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 2,
          shadowColor: BichofueColors.negro.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BichofueColors.amarillo,
          side: const BorderSide(color: BichofueColors.amarillo, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BichofueColors.beige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B3A1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.gris.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.gris.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BichofueColors.amarillo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: BichofueColors.cafe.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BichofueColors.cafe, width: 2),
        ),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.beige,
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: BichofueColors.gris,
        ),
        errorStyle: GoogleFonts.montserrat(
          fontSize: 12,
          color: BichofueColors.cafe,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1B3A1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadowColor: BichofueColors.negro.withValues(alpha: 0.08),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2F7D32),
        selectedColor: BichofueColors.amarillo,
        labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BichofueColors.amarillo,
        foregroundColor: BichofueColors.negro,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: BichofueColors.blanco,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BichofueColors.blanco,
        ),
        subtitleTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.beige,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BichofueColors.amarillo,
        circularTrackColor: Color(0xFF2F7D32),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1B3A1E),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: BichofueColors.blanco,
        ),
        contentTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.blanco.withValues(alpha: 0.87),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B3A1E),
        contentTextStyle: GoogleFonts.montserrat(
          fontSize: 14,
          color: BichofueColors.blanco,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(
        color: BichofueColors.gris.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }
}
