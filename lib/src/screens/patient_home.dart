import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/medical_specialties.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../providers/app_settings_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/consultation_provider.dart';
import '../providers/live_session_provider.dart';
import '../theme/sihha_theme.dart';
import '../widgets/consultation_request_dialog.dart';
import 'app_settings_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'health_blogs_section.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
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
      final chatProvider = context.read<ChatProvider>();
      final consultProvider = context.read<ConsultationProvider>();
      final existingRoom = await chatProvider.findRoomWithDoctor(doctor.id);
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

      final request = await consultProvider.submitConsultationRequest(
        doctorId: doctor.id,
        subjectType: input.subjectType,
        subjectName: input.subjectName,
        ageYears: input.ageYears,
        gender: input.gender,
        weightKg: input.weightKg,
        pregnancyStatus: input.pregnancyStatus,
        stateCode: input.stateCode,
        spokenLanguage: input.spokenLanguage,
        symptoms: input.symptoms,
        symptomsVoiceUrl: input.symptomsVoiceUrl,
      );
      if (!mounted) return;
      if (request == null) {
        final error = consultProvider.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
          consultProvider.clearError();
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
                'تم إرسال طلب الاستشارة بنجاح.',
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
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatProvider>.value(
              value: context.read<ChatProvider>(),
            ),
            ChangeNotifierProvider<AudioProvider>.value(
              value: context.read<AudioProvider>(),
            ),
            ChangeNotifierProvider<LiveSessionProvider>.value(
              value: context.read<LiveSessionProvider>(),
            ),
            ChangeNotifierProvider<ConsultationProvider>.value(
              value: context.read<ConsultationProvider>(),
            ),
          ],
          child: ChatScreen(room: room, currentUser: currentUser),
        ),
      ),
    );
  }

  void _onBottomNavigationTap(int index) {
    setState(() => _currentIndex = index);
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
                    ? const AppSettingsScreen()
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
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: tr('الإعدادات', 'Parametres'),
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
        final allDoctors = (snapshot.data ?? []).where((doctor) {
          if (doctor.id == currentUser.id) {
            return false;
          }
          return true;
        }).toList();

        final doctors = allDoctors.where((doctor) {
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
        MedicalSpecialty? selectedSpecialty;
        for (final specialty in kMedicalSpecialties) {
          if (specialty.nameAr == _selectedSpecialtyAr) {
            selectedSpecialty = specialty;
            break;
          }
        }
        final selectedSpecialtyLabel = selectedSpecialty == null
            ? tr('كل التخصصات', 'Toutes les specialites')
            : (isArabic ? selectedSpecialty.nameAr : selectedSpecialty.nameFr);
        final resultSummary = tr(
          'عرض ${doctors.length} طبيبًا من أصل ${allDoctors.length}',
          'Affichage de ${doctors.length} medecins sur ${allDoctors.length}',
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            _PatientHeroCard(
              patientName: currentUser.name,
              subtitle: tr(
                'اشرح حالتك وابدأ الاستشارة بضغطة واحدة.',
                'Decrivez votre besoin et lancez la consultation en un geste.',
              ),
              photoUrl: currentUser.photoUrl,
              infoOne: tr(
                '${allDoctors.length} أطباء متاحون',
                '${allDoctors.length} medecins disponibles',
              ),
              infoTwo: selectedSpecialtyLabel,
            ),
            const SizedBox(height: 12),
            _glassCard(
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: tr(
                    'ابحث عن طبيب أو رقم هاتف أو تخصص...',
                    'Chercher un medecin, un numero, ou une specialite...',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF141D28) : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HomeSectionHeader(
              title: tr('التخصصات', 'Specialites'),
              subtitle: selectedSpecialty == null
                  ? tr(
                      'اختر تخصصًا لتصفية الأطباء بسرعة.',
                      'Choisissez une specialite pour filtrer rapidement.',
                    )
                  : tr(
                      'التصفية الحالية: $selectedSpecialtyLabel',
                      'Filtre actuel: $selectedSpecialtyLabel',
                    ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
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
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        setState(() => _selectedSpecialtyAr = selectedValue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 132,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: selected
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                              )
                            : null,
                        color: selected
                            ? null
                            : (isDark ? const Color(0xFF141E2A) : Colors.white),
                        border: Border.all(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.16)
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: selected ? 0.12 : 0.05,
                            ),
                            blurRadius: selected ? 18 : 12,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : SihhaPalette.primary.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              color: selected
                                  ? Colors.white
                                  : SihhaPalette.primary,
                              size: 18,
                            ),
                          ),
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
            const SizedBox(height: 12),
            _HomeSectionHeader(
              title: tr('أطباء مقترحون', 'Medecins recommandes'),
              subtitle: resultSummary,
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
                      'لا يوجد أطباء يطابقون البحث.',
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
                  child: _DoctorListCard(
                    name: doctor.name,
                    specialty: doctorSpecialty,
                    phoneNumber: doctor.phoneNumber,
                    photoUrl: doctor.photoUrl,
                    isOpening: isOpening,
                    onConsult: () => _startConsultation(
                      patient: currentUser,
                      doctor: doctor,
                    ),
                    consultLabel: tr('استشر الآن', 'Consulter'),
                    openingLabel: tr('جاري الفتح...', 'Ouverture...'),
                    availableLabel: tr('متاح', 'Disponible'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _PatientHeroCard extends StatelessWidget {
  const _PatientHeroCard({
    required this.patientName,
    required this.subtitle,
    required this.photoUrl,
    required this.infoOne,
    required this.infoTwo,
  });

  final String patientName;
  final String subtitle;
  final String photoUrl;
  final String infoOne;
  final String infoTwo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF112739), Color(0xFF0E1726)]
              : const [Color(0xFF0F766E), Color(0xFF0284C7)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        color: Colors.white.withValues(alpha: 0.93),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProfileAvatar(photoUrl: photoUrl, radius: 28),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroInfoPill(icon: Icons.people, label: infoOne),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroInfoPill(
                  icon: Icons.local_hospital_outlined,
                  label: infoTwo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInfoPill extends StatelessWidget {
  const _HeroInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.tajawal(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.tajawal(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
      ],
    );
  }
}

class _DoctorListCard extends StatelessWidget {
  const _DoctorListCard({
    required this.name,
    required this.specialty,
    required this.phoneNumber,
    required this.photoUrl,
    required this.isOpening,
    required this.onConsult,
    required this.consultLabel,
    required this.openingLabel,
    required this.availableLabel,
  });

  final String name;
  final String specialty;
  final String phoneNumber;
  final String photoUrl;
  final bool isOpening;
  final VoidCallback onConsult;
  final String consultLabel;
  final String openingLabel;
  final String availableLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProfileAvatar(photoUrl: photoUrl, radius: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.tajawal(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: GoogleFonts.tajawal(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: SihhaPalette.accent.withValues(
                    alpha: isDark ? 0.20 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  availableLabel,
                  style: GoogleFonts.tajawal(
                    color: isDark ? Colors.white : SihhaPalette.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2A) : const Color(0xFFF2F8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_rounded,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    phoneNumber,
                    style: GoogleFonts.tajawal(
                      color: SihhaPalette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isOpening ? null : onConsult,
              icon: isOpening
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_rounded, size: 18),
              label: Text(isOpening ? openingLabel : consultLabel),
            ),
          ),
        ],
      ),
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
    final fallback = Icon(
      Icons.person_rounded,
      color: SihhaPalette.primary,
      size: radius * 0.9,
    );
    final candidates = _buildPhotoCandidates(photoUrl);
    final url = candidates.isEmpty ? '' : candidates.first;
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return fallback;
            },
            errorBuilder: (_, _, _) => fallback,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: fallback,
    );
  }
}

List<String> _buildPhotoCandidates(String rawUrl) {
  final raw = rawUrl.trim();
  if (raw.isEmpty) return const <String>[];

  final apiBase = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sihha.space/api',
  ).trim();
  final apiUri = Uri.tryParse(apiBase);
  final uri = Uri.tryParse(raw);
  final candidates = <String>[];

  void addCandidate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return;
    if (!candidates.contains(text)) {
      candidates.add(text);
    }
  }

  bool isUploadsPath(String path) {
    return path.startsWith('/uploads/') ||
        path.contains('/uploads/') ||
        path.startsWith('uploads/') ||
        path.contains('uploads/') ||
        path.startsWith('/api/uploads/') ||
        path.contains('/api/uploads/');
  }

  String normalizeUploadPath(String path) {
    if (path.startsWith('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    if (path.contains('/api/uploads/')) {
      return path.replaceFirst('/api/uploads/', '/uploads/');
    }
    final uploadsIndex = path.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return path.substring(uploadsIndex);
    }
    return path;
  }

  if (uri == null) {
    addCandidate(raw);
    return candidates;
  }

  final normalizedPath = normalizeUploadPath(uri.path);
  final normalizedPathWithSlash = normalizedPath.startsWith('/')
      ? normalizedPath
      : '/$normalizedPath';
  final uploadsPath = isUploadsPath(normalizedPathWithSlash);
  final preferredScheme = (apiUri != null && apiUri.scheme.isNotEmpty)
      ? apiUri.scheme
      : (uri.hasScheme ? uri.scheme : 'https');

  if (uploadsPath && apiUri != null && apiUri.host.isNotEmpty) {
    addCandidate(
      apiUri
          .replace(
            path: normalizedPathWithSlash,
            query: uri.query.isEmpty ? null : uri.query,
            fragment: uri.fragment.isEmpty ? null : uri.fragment,
          )
          .toString(),
    );
  }

  if (uri.hasScheme) {
    addCandidate(
      uri.replace(port: null, path: normalizedPathWithSlash).toString(),
    );
    addCandidate(uri.replace(path: normalizedPathWithSlash).toString());
  } else if (apiUri != null && apiUri.host.isNotEmpty) {
    addCandidate(
      apiUri
          .replace(
            path: normalizedPathWithSlash,
            query: uri.query.isEmpty ? null : uri.query,
            fragment: uri.fragment.isEmpty ? null : uri.fragment,
          )
          .toString(),
    );
  }

  if (apiUri != null && apiUri.host.isNotEmpty) {
    addCandidate(
      uri
          .replace(
            scheme: preferredScheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
            path: normalizedPathWithSlash,
            query: uri.query.isEmpty ? null : uri.query,
            fragment: uri.fragment.isEmpty ? null : uri.fragment,
          )
          .toString(),
    );
    addCandidate(
      uri
          .replace(
            scheme: preferredScheme,
            host: apiUri.host,
            port: null,
            path: normalizedPathWithSlash,
            query: uri.query.isEmpty ? null : uri.query,
            fragment: uri.fragment.isEmpty ? null : uri.fragment,
          )
          .toString(),
    );
  }

  addCandidate(raw);
  return candidates;
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
