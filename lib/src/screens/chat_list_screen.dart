import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../providers/app_settings_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/sihha_theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  String _searchQuery = '';
  String? _openingDoctorId;
  String? _ringingRoomId;
  bool _ringSyncInProgress = false;
  DateTime _lastRingSyncAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    unawaited(_stopIncomingRingtone());
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startIncomingRingtone(String roomId) async {
    if (_ringingRoomId == roomId) return;
    _ringingRoomId = roomId;
    try {
      await _ringtonePlayer.playRingtone(looping: true, volume: 0.9);
    } catch (_) {
      _ringingRoomId = null;
    }
  }

  Future<void> _stopIncomingRingtone() async {
    if (_ringingRoomId == null) return;
    _ringingRoomId = null;
    try {
      await _ringtonePlayer.stop();
    } catch (_) {
      // Ignore ringtone stop failures.
    }
  }

  void _syncIncomingCallRing(List<ChatRoom> rooms) {
    if (_ringSyncInProgress) return;
    final now = DateTime.now();
    if (now.difference(_lastRingSyncAt) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastRingSyncAt = now;
    _ringSyncInProgress = true;
    unawaited(_syncIncomingCallRingInternal(rooms));
  }

  Future<void> _syncIncomingCallRingInternal(List<ChatRoom> rooms) async {
    try {
      final roomId = await _findIncomingRoomIdFromStatus(rooms);
      if (!mounted) return;
      if (roomId != null) {
        await _startIncomingRingtone(roomId);
      } else {
        await _stopIncomingRingtone();
      }
    } finally {
      _ringSyncInProgress = false;
    }
  }

  Future<String?> _findIncomingRoomIdFromStatus(List<ChatRoom> rooms) async {
    final provider = context.read<ChatProvider>();
    for (final room in rooms) {
      final session = await provider.fetchLiveStatus(room.id);
      if (session == null) continue;
      final status = (session['status'] as String? ?? '').toLowerCase();
      final requestedBy = (session['requestedBy'] as String?)?.trim();
      final isIncoming =
          status == 'pending' &&
          requestedBy != null &&
          requestedBy.isNotEmpty &&
          requestedBy != widget.currentUser.id;
      if (isIncoming) return room.id;
    }
    return null;
  }

  Future<void> _openChatWithDoctor(AppUser doctor) async {
    setState(() => _openingDoctorId = doctor.id);
    try {
      final room = await context.read<ChatProvider>().createOrGetRoom(
        patient: widget.currentUser,
        doctor: doctor,
      );
      if (!mounted) return;
      await _openRoom(room);
    } catch (error) {
      if (!mounted) return;
      final tr = context.read<AppSettingsProvider>().tr;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'ØªØ¹Ø°Ø± ÙØªØ­ Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø©: $error',
                'Impossible d\'ouvrir la discussion: $error',
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

  Future<void> _openRoom(ChatRoom room, {ConsultationRequest? initialConsultation}) async {
    await _stopIncomingRingtone();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ChatProvider>.value(
          value: context.read<ChatProvider>(),
          child: ChatScreen(
            room: room,
            currentUser: widget.currentUser,
            initialConsultation: initialConsultation,
          ),
        ),
      ),
    );
  }

  Future<void> _acceptConsultation(String requestId) async {
    final provider = context.read<ChatProvider>();
    final result = await provider.acceptConsultationRequest(requestId);
    if (!mounted) return;
    if (result == null) {
      final error = provider.errorMessage;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        provider.clearError();
      }
      return;
    }
    final room = result['room'] as ChatRoom?;
    final request = result['request'] as ConsultationRequest?;
    if (room != null) {
      await _openRoom(room, initialConsultation: request);
    }
  }

  Future<void> _rejectConsultation(String requestId) async {
    final provider = context.read<ChatProvider>();
    final tr = context.read<AppSettingsProvider>().tr;
    final result = await provider.rejectConsultationRequest(requestId);
    if (!mounted) return;
    if (result == null) {
      final error = provider.errorMessage;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        provider.clearError();
      }
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('تم رفض الطلب.', 'Demande rejetée.'))));
  }

  Future<void> _transferConsultation(String requestId) async {
    final provider = context.read<ChatProvider>();
    final tr = context.read<AppSettingsProvider>().tr;

    // حوار إدخال هوية الطبيب الجديد
    final controller = TextEditingController();
    final newDoctorId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr('تحويل الطلب لطبيب آخر', 'Transférer vers un autre médecin')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: tr('معرّف الطبيب (id)', 'ID du médecin'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('إلغاء', 'Annuler')),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(tr('تحويل', 'Transférer')),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (newDoctorId == null || newDoctorId.isEmpty) return;

    final result = await provider.transferConsultationRequest(
      requestId: requestId,
      doctorId: newDoctorId,
    );
    if (!mounted) return;

    if (result == null) {
      final error = provider.errorMessage;
      if (error != null && error.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        provider.clearError();
      }
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('تم تحويل الطلب.', 'Demande transférée.'))));
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(tr('Ø§Ø³ØªØ´Ø§Ø±Ø§ØªÙŠ', 'Mes consultations')),
        ),
        body: Container(
          decoration: sihhaPageBackground(context: context),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                decoration: sihhaGlassCardDecoration(context: context),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: tr(
                      'Ø§Ø¨Ø­Ø« ÙÙŠ Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø§Øª...',
                      'Rechercher dans les discussions...',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              if (widget.currentUser.role == UserRole.patient)
                _DoctorsQuickStart(
                  currentUser: widget.currentUser,
                  openingDoctorId: _openingDoctorId,
                  onDoctorTap: _openChatWithDoctor,
                ),
              if (widget.currentUser.role == UserRole.doctor)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _DoctorConsultationInbox(
                    onAccept: _acceptConsultation,
                    onReject: _rejectConsultation,
                    onTransfer: _transferConsultation,
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ChatRoom>>(
                  stream: chatProvider.chatRoomsStream(
                    userId: widget.currentUser.id,
                    role: widget.currentUser.role,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Text(
                            tr(
                              'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ø§Ø³ØªØ´Ø§Ø±Ø§Øª.',
                              'Impossible de charger la liste des consultations.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final allRooms = snapshot.data ?? const <ChatRoom>[];
                    _syncIncomingCallRing(allRooms);
                    final rooms = allRooms.where((room) {
                      if (_searchQuery.isEmpty) return true;
                      final peerName = room.patientId == widget.currentUser.id
                          ? room.doctorName
                          : room.patientName;
                      return peerName.toLowerCase().contains(_searchQuery) ||
                          room.lastMessage.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (rooms.isEmpty) {
                      return _EmptyConsultations(
                        isPatient: widget.currentUser.role == UserRole.patient,
                        hasSearch: _searchQuery.isNotEmpty,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
                      itemCount: rooms.length,
                      separatorBuilder: (_, index) =>
                          const Divider(height: 1, indent: 76),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final isCurrentPatient =
                            room.patientId == widget.currentUser.id;
                        final peerName = isCurrentPatient
                            ? room.doctorName
                            : room.patientName;
                        final peerPhoto = isCurrentPatient
                            ? room.doctorPhotoUrl
                            : room.patientPhotoUrl;
                        final livePreview = _isLivePreview(room.lastMessage);
                        final hasUnread = room.unreadCount > 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF141D28,
                                  ).withValues(alpha: 0.92)
                                : Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            minLeadingWidth: 52,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: _PeerAvatar(
                              imageUrl: peerPhoto,
                              fallbackIcon: isCurrentPatient
                                  ? Icons.local_hospital_rounded
                                  : Icons.person_rounded,
                            ),
                            title: Text(
                              peerName,
                              style: TextStyle(
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 15.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _previewText(room.lastMessage, tr),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? const Color(0xFF2B3A4F)
                                    : SihhaPalette.textMuted,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatClock(
                                    room.lastUpdatedAt,
                                    settings.isArabic,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasUnread
                                        ? SihhaPalette.secondary
                                        : const Color(0xFF7D8A9A),
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (livePreview) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDE9E8),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                        ),
                                        child: Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (hasUnread) const SizedBox(width: 6),
                                    ],
                                    if (hasUnread)
                                      _UnreadBadge(count: room.unreadCount),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _openRoom(room),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLivePreview(String text) {
    final v = text.trim();
    if (v.isEmpty) return false;
    final lower = v.toLowerCase();
    return lower.contains('[live]') ||
        lower.contains('direct') ||
        lower.contains('live') ||
        v.contains('Ø¨Ø«') ||
        v.contains('ðŸ”´');
  }

  String _previewText(String raw, String Function(String, String) tr) {
    final value = raw.trim();
    if (value.isEmpty) {
      return tr(
        'Ø§Ø¨Ø¯Ø£ Ø§Ù„Ù…Ø­Ø§Ø¯Ø«Ø© Ø§Ù„Ø¢Ù†',
        'Commencez la discussion',
      );
    }
    if (value == 'Image') {
      return tr('ðŸ“· ØµÙˆØ±Ø©', 'ðŸ“· Photo');
    }
    if (value == 'Voice message') {
      return tr('ðŸŽ¤ Ø±Ø³Ø§Ù„Ø© ØµÙˆØªÙŠØ©', 'ðŸŽ¤ Message vocal');
    }
    if (_isLivePreview(value)) {
      return tr('ðŸ”´ Ù…Ø­Ø§Ø¯Ø«Ø© Ù…Ø¨Ø§Ø´Ø±Ø©', 'ðŸ”´ Diffusion en direct');
    }
    return value;
  }

  String _formatClock(DateTime dateTime, bool isArabic) {
    final now = DateTime.now();
    final sameDay =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    if (sameDay) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == dateTime.year &&
        yesterday.month == dateTime.month &&
        yesterday.day == dateTime.day;
    if (isYesterday) {
      return isArabic ? 'Ø£Ù…Ø³' : 'Hier';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class _DoctorsQuickStart extends StatelessWidget {
  const _DoctorsQuickStart({
    required this.currentUser,
    required this.openingDoctorId,
    required this.onDoctorTap,
  });

  final AppUser currentUser;
  final String? openingDoctorId;
  final Future<void> Function(AppUser doctor) onDoctorTap;

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final tr = context.watch<AppSettingsProvider>().tr;

    return SizedBox(
      height: 114,
      child: StreamBuilder<List<AppUser>>(
        stream: chatProvider.doctorsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctors = (snapshot.data ?? [])
              .where((doctor) => doctor.id != currentUser.id)
              .toList();
          if (doctors.isEmpty) {
            return Center(
              child: Text(
                tr(
                  'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ø£Ø·Ø¨Ø§Ø¡ Ù…ØªØ§Ø­ÙˆÙ† Ø­Ø§Ù„ÙŠØ§Ù‹.',
                  'Aucun medecin disponible.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            scrollDirection: Axis.horizontal,
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              final isOpening = openingDoctorId == doctor.id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: isOpening ? null : () => onDoctorTap(doctor),
                  child: SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SihhaPalette.secondary,
                              width: 2,
                            ),
                          ),
                          child: _PeerAvatar(
                            imageUrl: doctor.photoUrl,
                            fallbackIcon: Icons.local_hospital_rounded,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOpening
                              ? tr('Ø¬Ø§Ø±ÙŠ Ø§Ù„ÙØªØ­', 'Ouverture')
                              : doctor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DoctorConsultationInbox extends StatelessWidget {
  const _DoctorConsultationInbox({
    required this.onAccept,
    required this.onReject,
    required this.onTransfer,
  });

  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId) onReject;
  final Future<void> Function(String requestId) onTransfer;

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final tr = context.watch<AppSettingsProvider>().tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<ConsultationRequest>>(
      stream: chatProvider.doctorConsultationInboxStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: sihhaGlassCardDecoration(context: context),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('...'),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? const <ConsultationRequest>[];
        if (requests.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: sihhaGlassCardDecoration(context: context),
            child: Text(
              tr('لا توجد طلبات استشارة معلقة حالياً.', 'Aucune demande en attente.'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: sihhaGlassCardDecoration(context: context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('طلبات الاستشارة الواردة', 'Demandes de consultation'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...requests.map((req) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? const Color(0xFF141D28)
                        : Colors.white.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'المستفيد: ${req.subjectName}',
                          'Bénéficiaire : ${req.subjectName}',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          'العمر: ${req.ageYears}، الجنس: ${req.gender == RequestGender.male ? 'ذكر' : 'أنثى'}، الوزن: ${req.weightKg} كغ',
                          'Âge: ${req.ageYears}, sexe: ${req.gender == RequestGender.male ? 'Homme' : 'Femme'}, poids: ${req.weightKg} kg',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text(
                        tr(
                          'الأعراض: ${req.symptoms}',
                          'Symptômes: ${req.symptoms}',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => onAccept(req.id),
                              child: Text(tr('قبول', 'Accepter')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => onReject(req.id),
                              child: Text(tr('رفض', 'Rejeter')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: SihhaPalette.secondary),
                              ),
                              onPressed: () => onTransfer(req.id),
                              child: Text(tr('تحويل', 'Transférer')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyConsultations extends StatelessWidget {
  const _EmptyConsultations({required this.isPatient, required this.hasSearch});

  final bool isPatient;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<AppSettingsProvider>().tr;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.chat_rounded,
              size: 52,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 10),
            Text(
              hasSearch
                  ? tr(
                      'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù†ØªØ§Ø¦Ø¬ Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ù„Ø¨Ø­Ø«.',
                      'Aucun resultat correspondant.',
                    )
                  : isPatient
                  ? tr(
                      'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø§Ø³ØªØ´Ø§Ø±Ø§Øª Ø¨Ø¹Ø¯. Ø§Ø¨Ø¯Ø£ Ø§Ø³ØªØ´Ø§Ø±ØªÙƒ Ø§Ù„Ø£ÙˆÙ„Ù‰.',
                      'Aucune consultation pour le moment.',
                    )
                  : tr(
                      'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ø­Ø§Ø¯Ø«Ø§Øª Ø¨Ø¹Ø¯.',
                      'Aucune discussion pour le moment.',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.imageUrl, required this.fallbackIcon});

  final String imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFD7EBF8),
      child: ClipOval(
        child: url.isEmpty
            ? Icon(fallbackIcon, color: SihhaPalette.secondary)
            : Image.network(
                url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(fallbackIcon, color: SihhaPalette.secondary),
              ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SihhaPalette.danger,
        borderRadius: BorderRadius.circular(100),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
