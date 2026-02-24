import 'package:flutter/material.dart';

class BlogCategory {
  const BlogCategory({
    required this.nameAr,
    required this.nameFr,
    required this.icon,
  });

  final String nameAr;
  final String nameFr;
  final IconData icon;
}

const List<BlogCategory> kBlogCategories = [
  BlogCategory(
    nameAr: 'التغذية',
    nameFr: 'Nutrition',
    icon: Icons.restaurant_menu_rounded,
  ),
  BlogCategory(
    nameAr: 'الصحة النفسية',
    nameFr: 'Sante mentale',
    icon: Icons.psychology_alt_rounded,
  ),
  BlogCategory(
    nameAr: 'النشاط البدني',
    nameFr: 'Activite physique',
    icon: Icons.fitness_center_rounded,
  ),
  BlogCategory(
    nameAr: 'الأمراض المزمنة',
    nameFr: 'Maladies chroniques',
    icon: Icons.monitor_heart_rounded,
  ),
  BlogCategory(
    nameAr: 'الأمومة والطفولة',
    nameFr: 'Maternite et enfance',
    icon: Icons.child_friendly_rounded,
  ),
  BlogCategory(
    nameAr: 'الوقاية',
    nameFr: 'Prevention',
    icon: Icons.health_and_safety_rounded,
  ),
  BlogCategory(nameAr: 'أخرى', nameFr: 'Autre', icon: Icons.article_rounded),
];

String normalizeBlogCategory(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    return kBlogCategories.first.nameAr;
  }

  for (final category in kBlogCategories) {
    if (category.nameAr == value || category.nameFr == value) {
      return category.nameAr;
    }
  }

  return value;
}

String localizeBlogCategory(String rawValue, {required bool isArabic}) {
  final normalized = normalizeBlogCategory(rawValue);
  for (final category in kBlogCategories) {
    if (category.nameAr == normalized) {
      return isArabic ? category.nameAr : category.nameFr;
    }
  }
  return normalized;
}

IconData blogCategoryIcon(String rawValue) {
  final normalized = normalizeBlogCategory(rawValue);
  for (final category in kBlogCategories) {
    if (category.nameAr == normalized) {
      return category.icon;
    }
  }
  return Icons.article_rounded;
}
