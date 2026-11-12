import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'data/db/app_database.dart';
import 'features/home/home_shell.dart';
import 'features/lock/app_lock_controller.dart';
import 'features/lock/lock_overlay.dart';
import 'features/settings/backup_status_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(AppDatabase(), permanent: true);
  Get.put(AppLockController(), permanent: true);
  Get.put(BackupStatusController(), permanent: true);
  runApp(const ShopDebtApp());
}

class ShopDebtApp extends StatelessWidget {
  const ShopDebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'دفتر الدين',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF137C70),
          surface: const Color(0xFFF7F9F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F9F8),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE2E9E6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFF137C70), width: 1.5),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFDCEFEA),
          height: 68,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF137C70),
          foregroundColor: Colors.white,
        ),
      ),
      builder: (context, child) =>
          LockOverlay(child: child ?? const SizedBox.shrink()),
      home: const HomeShell(),
    );
  }
}
