import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'src/constants/medical_specialties.dart';
import 'src/models/app_user.dart';
import 'src/models/chat_room.dart';
import 'src/providers/app_settings_provider.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/chat_provider.dart';
import 'src/screens/app_settings_screen.dart';
import 'src/screens/chat_list_screen.dart';
import 'src/screens/chat_screen.dart';
import 'src/screens/health_blogs_section.dart';
import 'src/theme/sihha_theme.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late final AnimationController _bgController;
  int _currentIndex = 0;
  bool _isOnline = true;

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
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
  }

  Future<void> _pickProfilePhoto(AuthProvider authProvider) async {
    final tr = context.read<AppSettingsProvider>().tr;
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (pickedFile == null) return;

    final ok = await authProvider.updateProfilePhoto(File(pickedFile.path));
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('تم تحديث الصورة بنجاح.', 'Photo mise a jour avec succes.'),
          ),
        ),
      );
      return;
    }

    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
      authProvider.clearError();
    }
  }

  Future<void> _showChangePasswordDialog(AuthProvider authProvider) async {
    final tr = context.read<AppSettingsProvider>().tr;
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(tr('تعديل كلمة المرور', 'Modifier le mot de passe')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('الحالية', 'Actuel')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr('الجديدة', 'Nouveau'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr('تأكيد الجديدة', 'Confirmation'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(tr('إلغاء', 'Annuler')),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final current = currentController.text.trim();
                      final next = newController.text.trim();
                      final confirm = confirmController.text.trim();
                      if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'أدخل جميع الحقول المطلوبة.',
                                'Remplissez tous les champs.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      if (next.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'الحد الأدنى 8 أحرف.',
                                'Minimum 8 caracteres.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      if (next != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'تأكيد كلمة المرور غير مطابق.',
                                'La confirmation ne correspond pas.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final ok = await authProvider.changePassword(
                        currentPassword: current,
                        newPassword: next,
                      );
                      if (!mounted || !dialogContext.mounted) return;
                      setDialogState(() => isSubmitting = false);
                      if (ok) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'تم تغيير كلمة المرور بنجاح.',
                                'Mot de passe modifie.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      if (authProvider.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authProvider.errorMessage!)),
                        );
                        authProvider.clearError();
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('حفظ', 'Enregistrer')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    AuthProvider authProvider,
    AppUser user,
  ) async {
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;
    var selectedSpecialty = normalizeMedicalSpecialty(user.specialty);
    final hospitalController = TextEditingController(text: user.hospitalName);
    final expController = TextEditingController(
      text: user.experienceYears > 0 ? '${user.experienceYears}' : '',
    );
    final studyController = TextEditingController(
      text: user.studyYears > 0 ? '${user.studyYears}' : '',
    );
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(
            tr('تعديل بيانات الطبيب', 'Modifier les donnees du medecin'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedSpecialty,
                  decoration: InputDecoration(
                    labelText: tr('التخصص', 'Specialite'),
                  ),
                  items: kMedicalSpecialties
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s.nameAr,
                          child: Text(settings.isArabic ? s.nameAr : s.nameFr),
                        ),
                      )
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (v) => setDialogState(
                          () => selectedSpecialty = v ?? selectedSpecialty,
                        ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hospitalController,
                  decoration: InputDecoration(
                    labelText: tr('اسم المستشفى', 'Nom de l\'hopital'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: expController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('سنوات الخبرة', 'Annees d\'experience'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: studyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('سنوات الدراسة', 'Annees d\'etudes'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(tr('إلغاء', 'Annuler')),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final hospital = hospitalController.text.trim();
                      final exp = int.tryParse(expController.text.trim());
                      final study = int.tryParse(studyController.text.trim());
                      if (hospital.isEmpty ||
                          exp == null ||
                          study == null ||
                          exp < 0 ||
                          study < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'تأكد من البيانات المدخلة.',
                                'Verifiez les donnees saisies.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final ok = await authProvider.updateDoctorProfile(
                        specialty: selectedSpecialty,
                        hospitalName: hospital,
                        experienceYears: exp,
                        studyYears: study,
                      );
                      if (!mounted || !dialogContext.mounted) return;
                      setDialogState(() => isSubmitting = false);
                      if (ok) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              tr(
                                'تم تحديث البيانات بنجاح.',
                                'Donnees mises a jour.',
                              ),
                            ),
                          ),
                        );
                      } else if (authProvider.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(authProvider.errorMessage!)),
                        );
                        authProvider.clearError();
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('حفظ', 'Enregistrer')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final user = authProvider.currentUser ?? widget.currentUser;
    final baseTheme = Theme.of(context);

    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Theme(
        data: baseTheme.copyWith(
          textTheme: GoogleFonts.tajawalTextTheme(baseTheme.textTheme),
        ),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              _AnimatedBackdrop(controller: _bgController),
              SafeArea(
                child: _currentIndex == 3
                    ? _DoctorAccountView(
                        user: user,
                        onPickPhoto: authProvider.isLoading
                            ? null
                            : () => _pickProfilePhoto(authProvider),
                        onEditProfile: authProvider.isLoading
                            ? null
                            : () => _showEditProfileDialog(authProvider, user),
                        onChangePassword: authProvider.isLoading
                            ? null
                            : () => _showChangePasswordDialog(authProvider),
                        onSettings: _openSettings,
                        onLogout: authProvider.isLoading
                            ? null
                            : authProvider.signOut,
                      )
                    : _currentIndex == 2
                    ? DoctorHealthBlogsSection(currentUser: user)
                    : _currentIndex == 1
                    ? ChatListScreen(currentUser: user)
                    : _DoctorDashboardView(
                        user: user,
                        isOnline: _isOnline,
                        onToggleOnline: (value) =>
                            setState(() => _isOnline = value),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: tr('اللوحة', 'Tableau'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: tr('المحادثات', 'Discussions'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: tr('المدونات', 'Blogs'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: tr('حسابي', 'Mon compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorDashboardView extends StatelessWidget {
  const _DoctorDashboardView({
    required this.user,
    required this.isOnline,
    required this.onToggleOnline,
  });

  final AppUser user;
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final chatProvider = context.watch<ChatProvider>();

    return StreamBuilder<List<ChatRoom>>(
      stream: chatProvider.chatRoomsStream(userId: user.id, role: user.role),
      builder: (context, snapshot) {
        final rooms = snapshot.data ?? const <ChatRoom>[];
        final todayCount = rooms.where((r) {
          final d = r.lastUpdatedAt;
          final n = DateTime.now();
          return d.year == n.year && d.month == n.month && d.day == n.day;
        }).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    localizeMedicalSpecialty(
                      user.specialty,
                      isArabic: settings.isArabic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isOnline
                              ? tr('متاح لاستقبال الاستشارات', 'Disponible')
                              : tr('غير متاح حالياً', 'Indisponible'),
                        ),
                      ),
                      Switch(value: isOnline, onChanged: onToggleOnline),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Card(
                    child: _Stat(
                      title: tr('استشارات اليوم', 'Aujourd\'hui'),
                      value: '$todayCount',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Card(
                    child: _Stat(
                      title: tr('طلبات معلقة', 'En attente'),
                      value: '${rooms.length}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('صندوق الوارد', 'Boite de reception'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (rooms.isEmpty)
              _Card(
                child: Center(
                  child: Text(
                    tr(
                      'لا توجد محادثات بعد.',
                      'Aucune discussion pour le moment.',
                    ),
                  ),
                ),
              )
            else
              ...rooms.map((room) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Card(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(room.patientName),
                      subtitle: Text(
                        room.lastMessage.isEmpty
                            ? tr(
                                'ابدأ المحادثة الآن',
                                'Commencez la discussion',
                              )
                            : room.lastMessage,
                      ),
                      trailing: Text(
                        '${room.lastUpdatedAt.hour.toString().padLeft(2, '0')}:${room.lastUpdatedAt.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChangeNotifierProvider<ChatProvider>.value(
                                  value: context.read<ChatProvider>(),
                                  child: ChatScreen(
                                    room: room,
                                    currentUser: user,
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _DoctorAccountView extends StatelessWidget {
  const _DoctorAccountView({
    required this.user,
    required this.onPickPhoto,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onSettings,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback? onPickPhoto;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangePassword;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundImage: user.photoUrl.trim().isEmpty
                    ? null
                    : NetworkImage(user.photoUrl),
                child: user.photoUrl.trim().isEmpty
                    ? const Icon(Icons.person, size: 32)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(user.phoneNumber),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onPickPhoto,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(
                  tr(
                    'تحميل صورة الطبيب من المعرض',
                    'Charger la photo depuis la galerie',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(tr('تعديل بيانات الطبيب', 'Modifier les donnees')),
                onTap: onEditProfile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: Text(
                  tr('تعديل كلمة المرور', 'Modifier le mot de passe'),
                ),
                onTap: onChangePassword,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(tr('الإعدادات', 'Parametres')),
                onTap: onSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  tr('تسجيل الخروج', 'Se deconnecter'),
                  style: const TextStyle(color: SihhaPalette.danger),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ],
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: sihhaGlassCardDecoration(context: context),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        Text(title),
      ],
    );
  }
}
