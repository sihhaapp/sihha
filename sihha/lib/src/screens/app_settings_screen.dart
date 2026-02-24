import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../theme/sihha_theme.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            '\u0627\u0644\u0627\u0639\u062f\u0627\u062f\u0627\u062a',
            'Parametres',
          ),
        ),
      ),
      body: Container(
        decoration: sihhaPageBackground(context: context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              text: tr(
                '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062b\u064a\u0645',
                'Theme',
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: sihhaGlassCardDecoration(context: context),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text(tr('\u0641\u0627\u062a\u062d', 'Clair')),
                    icon: const Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text(tr('\u062f\u0627\u0643\u0646', 'Sombre')),
                    icon: const Icon(Icons.dark_mode_rounded),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text(
                      tr(
                        '\u062d\u0633\u0628 \u0627\u0644\u062c\u0647\u0627\u0632',
                        'Systeme',
                      ),
                    ),
                    icon: const Icon(Icons.phone_android_rounded),
                  ),
                ],
                selected: <ThemeMode>{settings.themeMode},
                onSelectionChanged: (selection) {
                  settings.setThemeMode(selection.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(text: tr('\u0627\u0644\u0644\u063a\u0629', 'Langue')),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: sihhaGlassCardDecoration(context: context),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'ar',
                    label: Text('\u0627\u0644\u0639\u0631\u0628\u064a\u0629'),
                    icon: Icon(Icons.translate_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'fr',
                    label: Text('Francais'),
                    icon: Icon(Icons.translate_rounded),
                  ),
                ],
                selected: <String>{settings.locale.languageCode},
                onSelectionChanged: (selection) {
                  final code = selection.first;
                  settings.setLocale(Locale(code));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
