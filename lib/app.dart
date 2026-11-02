import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/api/clinic_api.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/clinic_access.dart';

class DentalClinicApp extends StatefulWidget {
  const DentalClinicApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<DentalClinicApp> createState() => _DentalClinicAppState();
}

class _DentalClinicAppState extends State<DentalClinicApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ClinicApi.instance.onSessionExpired = _sessionExpired;
  }

  void _sessionExpired() {
    ClinicAccessSession.current.value = null;
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(config: widget.config),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    ClinicApi.instance.onSessionExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Clínica San Martín',
      builder: (context, child) => ValueListenableBuilder<ClinicAccess?>(
        valueListenable: ClinicAccessSession.current,
        builder: (context, access, _) => ClinicAccessScope(
          access: access,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B72)),
        scaffoldBackgroundColor: const Color(0xFFF7FAFA),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: LoginScreen(config: widget.config),
    );
  }
}
