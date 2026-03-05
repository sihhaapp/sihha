import '../models/triage_assessment.dart';

class TriageService {
  static const List<TriageQuestion> _allQuestions = <TriageQuestion>[
    TriageQuestion(
      id: 'hard_breathing',
      textAr: 'هل يوجد ضيق شديد في التنفس الآن؟',
      textFr: 'Existe-t-il une difficulte respiratoire severe maintenant ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'severe_bleeding',
      textAr: 'هل يوجد نزيف شديد مستمر؟',
      textFr: 'Y a-t-il un saignement severe continu ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'confusion_or_faint',
      textAr: 'هل يوجد إغماء أو تشوش شديد في الوعي؟',
      textFr: 'Y a-t-il perte de connaissance ou confusion severe ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'fever_over_39',
      concern: TriageConcern.respiratoryFever,
      textAr: 'هل الحرارة أعلى من 39 لأكثر من 3 أيام؟',
      textFr: 'La fievre depasse-t-elle 39 depuis plus de 3 jours ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'chest_pain',
      concern: TriageConcern.respiratoryFever,
      textAr: 'هل يوجد ألم شديد في الصدر؟',
      textFr: 'Y a-t-il une douleur thoracique severe ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'cough_blood',
      concern: TriageConcern.respiratoryFever,
      textAr: 'هل يوجد سعال مع دم؟',
      textFr: 'Y a-t-il une toux avec du sang ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'severe_abdominal_pain',
      concern: TriageConcern.digestivePain,
      textAr: 'هل يوجد ألم بطني شديد مستمر؟',
      textFr: 'Y a-t-il une douleur abdominale severe persistante ?',
      mediumWeight: 2,
    ),
    TriageQuestion(
      id: 'repeated_vomiting',
      concern: TriageConcern.digestivePain,
      textAr: 'هل يوجد قيء متكرر يمنع الأكل أو الشرب؟',
      textFr: 'Y a-t-il des vomissements repetes empechant de manger/boire ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'blood_in_stool_or_vomit',
      concern: TriageConcern.digestivePain,
      textAr: 'هل يوجد دم في القيء أو البراز؟',
      textFr: 'Y a-t-il du sang dans les vomissements ou les selles ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'pregnant_now',
      concern: TriageConcern.womenHealth,
      textAr: 'هل الحالة مرتبطة بحمل حالي؟',
      textFr: 'Le cas est-il lie a une grossesse en cours ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'pregnancy_bleeding',
      concern: TriageConcern.womenHealth,
      textAr: 'هل يوجد نزيف أثناء الحمل؟',
      textFr: 'Y a-t-il un saignement pendant la grossesse ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'severe_pelvic_pain',
      concern: TriageConcern.womenHealth,
      textAr: 'هل يوجد ألم شديد بالحوض أو أسفل البطن؟',
      textFr: 'Y a-t-il une douleur severe pelvienne ou bas-ventre ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'child_under_15',
      concern: TriageConcern.childHealth,
      textAr: 'هل المريض طفل أقل من 15 سنة؟',
      textFr: 'Le patient est-il un enfant de moins de 15 ans ?',
      suggestPediatrics: true,
    ),
    TriageQuestion(
      id: 'child_fever_high',
      concern: TriageConcern.childHealth,
      textAr: 'هل لدى الطفل حرارة مرتفعة أو خمول واضح؟',
      textFr: 'L enfant a-t-il forte fievre ou grande lethargie ?',
      mediumWeight: 1,
      suggestPediatrics: true,
    ),
    TriageQuestion(
      id: 'child_convulsion',
      concern: TriageConcern.childHealth,
      textAr: 'هل حدثت تشنجات للطفل؟',
      textFr: 'L enfant a-t-il presente des convulsions ?',
      emergencyWeight: 2,
      suggestPediatrics: true,
    ),
    TriageQuestion(
      id: 'head_trauma',
      concern: TriageConcern.injury,
      textAr: 'هل يوجد إصابة في الرأس مع فقدان وعي أو دوخة شديدة؟',
      textFr: 'Y a-t-il un traumatisme cranien avec perte de conscience ou vertige severe ?',
      emergencyWeight: 2,
    ),
    TriageQuestion(
      id: 'fracture_signs',
      concern: TriageConcern.injury,
      textAr: 'هل توجد علامات كسر أو تورم شديد؟',
      textFr: 'Y a-t-il des signes de fracture ou gonflement important ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'deep_wound',
      concern: TriageConcern.injury,
      textAr: 'هل يوجد جرح عميق يحتاج خياطة؟',
      textFr: 'Y a-t-il une plaie profonde necessitant des points de suture ?',
      mediumWeight: 1,
    ),
    TriageQuestion(
      id: 'symptoms_over_week',
      concern: TriageConcern.general,
      textAr: 'هل استمرت الأعراض أكثر من 7 أيام؟',
      textFr: 'Les symptomes durent-ils depuis plus de 7 jours ?',
      mediumWeight: 1,
    ),
  ];

  static List<TriageQuestion> questionsForConcern(TriageConcern concern) {
    return _allQuestions
        .where((q) => q.concern == null || q.concern == concern)
        .toList(growable: false);
  }

  static TriageAssessmentResult evaluate({
    required TriageConcern concern,
    required Map<String, bool> answers,
  }) {
    final questions = questionsForConcern(concern);
    var emergencyScore = 0;
    var mediumScore = 0;
    var suggestPediatrics = concern == TriageConcern.childHealth;

    for (final question in questions) {
      if (answers[question.id] != true) {
        continue;
      }
      emergencyScore += question.emergencyWeight;
      mediumScore += question.mediumWeight;
      if (question.suggestPediatrics) {
        suggestPediatrics = true;
      }
    }

    final risk = emergencyScore > 0
        ? TriageRiskLevel.high
        : (mediumScore >= 2 ? TriageRiskLevel.medium : TriageRiskLevel.low);

    final recommendation = _resolveRecommendation(
      concern: concern,
      risk: risk,
      suggestPediatrics: suggestPediatrics,
    );

    final summary = _buildSummary(risk: risk, recommendation: recommendation);

    return TriageAssessmentResult(
      concern: concern,
      riskLevel: risk,
      recommendation: recommendation,
      summaryAr: summary.$1,
      summaryFr: summary.$2,
    );
  }

  static TriageRecommendation _resolveRecommendation({
    required TriageConcern concern,
    required TriageRiskLevel risk,
    required bool suggestPediatrics,
  }) {
    if (risk == TriageRiskLevel.high) {
      return TriageRecommendation.emergency;
    }
    if (concern == TriageConcern.womenHealth) {
      return TriageRecommendation.gynecology;
    }
    if (suggestPediatrics) {
      return TriageRecommendation.pediatrician;
    }
    return TriageRecommendation.generalDoctor;
  }

  static (String, String) _buildSummary({
    required TriageRiskLevel risk,
    required TriageRecommendation recommendation,
  }) {
    if (risk == TriageRiskLevel.high) {
      return (
        'تم رصد مؤشرات خطورة مرتفعة. التوجه للطوارئ أولًا هو الخيار الأكثر أمانًا.',
        'Des signes de gravite elevee ont ete detectes. Les urgences sont recommandees en priorite.',
      );
    }
    if (risk == TriageRiskLevel.medium) {
      final rec = recommendation == TriageRecommendation.pediatrician
          ? 'طبيب أطفال'
          : recommendation == TriageRecommendation.gynecology
              ? 'طبيب نساء'
              : 'طبيب عام';
      final recFr = recommendation == TriageRecommendation.pediatrician
          ? 'Pediatre'
          : recommendation == TriageRecommendation.gynecology
              ? 'Gynecologue'
              : 'Medecin generaliste';
      return (
        'الحالة متوسطة الخطورة. يُنصح بإتمام الاستشارة اليوم مع $rec.',
        'Le niveau de risque est modere. Il est conseille de consulter aujourd hui avec $recFr.',
      );
    }
    final rec = recommendation == TriageRecommendation.pediatrician
        ? 'طبيب أطفال'
        : recommendation == TriageRecommendation.gynecology
            ? 'طبيب نساء'
            : 'طبيب عام';
    final recFr = recommendation == TriageRecommendation.pediatrician
        ? 'Pediatre'
        : recommendation == TriageRecommendation.gynecology
            ? 'Gynecologue'
            : 'Medecin generaliste';
    return (
      'مستوى الخطورة منخفض حاليًا. يمكنك بدء استشارة اعتيادية مع $rec.',
      'Le niveau de risque est faible pour le moment. Vous pouvez lancer une consultation standard avec $recFr.',
    );
  }
}
