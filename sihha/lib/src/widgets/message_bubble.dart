import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/app_settings_provider.dart';
import '../theme/sihha_theme.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isPending = false,
    this.isPlaying = false,
    this.onAudioTap,
  });

  final ChatMessage message;
  final bool isMine;
  final bool isPending;
  final bool isPlaying;
  final VoidCallback? onAudioTap;

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<AppSettingsProvider>().tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = message.type == MessageType.live;

    if (isLive) {
      final liveUi = _LiveEventViewData.fromRaw(
        raw: message.content,
        senderName: message.senderName,
        tr: tr,
      );
      if (liveUi.hidden) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.center,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.92,
          ),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: liveUi.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: liveUi.border, width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(liveUi.icon, color: liveUi.iconColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      liveUi.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: liveUi.textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (liveUi.subtitle != null && liveUi.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    liveUi.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: liveUi.textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatClock(message.sentAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: liveUi.textColor.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleColor = isMine
        ? const Color(0xFF5F5DE8)
        : (isDark ? const Color(0xFF1A232D) : Colors.white);
    final textColor = isMine
        ? Colors.white
        : (isDark ? SihhaPalette.textOnDark : SihhaPalette.text);
    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.84)
        : (isDark ? const Color(0xFFB9CFE0) : Colors.black54);
    const outgoingGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6B58E7), Color(0xFF51B2FF)],
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.fromLTRB(
          message.type == MessageType.image ? 6 : 10,
          message.type == MessageType.image ? 6 : 7,
          message.type == MessageType.image ? 6 : 10,
          6,
        ),
        decoration: BoxDecoration(
          color: isMine ? null : bubbleColor,
          gradient: isMine ? outgoingGradient : null,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Opacity(
          opacity: isPending ? 0.9 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.type == MessageType.text)
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.28,
                    color: textColor,
                  ),
                ),
              if (message.type == MessageType.audio)
                InkWell(
                  onTap: onAudioTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: isMine ? Colors.white : SihhaPalette.secondary,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr('رسالة صوتية', 'Message vocal')} ${_formatDuration(message.durationSeconds)}',
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.type == MessageType.image)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(content: message.content, tr: tr),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatClock(message.sentAt),
                      style: TextStyle(fontSize: 11, color: metaColor),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: metaColor,
                        ),
                      ),
                    ] else if (isMine) ...[
                      const SizedBox(width: 4),
                      _MessageStatusIcon(message: message),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget({
    required String content,
    required String Function(String, String) tr,
  }) {
    if (_isRemoteImageUrl(content)) {
      return Image.network(
        content,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 210,
          height: 140,
          color: const Color(0xFFE8EDF5),
          alignment: Alignment.center,
          child: Text(
            tr('تعذر عرض الصورة', 'Image indisponible'),
            style: const TextStyle(color: Color(0xFF5A6A81)),
          ),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 210,
            height: 140,
            color: const Color(0xFFF0F4FA),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
      );
    }

    final localPath = content.startsWith('file://')
        ? Uri.parse(content).toFilePath()
        : content;
    return Image.file(
      File(localPath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 210,
        height: 140,
        color: const Color(0xFFE8EDF5),
        alignment: Alignment.center,
        child: Text(
          tr('تعذر عرض الصورة', 'Image indisponible'),
          style: const TextStyle(color: Color(0xFF5A6A81)),
        ),
      ),
    );
  }

  bool _isRemoteImageUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _formatClock(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDuration(int seconds) {
    final clamped = seconds < 0 ? 0 : seconds;
    final min = (clamped ~/ 60).toString().padLeft(2, '0');
    final sec = (clamped % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _LiveEventViewData {
  const _LiveEventViewData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.background,
    required this.border,
    required this.hidden,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color background;
  final Color border;
  final bool hidden;

  factory _LiveEventViewData.fromRaw({
    required String raw,
    required String senderName,
    required String Function(String, String) tr,
  }) {
    final cleaned = raw.trim();
    final match = RegExp(r'^\[(LIVE_[A-Z_]+)\]\s*(.*)$').firstMatch(cleaned);
    final marker = match?.group(1) ?? '';
    final actor = (match?.group(2) ?? '').trim();
    final by = actor.isNotEmpty ? actor : senderName;
    final byText = by.isEmpty ? null : tr('بواسطة $by', 'Par $by');

    switch (marker) {
      case 'LIVE_SIGNAL':
        return const _LiveEventViewData(
          title: '',
          subtitle: null,
          icon: Icons.circle,
          iconColor: Colors.transparent,
          textColor: Colors.transparent,
          background: Colors.transparent,
          border: Colors.transparent,
          hidden: true,
        );
      case 'LIVE_REQUEST':
        return _LiveEventViewData(
          title: tr('طلب مكالمة جديدة', 'Nouvelle demande d\'appel'),
          subtitle: byText,
          icon: Icons.ring_volume_rounded,
          iconColor: const Color(0xFFCC7A00),
          textColor: const Color(0xFF7C4A00),
          background: const Color(0xFFFFF7E8),
          border: const Color(0xFFF2D39B),
          hidden: false,
        );
      case 'LIVE_ACCEPT':
        return _LiveEventViewData(
          title: tr('تم قبول المكالمة', 'Appel accepte'),
          subtitle: byText,
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF2E7D32),
          textColor: const Color(0xFF1F5A23),
          background: const Color(0xFFEAF8EE),
          border: const Color(0xFFBDE2C4),
          hidden: false,
        );
      case 'LIVE_START':
        return _LiveEventViewData(
          title: tr('بدأت المكالمة', 'Appel demarre'),
          subtitle: byText,
          icon: Icons.phone_in_talk_rounded,
          iconColor: const Color(0xFF1565C0),
          textColor: const Color(0xFF12497F),
          background: const Color(0xFFEAF3FF),
          border: const Color(0xFFB9D5FF),
          hidden: false,
        );
      case 'LIVE_STOP':
        return _LiveEventViewData(
          title: tr('انتهت المكالمة', 'Appel termine'),
          subtitle: byText,
          icon: Icons.call_end_rounded,
          iconColor: const Color(0xFFC62828),
          textColor: const Color(0xFF8B1D1D),
          background: const Color(0xFFFFEFEF),
          border: const Color(0xFFFFC5C5),
          hidden: false,
        );
      case 'LIVE_REJECT':
        return _LiveEventViewData(
          title: tr('تم رفض الطلب', 'Demande refusee'),
          subtitle: byText,
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFAD1457),
          textColor: const Color(0xFF7E1040),
          background: const Color(0xFFFFEEF5),
          border: const Color(0xFFF4C4D8),
          hidden: false,
        );
      default:
        final fallbackText = cleaned.replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '');
        return _LiveEventViewData(
          title: fallbackText.isEmpty
              ? tr('تحديث مكالمة', 'Mise a jour d\'appel')
              : fallbackText,
          subtitle: byText,
          icon: Icons.info_rounded,
          iconColor: const Color(0xFF455A64),
          textColor: const Color(0xFF37474F),
          background: const Color(0xFFF0F4F7),
          border: const Color(0xFFD3DEE6),
          hidden: false,
        );
    }
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final read = message.readAt != null;
    final delivered = message.deliveredAt != null;
    final defaultColor = Colors.white.withValues(alpha: 0.72);
    final deliveredColor = Colors.white.withValues(alpha: 0.78);

    if (read) {
      return const Icon(
        Icons.done_all_rounded,
        size: 16,
        color: Color(0xFF8BE9FF),
      );
    }
    if (delivered) {
      return Icon(Icons.done_all_rounded, size: 16, color: deliveredColor);
    }
    return Icon(Icons.done_rounded, size: 16, color: defaultColor);
  }
}
