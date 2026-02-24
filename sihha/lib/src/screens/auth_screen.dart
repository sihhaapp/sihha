import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/sihha_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const String _chadPrefix = '+235';
  static const String _adminLocalPhone = '00000000';
  static const String _logoAsset = 'assets/branding/logo.png';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AnimationController _bgController;

  bool _isLogin = true;
  UserRole _selectedRole = UserRole.patient;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    if (_isLogin) {
      await authProvider.signIn(
        phoneNumber: _composeFullPhone(),
        password: _passwordController.text,
      );
    } else {
      await authProvider.signUp(
        name: _nameController.text,
        phoneNumber: _composeFullPhone(),
        password: _passwordController.text,
        role: _selectedRole,
      );
    }

    if (!mounted) {
      return;
    }

    final error = authProvider.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      authProvider.clearError();
    }
  }

  void _showForgotPasswordHint() {
    final tr = context.read<AppSettingsProvider>().tr;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            tr('استعادة كلمة المرور', 'Recuperation du mot de passe'),
          ),
          content: Text(
            tr(
              'إذا نسيت كلمة المرور، تواصل مع إدارة المنصة لإعادة تعيينها. بعد تسجيل الدخول يمكنك تغيير كلمة المرور من الإعدادات.',
              'Si vous avez oublie votre mot de passe, contactez l administration pour le reinitialiser. Apres connexion, vous pouvez le modifier depuis les parametres.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('حسنًا', 'OK')),
            ),
          ],
        );
      },
    );
  }

  String _composeFullPhone() {
    final digits = _normalizeLocalPhoneDigits(_phoneController.text);
    return '$_chadPrefix$digits';
  }

  String _normalizeLocalPhoneDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('235')) {
      digits = digits.substring(3);
    }
    if (digits == _adminLocalPhone) {
      return digits;
    }
    return digits.replaceFirst(RegExp(r'^0+'), '');
  }

  String? _validateChadLocalPhone(String? value) {
    final tr = context.read<AppSettingsProvider>().tr;
    if (value == null || value.trim().isEmpty) {
      return tr('أدخل رقم الهاتف.', 'Saisissez le numero de telephone.');
    }

    final rawDigits = value.replaceAll(RegExp(r'\D'), '');
    if (rawDigits == _adminLocalPhone) {
      return null;
    }

    final digits = _normalizeLocalPhoneDigits(value);

    if (digits.length != 8) {
      return tr(
        'رقم الهاتف في تشاد يجب أن يكون 8 أرقام.',
        'Le numero tchadien doit contenir 8 chiffres.',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;

    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            _AnimatedBackdrop(controller: _bgController),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _LogoBadge(assetPath: _logoAsset)),
                            const SizedBox(height: 14),
                            Text(
                              _isLogin
                                  ? tr(
                                      'مرحبًا بك في صحّة',
                                      'Bienvenue sur Sihha',
                                    )
                                  : tr(
                                      'إنشاء حساب صحي جديد',
                                      'Creer un compte sante',
                                    ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isLogin
                                  ? tr(
                                      'سجّل الدخول للوصول الآمن إلى ملفك الصحي ومحادثاتك.',
                                      'Connectez-vous pour acceder en securite a votre dossier et vos conversations.',
                                    )
                                  : tr(
                                      'ابدأ رحلتك الصحية معنا خلال أقل من دقيقة.',
                                      'Demarrez votre parcours sante en moins d une minute.',
                                    ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.78),
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (!_isLogin) ...[
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: tr('الاسم الكامل', 'Nom complet'),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().length < 3) {
                                    return tr(
                                      'أدخل اسمًا صحيحًا (3 أحرف على الأقل).',
                                      'Saisissez un nom valide (3 caracteres minimum).',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<UserRole>(
                                initialValue: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: tr('نوع الحساب', 'Type de compte'),
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                                items: UserRole.values
                                    .map(
                                      (role) => DropdownMenuItem<UserRole>(
                                        value: role,
                                        child: Text(
                                          role.label(
                                            isArabic: settings.isArabic,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedRole = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: tr(
                                  'رقم الهاتف',
                                  'Numero de telephone',
                                ),
                                hintText: '66123456',
                                prefixIcon: const Icon(Icons.phone_rounded),
                                prefixText: ' +235 ',
                              ),
                              validator: _validateChadLocalPhone,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: tr('كلمة المرور', 'Mot de passe'),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                final minLength = _isLogin ? 4 : 6;
                                if (value == null || value.length < minLength) {
                                  return tr(
                                    _isLogin
                                        ? 'كلمة المرور يجب أن تكون 4 أحرف على الأقل.'
                                        : 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.',
                                    _isLogin
                                        ? 'Le mot de passe doit contenir au moins 4 caracteres.'
                                        : 'Le mot de passe doit contenir au moins 6 caracteres.',
                                  );
                                }
                                return null;
                              },
                            ),
                            if (_isLogin) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _showForgotPasswordHint,
                                  child: Text(
                                    tr(
                                      'هل نسيت كلمة السر؟',
                                      'Mot de passe oublie ?',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: SihhaPalette.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isLogin
                                          ? tr('تسجيل الدخول', 'Connexion')
                                          : tr(
                                              'إنشاء الحساب',
                                              'Creer le compte',
                                            ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            if (_isLogin)
                              FilledButton.tonal(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => setState(() => _isLogin = false),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SihhaPalette.accent
                                      .withValues(alpha: 0.14),
                                  foregroundColor: SihhaPalette.accent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  tr(
                                    'إنشاء حساب جديد',
                                    'Creer un nouveau compte',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => setState(() => _isLogin = true),
                                child: Text(
                                  tr(
                                    'لديك حساب بالفعل؟ تسجيل الدخول',
                                    'Vous avez deja un compte ? Connexion',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B25) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.health_and_safety_rounded,
            color: SihhaPalette.primary,
            size: 44,
          );
        },
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: sihhaGlassCardDecoration(context: context),
      child: child,
    );
  }
}

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final dx = 42 * math.sin(t * math.pi * 2);
        final dy = 64 * math.cos(t * math.pi * 2);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? SihhaPalette.pageGradientDark
                  : SihhaPalette.pageGradient,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34 + dx,
                top: -30 + dy * 0.24,
                child: _blurBall(SihhaPalette.primary, 180),
              ),
              Positioned(
                left: -28 - dx * 0.18,
                bottom: -38 + dy * 0.35,
                child: _blurBall(SihhaPalette.secondary, 210),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blurBall(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.26),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}
