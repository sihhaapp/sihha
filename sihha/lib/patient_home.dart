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
import 'src/widgets/consultation_request_dialog.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late final AnimationController _bgController;

  int _currentIndex = 0;
  String _searchQuery = '';
  String? _selectedSpecialtyAr;
  String? _openingDoctorId;

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
    _searchController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _startConsultation({
    required AppUser patient,
    required AppUser doctor,
  }) async {
    setState(() => _openingDoctorId = doctor.id);

    try {
      final provider = context.read<ChatProvider>();
      final existingRoom = await provider.findRoomWithDoctor(doctor.id);
      if (existingRoom != null) {
        if (!mounted) return;
        await _openRoom(existingRoom, patient);
        return;
      }

      if (!mounted) return;
      final input = await showConsultationRequestDialog(
        context: context,
        patient: patient,
        doctor: doctor,
      );
      if (!mounted || input == null) return;

      final request = await provider.submitConsultationRequest(
        doctorId: doctor.id,
        subjectType: input.subjectType,
        subjectName: input.subjectName,
        ageYears: input.ageYears,
        gender: input.gender,
        weightKg: input.weightKg,
        stateCode: input.stateCode,
        spokenLanguage: input.spokenLanguage,
        symptoms: input.symptoms,
      );
      if (!mounted) return;
      if (request == null) {
        final error = provider.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
          provider.clearError();
        }
        return;
      }

      final tr = context.read<AppSettingsProvider>().tr;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'تم إرسال طلب الاستشارة للطبيب بنجاح.',
                'Votre demande de consultation a ete envoyee au medecin.',
              ),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final tr = context.read<AppSettingsProvider>().tr;
      final raw = error.toString();
      final details = raw.length > 220 ? '${raw.substring(0, 220)}...' : raw;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'تعذر بدء الاستشارة: $details',
                'Impossible de demarrer la consultation: $details',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _openingDoctorId = null);
      }
    }
  }

  Future<void> _openRoom(ChatRoom room, AppUser currentUser) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ChatProvider>.value(
          value: context.read<ChatProvider>(),
          child: ChatScreen(room: room, currentUser: currentUser),
        ),
      ),
    );
  }

  void _onBottomNavigationTap(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _pickProfilePhotoFromGallery(AuthProvider authProvider) async {
    final tr = context.read<AppSettingsProvider>().tr;
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedFile == null) {
        return;
      }

      final success = await authProvider.updateProfilePhoto(
        File(pickedFile.path),
      );
      if (!mounted) {
        return;
      }

      if (success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                tr('تم تحديث الصورة بنجاح.', 'Photo mise a jour avec succes.'),
              ),
            ),
          );
        return;
      }

      final error = authProvider.errorMessage;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        authProvider.clearError();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr('تعذر فتح معرض الصور.', 'Impossible d\'ouvrir la galerie.'),
            ),
          ),
        );
    }
  }

  Future<void> _showChangePasswordDialog(AuthProvider authProvider) async {
    final tr = context.read<AppSettingsProvider>().tr;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: Text(tr('تعديل كلمة المرور', 'Modifier le mot de passe')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr(
                        'كلمة المرور الحالية',
                        'Mot de passe actuel',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr(
                        'كلمة المرور الجديدة',
                        'Nouveau mot de passe',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr(
                        'تأكيد كلمة المرور',
                        'Confirmer le mot de passe',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(tr('إلغاء', 'Annuler')),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final currentPassword = currentPasswordController.text
                              .trim();
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword = confirmPasswordController.text
                              .trim();

                          if (currentPassword.isEmpty ||
                              newPassword.isEmpty ||
                              confirmPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'أدخل جميع الحقول المطلوبة.',
                                    'Remplissez tous les champs requis.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          if (newPassword.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.',
                                    'Le nouveau mot de passe doit contenir au moins 8 caracteres.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          if (newPassword != confirmPassword) {
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
                          final success = await authProvider.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                          );
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          setDialogState(() => isSubmitting = false);

                          if (success) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'تم تغيير كلمة المرور بنجاح.',
                                    'Mot de passe modifie avec succes.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          final error = authProvider.errorMessage;
                          if (error != null && error.isNotEmpty) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
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
            );
          },
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final appSettings = context.watch<AppSettingsProvider>();
    final tr = appSettings.tr;
    final currentUser = authProvider.currentUser ?? widget.currentUser;
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(baseTheme.textTheme),
      ),
      child: Directionality(
        textDirection: appSettings.isArabic
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              _AnimatedBackdrop(controller: _bgController),
              SafeArea(
                child: _currentIndex == 3
                    ? _buildAccountSection(
                        authProvider,
                        appSettings,
                        currentUser,
                      )
                    : _currentIndex == 1
                    ? ChatListScreen(currentUser: currentUser)
                    : _currentIndex == 2
                    ? const HealthBlogsCatalogView()
                    : _buildHomeSection(currentUser),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onBottomNavigationTap,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: tr('الرئيسية', 'Accueil'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: const Icon(Icons.chat_bubble_rounded),
                label: tr('استشاراتي', 'Mes consultations'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: tr('مدونات صحية', 'Blogs sante'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: tr('حسابي', 'Mon compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSection(AppUser currentUser) {
    final appSettings = context.watch<AppSettingsProvider>();
    final tr = appSettings.tr;
    final isArabic = appSettings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<AppUser>>(
      stream: context.read<ChatProvider>().doctorsStream(),
      builder: (context, snapshot) {
        final doctors = (snapshot.data ?? []).where((doctor) {
          if (doctor.id == currentUser.id) {
            return false;
          }

          final doctorSpecialtyAr = normalizeMedicalSpecialty(doctor.specialty);
          final doctorSpecialtyLocalized = localizeMedicalSpecialty(
            doctor.specialty,
            isArabic: isArabic,
          );
          if (_selectedSpecialtyAr != null &&
              doctorSpecialtyAr != _selectedSpecialtyAr) {
            return false;
          }

          if (_searchQuery.isEmpty) {
            return true;
          }

          return doctor.name.toLowerCase().contains(_searchQuery) ||
              doctor.phoneNumber.toLowerCase().contains(_searchQuery) ||
              doctorSpecialtyAr.toLowerCase().contains(_searchQuery) ||
              doctorSpecialtyLocalized.toLowerCase().contains(_searchQuery);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                'أهلاً بك، ${currentUser.name}',
                                'Bienvenue, ${currentUser.name}',
                              ),
                              style: GoogleFonts.tajawal(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr(
                                'اختر طبيباً وابدأ استشارتك فوراً',
                                'Choisissez un medecin et commencez votre consultation',
                              ),
                              style: GoogleFonts.tajawal(
                                color: const Color(0xFF5A6B81),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ProfileAvatar(
                        photoUrl: currentUser.photoUrl,
                        radius: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _searchQuery = value.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText: tr(
                        'ابحث عن طبيب أو تخصص...',
                        'Chercher un medecin ou une specialite...',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF141D28)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('التخصصات الطبية', 'Specialites medicales'),
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kMedicalSpecialties.length + 1,
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selectedValue = index == 0
                      ? null
                      : kMedicalSpecialties[index - 1].nameAr;
                  final displayLabel = index == 0
                      ? tr('الكل', 'Tous')
                      : (isArabic
                            ? kMedicalSpecialties[index - 1].nameAr
                            : kMedicalSpecialties[index - 1].nameFr);
                  final icon = index == 0
                      ? Icons.grid_view_rounded
                      : kMedicalSpecialties[index - 1].icon;
                  final selected = selectedValue == _selectedSpecialtyAr;

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        setState(() => _selectedSpecialtyAr = selectedValue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: selected
                            ? SihhaPalette.primary
                            : (isDark ? const Color(0xFF141E2A) : Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: selected
                                ? Colors.white
                                : SihhaPalette.primary,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            displayLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr('الأطباء المتاحون', 'Medecins disponibles'),
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot.hasError)
              _glassCard(
                child: Center(
                  child: Text(
                    tr(
                      'تعذر تحميل قائمة الأطباء.',
                      'Impossible de charger la liste des medecins.',
                    ),
                  ),
                ),
              )
            else if (doctors.isEmpty)
              _glassCard(
                child: Center(
                  child: Text(
                    tr(
                      'لا يوجد أطباء مطابقو للبحث.',
                      'Aucun medecin ne correspond a la recherche.',
                    ),
                  ),
                ),
              )
            else
              ...doctors.map((doctor) {
                final isOpening = _openingDoctorId == doctor.id;
                final doctorSpecialty = localizeMedicalSpecialty(
                  doctor.specialty,
                  isArabic: isArabic,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _glassCard(
                    child: Row(
                      children: [
                        _ProfileAvatar(photoUrl: doctor.photoUrl, radius: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                doctorSpecialty,
                                style: GoogleFonts.tajawal(
                                  color: const Color(0xFF647489),
                                ),
                              ),
                              Text(
                                doctor.phoneNumber,
                                style: GoogleFonts.tajawal(
                                  color: SihhaPalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: isOpening
                              ? null
                              : () => _startConsultation(
                                  patient: currentUser,
                                  doctor: doctor,
                                ),
                          icon: isOpening
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_rounded, size: 18),
                          label: Text(
                            isOpening
                                ? tr('جاري الفتح', 'Ouverture')
                                : tr('استشارة', 'Consulter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildAccountSection(
    AuthProvider authProvider,
    AppSettingsProvider appSettings,
    AppUser currentUser,
  ) {
    final tr = appSettings.tr;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _glassCard(
          child: Column(
            children: [
              _ProfileAvatar(photoUrl: currentUser.photoUrl, radius: 44),
              const SizedBox(height: 10),
              Text(
                currentUser.name,
                style: GoogleFonts.tajawal(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                currentUser.phoneNumber,
                style: GoogleFonts.tajawal(color: const Color(0xFF66778D)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () => _pickProfilePhotoFromGallery(authProvider),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(
                  tr(
                    'تغيير الصورة من المعرض',
                    'Changer la photo depuis la galerie',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _glassCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: Text(
                  tr('تعديل كلمة المرور', 'Modifier le mot de passe'),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: authProvider.isLoading
                    ? null
                    : () => _showChangePasswordDialog(authProvider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: Text(tr('الإعدادات', 'Parametres')),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _openSettings,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: Colors.red.shade700),
                title: Text(
                  tr('تسجيل الخروج', 'Se deconnecter'),
                  style: TextStyle(color: Colors.red.shade700),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: authProvider.isLoading ? null : authProvider.signOut,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.radius});

  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: NetworkImage(photoUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person_rounded,
        color: SihhaPalette.primary,
        size: radius * 0.9,
      ),
    );
  }
}

Widget _glassCard({required Widget child}) {
  return Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: sihhaGlassCardDecoration(context: context),
      child: child,
    ),
  );
}
