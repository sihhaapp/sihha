import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/chad_states.dart';
import '../models/app_user.dart';
import '../models/consultation_request.dart';
import '../providers/app_settings_provider.dart';

class ConsultationRequestInput {
  const ConsultationRequestInput({
    required this.subjectType,
    required this.subjectName,
    required this.ageYears,
    required this.gender,
    required this.weightKg,
    required this.stateCode,
    required this.spokenLanguage,
    required this.symptoms,
  });

  final RequestSubjectType subjectType;
  final String subjectName;
  final int ageYears;
  final RequestGender gender;
  final double weightKg;
  final String stateCode;
  final SpokenLanguage spokenLanguage;
  final String symptoms;
}

Future<ConsultationRequestInput?> showConsultationRequestDialog({
  required BuildContext context,
  required AppUser patient,
  required AppUser doctor,
}) async {
  final settings = context.read<AppSettingsProvider>();
  final tr = settings.tr;

  final otherNameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final symptomsController = TextEditingController();

  RequestSubjectType subjectType = RequestSubjectType.self;
  RequestGender gender = RequestGender.male;
  SpokenLanguage spokenLanguage = SpokenLanguage.ar;
  String stateCode = kChadStates.first.code;

  ConsultationRequestInput? result;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isArabic = settings.isArabic;
          final selectedState = kChadStates.firstWhere(
            (s) => s.code == stateCode,
            orElse: () => kChadStates.first,
          );
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('طلب استشارة جديدة', 'Nouvelle demande de consultation'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'الدكتور المستهدف: ${doctor.name}',
                      'Medecin cible: ${doctor.name}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('المريض هو', 'Le patient est'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<RequestSubjectType>(
                    segments: <ButtonSegment<RequestSubjectType>>[
                      ButtonSegment<RequestSubjectType>(
                        value: RequestSubjectType.self,
                        label: Text(tr('أنا', 'Moi')),
                        icon: const Icon(Icons.person_rounded),
                      ),
                      ButtonSegment<RequestSubjectType>(
                        value: RequestSubjectType.other,
                        label: Text(tr('شخص آخر', 'Autre personne')),
                        icon: const Icon(Icons.group_rounded),
                      ),
                    ],
                    selected: <RequestSubjectType>{subjectType},
                    onSelectionChanged: (selection) {
                      setSheetState(() => subjectType = selection.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: otherNameController,
                    enabled: subjectType == RequestSubjectType.other,
                    decoration: InputDecoration(
                      labelText: tr('اسم المريض', 'Nom du patient'),
                      hintText: subjectType == RequestSubjectType.self
                          ? patient.name
                          : tr('أدخل اسم الشخص', 'Entrez le nom'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr('العمر', 'Age'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<RequestGender>(
                          initialValue: gender,
                          decoration: InputDecoration(
                            labelText: tr('الجنس', 'Sexe'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: RequestGender.male,
                              child: Text(tr('ذكر', 'Homme')),
                            ),
                            DropdownMenuItem(
                              value: RequestGender.female,
                              child: Text(tr('أنثى', 'Femme')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => gender = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('الوزن (كغ)', 'Poids (kg)'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: stateCode,
                    decoration: InputDecoration(
                      labelText: tr('الولاية', 'Province'),
                    ),
                    items: kChadStates
                        .map(
                          (state) => DropdownMenuItem<String>(
                            value: state.code,
                            child: Text(isArabic ? state.nameAr : state.nameFr),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => stateCode = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<SpokenLanguage>(
                    initialValue: spokenLanguage,
                    decoration: InputDecoration(
                      labelText: tr('اللغة التي يتحدث بها', 'Langue parlee'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: SpokenLanguage.ar,
                        child: Text(tr('عربي', 'Arabe')),
                      ),
                      DropdownMenuItem(
                        value: SpokenLanguage.fr,
                        child: Text(tr('فرنسي', 'Francais')),
                      ),
                      DropdownMenuItem(
                        value: SpokenLanguage.bilingual,
                        child: Text(tr('مزدوج', 'Bilingue')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => spokenLanguage = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: symptomsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: tr('الأعراض الحالية', 'Symptomes actuels'),
                      hintText: tr(
                        'اكتب الأعراض التي يشعر بها المريض',
                        'Ecrivez les symptomes ressentis',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final resolvedSubjectName = subjectType == RequestSubjectType.self
                            ? patient.name.trim()
                            : otherNameController.text.trim();
                        final age = int.tryParse(ageController.text.trim());
                        final weight = double.tryParse(weightController.text.trim());
                        final symptoms = symptomsController.text.trim();

                        String? error;
                        if (resolvedSubjectName.length < 2) {
                          error = tr(
                            'يرجى إدخال اسم صحيح.',
                            'Veuillez saisir un nom valide.',
                          );
                        } else if (age == null || age < 0 || age > 120) {
                          error = tr(
                            'العمر يجب أن يكون بين 0 و 120.',
                            'L\'age doit etre entre 0 et 120.',
                          );
                        } else if (weight == null || weight < 1 || weight > 400) {
                          error = tr(
                            'الوزن يجب أن يكون بين 1 و 400.',
                            'Le poids doit etre entre 1 et 400.',
                          );
                        } else if (symptoms.length < 5) {
                          error = tr(
                            'اكتب الأعراض بشكل أوضح (5 أحرف على الأقل).',
                            'Decrivez mieux les symptomes (au moins 5 caracteres).',
                          );
                        }

                        if (error != null) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }

                        result = ConsultationRequestInput(
                          subjectType: subjectType,
                          subjectName: resolvedSubjectName,
                          ageYears: age!,
                          gender: gender,
                          weightKg: weight!,
                          stateCode: selectedState.code,
                          spokenLanguage: spokenLanguage,
                          symptoms: symptoms,
                        );
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(tr('إرسال الطلب', 'Envoyer la demande')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  // ملاحظة: لا نَتخلّص من الـ controllers هنا لتجنب استثناءات التركيز المتأخرة
  // عند إغلاق الـ bottom sheet. مدة حياة الـ sheet قصيرة، والتسريب هنا ضئيل.
  return result;
}
