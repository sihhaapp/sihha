enum TriageConcern {
  general,
  respiratoryFever,
  digestivePain,
  womenHealth,
  childHealth,
  injury,
}

enum TriageRiskLevel {
  low,
  medium,
  high,
}

enum TriageRecommendation {
  generalDoctor,
  pediatrician,
  gynecology,
  emergency,
}

class TriageQuestion {
  const TriageQuestion({
    required this.id,
    required this.textAr,
    required this.textFr,
    this.concern,
    this.emergencyWeight = 0,
    this.mediumWeight = 0,
    this.suggestPediatrics = false,
  });

  final String id;
  final String textAr;
  final String textFr;
  final TriageConcern? concern;
  final int emergencyWeight;
  final int mediumWeight;
  final bool suggestPediatrics;
}

class TriageAssessmentResult {
  const TriageAssessmentResult({
    required this.concern,
    required this.riskLevel,
    required this.recommendation,
    required this.summaryAr,
    required this.summaryFr,
  });

  final TriageConcern concern;
  final TriageRiskLevel riskLevel;
  final TriageRecommendation recommendation;
  final String summaryAr;
  final String summaryFr;

  String summary({required bool isArabic}) => isArabic ? summaryAr : summaryFr;
}
