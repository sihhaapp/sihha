import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/constants/medical_specialties.dart';
import 'src/models/admin_dashboard.dart';
import 'src/models/app_user.dart';
import 'src/providers/admin_provider.dart';
import 'src/providers/app_settings_provider.dart';
import 'src/providers/auth_provider.dart';
import 'src/theme/sihha_theme.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminDashboardPanel extends StatelessWidget {
  const _AdminDashboardPanel({
    required this.tr,
    required this.isArabic,
    required this.isLoading,
    required this.totalUsers,
    required this.doctorsCount,
    required this.patientsCount,
    required this.disabledUsersCount,
    required this.visitors,
    required this.doctorStats,
    required this.currentVisitors,
    required this.onRefresh,
  });

  final String Function(String, String) tr;
  final bool isArabic;
  final bool isLoading;
  final int totalUsers;
  final int doctorsCount;
  final int patientsCount;
  final int disabledUsersCount;
  final AdminVisitorsStats visitors;
  final List<AdminDoctorKpi> doctorStats;
  final List<AdminCurrentVisitor> currentVisitors;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          _SectionCard(
            title: tr('ملخص المنصة', 'Vue globale'),
            icon: Icons.space_dashboard_rounded,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  title: tr('إجمالي المستخدمين', 'Utilisateurs'),
                  value: totalUsers.toString(),
                  icon: Icons.groups_rounded,
                  color: SihhaPalette.primaryDeep,
                ),
                _MetricTile(
                  title: tr('الأطباء', 'Medecins'),
                  value: doctorsCount.toString(),
                  icon: Icons.medical_services_rounded,
                  color: SihhaPalette.secondary,
                ),
                _MetricTile(
                  title: tr('المرضى', 'Patients'),
                  value: patientsCount.toString(),
                  icon: Icons.personal_injury_rounded,
                  color: SihhaPalette.accent,
                ),
                _MetricTile(
                  title: tr('الحسابات المعطلة', 'Comptes desactives'),
                  value: disabledUsersCount.toString(),
                  icon: Icons.block_rounded,
                  color: SihhaPalette.danger,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: tr('زوار التطبيق', 'Visiteurs de l\'application'),
            icon: Icons.bar_chart_rounded,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  title: tr('اليوم', 'Aujourd\'hui'),
                  value: visitors.today.toString(),
                  icon: Icons.today_rounded,
                  color: const Color(0xFF0EA5A4),
                ),
                _MetricTile(
                  title: tr('هذا الشهر', 'Ce mois'),
                  value: visitors.month.toString(),
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF0284C7),
                ),
                _MetricTile(
                  title: tr('هذه السنة', 'Cette annee'),
                  value: visitors.year.toString(),
                  icon: Icons.date_range_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _MetricTile(
                  title: tr('متصلون الآن', 'En ligne'),
                  value: visitors.currentOnline.toString(),
                  icon: Icons.wifi_tethering_rounded,
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: tr(
              'أداء الأطباء (عدد المرضى الذين عاينوهم)',
              'Performance medecins (patients consultes)',
            ),
            icon: Icons.monitor_heart_rounded,
            trailing: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            child: doctorStats.isEmpty
                ? Text(
                    tr('لا توجد بيانات بعد.', 'Aucune donnee disponible.'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    children: doctorStats.take(20).map((doctor) {
                      return _DoctorPerformanceTile(doctor: doctor, tr: tr);
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: tr('الزوار الحاليون', 'Visiteurs en cours'),
            icon: Icons.visibility_rounded,
            child: currentVisitors.isEmpty
                ? Text(
                    tr('لا يوجد زوار متصلون الآن.', 'Aucun visiteur en ligne.'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentVisitors.map((visitor) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: _roleColor(
                            visitor.role,
                          ).withValues(alpha: 0.14),
                          child: Icon(
                            visitor.role == UserRole.doctor
                                ? Icons.medical_services_rounded
                                : Icons.person_rounded,
                            size: 16,
                            color: _roleColor(visitor.role),
                          ),
                        ),
                        label: Text(
                          '${visitor.name} • ${_formatRelativeTime(visitor.lastSeenAt, tr)}',
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.80),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminUsersPanel extends StatelessWidget {
  const _AdminUsersPanel({
    required this.tr,
    required this.isArabic,
    required this.users,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onToggleDisabled,
    required this.onResetPassword,
  });

  final String Function(String, String) tr;
  final bool isArabic;
  final List<AppUser> users;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(AppUser user) onToggleDisabled;
  final Future<void> Function(AppUser user) onResetPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: sihhaGlassCardDecoration(context: context),
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: isLoading && users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : users.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.manage_accounts_outlined,
                    size: 44,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (errorMessage != null && errorMessage!.isNotEmpty)
                        ? errorMessage!
                        : tr(
                            'No accounts available right now.',
                            'Aucun compte a afficher pour le moment.',
                          ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                padding: const EdgeInsets.all(10),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final roleText = user.isAdmin
                      ? tr('إداري', 'Admin')
                      : user.role.label(isArabic: isArabic);
                  final roleColor = user.isAdmin
                      ? Colors.deepOrange
                      : _roleColor(user.role);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: roleColor.withValues(alpha: 0.14),
                      child: Icon(
                        user.isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : (user.role == UserRole.doctor
                                  ? Icons.medical_services_rounded
                                  : Icons.person_rounded),
                        color: roleColor,
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: user.isDisabled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${user.phoneNumber}\n'
                      '$roleText • ${_formatRelativeTime(user.lastSeenAt, tr)}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      enabled: !user.isAdmin,
                      onSelected: (value) {
                        if (value == 'toggle') {
                          onToggleDisabled(user);
                        } else if (value == 'reset_password') {
                          onResetPassword(user);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'toggle',
                          child: Text(
                            user.isDisabled
                                ? tr('تفعيل الحساب', 'Activer le compte')
                                : tr('تعطيل الحساب', 'Desactiver le compte'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'reset_password',
                          child: Text(
                            tr('تغيير كلمة المرور', 'Changer le mot de passe'),
                          ),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: user.isDisabled
                            ? SihhaPalette.danger
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: sihhaGlassCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: SihhaPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DoctorPerformanceTile extends StatelessWidget {
  const _DoctorPerformanceTile({required this.doctor, required this.tr});

  final AdminDoctorKpi doctor;
  final String Function(String, String) tr;

  @override
  Widget build(BuildContext context) {
    final subtitle = doctor.specialty.isEmpty
        ? doctor.phoneNumber
        : '${doctor.specialty} • ${doctor.phoneNumber}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doctor.isDisabled
              ? SihhaPalette.danger.withValues(alpha: 0.40)
              : SihhaPalette.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: SihhaPalette.primary.withValues(alpha: 0.14),
            child: const Icon(Icons.person_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _KpiPill(
                label: tr('اليوم', 'Jour'),
                value: doctor.patientsToday,
                color: const Color(0xFF14B8A6),
              ),
              const SizedBox(height: 4),
              _KpiPill(
                label: tr('شهر', 'Mois'),
                value: doctor.patientsMonth,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(height: 4),
              _KpiPill(
                label: tr('سنة', 'Annee'),
                value: doctor.patientsYear,
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _roleColor(UserRole role) {
  return role == UserRole.doctor
      ? SihhaPalette.primaryDeep
      : SihhaPalette.secondary;
}

String _formatRelativeTime(
  DateTime? dateTime,
  String Function(String, String) tr,
) {
  if (dateTime == null) {
    return tr('آخر ظهور: غير متاح', 'Derniere presence: indisponible');
  }
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) {
    return tr('نشط الآن', 'Actif maintenant');
  }
  if (diff.inMinutes < 60) {
    return tr('قبل ${diff.inMinutes} دقيقة', 'il y a ${diff.inMinutes} min');
  }
  if (diff.inHours < 24) {
    return tr('قبل ${diff.inHours} ساعة', 'il y a ${diff.inHours} h');
  }
  return tr('قبل ${diff.inDays} يوم', 'il y a ${diff.inDays} j');
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const String _countryPrefix = '+235';

  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _experienceController = TextEditingController();
  final _studyController = TextEditingController();

  UserRole _selectedRole = UserRole.doctor;
  String _selectedSpecialtyAr = kMedicalSpecialties.first.nameAr;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _hospitalController.dispose();
    _experienceController.dispose();
    _studyController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await context.read<AdminProvider>().refreshAll();
  }

  String _normalizeLocalPhoneDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('235')) {
      digits = digits.substring(3);
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    return digits;
  }

  String _composeFullPhone() {
    final digits = _normalizeLocalPhoneDigits(_phoneController.text);
    return '$_countryPrefix$digits';
  }

  String? _validateLocalPhone(String? value) {
    final tr = context.read<AppSettingsProvider>().tr;
    final digits = _normalizeLocalPhoneDigits(value ?? '');
    if (digits.isEmpty) {
      return tr('أدخل رقم الهاتف.', 'Saisissez le numero de telephone.');
    }
    if (digits.length != 8) {
      return tr(
        'رقم الهاتف يجب أن يكون 8 أرقام.',
        'Le numero de telephone doit contenir 8 chiffres.',
      );
    }
    return null;
  }

  Future<void> _createAccount() async {
    if (!_createFormKey.currentState!.validate()) {
      return;
    }

    final adminProvider = context.read<AdminProvider>();
    final ok = await adminProvider.createUser(
      name: _nameController.text.trim(),
      phoneNumber: _composeFullPhone(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
      specialty: _selectedRole == UserRole.doctor ? _selectedSpecialtyAr : '',
      hospitalName: _hospitalController.text.trim(),
      experienceYears: int.tryParse(_experienceController.text.trim()) ?? 0,
      studyYears: int.tryParse(_studyController.text.trim()) ?? 0,
    );

    if (!mounted) return;
    final tr = context.read<AppSettingsProvider>().tr;
    if (ok) {
      _nameController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _hospitalController.clear();
      _experienceController.clear();
      _studyController.clear();
      _selectedSpecialtyAr = kMedicalSpecialties.first.nameAr;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('تم إنشاء الحساب بنجاح.', 'Compte cree avec succes.'),
          ),
        ),
      );
      setState(() => _tabIndex = 2);
      return;
    }

    final err = adminProvider.errorMessage;
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      adminProvider.clearError();
    }
  }

  Future<void> _toggleDisabled(AppUser user) async {
    final tr = context.read<AppSettingsProvider>().tr;
    final disabling = !user.isDisabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          disabling
              ? tr('تعطيل الحساب', 'Desactiver le compte')
              : tr('تفعيل الحساب', 'Activer le compte'),
        ),
        content: Text(
          disabling
              ? tr(
                  'هل تريد تعطيل حساب ${user.name}؟',
                  'Voulez-vous desactiver le compte de ${user.name} ?',
                )
              : tr(
                  'هل تريد تفعيل حساب ${user.name}؟',
                  'Voulez-vous activer le compte de ${user.name} ?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('إلغاء', 'Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('تأكيد', 'Confirmer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final ok = await context.read<AdminProvider>().setUserDisabled(
      userId: user.id,
      disabled: disabling,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            disabling
                ? tr('تم تعطيل الحساب.', 'Compte desactive.')
                : tr('تم تفعيل الحساب.', 'Compte active.'),
          ),
        ),
      );
      return;
    }
    final error = context.read<AdminProvider>().errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    final tr = context.read<AppSettingsProvider>().tr;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('تغيير كلمة المرور', 'Changer le mot de passe')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr('كلمة المرور الجديدة', 'Nouveau mot de passe'),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 4) {
                return tr('4 أحرف على الأقل.', 'Au moins 4 caracteres.');
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('إلغاء', 'Annuler')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: Text(tr('حفظ', 'Enregistrer')),
          ),
        ],
      ),
    );

    final newPassword = controller.text.trim();
    controller.dispose();
    if (confirmed != true || newPassword.isEmpty || !mounted) {
      return;
    }

    final ok = await context.read<AdminProvider>().resetUserPassword(
      userId: user.id,
      newPassword: newPassword,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('تم تحديث كلمة المرور.', 'Mot de passe mis a jour.'),
          ),
        ),
      );
      return;
    }
    final error = context.read<AdminProvider>().errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final authProvider = context.watch<AuthProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final user = authProvider.currentUser ?? widget.currentUser;

    final tabs = <Widget>[
      _AdminDashboardPanel(
        tr: tr,
        isArabic: settings.isArabic,
        isLoading: adminProvider.isDashboardLoading,
        totalUsers: adminProvider.totalUsers,
        doctorsCount: adminProvider.doctorsCount,
        patientsCount: adminProvider.patientsCount,
        disabledUsersCount: adminProvider.disabledUsersCount,
        visitors: adminProvider.visitorsStats,
        doctorStats: adminProvider.doctorStats,
        currentVisitors: adminProvider.currentVisitors,
        onRefresh: _refreshAll,
      ),
      _buildCreatePanel(tr, settings.isArabic, adminProvider),
      _AdminUsersPanel(
        tr: tr,
        isArabic: settings.isArabic,
        users: adminProvider.users,
        isLoading: adminProvider.isLoading,
        errorMessage: adminProvider.errorMessage,
        onRefresh: _refreshAll,
        onToggleDisabled: _toggleDisabled,
        onResetPassword: _resetPassword,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('لوحة التحكم الذكية', 'Console admin intelligente')),
        actions: [
          IconButton(
            tooltip: tr('تحديث', 'Rafraichir'),
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: tr('اللغة', 'Langue'),
            icon: const Icon(Icons.translate_rounded),
            onSelected: (code) => settings.setLocale(Locale(code)),
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'ar',
                checked: settings.locale.languageCode == 'ar',
                child: const Text('العربية'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'fr',
                checked: settings.locale.languageCode == 'fr',
                child: const Text('Francais'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            tooltip: tr('تسجيل الخروج', 'Deconnexion'),
            onPressed: authProvider.isLoading ? null : authProvider.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: sihhaPageBackground(context: context),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Padding(
            key: ValueKey<int>(_tabIndex),
            padding: const EdgeInsets.all(14),
            child: tabs[_tabIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: tr('الإحصائيات', 'Statistiques'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            selectedIcon: const Icon(Icons.person_add_alt_1_rounded),
            label: tr('إنشاء حساب', 'Creer'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.manage_accounts_outlined),
            selectedIcon: const Icon(Icons.manage_accounts_rounded),
            label: tr('إدارة الحسابات', 'Comptes'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePanel(
    String Function(String, String) tr,
    bool isArabic,
    AdminProvider adminProvider,
  ) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: sihhaGlassCardDecoration(context: context),
        child: Form(
          key: _createFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded),
                  const SizedBox(width: 8),
                  Text(
                    tr('إنشاء حساب جديد', 'Creation d\'un nouveau compte'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: tr('الاسم الكامل', 'Nom complet'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return tr(
                      'أدخل اسمًا صحيحًا (3 أحرف على الأقل).',
                      'Saisissez un nom valide (3 caracteres minimum).',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
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
                        child: Text(role.label(isArabic: isArabic)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedRole = value;
                    if (_selectedRole == UserRole.doctor &&
                        _selectedSpecialtyAr.isEmpty) {
                      _selectedSpecialtyAr = kMedicalSpecialties.first.nameAr;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr('رقم الهاتف', 'Numero de telephone'),
                  prefixText: ' +235 ',
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
                validator: _validateLocalPhone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr('كلمة المرور', 'Mot de passe'),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 4) {
                    return tr(
                      'كلمة المرور يجب أن تكون 4 أحرف على الأقل.',
                      'Le mot de passe doit contenir au moins 4 caracteres.',
                    );
                  }
                  return null;
                },
              ),
              if (_selectedRole == UserRole.doctor) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSpecialtyAr,
                  decoration: InputDecoration(
                    labelText: tr('التخصص', 'Specialite'),
                    prefixIcon: const Icon(Icons.medical_information_outlined),
                  ),
                  items: kMedicalSpecialties
                      .map(
                        (specialty) => DropdownMenuItem<String>(
                          value: specialty.nameAr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(specialty.icon, size: 18),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  isArabic
                                      ? specialty.nameAr
                                      : specialty.nameFr,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSpecialtyAr = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _hospitalController,
                  decoration: InputDecoration(
                    labelText: tr('المستشفى', 'Hopital'),
                    prefixIcon: const Icon(Icons.local_hospital_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _experienceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('سنوات الخبرة', 'Annees d\'experience'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _studyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('سنوات الدراسة', 'Annees d\'etudes'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: adminProvider.isLoading ? null : _createAccount,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  adminProvider.isLoading
                      ? tr('جارٍ الإنشاء...', 'Creation en cours...')
                      : tr('إنشاء الحساب', 'Creer le compte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
