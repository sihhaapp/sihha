import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../constants/chad_states.dart';
import '../models/app_user.dart';
import '../models/consultation_request.dart';
import '../providers/app_settings_provider.dart';
import '../providers/audio_provider.dart';
import '../services/voice_service.dart';

class ConsultationRequestInput {
  const ConsultationRequestInput({
    required this.subjectType,
    required this.subjectName,
    required this.ageYears,
    required this.gender,
    required this.pregnancyStatus,
    required this.weightKg,
    required this.stateCode,
    required this.spokenLanguage,
    required this.symptoms,
    required this.symptomsVoiceUrl,
  });
  final RequestSubjectType subjectType;
  final String subjectName;
  final int ageYears;
  final RequestGender gender;
  final RequestPregnancyStatus pregnancyStatus;
  final double weightKg;
  final String stateCode;
  final SpokenLanguage spokenLanguage;
  final String symptoms;
  final String symptomsVoiceUrl;
}

Future<ConsultationRequestInput?> showConsultationRequestDialog({
  required BuildContext context,
  required AppUser patient,
  required AppUser doctor,
}) async {
  final settings = context.read<AppSettingsProvider>();
  final tr = settings.tr;
  final audio = context.read<AudioProvider>();
  final voice = VoiceService();
  final player = AudioPlayer();
  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  RequestSubjectType st = RequestSubjectType.self;
  RequestGender g = RequestGender.male;
  RequestPregnancyStatus p = RequestPregnancyStatus.notApplicable;
  SpokenLanguage lang = SpokenLanguage.ar;
  String state = kChadStates.first.code;
  String? selected;
  final picked = <String>[];
  bool rec = false;
  bool up = false;
  String voiceUrl = '';
  String localVoicePath = '';
  int voiceSec = 0;
  DateTime? startedAt;
  ConsultationRequestInput? out;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheet) {
          final isAr = settings.isArabic;
          void snack(String m) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(m)));

          Future<void> toggleRec() async {
            if (up) {
              return;
            }
            if (!rec) {
              await player.stop();
              await voice.startRecording();
              if (!context.mounted) {
                return;
              }
              setSheet(() {
                rec = true;
                startedAt = DateTime.now();
              });
              return;
            }
            setSheet(() {
              rec = false;
              up = true;
            });
            final path = await voice.stopRecording();
            if (path != null && path.isNotEmpty) {
              final url = await audio.uploadConsultationSymptomsAudio(
                file: File(path),
              );
              final sec = DateTime.now()
                  .difference(startedAt ?? DateTime.now())
                  .inSeconds
                  .clamp(1, 300);
              if (context.mounted) {
                setSheet(() {
                  localVoicePath = path;
                  voiceUrl = (url ?? '').trim();
                  voiceSec = sec;
                });
              }
            }
            if (context.mounted) {
              setSheet(() => up = false);
            }
          }

          Future<void> togglePlay() async {
            final hasLocal = localVoicePath.trim().isNotEmpty;
            final hasRemote = voiceUrl.trim().isNotEmpty;
            if (!hasLocal && !hasRemote) {
              return;
            }
            if (player.playing) {
              await player.pause();
              return;
            }

            try {
              if (hasLocal) {
                await player.setFilePath(localVoicePath);
              } else {
                await player.setUrl(voiceUrl);
              }
              await player.play();
            } catch (_) {
              if (hasLocal && hasRemote) {
                try {
                  await player.setUrl(voiceUrl);
                  await player.play();
                  return;
                } catch (_) {}
              }
              if (context.mounted) {
                snack(
                  tr(
                    'تعذر تشغيل التسجيل الصوتي.',
                    'Impossible de lire le vocal.',
                  ),
                );
              }
            }
          }

          final selectedState = kChadStates.firstWhere(
            (s) => s.code == state,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'الدكتور المستهدف: ${doctor.name}',
                      'Medecin cible: ${doctor.name}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<RequestSubjectType>(
                    segments: [
                      ButtonSegment(
                        value: RequestSubjectType.self,
                        label: Text(tr('أنا', 'Moi')),
                      ),
                      ButtonSegment(
                        value: RequestSubjectType.other,
                        label: Text(tr('شخص آخر', 'Autre')),
                      ),
                    ],
                    selected: {st},
                    onSelectionChanged: (v) => setSheet(() => st = v.first),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    enabled: st == RequestSubjectType.other,
                    decoration: InputDecoration(
                      labelText: tr('اسم المريض', 'Nom du patient'),
                      hintText: st == RequestSubjectType.self
                          ? patient.name
                          : tr('أدخل اسم الشخص', 'Entrez le nom'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr('العمر', 'Age'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<RequestGender>(
                          initialValue: g,
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
                          onChanged: (v) => setSheet(() {
                            g = v ?? g;
                            if (g == RequestGender.male) {
                              p = RequestPregnancyStatus.notApplicable;
                            }
                            if (g == RequestGender.female &&
                                p == RequestPregnancyStatus.notApplicable) {
                              p = RequestPregnancyStatus.notSure;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (g == RequestGender.female) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RequestPregnancyStatus>(
                      initialValue: p == RequestPregnancyStatus.notApplicable
                          ? RequestPregnancyStatus.notSure
                          : p,
                      decoration: InputDecoration(
                        labelText: tr('حالة الحمل', 'Statut de grossesse'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: RequestPregnancyStatus.pregnant,
                          child: Text(
                            _pregnancyStatusLabel(
                              RequestPregnancyStatus.pregnant,
                              isArabic: isAr,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: RequestPregnancyStatus.notPregnant,
                          child: Text(
                            _pregnancyStatusLabel(
                              RequestPregnancyStatus.notPregnant,
                              isArabic: isAr,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: RequestPregnancyStatus.notSure,
                          child: Text(
                            _pregnancyStatusLabel(
                              RequestPregnancyStatus.notSure,
                              isArabic: isAr,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheet(() => p = v ?? p),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: tr('الوزن (كغ)', 'Poids (kg)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: state,
                    decoration: InputDecoration(
                      labelText: tr('الولاية', 'Province'),
                    ),
                    items: kChadStates
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.code,
                            child: Text(isAr ? s.nameAr : s.nameFr),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => state = v ?? state),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SpokenLanguage>(
                    initialValue: lang,
                    decoration: InputDecoration(
                      labelText: tr('اللغة', 'Langue'),
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
                    onChanged: (v) => setSheet(() => lang = v ?? lang),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: InputDecoration(
                      labelText: tr('الأعراض', 'Symptomes'),
                    ),
                    items: _symptoms
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.code,
                            child: Text(isAr ? s.ar : s.fr),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => selected = v),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: selected == null
                        ? null
                        : () => setSheet(() {
                            if (!picked.contains(selected!)) {
                              picked.add(selected!);
                            }
                          }),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('إضافة العرض', 'Ajouter le symptome')),
                  ),
                  if (picked.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: picked
                          .map(
                            (c) => InputChip(
                              label: Text(_symptomText(c, isArabic: isAr)),
                              onDeleted: () => setSheet(() => picked.remove(c)),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: tr(
                        'تفاصيل إضافية (اختياري)',
                        'Details supplementaires (optionnel)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: up ? null : toggleRec,
                          icon: Icon(rec ? Icons.stop_circle : Icons.mic),
                          label: Text(
                            rec
                                ? tr('إيقاف ورفع', 'Arreter et televerser')
                                : tr('حفظ', 'Enregistrer'),
                          ),
                        ),
                      ),
                      if (up) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  if (voiceUrl.isNotEmpty || localVoicePath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, snap) {
                            final playing =
                                snap.data?.playing == true &&
                                snap.data?.processingState !=
                                    ProcessingState.completed;
                            return OutlinedButton.icon(
                              onPressed: togglePlay,
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                              ),
                              label: Text(
                                playing
                                    ? tr('إيقاف الاستماع', 'Pause')
                                    : tr('سماع التسجيل', 'Ecouter'),
                              ),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await player.stop();
                            setSheet(() {
                              localVoicePath = '';
                              voiceUrl = '';
                              voiceSec = 0;
                            });
                            await toggleRec();
                          },
                          icon: const Icon(Icons.fiber_manual_record),
                          label: Text(tr('إعادة التسجيل', 'Reenregistrer')),
                        ),
                        IconButton(
                          onPressed: () async {
                            await player.stop();
                            setSheet(() {
                              localVoicePath = '';
                              voiceUrl = '';
                              voiceSec = 0;
                            });
                          },
                          tooltip: tr('حذف', 'Supprimer'),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    Text(
                      tr(
                        'مدة التسجيل: ${voiceSec}s',
                        'Duree du vocal: ${voiceSec}s',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: up
                          ? null
                          : () {
                              final resolvedName = st == RequestSubjectType.self
                                  ? patient.name.trim()
                                  : nameCtrl.text.trim();
                              final age = int.tryParse(ageCtrl.text.trim());
                              final w = double.tryParse(
                                weightCtrl.text.trim().replaceAll(',', '.'),
                              );
                              final note = noteCtrl.text.trim();
                              final hasVoice = voiceUrl.trim().isNotEmpty;

                              if (resolvedName.length < 2) {
                                return snack(
                                  tr(
                                    'يرجى إدخال اسم صحيح.',
                                    'Veuillez saisir un nom valide.',
                                  ),
                                );
                              }

                              if (age == null || age < 0 || age > 120) {
                                return snack(
                                  tr(
                                    'العمر يجب أن يكون بين 0 و 120.',
                                    'L age doit etre entre 0 et 120.',
                                  ),
                                );
                              }

                              if (w == null || w < 1 || w > 400) {
                                return snack(
                                  tr(
                                    'الوزن يجب أن يكون بين 1 و 400.',
                                    'Le poids doit etre entre 1 et 400.',
                                  ),
                                );
                              }

                              if (picked.isEmpty &&
                                  note.length < 5 &&
                                  !hasVoice) {
                                return snack(
                                  tr(
                                    'اختر عرضا واحدا على الأقل أو أضف تفاصيل/صوت.',
                                    'Choisissez au moins un symptome ou ajoutez details/vocal.',
                                  ),
                                );
                              }

                              final chosen = picked
                                  .map((c) => _symptomText(c, isArabic: isAr))
                                  .join(', ');
                              final parts = <String>[];

                              if (chosen.isNotEmpty) {
                                parts.add(
                                  tr(
                                    'الأعراض المختارة: $chosen',
                                    'Symptomes selectionnes: $chosen',
                                  ),
                                );
                              }

                              if (note.isNotEmpty) {
                                parts.add(
                                  tr(
                                    'تفاصيل إضافية: $note',
                                    'Details supplementaires: $note',
                                  ),
                                );
                              }

                              if (parts.isEmpty) {
                                parts.add(
                                  tr(
                                    'تم إرفاق رسالة صوتية بالأعراض.',
                                    'Message vocal des symptomes joint.',
                                  ),
                                );
                              }

                              out = ConsultationRequestInput(
                                subjectType: st,
                                subjectName: resolvedName,
                                ageYears: age,
                                gender: g,
                                pregnancyStatus: g == RequestGender.male
                                    ? RequestPregnancyStatus.notApplicable
                                    : p,
                                weightKg: w,
                                stateCode: selectedState.code,
                                spokenLanguage: lang,
                                symptoms: parts.join('\n'),
                                symptomsVoiceUrl: voiceUrl.trim(),
                              );
                              Navigator.of(sheetCtx).pop();
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
      ),
    );
  } finally {
    try {
      await voice.stopRecording();
    } catch (_) {}
    await player.dispose();
    await voice.dispose();
  }
  return out;
}

String _pregnancyStatusLabel(
  RequestPregnancyStatus s, {
  required bool isArabic,
}) {
  switch (s) {
    case RequestPregnancyStatus.pregnant:
      return isArabic ? 'حامل' : 'Enceinte';
    case RequestPregnancyStatus.notPregnant:
      return isArabic ? 'غير حامل' : 'Non enceinte';
    case RequestPregnancyStatus.notSure:
      return isArabic ? 'غير متأكدة' : 'Pas sure';
    case RequestPregnancyStatus.notApplicable:
      return isArabic ? 'غير منطبق' : 'Non applicable';
  }
}

String _symptomText(String code, {required bool isArabic}) {
  for (final s in _symptoms) {
    if (s.code == code) return isArabic ? s.ar : s.fr;
  }
  return code;
}

class _S {
  const _S(this.code, this.ar, this.fr);
  final String code;
  final String ar;
  final String fr;
}

const _symptoms = <_S>[
  _S('cough', 'كحة / سعال', 'Toux'),
  _S('bleeding', 'نزيف', 'Saignement'),
  _S('headache', 'صداع', 'Maux de tete'),
  _S('toothache', 'وجع ضرس', 'Douleur dentaire'),
  _S('eye_pain', 'ألم في العين', 'Douleur oculaire'),
  _S('eye_redness', 'احمرار العين', 'Rougeur oculaire'),
  _S('abdominal_pain', 'ألم في البطن', 'Douleur abdominale'),
  _S('diarrhea', 'إسهال', 'Diarrhee'),
  _S('chest_pain', 'ألم في الصدر', 'Douleur thoracique'),
  _S('heartburn', 'حموضة المعدة', 'Brulure d estomac'),
  _S('vaginal_pain', 'ألم في المهبل', 'Douleur vaginale'),
  _S('vaginal_discharge', 'سيلان مهبلي', 'Pertes vaginales'),
  _S('fever', 'حمى', 'Fievre'),
  _S('sore_throat', 'ألم الحلق', 'Mal de gorge'),
  _S('runny_nose', 'سيلان الأنف', 'Nez qui coule'),
  _S('nasal_congestion', 'احتقان الأنف', 'Congestion nasale'),
  _S('sneezing', 'عطاس', 'Eternuement'),
  _S('chills', 'قشعريرة', 'Frissons'),
  _S('night_sweats', 'تعرق ليلي', 'Sueurs nocturnes'),
  _S('shortness_breath', 'ضيق التنفس', 'Difficulte respiratoire'),
  _S('wheezing', 'صفير الصدر', 'Sifflement thoracique'),
  _S('dizziness', 'دوخة', 'Vertiges'),
  _S('fainting', 'إغماء', 'Evanouissement'),
  _S('blurred_vision', 'تشوش الرؤية', 'Vision floue'),
  _S('ear_discharge', 'إفرازات الأذن', 'Ecoulement oreille'),
  _S('nausea', 'غثيان', 'Nausee'),
  _S('vomiting', 'قيء', 'Vomissements'),
  _S('constipation', 'إمساك', 'Constipation'),
  _S('bloating', 'انتفاخ', 'Ballonnements'),
  _S('loss_appetite', 'فقدان الشهية', 'Perte d appetit'),
  _S('blood_stool', 'دم في البراز', 'Sang dans les selles'),
  _S('urinary_pain', 'ألم عند التبول', 'Douleur urinaire'),
  _S('frequent_urine', 'كثرة التبول', 'Urines frequentes'),
  _S('urine_burning', 'حرقان البول', 'Brulure urinaire'),
  _S('blood_urine', 'دم في البول', 'Sang dans les urines'),
  _S('flank_pain', 'ألم الخاصرة', 'Douleur flanc'),
  _S('back_pain', 'ألم الظهر', 'Mal de dos'),
  _S('neck_pain', 'ألم الرقبة', 'Douleur du cou'),
  _S('joint_pain', 'ألم المفاصل', 'Douleurs articulaires'),
  _S('muscle_pain', 'ألم العضلات', 'Douleurs musculaires'),
  _S('leg_swelling', 'تورم الساق', 'Jambe enflee'),
  _S('hand_swelling', 'تورم اليد', 'Main enflee'),
  _S('skin_rash', 'طفح جلدي', 'Eruption cutanee'),
  _S('itching', 'حكة', 'Demangeaisons'),
  _S('skin_redness', 'احمرار الجلد', 'Rougeur cutanee'),
  _S('skin_wound', 'جرح جلدي', 'Plaie cutanee'),
  _S('skin_burn', 'حرق جلدي', 'Brulure cutanee'),
  _S('allergy', 'حساسية', 'Allergie'),
  _S('swollen_face', 'تورم الوجه', 'Visage enfle'),
  _S('difficulty_swallowing', 'صعوبة البلع', 'Difficulte a avaler'),
  _S('palpitations', 'خفقان', 'Palpitations'),
  _S('fatigue', 'إرهاق شديد', 'Fatigue intense'),
  _S('insomnia', 'أرق', 'Insomnie'),
  _S('anxiety', 'قلق', 'Anxiete'),
  _S('confusion', 'تشوش ذهني', 'Confusion mentale'),
  _S('memory_loss', 'ضعف الذاكرة', 'Perte de memoire'),
  _S('seizure', 'تشنجات', 'Convulsions'),
  _S('trauma', 'إصابة/حادث', 'Traumatisme'),
  _S('fracture', 'اشتباه كسر', 'Suspicion de fracture'),
  _S('ear_pain', 'ألم الأذن', 'Douleur oreille'),
  _S('mouth_ulcer', 'تقرحات الفم', 'Ulcere buccal'),
  _S('gum_swelling', 'تورم اللثة', 'Gencive enflee'),
  _S('breast_pain', 'ألم الثدي', 'Douleur mammaire'),
  _S('vaginal_bleeding', 'نزيف مهبلي', 'Saignement vaginal'),
  _S('pelvic_pain', 'ألم الحوض', 'Douleur pelvienne'),
  _S('genital_itching', 'حكة تناسلية', 'Demangeaison genitale'),
  _S('other', 'أعراض أخرى', 'Autres symptomes'),
];
