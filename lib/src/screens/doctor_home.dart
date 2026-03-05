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
import 'app_settings_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'health_blogs_section.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen>
    with SingleTickerProviderStateMixin {
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
                    ? const AppSettingsScreen()
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
                label: tr('\u0627\u0644\u0644\u0648\u062d\u0629', 'Tableau'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: tr(
                  '\u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0627\u062a',
                  'Discussions',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: tr(
                  '\u0627\u0644\u0645\u062f\u0648\u0646\u0627\u062a',
                  'Blogs',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: tr(
                  '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
                  'Parametres',
                ),
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
        final now = DateTime.now();
        final rooms = [...(snapshot.data ?? const <ChatRoom>[])]
          ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
        final todayCount = rooms.where((r) {
          final d = r.lastUpdatedAt;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).length;
        final activeCount = rooms.where((room) => !room.isClosed).length;
        final waitingCount = rooms
            .where(
              (room) => room.lastMessage.trim().isEmpty || room.unreadCount > 0,
            )
            .length;
        final unreadCount = rooms.fold<int>(
          0,
          (sum, room) => sum + room.unreadCount,
        );
        final shiftLabel = now.hour < 12
            ? tr(
                '\u0627\u0644\u062f\u0648\u0627\u0645 \u0627\u0644\u0635\u0628\u0627\u062d\u064a',
                'Service du matin',
              )
            : now.hour < 18
            ? tr(
                '\u062f\u0648\u0627\u0645 \u0628\u0639\u062f \u0627\u0644\u0638\u0647\u0631',
                'Service de l\'apres-midi',
              )
            : tr(
                '\u0627\u0644\u062f\u0648\u0627\u0645 \u0627\u0644\u0645\u0633\u0627\u0626\u064a',
                'Service du soir',
              );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _DoctorHeroCard(
              doctorName: user.name,
              specialty: localizeMedicalSpecialty(
                user.specialty,
                isArabic: settings.isArabic,
              ),
              shiftLabel: shiftLabel,
              isOnline: isOnline,
              onToggleOnline: onToggleOnline,
              onlineLabel: tr(
                '\u0645\u062a\u0627\u062d \u0627\u0644\u0622\u0646',
                'Disponible maintenant',
              ),
              offlineLabel: tr(
                '\u063a\u064a\u0631 \u0645\u062a\u0627\u062d \u062d\u0627\u0644\u064a\u0627\u064b',
                'Indisponible',
              ),
              availabilityTitle: tr(
                '\u062a\u0648\u0641\u0631 \u0627\u0644\u0627\u0633\u062a\u0634\u0627\u0631\u0629',
                'Disponibilite de consultation',
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _MetricCard(
                        icon: Icons.today_rounded,
                        title: tr(
                          '\u0627\u0633\u062a\u0634\u0627\u0631\u0627\u062a \u0627\u0644\u064a\u0648\u0645',
                          'Consultations du jour',
                        ),
                        value: '$todayCount',
                        accent: SihhaPalette.primary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricCard(
                        icon: Icons.forum_rounded,
                        title: tr(
                          '\u0627\u0644\u063a\u0631\u0641 \u0627\u0644\u0646\u0634\u0637\u0629',
                          'Salles actives',
                        ),
                        value: '$activeCount',
                        accent: SihhaPalette.secondary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricCard(
                        icon: Icons.pending_actions_rounded,
                        title: tr(
                          '\u062a\u062d\u062a\u0627\u062c \u0645\u062a\u0627\u0628\u0639\u0629',
                          'Suivi requis',
                        ),
                        value: '$waitingCount',
                        accent: const Color(0xFFEA580C),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _MetricCard(
                        icon: Icons.mark_chat_unread_rounded,
                        title: tr(
                          '\u0631\u0633\u0627\u0626\u0644 \u063a\u064a\u0631 \u0645\u0642\u0631\u0648\u0621\u0629',
                          'Messages non lus',
                        ),
                        value: '$unreadCount',
                        accent: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: tr(
                '\u0622\u062e\u0631 \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0627\u062a',
                'Conversations recentes',
              ),
              subtitle: tr(
                '\u0627\u0641\u062a\u062d \u063a\u0631\u0641\u0629 \u0644\u0645\u062a\u0627\u0628\u0639\u0629 \u0627\u0644\u0627\u0633\u062a\u0634\u0627\u0631\u0629 \u0627\u0644\u0637\u0628\u064a\u0629.',
                'Ouvrez une salle pour poursuivre le suivi medical.',
              ),
            ),
            const SizedBox(height: 10),
            if (rooms.isEmpty)
              _Card(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u062d\u0627\u062f\u062b\u0627\u062a \u0628\u0639\u062f.',
                            'Aucune discussion pour le moment.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...rooms.map((room) {
                final timeLabel = _formatRoomTime(
                  value: room.lastUpdatedAt,
                  now: now,
                  yesterdayLabel: tr('\u0623\u0645\u0633', 'Hier'),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InboxRoomCard(
                    patientName: room.patientName,
                    subtitle: room.lastMessage.trim().isEmpty
                        ? tr(
                            '\u0627\u0628\u062f\u0623 \u0627\u0644\u0645\u062d\u0627\u062f\u062b\u0629 \u0627\u0644\u0622\u0646',
                            'Commencez la discussion',
                          )
                        : room.lastMessage,
                    timeLabel: timeLabel,
                    unreadCount: room.unreadCount,
                    onTap: () {
                      Navigator.of(context).push(
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
                              ChangeNotifierProvider<
                                ConsultationProvider
                              >.value(
                                value: context.read<ConsultationProvider>(),
                              ),
                            ],
                            child: ChatScreen(room: room, currentUser: user),
                          ),
                        ),
                      );
                    },
                    unreadLabel: tr('\u062c\u062f\u064a\u062f', 'nouveau'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _DoctorHeroCard extends StatelessWidget {
  const _DoctorHeroCard({
    required this.doctorName,
    required this.specialty,
    required this.shiftLabel,
    required this.isOnline,
    required this.onToggleOnline,
    required this.onlineLabel,
    required this.offlineLabel,
    required this.availabilityTitle,
  });

  final String doctorName;
  final String specialty;
  final String shiftLabel;
  final bool isOnline;
  final ValueChanged<bool> onToggleOnline;
  final String onlineLabel;
  final String offlineLabel;
  final String availabilityTitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF112739), Color(0xFF0E1726)]
              : const [Color(0xFF0F766E), Color(0xFF0EA5A1)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  shiftLabel,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  availabilityTitle,
                  style: GoogleFonts.tajawal(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isOnline ? onlineLabel : offlineLabel,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(value: isOnline, onChanged: onToggleOnline),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.20 : 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

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

class _InboxRoomCard extends StatelessWidget {
  const _InboxRoomCard({
    required this.patientName,
    required this.subtitle,
    required this.timeLabel,
    required this.unreadCount,
    required this.onTap,
    required this.unreadLabel,
  });

  final String patientName;
  final String subtitle;
  final String timeLabel;
  final int unreadCount;
  final VoidCallback onTap;
  final String unreadLabel;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: SihhaPalette.primary.withValues(alpha: 0.15),
                  child: Text(
                    _initialsFromName(patientName),
                    style: GoogleFonts.tajawal(
                      color: SihhaPalette.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.60),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SihhaPalette.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unreadCount $unreadLabel',
                          style: GoogleFonts.tajawal(
                            color: SihhaPalette.primaryDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRoomTime({
  required DateTime value,
  required DateTime now,
  required String yesterdayLabel,
}) {
  final isToday =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  if (isToday) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      value.year == yesterday.year &&
      value.month == yesterday.month &&
      value.day == yesterday.day;
  if (isYesterday) {
    return yesterdayLabel;
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}

String _initialsFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
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
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: sihhaGlassCardDecoration(context: context),
      child: child,
    );
  }
}
