import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/sihha_theme.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

enum _PhotoSourceOption { camera, gallery }

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _photoSubmitting = false;
  int _photoVersion = DateTime.now().millisecondsSinceEpoch;

  Future<void> _showPhotoPreview(String photoUrl) async {
    final raw = photoUrl.trim();
    if (raw.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints(
                    maxHeight: 520,
                    minHeight: 260,
                  ),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      raw,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, _, _) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPhotoSourceSheet() async {
    if (_photoSubmitting) {
      return;
    }
    final tr = context.read<AppSettingsProvider>().tr;
    final source = await showModalBottomSheet<_PhotoSourceOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('اختر مصدر الصورة', 'Choisir la source de la photo'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: Text(tr('الكاميرا', 'Camera')),
                  subtitle: Text(
                    tr(
                      'التقاط صورة جديدة الآن.',
                      'Prendre une nouvelle photo.',
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _PhotoSourceOption.camera),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(tr('المعرض', 'Galerie')),
                  subtitle: Text(
                    tr(
                      'اختيار صورة من معرض الهاتف.',
                      'Choisir une image depuis la galerie.',
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _PhotoSourceOption.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || source == null) {
      return;
    }

    final imageSource = source == _PhotoSourceOption.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    await _pickProfilePhoto(imageSource);
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    if (_photoSubmitting) {
      return;
    }
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;
    final authProvider = context.read<AuthProvider>();

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile == null) {
        return;
      }
      if (!mounted) {
        return;
      }

      setState(() => _photoSubmitting = true);
      final success = await authProvider.updateProfilePhoto(
        File(pickedFile.path),
      );
      if (!mounted) {
        return;
      }

      if (success) {
        setState(() => _photoVersion = DateTime.now().millisecondsSinceEpoch);
        _showSnack(
          tr(
            'تم تحديث صورة البروفايل بنجاح.',
            'Photo de profil mise a jour avec succes.',
          ),
        );
        return;
      }

      final error = authProvider.errorMessage;
      if (error != null && error.isNotEmpty) {
        _showSnack(error);
        authProvider.clearError();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      final sourceLabel = source == ImageSource.camera
          ? tr('الكاميرا', 'la camera')
          : tr('المعرض', 'la galerie');
      _showSnack(
        tr(
          'تعذر الوصول إلى $sourceLabel أو قراءة الصورة.',
          'Impossible d\'ouvrir $sourceLabel ou de lire l\'image.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _photoSubmitting = false);
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;
    final authProvider = context.read<AuthProvider>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
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
                    controller: currentController,
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
                    controller: newController,
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
                    controller: confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr('تأكيد كلمة المرور', 'Confirmation'),
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

                          if (current.isEmpty ||
                              next.isEmpty ||
                              confirm.isEmpty) {
                            _showSnack(
                              tr(
                                'يرجى إدخال جميع الحقول.',
                                'Veuillez remplir tous les champs.',
                              ),
                            );
                            return;
                          }
                          if (next.length < 8) {
                            _showSnack(
                              tr(
                                'كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل.',
                                'Le nouveau mot de passe doit contenir au moins 8 caracteres.',
                              ),
                            );
                            return;
                          }
                          if (next != confirm) {
                            _showSnack(
                              tr(
                                'تأكيد كلمة المرور غير مطابق.',
                                'La confirmation ne correspond pas.',
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final success = await authProvider.changePassword(
                            currentPassword: current,
                            newPassword: next,
                          );
                          if (!mounted || !dialogContext.mounted) {
                            return;
                          }
                          setDialogState(() => isSubmitting = false);

                          if (success) {
                            Navigator.pop(dialogContext);
                            _showSnack(
                              tr(
                                'تم تغيير كلمة المرور بنجاح.',
                                'Mot de passe modifie avec succes.',
                              ),
                            );
                            return;
                          }

                          final error = authProvider.errorMessage;
                          if (error != null && error.isNotEmpty) {
                            _showSnack(error);
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

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> _confirmSignOut() async {
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr('تسجيل الخروج', 'Se deconnecter')),
          content: Text(
            tr(
              'هل تريد تسجيل الخروج من حسابك الآن؟',
              'Voulez-vous vous deconnecter maintenant ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('إلغاء', 'Annuler')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: SihhaPalette.danger,
              ),
              child: Text(tr('خروج', 'Deconnexion')),
            ),
          ],
        );
      },
    );
    if (shouldSignOut != true || !mounted) {
      return;
    }

    await context.read<AuthProvider>().signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _versionedPhotoUrl(String photoUrl) {
    final raw = photoUrl.trim();
    if (raw.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return raw;
    }
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['v'] = _photoVersion.toString();
    return uri.replace(queryParameters: queryParams).toString();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tr = settings.tr;
    final currentUser = authProvider.currentUser;
    final isBusy = authProvider.isLoading || _photoSubmitting;

    return Scaffold(
      appBar: AppBar(title: Text(tr('الإعدادات', 'Parametres'))),
      body: Container(
        decoration: sihhaPageBackground(context: context),
        child: currentUser == null
            ? Center(
                child: Text(
                  tr('لا يوجد مستخدم نشط.', 'Aucun utilisateur actif.'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _ProfileHeaderCard(
                      user: currentUser,
                      isArabic: settings.isArabic,
                      tr: tr,
                      photoUrl: _versionedPhotoUrl(currentUser.photoUrl),
                      isUpdatingPhoto: isBusy,
                      onUpdatePhoto: _showPhotoSourceSheet,
                      onPreviewPhoto: _showPhotoPreview,
                    ),
                    const SizedBox(height: 14),
                    _SettingsPanel(
                      title: tr('الحساب والأمان', 'Compte et securite'),
                      subtitle: tr(
                        'تحكم بكلمة المرور وإجراءات الحساب بشكل آمن.',
                        'Gerez le mot de passe et les actions du compte en securite.',
                      ),
                      child: Column(
                        children: [
                          _OptionTile(
                            icon: Icons.lock_reset_rounded,
                            title: tr(
                              'تعديل كلمة المرور',
                              'Modifier le mot de passe',
                            ),
                            subtitle: tr(
                              'اختر كلمة مرور قوية (8 أحرف على الأقل).',
                              'Utilisez un mot de passe fort (8 caracteres minimum).',
                            ),
                            enabled: !isBusy,
                            isArabic: settings.isArabic,
                            onTap: _showChangePasswordDialog,
                          ),
                          const SizedBox(height: 8),
                          _OptionTile(
                            icon: Icons.logout_rounded,
                            title: tr('تسجيل الخروج', 'Se deconnecter'),
                            subtitle: tr(
                              'الخروج من الجلسة الحالية على هذا الجهاز.',
                              'Se deconnecter sur cet appareil seulement.',
                            ),
                            enabled: !isBusy,
                            isArabic: settings.isArabic,
                            iconColor: SihhaPalette.danger,
                            titleColor: SihhaPalette.danger,
                            onTap: _confirmSignOut,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsPanel(
                      title: tr('المظهر واللغة', 'Apparence et langue'),
                      subtitle: tr(
                        'اضبط شكل التطبيق واللغة حسب تفضيلك.',
                        'Personnalisez le theme et la langue de l\'application.',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreferenceLabel(text: tr('نمط العرض', 'Theme')),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<ThemeMode>(
                              segments: [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  label: Text(tr('فاتح', 'Clair')),
                                  icon: const Icon(Icons.light_mode_rounded),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  label: Text(tr('داكن', 'Sombre')),
                                  icon: const Icon(Icons.dark_mode_rounded),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  label: Text(tr('حسب الجهاز', 'Systeme')),
                                  icon: const Icon(Icons.phone_android_rounded),
                                ),
                              ],
                              selected: <ThemeMode>{settings.themeMode},
                              onSelectionChanged: (selection) {
                                if (selection.isEmpty) {
                                  return;
                                }
                                settings.setThemeMode(selection.first);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PreferenceLabel(text: tr('اللغة', 'Langue')),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'ar',
                                  label: Text('العربية'),
                                  icon: Icon(Icons.translate_rounded),
                                ),
                                ButtonSegment<String>(
                                  value: 'fr',
                                  label: Text('Français'),
                                  icon: Icon(Icons.translate_rounded),
                                ),
                              ],
                              selected: <String>{settings.locale.languageCode},
                              onSelectionChanged: (selection) {
                                if (selection.isEmpty) {
                                  return;
                                }
                                settings.setLocale(Locale(selection.first));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.user,
    required this.isArabic,
    required this.tr,
    required this.photoUrl,
    required this.isUpdatingPhoto,
    required this.onUpdatePhoto,
    required this.onPreviewPhoto,
  });

  final AppUser user;
  final bool isArabic;
  final String Function(String ar, String fr) tr;
  final String photoUrl;
  final bool isUpdatingPhoto;
  final VoidCallback onUpdatePhoto;
  final void Function(String photoUrl) onPreviewPhoto;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.90),
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
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: photoUrl.trim().isEmpty
                    ? null
                    : () => onPreviewPhoto(photoUrl),
                child: Stack(
                  children: [
                    _UserAvatar(photoUrl: photoUrl, radius: 40),
                    PositionedDirectional(
                      end: -1,
                      bottom: -1,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: SihhaPalette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.90),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    const SizedBox(height: 3),
                    Text(
                      user.phoneNumber.isEmpty
                          ? tr('لا يوجد رقم هاتف', 'Numero indisponible')
                          : user.phoneNumber,
                      style: subtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TagBadge(text: user.role.label(isArabic: isArabic)),
                        _TagBadge(
                          text: user.isAdmin
                              ? tr('مشرف', 'Administrateur')
                              : tr('حساب نشط', 'Compte actif'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isUpdatingPhoto ? null : onUpdatePhoto,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SihhaPalette.primaryDeep,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.78),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isUpdatingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_back_rounded),
              label: Text(tr('تحديث صورة البروفايل', 'Mettre a jour la photo')),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'يمكنك اختيار صورة من الكاميرا أو المعرض.',
              'Vous pouvez choisir la camera ou la galerie.',
            ),
            style: subtitleStyle?.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.photoUrl, required this.radius});

  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.trim().isNotEmpty;
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.60),
          width: 1.2,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 36,
                  );
                },
              )
            : const Icon(Icons.person_rounded, color: Colors.white, size: 36),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          Text(subtitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.isArabic,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool isArabic;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedIconColor = iconColor ?? theme.colorScheme.primary;
    final resolvedTitleColor = titleColor ?? theme.textTheme.titleSmall?.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.58),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: resolvedIconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: resolvedIconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: resolvedTitleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  isArabic
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceLabel extends StatelessWidget {
  const _PreferenceLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
