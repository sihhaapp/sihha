import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/triage_assessment.dart';
import '../providers/app_settings_provider.dart';
import '../services/triage_service.dart';

Future<TriageAssessmentResult?> showSmartTriageDialog({
  required BuildContext context,
}) async {
  final settings = context.read<AppSettingsProvider>();
  final tr = settings.tr;
  TriageConcern concern = TriageConcern.general;
  final answers = <String, bool>{};
  TriageAssessmentResult? result;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isArabic = settings.isArabic;
          final questions = TriageService.questionsForConcern(concern);

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('الفرز الطبي الذكي', 'Triage medical intelligent'),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'أجب على الأسئلة التالية لتحديد درجة الخطورة واقتراح الطبيب الأنسب.',
                      'Repondez aux questions pour estimer le niveau de risque et suggerer le bon medecin.',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TriageConcern>(
                    initialValue: concern,
                    decoration: InputDecoration(
                      labelText: tr('نوع الأعراض الأساسية', 'Type de symptomes principaux'),
                    ),
                    items: TriageConcern.values
                        .map(
                          (item) => DropdownMenuItem<TriageConcern>(
                            value: item,
                            child: Text(_concernLabel(item, isArabic: isArabic)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        concern = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ...questions.map((question) {
                    final value = answers[question.id] ?? false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          value: value,
                          onChanged: (next) {
                            setSheetState(() {
                              answers[question.id] = next;
                            });
                          },
                          title: Text(
                            isArabic ? question.textAr : question.textFr,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _answerLabel(next: value, tr: tr),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(tr('إلغاء', 'Annuler')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            result = TriageService.evaluate(
                              concern: concern,
                              answers: answers,
                            );
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: Text(tr('تحليل الحالة', 'Analyser')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}

String _concernLabel(TriageConcern concern, {required bool isArabic}) {
  switch (concern) {
    case TriageConcern.respiratoryFever:
      return isArabic ? 'حمّى / تنفس / صدر' : 'Fievre / respiration / thorax';
    case TriageConcern.digestivePain:
      return isArabic ? 'ألم بطني / هضمي' : 'Douleur abdominale / digestive';
    case TriageConcern.womenHealth:
      return isArabic ? 'صحة النساء / الحمل' : 'Sante feminine / grossesse';
    case TriageConcern.childHealth:
      return isArabic ? 'أعراض طفل' : 'Symptomes pediatriques';
    case TriageConcern.injury:
      return isArabic ? 'إصابة / حادث' : 'Blessure / accident';
    case TriageConcern.general:
      return isArabic ? 'أعراض عامة' : 'Symptomes generaux';
  }
}

String _answerLabel({
  required bool next,
  required String Function(String, String) tr,
}) {
  return next ? tr('الإجابة: نعم', 'Reponse: Oui') : tr('الإجابة: لا', 'Reponse: Non');
}
