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
  final Set<String> _photoWarmupAttempted = <String>{};
  final Set<String> _photoWarmupInFlight = <String>{};
  String _searchQuery = '';
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

  Future<void> _openRoom(
    ChatRoom room, {
    ConsultationRequest? initialConsultation,
  }) async {
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

  ChatRoom _roomWithFallbackPhotos(ChatRoom room, ChatProvider provider) {
    final req = provider.getCachedConsultation(room.id);
    if (req == null) {
      return room;
    }

    final resolvedPatientPhoto = room.patientPhotoUrl.trim().isNotEmpty
        ? room.patientPhotoUrl
        : req.patientPhotoUrl.trim();
    final resolvedDoctorPhoto = room.doctorPhotoUrl.trim().isNotEmpty
        ? room.doctorPhotoUrl
        : req.targetDoctorPhotoUrl.trim();

    if (resolvedPatientPhoto == room.patientPhotoUrl &&
        resolvedDoctorPhoto == room.doctorPhotoUrl) {
      return room;
    }

    return ChatRoom(
      id: room.id,
      patientId: room.patientId,
      patientName: room.patientName,
      patientPhotoUrl: resolvedPatientPhoto,
      doctorId: room.doctorId,
      doctorName: room.doctorName,
      doctorPhotoUrl: resolvedDoctorPhoto,
      participantIds: room.participantIds,
      lastMessage: room.lastMessage,
      unreadCount: room.unreadCount,
      createdAt: room.createdAt,
      lastUpdatedAt: room.lastUpdatedAt,
      isClosed: room.isClosed,
    );
  }

  String _resolvePeerPhotoUrl(ChatRoom room, ChatProvider provider) {
    final isCurrentPatient = room.patientId == widget.currentUser.id;
    final direct =
        (isCurrentPatient ? room.doctorPhotoUrl : room.patientPhotoUrl).trim();
    if (direct.isNotEmpty) {
      return direct;
    }

    final req = provider.getCachedConsultation(room.id);
    if (req == null) {
      return '';
    }
    return (isCurrentPatient ? req.targetDoctorPhotoUrl : req.patientPhotoUrl)
        .trim();
  }

  void _warmUpRoomPhoto(ChatRoom room, ChatProvider provider) {
    if (_photoWarmupAttempted.contains(room.id) ||
        _photoWarmupInFlight.contains(room.id)) {
      return;
    }
    if (_resolvePeerPhotoUrl(room, provider).isNotEmpty) {
      return;
    }

    _photoWarmupInFlight.add(room.id);
    _photoWarmupAttempted.add(room.id);
    unawaited(() async {
      final req = await provider.fetchConsultationRequestByRoom(room.id);
      _photoWarmupInFlight.remove(room.id);
      if (!mounted || req == null) {
        return;
      }
      final fallbackPhoto =
          (widget.currentUser.role == UserRole.patient
                  ? req.targetDoctorPhotoUrl
                  : req.patientPhotoUrl)
              .trim();
      if (fallbackPhoto.isNotEmpty) {
        setState(() {});
      }
    }());
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
      ..showSnackBar(
        SnackBar(
          content: Text(tr('تم رفض الطلب.', 'Demande rejetee.')),
        ),
      );
  }

  Future<void> _transferConsultation(String requestId) async {
    final provider = context.read<ChatProvider>();
    final tr = context.read<AppSettingsProvider>().tr;

    // Dialog to enter the new doctor id.
    var enteredDoctorId = '';
    final newDoctorId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            tr(
              'تحويل الطلب إلى طبيب آخر',
              'Transferer vers un autre medecin',
            ),
          ),
          content: TextFormField(
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (value) => enteredDoctorId = value.trim(),
            onFieldSubmitted: (value) {
              final id = value.trim();
              if (id.isEmpty) return;
              Navigator.of(dialogContext).pop(id);
            },
            decoration: InputDecoration(
              labelText: tr('معرّف الطبيب', 'ID du medecin'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('إلغاء', 'Annuler')),
            ),
            FilledButton(
              onPressed: () {
                if (enteredDoctorId.isEmpty) return;
                Navigator.of(dialogContext).pop(enteredDoctorId);
              },
              child: Text(tr('تحويل', 'Transferer')),
            ),
          ],
        );
      },
    );

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
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr('تم تحويل الطلب.', 'Demande transferee.'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPatient = widget.currentUser.role == UserRole.patient;

    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            isPatient
                ? tr('الاستشارات', 'Consultations')
                : tr('المحادثات', 'Discussions'),
          ),
        ),
        body: Container(
          decoration: sihhaPageBackground(context: context),
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
                        'تعذر تحميل قائمة المحادثات.',
                        'Impossible de charger la liste des discussions.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final allRooms = snapshot.data ?? const <ChatRoom>[];
              _syncIncomingCallRing(allRooms);
              for (final room in allRooms) {
                _warmUpRoomPhoto(room, chatProvider);
              }
              final rooms = allRooms.where((room) {
                if (_searchQuery.isEmpty) return true;
                final peerName = room.patientId == widget.currentUser.id
                    ? room.doctorName
                    : room.patientName;
                return peerName.toLowerCase().contains(_searchQuery) ||
                    room.lastMessage.toLowerCase().contains(_searchQuery);
              }).toList();
              final unreadCount = allRooms.fold<int>(
                0,
                (sum, room) => sum + room.unreadCount,
              );

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _ConversationsHeaderCard(
                      user: widget.currentUser,
                      totalRooms: allRooms.length,
                      unreadCount: unreadCount,
                      isPatient: isPatient,
                      isArabic: settings.isArabic,
                      tr: tr,
                    ),
                    const SizedBox(height: 14),
                    _ConversationPanel(
                      title: tr(
                        'البحث في المحادثات',
                        'Recherche dans les discussions',
                      ),
                      subtitle: tr(
                        'ابحث باسم الطبيب أو المريض أو بمحتوى الرسالة.',
                        'Recherchez par nom ou par contenu du message.',
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(
                          () => _searchQuery = value.trim().toLowerCase(),
                        ),
                        decoration: InputDecoration(
                          hintText: tr(
                            'ابحث في المحادثات...',
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
                          fillColor: isDark
                              ? const Color(0xFF141D28)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                    if (!isPatient) ...[
                      const SizedBox(height: 14),
                      _ConversationPanel(
                        title: tr(
                          'طلبات الاستشارة الواردة',
                          'Demandes de consultation recues',
                        ),
                        subtitle: tr(
                          'راجع الطلبات المعلقة ثم اقبل أو ارفض أو حوّل.',
                          'Traitez les demandes en attente: accepter, rejeter ou transferer.',
                        ),
                        child: _DoctorConsultationInbox(
                          onAccept: _acceptConsultation,
                          onReject: _rejectConsultation,
                          onTransfer: _transferConsultation,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ConversationPanel(
                      title: isPatient
                          ? tr('استشاراتي', 'Mes consultations')
                          : tr('محادثاتي', 'Mes discussions'),
                      subtitle: isPatient
                          ? tr(
                              'جميع استشاراتك مع الأطباء.',
                              'Voici la liste de vos consultations avec les medecins.',
                            )
                          : tr(
                              'جميع محادثاتك مع المرضى.',
                              'Voici la liste de vos discussions avec les patients.',
                            ),
                      child: rooms.isEmpty
                          ? _EmptyConsultations(
                              isPatient: isPatient,
                              hasSearch: _searchQuery.isNotEmpty,
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < rooms.length; i++) ...[
                                  _RoomTile(
                                    room: rooms[i],
                                    currentUserId: widget.currentUser.id,
                                    isArabic: settings.isArabic,
                                    peerPhotoUrl: _resolvePeerPhotoUrl(
                                      rooms[i],
                                      chatProvider,
                                    ),
                                    previewText: _previewText(
                                      rooms[i].lastMessage,
                                      tr,
                                    ),
                                    livePreview: _isLivePreview(
                                      rooms[i].lastMessage,
                                    ),
                                    onTap: () => _openRoom(
                                      _roomWithFallbackPhotos(
                                        rooms[i],
                                        chatProvider,
                                      ),
                                    ),
                                    formatClock: _formatClock,
                                  ),
                                  if (i != rooms.length - 1)
                                    const SizedBox(height: 8),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isLivePreview(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    const arabicLiveHint = '\u0628\u062b';
    return lower.contains('[live]') ||
        lower.contains('direct') ||
        lower.contains('live') ||
        lower.contains('session') ||
        value.contains(arabicLiveHint);
  }

  String _previewText(String raw, String Function(String, String) tr) {
    final value = raw.trim();
    if (value.isEmpty) {
      return tr('ابدأ المحادثة الآن',
        'Commencez la discussion',
      );
    }
    if (value == 'Image') {
      return tr('صورة', 'Photo');
    }
    if (value == 'Voice message') {
      return tr('رسالة صوتية', 'Message vocal');
    }
    if (_isLivePreview(value)) {
      return tr('جلسة مباشرة', 'Session en direct');
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
      return isArabic ? '\u0623\u0645\u0633' : 'Hier';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class _ConversationsHeaderCard extends StatelessWidget {
  const _ConversationsHeaderCard({
    required this.user,
    required this.totalRooms,
    required this.unreadCount,
    required this.isPatient,
    required this.isArabic,
    required this.tr,
  });

  final AppUser user;
  final int totalRooms;
  final int unreadCount;
  final bool isPatient;
  final bool isArabic;
  final String Function(String, String) tr;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.92),
      height: 1.3,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [SihhaPalette.primaryDeep, SihhaPalette.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: SihhaPalette.secondary.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PeerAvatar(
                imageUrl: user.photoUrl,
                fallbackIcon: isPatient
                    ? Icons.person_rounded
                    : Icons.local_hospital_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPatient
                          ? tr(
                              'لوحة الاستشارات',
                              'Tableau des consultations',
                            )
                          : tr(
                              'لوحة المحادثات الطبية',
                              'Tableau des discussions medicales',
                            ),
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderBadge(
                icon: Icons.chat_bubble_rounded,
                text: tr('الإجمالي: $totalRooms', 'Total: $totalRooms'),
              ),
              _HeaderBadge(
                icon: Icons.mark_chat_unread_rounded,
                text: tr(
                  'غير المقروء: $unreadCount',
                  'Non lus: $unreadCount',
                ),
              ),
              _HeaderBadge(
                icon: Icons.verified_user_rounded,
                text: user.role.label(isArabic: isArabic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: sihhaGlassCardDecoration(context: context),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SihhaPalette.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.currentUserId,
    required this.isArabic,
    required this.peerPhotoUrl,
    required this.previewText,
    required this.livePreview,
    required this.onTap,
    required this.formatClock,
  });

  final ChatRoom room;
  final String currentUserId;
  final bool isArabic;
  final String peerPhotoUrl;
  final String previewText;
  final bool livePreview;
  final VoidCallback onTap;
  final String Function(DateTime, bool) formatClock;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrentPatient = room.patientId == currentUserId;
    final peerName = isCurrentPatient ? room.doctorName : room.patientName;
    final hasUnread = room.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141D28).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUnread
                  ? SihhaPalette.secondary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              _PeerAvatar(
                imageUrl: peerPhotoUrl,
                fallbackIcon: isCurrentPatient
                    ? Icons.local_hospital_rounded
                    : Icons.person_rounded,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                    const SizedBox(height: 3),
                    Text(
                      previewText,
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatClock(room.lastUpdatedAt, isArabic),
                    style: TextStyle(
                      fontSize: 11,
                      color: hasUnread
                          ? SihhaPalette.secondary
                          : const Color(0xFF7D8A9A),
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
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
                            borderRadius: BorderRadius.circular(100),
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
                      if (hasUnread) _UnreadBadge(count: room.unreadCount),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              tr(
                'لا توجد طلبات استشارة معلقة حاليًا.',
                'Aucune demande en attente.',
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < requests.length; i++) ...[
              _DoctorRequestTile(
                request: requests[i],
                isDark: isDark,
                tr: tr,
                onAccept: onAccept,
                onReject: onReject,
                onTransfer: onTransfer,
              ),
              if (i != requests.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _DoctorRequestTile extends StatelessWidget {
  const _DoctorRequestTile({
    required this.request,
    required this.isDark,
    required this.tr,
    required this.onAccept,
    required this.onReject,
    required this.onTransfer,
  });

  final ConsultationRequest request;
  final bool isDark;
  final String Function(String, String) tr;
  final Future<void> Function(String requestId) onAccept;
  final Future<void> Function(String requestId) onReject;
  final Future<void> Function(String requestId) onTransfer;

  @override
  Widget build(BuildContext context) {
    final genderLabel = request.gender == RequestGender.male
        ? tr('ذكر', 'Homme')
        : tr('أنثى', 'Femme');

    return Container(
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
            request.patientName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'المستفيد: ${request.subjectName}',
              'Beneficiaire: ${request.subjectName}',
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              'العمر: ${request.ageYears}، الجنس: $genderLabel، الوزن: ${request.weightKg} كغ',
              'Age: ${request.ageYears}, sexe: $genderLabel, poids: ${request.weightKg} kg',
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              'الأعراض: ${request.symptoms}',
              'Symptomes: ${request.symptoms}',
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
                  onPressed: () => onAccept(request.id),
                  child: Text(tr('قبول', 'Accepter')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onReject(request.id),
                  child: Text(tr('رفض', 'Rejeter')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SihhaPalette.secondary),
                  ),
                  onPressed: () => onTransfer(request.id),
                  child: Text(tr('تحويل', 'Transferer')),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.chat_bubble_outline_rounded,
            size: 46,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? tr(
                    'لا توجد نتائج مطابقة.',
                    'Aucun resultat correspondant.',
                  )
                : isPatient
                ? tr(
                    'لا توجد استشارات بعد. ابدأ استشارة جديدة.',
                    'Aucune consultation pour le moment.',
                  )
                : tr('لا توجد محادثات بعد.',
                    'Aucune discussion pour le moment.',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatefulWidget {
  const _PeerAvatar({required this.imageUrl, required this.fallbackIcon});

  final String imageUrl;
  final IconData fallbackIcon;

  @override
  State<_PeerAvatar> createState() => _PeerAvatarState();
}

class _PeerAvatarState extends State<_PeerAvatar> {
  late List<String> _candidates;
  int _candidateIndex = 0;
  bool _advanceScheduled = false;

  @override
  void initState() {
    super.initState();
    _resetCandidates();
  }

  @override
  void didUpdateWidget(covariant _PeerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resetCandidates();
    }
  }

  void _resetCandidates() {
    _candidates = _buildPhotoCandidates(widget.imageUrl);
    _candidateIndex = 0;
    _advanceScheduled = false;
  }

  void _tryNextCandidate() {
    if (_advanceScheduled) return;
    if (_candidateIndex >= _candidates.length - 1) return;
    _advanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _candidateIndex += 1;
        _advanceScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _candidates.isEmpty ? '' : _candidates[_candidateIndex];
    final fallback = Icon(widget.fallbackIcon, color: SihhaPalette.secondary);
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFD7EBF8),
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return fallback;
                },
                errorBuilder: (context, error, stackTrace) {
                  _tryNextCandidate();
                  return fallback;
                },
              ),
      ),
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

  // Prefer canonical API host URL first to avoid long hangs on stale :3000 links.
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
