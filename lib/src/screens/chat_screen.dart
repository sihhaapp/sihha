import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/consultation_request.dart';
import '../providers/app_settings_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/sihha_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/consultation_request_dialog.dart';
import 'livekit_call_screen.dart';

enum _CallIntent { voice }

class _PendingImageMessage {
  const _PendingImageMessage({
    required this.id,
    required this.filePath,
    required this.sentAt,
  });

  final String id;
  final String filePath;
  final DateTime sentAt;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.room,
    required this.currentUser,
    this.initialConsultation,
  });

  final ChatRoom room;
  final AppUser currentUser;
  final ConsultationRequest? initialConsultation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  late final ChatProvider _chatProvider;

  late final AnimationController _bgController;
  late final AnimationController _ringController;
  late Stream<List<ChatMessage>> _messagesStream;

  Timer? _statusTimer;
  int _lastCount = 0;
  bool _keyboardVisible = false;
  final List<_PendingImageMessage> _pendingImages = <_PendingImageMessage>[];

  String _liveStatus = 'idle';
  String? _requestedBy;
  String? _requestedAt;
  String? _lastIncomingRequestToken;
  _CallIntent? _outgoingIntent;
  bool _launchingCall = false;
  bool _isIncomingRinging = false;
  ConsultationRequest? _consultation;
  bool _loadingConsultation = false;
  bool _roomClosed = false;

  bool get _incomingRequest =>
      _liveStatus == 'pending' &&
      _requestedBy != null &&
      _requestedBy != widget.currentUser.id;
  bool get _outgoingRequest =>
      _liveStatus == 'pending' && _requestedBy == widget.currentUser.id;
  bool get _activeSession => _liveStatus == 'active';
  bool _consultationSectionVisible() => _loadingConsultation || _consultation != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatProvider = context.read<ChatProvider>();
    _roomClosed = widget.room.isClosed;
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _messagesStream = _chatProvider.messagesStream(
      widget.room.id,
      liveMode: true,
    );
    _loadConsultation();
    unawaited(_chatProvider.setPresence(roomId: widget.room.id, active: true));
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        _scrollToBottomRobust();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomRobust(animated: false);
    });
    _startStatusPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = _chatProvider;
    if (state == AppLifecycleState.resumed) {
      unawaited(provider.setPresence(roomId: widget.room.id, active: true));
      unawaited(_refreshStatus());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(provider.setPresence(roomId: widget.room.id, active: false));
    }
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final nowVisible = view.viewInsets.bottom > 0;
    if (nowVisible && !_keyboardVisible) {
      _keyboardVisible = true;
      _scrollToBottomRobust(delay: const Duration(milliseconds: 90));
    } else if (!nowVisible && _keyboardVisible) {
      _keyboardVisible = false;
    }
  }

  @override
  void dispose() {
    if (_outgoingRequest) {
      unawaited(_chatProvider.stopLiveConversation(widget.room.id));
    }
    unawaited(_chatProvider.setPresence(roomId: widget.room.id, active: false));
    _statusTimer?.cancel();
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _bgController.dispose();
    _ringController.dispose();
    unawaited(_stopIncomingRingtone());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadConsultation() async {
    final cached = _chatProvider.getCachedConsultation(widget.room.id);
    if (cached != null && mounted) {
      setState(() {
        _consultation = cached;
        _loadingConsultation = true;
      });
    } else {
      setState(() => _loadingConsultation = true);
    }
    final initial = widget.initialConsultation;
    if (initial != null) {
      _consultation = initial;
      _chatProvider.rememberConsultation(widget.room.id, initial);
      setState(() => _loadingConsultation = false);
      return;
    }
    final req =
        await _chatProvider.fetchConsultationRequestByRoom(widget.room.id);
    if (!mounted) return;
    setState(() {
      // احتفظ بالقيمة السابقة إذا لم يرجع الخادم شيئًا
      _consultation = req ?? _consultation;
      if (_consultation != null) {
        _chatProvider.rememberConsultation(widget.room.id, _consultation!);
      }
      _loadingConsultation = false;
    });
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    unawaited(_refreshStatus());
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshStatus());
    });
  }

  Future<void> _refreshStatus() async {
    final session = await context.read<ChatProvider>().fetchLiveStatus(
      widget.room.id,
    );
    if (!mounted || session == null) return;

    final status = ((session['status'] as String?) ?? 'idle').toLowerCase();
    final requestedByRaw = (session['requestedBy'] as String?)?.trim();
    final requestedBy = (requestedByRaw == null || requestedByRaw.isEmpty)
        ? null
        : requestedByRaw;
    final requestedAtRaw = (session['requestedAt'] as String?)?.trim();
    final requestedAt = (requestedAtRaw == null || requestedAtRaw.isEmpty)
        ? null
        : requestedAtRaw;

    final oldIncoming = _incomingRequest;
    setState(() {
      _liveStatus = status;
      _requestedBy = requestedBy;
      _requestedAt = requestedAt;
      if (status == 'idle' ||
          (status == 'pending' && requestedBy != widget.currentUser.id)) {
        _outgoingIntent = null;
      }
    });

    if (_incomingRequest && !oldIncoming) {
      final token = '${_requestedBy ?? ''}-${_requestedAt ?? ''}';
      if (_lastIncomingRequestToken != token) {
        _lastIncomingRequestToken = token;
        _showIncomingCallNotification();
        unawaited(_startIncomingRingtone());
      }
    }
    if (!_incomingRequest && oldIncoming) {
      unawaited(_stopIncomingRingtone());
    }

    if (_activeSession && _outgoingIntent != null && !_launchingCall) {
      setState(() {
        _launchingCall = true;
        _outgoingIntent = null;
      });
      unawaited(_openLiveKitCall(stopSessionOnReturn: true));
    }
  }

  Future<void> _openEditConsultation() async {
    if (_consultation == null || widget.currentUser.role != UserRole.doctor) return;
    final tr = context.read<AppSettingsProvider>().tr;
    final c = _consultation!;
    final subjectController = TextEditingController(text: c.subjectName);
    final ageController = TextEditingController(text: c.ageYears.toString());
    final weightController = TextEditingController(text: c.weightKg.toString());
    final symptomsController = TextEditingController(text: c.symptoms);
    RequestGender gender = c.gender;
    RequestSubjectType subjectType = c.subjectType;
    SpokenLanguage language = c.spokenLanguage;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('تعديل بيانات الاستشارة', 'Modifier la consultation'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RequestSubjectType>(
                      value: subjectType,
                      decoration: InputDecoration(labelText: tr('المستفيد', 'Bénéficiaire')),
                      items: [
                        DropdownMenuItem(
                          value: RequestSubjectType.self,
                          child: Text(tr('المريض نفسه', 'Patient lui-même')),
                        ),
                        DropdownMenuItem(
                          value: RequestSubjectType.other,
                          child: Text(tr('شخص آخر', 'Autre personne')),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => subjectType = v ?? subjectType),
                    ),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: tr('اسم المريض/المستفيد', 'Nom du bénéficiaire'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: tr('العمر', 'Âge')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<RequestGender>(
                            value: gender,
                            decoration: InputDecoration(labelText: tr('الجنس', 'Sexe')),
                            items: RequestGender.values
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g == RequestGender.male ? tr('ذكر', 'Homme') : tr('أنثى', 'Femme')),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setSheet(() => gender = v ?? gender),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: tr('الوزن (كغ)', 'Poids (kg)')),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SpokenLanguage>(
                      value: language,
                      decoration: InputDecoration(labelText: tr('اللغة', 'Langue')),
                      items: SpokenLanguage.values
                          .map(
                            (l) => DropdownMenuItem(
                              value: l,
                              child: Text(
                                l == SpokenLanguage.ar
                                    ? tr('عربي', 'Arabe')
                                    : l == SpokenLanguage.fr
                                        ? tr('فرنسي', 'Français')
                                        : tr('مزدوج', 'Bilingue'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheet(() => language = v ?? language),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: symptomsController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: tr('الأعراض', 'Symptômes')),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(false),
                            child: Text(tr('إلغاء', 'Annuler')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(sheetContext).pop(true),
                            child: Text(tr('حفظ', 'Enregistrer')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved != true) return;

    final age = int.tryParse(ageController.text.trim()) ?? c.ageYears;
    final weight = double.tryParse(weightController.text.trim()) ?? c.weightKg;
    final payload = <String, dynamic>{
      'subjectType': subjectType.value,
      'subjectName': subjectController.text.trim().isEmpty
          ? c.subjectName
          : subjectController.text.trim(),
      'ageYears': age,
      'gender': gender.value,
      'weightKg': weight,
      'stateCode': c.stateCode,
      'spokenLanguage': language.value,
      'symptoms': symptomsController.text.trim().isEmpty
          ? c.symptoms
          : symptomsController.text.trim(),
    };

    final updated = await _chatProvider.updateConsultationRequest(
      requestId: c.id,
      payload: payload,
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _consultation = updated);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('تم تحديث البيانات.', 'Données mises à jour.'))));
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _roomClosed) return;
    await context.read<ChatProvider>().sendTextMessage(
      roomId: widget.room.id,
      senderId: widget.currentUser.id,
      senderName: widget.currentUser.name,
      text: text,
    );
    _textController.clear();
  }

  Future<void> _pickAndSendImage() async {
    if (_roomClosed) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final pending = _PendingImageMessage(
      id: 'pending-image-${DateTime.now().microsecondsSinceEpoch}',
      filePath: picked.path,
      sentAt: DateTime.now(),
    );
    setState(() => _pendingImages.add(pending));
    _scrollToBottomRobust();
    unawaited(_sendPendingImage(pending));
  }

  Future<void> _sendPendingImage(_PendingImageMessage pending) async {
    final ok = await context.read<ChatProvider>().sendImageMessage(
      roomId: widget.room.id,
      imageFile: File(pending.filePath),
    );
    if (!mounted) return;

    if (!ok) {
      setState(() => _pendingImages.removeWhere((p) => p.id == pending.id));
      _showErrorIfAny();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _pendingImages.removeWhere((p) => p.id == pending.id));
    _scrollToBottomRobust();
  }

  Future<void> _closeRoom() async {
    final tr = context.read<AppSettingsProvider>().tr;
    final ok = await _chatProvider.closeRoom(widget.room.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _roomClosed = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('تم إغلاق الاستشارة.', 'Consultation clôturée.'))));
    } else {
      _showErrorIfAny();
    }
  }

  Future<void> _startNewConsultationRequest() async {
    final tr = context.read<AppSettingsProvider>().tr;
    final patient = widget.currentUser;
    if (patient.role != UserRole.patient) return;

    final doctor = AppUser(
      id: widget.room.doctorId,
      name: widget.room.doctorName,
      phoneNumber: '',
      role: UserRole.doctor,
      createdAt: DateTime.now(),
      photoUrl: widget.room.doctorPhotoUrl,
    );

    final input = await showConsultationRequestDialog(
      context: context,
      patient: patient,
      doctor: doctor,
    );
    if (input == null || !mounted) return;

    final req = await _chatProvider.submitConsultationRequest(
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
    if (req != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('تم إرسال طلب جديد للطبيب.', 'Nouvelle demande envoyée.'))));
    } else {
      _showErrorIfAny();
    }
  }

  Future<void> _requestCall() async {
    if (_incomingRequest) {
      return;
    }
    final ok = await context.read<ChatProvider>().requestLiveConversation(
      widget.room.id,
    );
    _showErrorIfAny();
    if (!ok || !mounted) return;
    setState(() {
      _outgoingIntent = _CallIntent.voice;
    });
    unawaited(_refreshStatus());
  }

  Future<void> _cancelOutgoingRequest() async {
    final ok = await context.read<ChatProvider>().stopLiveConversation(
      widget.room.id,
    );
    _showErrorIfAny();
    if (!ok || !mounted) return;
    setState(() {
      _outgoingIntent = null;
    });
    unawaited(_refreshStatus());
  }

  Future<void> _acceptIncomingCall() async {
    final ok = await context.read<ChatProvider>().acceptLiveConversation(
      widget.room.id,
    );
    _showErrorIfAny();
    if (!ok) return;
    await _stopIncomingRingtone();
    await _openLiveKitCall(stopSessionOnReturn: true);
  }

  Future<void> _rejectIncomingCall() async {
    await _stopIncomingRingtone();
    if (!mounted) return;
    await context.read<ChatProvider>().rejectLiveConversation(widget.room.id);
    _showErrorIfAny();
    unawaited(_refreshStatus());
  }

  Future<void> _startIncomingRingtone() async {
    if (_isIncomingRinging) return;
    _isIncomingRinging = true;
    try {
      await _ringtonePlayer.playRingtone(looping: true, volume: 0.9);
    } catch (_) {
      _isIncomingRinging = false;
    }
  }

  Future<void> _stopIncomingRingtone() async {
    if (!_isIncomingRinging) return;
    _isIncomingRinging = false;
    try {
      await _ringtonePlayer.stop();
    } catch (_) {
      // Ignore ringtone stop failures.
    }
  }

  Future<void> _openLiveKitCall({required bool stopSessionOnReturn}) async {
    if (!mounted) return;
    final payload = await context.read<ChatProvider>().joinLiveSession(
      widget.room.id,
    );
    _showErrorIfAny();
    if (!mounted) return;
    if (payload == null) {
      setState(() {
        _launchingCall = false;
      });
      return;
    }

    final url = (payload['url'] as String?)?.trim() ?? '';
    final token = (payload['token'] as String?)?.trim() ?? '';
    final roomName = (payload['roomName'] as String?)?.trim() ?? widget.room.id;
    if (url.isEmpty || token.isEmpty) {
      _showCallServerError();
      setState(() {
        _launchingCall = false;
      });
      return;
    }

    final meIsPatient = widget.currentUser.id == widget.room.patientId;
    final shouldStopSession = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LiveKitCallScreen(
          roomId: widget.room.id,
          url: url,
          token: token,
          roomName: roomName,
          localDisplayName: widget.currentUser.name,
          localPhotoUrl: widget.currentUser.photoUrl,
          localRoleLabel: meIsPatient ? 'Patient' : 'Doctor',
          remoteDisplayName: meIsPatient
              ? widget.room.doctorName
              : widget.room.patientName,
          remotePhotoUrl: meIsPatient
              ? widget.room.doctorPhotoUrl
              : widget.room.patientPhotoUrl,
          remoteRoleLabel: meIsPatient ? 'Doctor' : 'Patient',
        ),
      ),
    );
    if (!mounted) return;
    if (stopSessionOnReturn && (shouldStopSession ?? true)) {
      await context.read<ChatProvider>().stopLiveConversation(widget.room.id);
      _showErrorIfAny();
    }
    if (!mounted) return;
    setState(() {
      _launchingCall = false;
    });
    unawaited(_refreshStatus());
  }

  void _showCallServerError() {
    if (!mounted) return;
    final tr = context.read<AppSettingsProvider>().tr;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Unable to get call connection details.',
              'Impossible d\'obtenir les donnees de connexion a l\'appel.',
            ),
          ),
        ),
      );
  }

  void _showIncomingCallNotification() {
    if (!mounted) return;
    final tr = context.read<AppSettingsProvider>().tr;
    final meIsPatient = widget.currentUser.id == widget.room.patientId;
    final peerName = meIsPatient
        ? widget.room.doctorName
        : widget.room.patientName;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.ring_volume_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    'Ù…ÙƒØ§Ù„Ù…Ø© ÙˆØ§Ø±Ø¯Ø© Ù…Ù† $peerName',
                    'Appel entrant de $peerName',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showErrorIfAny() {
    if (!mounted) return;
    final provider = context.read<ChatProvider>();
    final error = provider.errorMessage;
    if (error == null || error.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
    provider.clearError();
  }

  void _scrollToBottom({bool animated = true, Duration delay = Duration.zero}) {
    Future<void>.delayed(delay, () {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (!animated) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToBottomRobust({
    bool animated = true,
    Duration delay = Duration.zero,
  }) {
    _scrollToBottom(animated: animated, delay: delay);
    for (var i = 1; i <= 8; i++) {
      _scrollToBottom(
        animated: true,
        delay: delay + Duration(milliseconds: 45 * i),
      );
    }
  }

  Widget _buildCallPanel({
    required String peerName,
    required String Function(String, String) tr,
  }) {
    if (_incomingRequest) {
      return _IncomingCallPanel(
        controller: _ringController,
        tr: tr,
        peerName: peerName,
        onReject: _rejectIncomingCall,
        onAccept: _acceptIncomingCall,
      );
    }
    if (_outgoingRequest) {
      return _OutgoingCallPanel(
        controller: _ringController,
        tr: tr,
        onCancel: _cancelOutgoingRequest,
      );
    }
    return const SizedBox.shrink();
  }

  bool _isSystemLiveMessage(ChatMessage message) {
    if (message.type != MessageType.live) return false;
    return message.content.trim().startsWith('[LIVE_');
  }

  bool _sameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final meIsPatient = widget.currentUser.id == widget.room.patientId;
    final peerName = meIsPatient
        ? widget.room.doctorName
        : widget.room.patientName;
    final peerPhotoUrl =
        (meIsPatient ? widget.room.doctorPhotoUrl : widget.room.patientPhotoUrl)
            .trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
        ),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: isDark
                ? const Color(0xFF0B2236)
                : const Color(0xFFE6F3FA),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 6,
            title: Row(
              children: [
                _HeaderPeerAvatar(
                  imageUrl: peerPhotoUrl,
                  fallbackText: peerName.isNotEmpty
                      ? peerName[0].toUpperCase()
                      : '?',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFEAF7FF)
                          : const Color(0xFF13405A),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.currentUser.role == UserRole.doctor)
                IconButton(
                  tooltip: _roomClosed
                      ? tr('الاستشارة مغلقة', 'Consultation clôturée')
                      : tr('إغلاق الاستشارة', 'Clôturer la consultation'),
                  onPressed: _roomClosed ? null : _closeRoom,
                  icon: Icon(
                    _roomClosed ? Icons.lock_rounded : Icons.lock_outline_rounded,
                  ),
                ),
            ],
          ),
          body: Stack(
            children: [
              _Backdrop(controller: _bgController),
              Column(
                children: [
                  if (_consultationSectionVisible())
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: _ConsultationCard(
                        consultation: _consultation,
                        loading: _loadingConsultation,
                        isDoctor: widget.currentUser.role == UserRole.doctor,
                        tr: tr,
                        onEdit: _openEditConsultation,
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _buildCallPanel(peerName: peerName, tr: tr),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ChatMessage>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              tr(
                                'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø±Ø³Ø§Ø¦Ù„.',
                                'Impossible de charger les messages.',
                              ),
                            ),
                          );
                        }

                        final serverMessages =
                            (snapshot.data ?? const <ChatMessage>[])
                                .where((m) => !_isSystemLiveMessage(m))
                                .toList();
                        final pendingMessages = _pendingImages
                            .map(
                              (pending) => ChatMessage(
                                id: pending.id,
                                roomId: widget.room.id,
                                senderId: widget.currentUser.id,
                                senderName: widget.currentUser.name,
                                type: MessageType.image,
                                content: pending.filePath,
                                durationSeconds: 0,
                                deliveredAt: null,
                                readAt: null,
                                sentAt: pending.sentAt,
                              ),
                            )
                            .toList(growable: false);
                        final messages =
                            <ChatMessage>[...serverMessages, ...pendingMessages]
                              ..sort((a, b) {
                                final byTime = a.sentAt.compareTo(b.sentAt);
                                if (byTime != 0) return byTime;
                                return a.id.compareTo(b.id);
                              });
                        if (messages.length > _lastCount) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToBottomRobust();
                          });
                        }
                        _lastCount = messages.length;

                        return messages.isEmpty
                            ? Center(
                                child: Text(
                                  tr(
                                    'Ø§Ø¨Ø¯Ø£ Ø§Ù„Ø§Ø³ØªØ´Ø§Ø±Ø© Ø§Ù„Ø¢Ù†.',
                                    'Commencez la consultation maintenant.',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  10,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final m = messages[index];
                                  final showDayChip =
                                      index == 0 ||
                                      !_sameCalendarDay(
                                        messages[index - 1].sentAt,
                                        m.sentAt,
                                      );
                                  final isMine =
                                      m.senderId == widget.currentUser.id;
                                  final isPending = m.id.startsWith(
                                    'pending-image-',
                                  );
                                  final provider = context
                                      .watch<ChatProvider>();
                                  final isPlaying =
                                      provider.activeAudioUrl == m.content;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showDayChip)
                                        _DateChip(dateTime: m.sentAt),
                                      MessageBubble(
                                        message: m,
                                        isMine: isMine,
                                        isPending: isPending,
                                        isPlaying: isPlaying,
                                        onAudioTap:
                                            !isPending &&
                                                m.type == MessageType.audio
                                            ? () => provider.playOrPauseAudio(
                                                m.content,
                                              )
                                            : null,
                                      ),
                                    ],
                                  );
                                },
                              );
                      },
                    ),
                  ),
                  if (_roomClosed)
                    _ClosedRoomPanel(
                      tr: tr,
                      isPatient: widget.currentUser.role == UserRole.patient,
                      onNewRequest: widget.currentUser.role == UserRole.patient
                          ? _startNewConsultationRequest
                          : null,
                    )
                  else
                    _WhatsAppComposerBar(
                      tr: tr,
                      controller: _textController,
                      onSend: _sendText,
                      onPickImage: _pickAndSendImage,
                      onStartVoiceCall: _requestCall,
                      canStartVoiceCall:
                          !_incomingRequest &&
                          !_outgoingRequest &&
                          !_activeSession &&
                          !_launchingCall,
                      onInputTap: () => _scrollToBottomRobust(),
                      inputFocusNode: _inputFocusNode,
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

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final dx = 0.08 * math.sin(t * math.pi * 2);
        final dy = 0.08 * math.cos(t * math.pi * 2);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF071A2A), Color(0xFF0D2D43)]
                  : const [Color(0xFFEAF6FD), Color(0xFFDDF0FB)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(dx * 40, dy * 40),
                  child: CustomPaint(
                    painter: _ChatDoodlePainter(isDark: isDark),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: isDark ? 0.10 : 0.02),
                        Colors.transparent,
                        Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderPeerAvatar extends StatelessWidget {
  const _HeaderPeerAvatar({required this.imageUrl, required this.fallbackText});

  final String imageUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = imageUrl.trim();
    final fallback = CircleAvatar(
      radius: 18,
      backgroundColor: isDark
          ? const Color(0xFF21425A)
          : const Color(0xFFCFE8F5),
      child: Text(
        fallbackText,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFEAF7FF) : const Color(0xFF13405A),
        ),
      ),
    );
    if (url.isEmpty) {
      return fallback;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: isDark
          ? const Color(0xFF21425A)
          : const Color(0xFFCFE8F5),
      child: ClipOval(
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 36,
            height: 36,
            color: isDark ? const Color(0xFF21425A) : const Color(0xFFCFE8F5),
            alignment: Alignment.center,
            child: Text(
              fallbackText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFEAF7FF)
                    : const Color(0xFF13405A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text =
        '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C3E56).withValues(alpha: 0.95)
              : const Color(0xFFCCE6F5).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFDCF0FF) : const Color(0xFF15455F),
          ),
        ),
      ),
    );
  }
}

class _ChatDoodlePainter extends CustomPainter {
  const _ChatDoodlePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark
          ? const Color(0xFF2E5B78).withValues(alpha: 0.40)
          : const Color(0xFF91BFD8).withValues(alpha: 0.30);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark
          ? const Color(0xFF2E5B78).withValues(alpha: 0.20)
          : const Color(0xFF91BFD8).withValues(alpha: 0.12);

    const step = 76.0;
    for (double y = -step; y < size.height + step; y += step) {
      for (double x = -step; x < size.width + step; x += step) {
        final k = ((x ~/ step) + (y ~/ step)).abs() % 5;
        final c = Offset(x + 36, y + 36);
        switch (k) {
          case 0:
            canvas.drawCircle(c, 10, stroke);
            break;
          case 1:
            canvas.drawLine(
              Offset(c.dx - 8, c.dy),
              Offset(c.dx + 8, c.dy),
              stroke,
            );
            canvas.drawLine(
              Offset(c.dx, c.dy - 8),
              Offset(c.dx, c.dy + 8),
              stroke,
            );
            break;
          case 2:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: c, width: 16, height: 12),
                const Radius.circular(4),
              ),
              stroke,
            );
            break;
          case 3:
            canvas.drawArc(
              Rect.fromCircle(center: c, radius: 10),
              math.pi * 0.1,
              math.pi * 1.45,
              false,
              stroke,
            );
            break;
          default:
            canvas.drawCircle(c, 2.5, fill);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatDoodlePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _IncomingCallPanel extends StatelessWidget {
  const _IncomingCallPanel({
    required this.controller,
    required this.tr,
    required this.peerName,
    required this.onReject,
    required this.onAccept,
  });

  final AnimationController controller;
  final String Function(String, String) tr;
  final String peerName;
  final Future<void> Function() onReject;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse =
            0.55 + (math.sin(controller.value * math.pi * 2) + 1) * 0.15;
        return Container(
          key: const ValueKey('incoming-call'),
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFEDEE), Color(0xFFFFF6F2)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB8B8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: pulse * 0.20),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.ring_volume_rounded,
                    color: Color(0xFFD32F2F),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        'Ù…ÙƒØ§Ù„Ù…Ø© ÙˆØ§Ø±Ø¯Ø© Ù…Ù† $peerName',
                        'Appel entrant de $peerName',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(
                        Icons.call_end_rounded,
                        color: Color(0xFFD32F2F),
                      ),
                      label: Text(tr('Ø±ÙØ¶', 'Refuser')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.call_rounded),
                      label: Text(tr('Ø±Ø¯ ØµÙˆØªÙŠ', 'Accepter vocal')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutgoingCallPanel extends StatelessWidget {
  const _OutgoingCallPanel({
    required this.controller,
    required this.tr,
    required this.onCancel,
  });

  final AnimationController controller;
  final String Function(String, String) tr;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse =
            0.48 + (math.sin(controller.value * math.pi * 2) + 1) * 0.12;
        final title = tr(
          'Voice call request pending...',
          'En attente de l\'acceptation vocale...',
        );
        return Container(
          key: const ValueKey('outgoing-call'),
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF4FF), Color(0xFFF6FAFF)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB9D9FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A8BC9).withValues(alpha: pulse * 0.20),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1A8BC9),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text(tr('Ø¥Ù„ØºØ§Ø¡', 'Annuler')),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.tr,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onStartVoiceCall,
    required this.canStartVoiceCall,
    required this.onInputTap,
    required this.inputFocusNode,
  });

  final String Function(String, String) tr;
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onStartVoiceCall;
  final bool canStartVoiceCall;
  final VoidCallback onInputTap;
  final FocusNode inputFocusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121B26).withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: canStartVoiceCall ? onStartVoiceCall : null,
            icon: const Icon(Icons.call_rounded, color: SihhaPalette.accent),
          ),
          IconButton(
            onPressed: onPickImage,
            icon: const Icon(
              Icons.photo_library_rounded,
              color: SihhaPalette.secondary,
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 128),
              child: TextField(
                controller: controller,
                focusNode: inputFocusNode,
                minLines: 1,
                maxLines: null,
                onTap: onInputTap,
                decoration: InputDecoration(
                  hintText: tr(
                    'Ø§ÙƒØªØ¨ Ø±Ø³Ø§Ù„ØªÙƒ Ù‡Ù†Ø§...',
                    'Ecrivez votre message ici...',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
          CircleAvatar(
            radius: 21,
            backgroundColor: SihhaPalette.primary,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: hasText ? onSend : null,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppComposerBar extends StatelessWidget {
  const _WhatsAppComposerBar({
    required this.tr,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onStartVoiceCall,
    required this.canStartVoiceCall,
    required this.onInputTap,
    required this.inputFocusNode,
  });

  final String Function(String, String) tr;
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onStartVoiceCall;
  final bool canStartVoiceCall;
  final VoidCallback onInputTap;
  final FocusNode inputFocusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = isDark
        ? const Color(0xFF16212B)
        : const Color(0xFFEFF3F7);
    final iconColor = isDark
        ? const Color(0xFFA9B8C7)
        : const Color(0xFF6A7C8E);
    final inputColor = isDark
        ? const Color(0xFFEAF0F6)
        : const Color(0xFF1F2E3B);
    final hintColor = isDark
        ? const Color(0xFF8295A9)
        : const Color(0xFF8092A1);
    const actionColor = Color(0xFF11A77F);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 54, maxHeight: 132),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: shellColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
                    child: FilledButton.icon(
                      onPressed: canStartVoiceCall ? onStartVoiceCall : null,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFF11A77F),
                        disabledBackgroundColor: iconColor.withValues(
                          alpha: isDark ? 0.22 : 0.35,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(
                        Icons.call_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        tr('Ø§Ø³ØªØ´Ø§Ø±Ø©', 'Consulter'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onPickImage,
                    icon: Icon(
                      Icons.photo_outlined,
                      color: iconColor,
                      size: 23,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: inputFocusNode,
                      minLines: 1,
                      maxLines: 5,
                      onTap: onInputTap,
                      style: TextStyle(fontSize: 19, color: inputColor),
                      decoration: InputDecoration(
                        hintText: tr('Message', 'Message'),
                        hintStyle: TextStyle(color: hintColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return SizedBox(
                width: 52,
                height: 52,
                child: FloatingActionButton(
                  heroTag: null,
                  elevation: 0,
                  backgroundColor: actionColor,
                  onPressed: hasText ? onSend : null,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({
    required this.consultation,
    required this.loading,
    required this.isDoctor,
    required this.tr,
    required this.onEdit,
  });

  final ConsultationRequest? consultation;
  final bool loading;
  final bool isDoctor;
  final String Function(String, String) tr;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: sihhaGlassCardDecoration(context: context),
      child: loading
          ? Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(tr('جارِ تحميل بيانات الاستشارة...', 'Chargement...')),
              ],
            )
          : (consultation == null
              ? Text(
                  tr('لا توجد بيانات استشارة مرتبطة بهذه المحادثة.', 'Aucune donnée de consultation.'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('بيانات الاستشارة', 'Données de consultation'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isDoctor)
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text(tr('تعديل', 'Modifier')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _line(tr('المريض', 'Patient'), consultation!.patientName),
                    _line(tr('المستفيد', 'Bénéficiaire'), consultation!.subjectName),
                    _line(
                      tr('العمر / الجنس', 'Âge / sexe'),
                      '${consultation!.ageYears} / ${consultation!.gender == RequestGender.male ? tr('ذكر', 'Homme') : tr('أنثى', 'Femme')}',
                    ),
                    _line(tr('الوزن (كغ)', 'Poids (kg)'), consultation!.weightKg.toString()),
                    _line(
                      tr('اللغة', 'Langue'),
                      consultation!.spokenLanguage == SpokenLanguage.ar
                          ? tr('عربي', 'Arabe')
                          : consultation!.spokenLanguage == SpokenLanguage.fr
                              ? tr('فرنسي', 'Français')
                              : tr('مزدوج', 'Bilingue'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('الأعراض', 'Symptômes'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consultation!.symptoms,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                )),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedRoomPanel extends StatelessWidget {
  const _ClosedRoomPanel({
    required this.tr,
    required this.isPatient,
    this.onNewRequest,
  });

  final String Function(String, String) tr;
  final bool isPatient;
  final VoidCallback? onNewRequest;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: sihhaGlassCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, color: SihhaPalette.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('تم إغلاق هذه الاستشارة.', 'Cette consultation est clôturée.'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPatient
                ? tr('لطلب التواصل مجدداً، أرسل طلب استشارة جديد لهذا الطبيب.',
                    'Pour reprendre contact, envoyez une nouvelle demande de consultation à ce médecin.')
                : tr('لا يمكن للمريض إرسال رسائل بعد الإغلاق.', 'Le patient ne peut plus envoyer de messages.'),
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          if (isPatient && onNewRequest != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onNewRequest,
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(tr('طلب استشارة جديدة', 'Nouvelle demande')),
            ),
          ],
        ],
      ),
    );
  }
}
