import 'package:flutter/material.dart';

class MedicalSpecialty {
  const MedicalSpecialty({
    required this.nameAr,
    required this.nameFr,
    required this.icon,
  });

  final String nameAr;
  final String nameFr;
  final IconData icon;
}

const List<MedicalSpecialty> kMedicalSpecialties = [
  MedicalSpecialty(
    nameAr: 'طب عام',
    nameFr: 'Medecine generale',
    icon: Icons.medical_services,
  ),
  MedicalSpecialty(
    nameAr: 'باطنية',
    nameFr: 'Medecine interne',
    icon: Icons.favorite,
  ),
  MedicalSpecialty(
    nameAr: 'أطفال',
    nameFr: 'Pediatrie',
    icon: Icons.child_care,
  ),
  MedicalSpecialty(
    nameAr: 'نساء وتوليد',
    nameFr: 'Gynecologie-obstetrique',
    icon: Icons.female,
  ),
  MedicalSpecialty(
    nameAr: 'أسنان',
    nameFr: 'Dentaire',
    icon: Icons.medical_services,
  ),
  MedicalSpecialty(
    nameAr: 'طبيب نفسي',
    nameFr: 'Psychiatrie',
    icon: Icons.psychology,
  ),
  MedicalSpecialty(
    nameAr: 'عيون',
    nameFr: 'Ophtalmologie',
    icon: Icons.remove_red_eye,
  ),
  MedicalSpecialty(nameAr: 'جلدية', nameFr: 'Dermatologie', icon: Icons.spa),
  MedicalSpecialty(
    nameAr: 'عظام',
    nameFr: 'Orthopedie',
    icon: Icons.accessibility_new,
  ),
  MedicalSpecialty(
    nameAr: 'أنف وأذن وحنجرة',
    nameFr: 'ORL',
    icon: Icons.hearing,
  ),
];

String normalizeMedicalSpecialty(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    return kMedicalSpecialties.first.nameAr;
  }

  if (value == 'طبيب عام') {
    return 'طب عام';
  }

  for (final specialty in kMedicalSpecialties) {
    if (specialty.nameAr == value || specialty.nameFr == value) {
      return specialty.nameAr;
    }
  }

  return value;
}

String localizeMedicalSpecialty(String rawValue, {required bool isArabic}) {
  final normalized = normalizeMedicalSpecialty(rawValue);
  for (final specialty in kMedicalSpecialties) {
    if (specialty.nameAr == normalized) {
      return isArabic ? specialty.nameAr : specialty.nameFr;
    }
  }
  return normalized;
}
