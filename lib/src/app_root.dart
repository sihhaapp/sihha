import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../admin_home.dart';
import '../doctor_home.dart';
import '../patient_home.dart';
import 'models/app_user.dart';
import 'providers/admin_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/blog_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth_screen.dart';
import 'services/admin_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/blog_service.dart';
import 'services/chat_service.dart';
import 'services/voice_service.dart';
import 'theme/sihha_theme.dart';

class SihhaApp extends StatelessWidget {
  const SihhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppSettingsProvider>(
      create: (_) => AppSettingsProvider(),
      child: const _SihhaAppView(),
    );
  }
}

class _SihhaAppView extends StatelessWidget {
  const _SihhaAppView();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final textDirection = settings.isArabic
        ? TextDirection.rtl
        : TextDirection.ltr;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: settings.tr('صحة', 'Sihha'),
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: SihhaTheme.light(),
      darkTheme: SihhaTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final ApiService _apiService;
  late final AuthService _authService;
  late final ChatService _chatService;
  late final BlogService _blogService;
  late final AdminService _adminService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService(_apiService);
    _chatService = ChatService(_apiService);
    _blogService = BlogService(_apiService);
    _adminService = AdminService(_apiService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(_authService),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(_chatService, VoiceService()),
        ),
        ChangeNotifierProvider<BlogProvider>(
          create: (_) => BlogProvider(_blogService),
        ),
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => AdminProvider(_adminService),
        ),
      ],
      child: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return _LoadingView(
            title: settings.tr(
              'جاري التحقق من الحساب',
              'Verification du compte...',
            ),
            subtitle: settings.tr('يرجى الانتظار...', 'Veuillez patienter...'),
          );
        }

        if (authProvider.currentUser == null) {
          return const AuthScreen();
        }

        if (authProvider.currentUser!.isAdmin) {
          return AdminHomeScreen(currentUser: authProvider.currentUser!);
        }

        if (authProvider.currentUser!.role == UserRole.patient) {
          return PatientHomeScreen(currentUser: authProvider.currentUser!);
        }

        return DoctorHomeScreen(currentUser: authProvider.currentUser!);
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: sihhaPageBackground(context: context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: sihhaGlassCardDecoration(context: context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.asset(
                      'assets/branding/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.health_and_safety_rounded,
                          size: 56,
                          color: SihhaPalette.primaryDeep,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
