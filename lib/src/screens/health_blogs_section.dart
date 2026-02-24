import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/blog_categories.dart';
import '../models/app_user.dart';
import '../models/health_blog.dart';
import '../providers/app_settings_provider.dart';
import '../providers/blog_provider.dart';
import '../theme/sihha_theme.dart';

class HealthBlogsCatalogView extends StatefulWidget {
  const HealthBlogsCatalogView({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  State<HealthBlogsCatalogView> createState() => _HealthBlogsCatalogViewState();
}

class _HealthBlogsCatalogViewState extends State<HealthBlogsCatalogView> {
  static const String _allCategoriesKey = '__all__';
  String _selectedCategoryAr = _allCategoriesKey;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedFilterCategory = _selectedCategoryAr == _allCategoriesKey
        ? null
        : _selectedCategoryAr;

    return StreamBuilder<List<HealthBlog>>(
      stream: context.read<BlogProvider>().blogsStream(),
      builder: (context, snapshot) {
        final allBlogs = snapshot.data ?? const <HealthBlog>[];
        final blogs = selectedFilterCategory == null
            ? allBlogs
            : allBlogs
                  .where(
                    (blog) =>
                        normalizeBlogCategory(blog.category) ==
                        selectedFilterCategory,
                  )
                  .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          children: [
            if (widget.showHeader)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? SihhaPalette.nightCard.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.26)
                          : const Color(0x10000000),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('مدونات صحية', 'Blogs sante'),
                      style: GoogleFonts.tajawal(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        'مقالات موثوقة ومصنفة من أطباء المنصة.',
                        'Articles classes et fiables rediges par les medecins.',
                      ),
                      style: GoogleFonts.tajawal(
                        color: isDark
                            ? SihhaPalette.textMutedOnDark
                            : SihhaPalette.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.showHeader) const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? SihhaPalette.nightCard.withValues(alpha: 0.94)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.22)
                        : const Color(0x0D000000),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategoryAr,
                decoration: InputDecoration(
                  labelText: tr('تصفية حسب التصنيف', 'Filtrer par categorie'),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: _allCategoriesKey,
                    child: Text(tr('كل التصنيفات', 'Toutes les categories')),
                  ),
                  ...kBlogCategories.map(
                    (category) => DropdownMenuItem<String>(
                      value: category.nameAr,
                      child: Text(
                        isArabic ? category.nameAr : category.nameFr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _selectedCategoryAr = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _BlogsStatusCard(
                message: tr(
                  'تعذر تحميل المقالات الصحية حالياً.',
                  'Impossible de charger les articles de sante.',
                ),
              )
            else if (blogs.isEmpty)
              _BlogsStatusCard(
                message: selectedFilterCategory == null
                    ? tr(
                        'لا توجد مقالات منشورة حتى الآن.',
                        'Aucun article publie pour le moment.',
                      )
                    : tr(
                        'لا توجد مقالات ضمن هذا التصنيف.',
                        'Aucun article dans cette categorie.',
                      ),
              )
            else
              ...blogs.map((blog) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BlogCard(blog: blog),
                );
              }),
          ],
        );
      },
    );
  }
}

class DoctorHealthBlogsSection extends StatelessWidget {
  const DoctorHealthBlogsSection({
    super.key,
    required this.currentUser,
    this.onPublished,
  });

  final AppUser currentUser;
  final VoidCallback? onPublished;

  @override
  Widget build(BuildContext context) {
    final tr = context.watch<AppSettingsProvider>().tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? SihhaPalette.nightCard.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.24)
                        : const Color(0x10000000),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: SihhaPalette.primary,
                unselectedLabelColor: isDark
                    ? SihhaPalette.textMutedOnDark
                    : SihhaPalette.textMuted,
                labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
                indicatorColor: SihhaPalette.primary,
                tabs: [
                  Tab(text: tr('تصفح المقالات', 'Parcourir')),
                  Tab(text: tr('إنشاء مقالة', 'Nouvel article')),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const HealthBlogsCatalogView(showHeader: false),
                DoctorBlogComposerView(
                  currentUser: currentUser,
                  onPublished: onPublished,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorBlogComposerView extends StatefulWidget {
  const DoctorBlogComposerView({
    super.key,
    required this.currentUser,
    this.onPublished,
  });

  final AppUser currentUser;
  final VoidCallback? onPublished;

  @override
  State<DoctorBlogComposerView> createState() => _DoctorBlogComposerViewState();
}

class _DoctorBlogComposerViewState extends State<DoctorBlogComposerView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedCategoryAr = kBlogCategories.first.nameAr;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final provider = context.read<BlogProvider>();
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;

    final success = await provider.publishBlog(
      author: widget.currentUser,
      title: _titleController.text,
      content: _contentController.text,
      category: _selectedCategoryAr,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _titleController.clear();
      _contentController.clear();
      setState(() => _selectedCategoryAr = kBlogCategories.first.nameAr);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr('تم نشر المقال بنجاح.', 'Article publie avec succes.'),
            ),
          ),
        );
      widget.onPublished?.call();
      return;
    }

    final error = provider.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      provider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPublishing = context.watch<BlogProvider>().isPublishing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? SihhaPalette.nightCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.24)
                    : const Color(0x10000000),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('إنشاء مقال صحي جديد', 'Publier un nouvel article de sante'),
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr('عنوان المقال', 'Titre de l\'article'),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryAr,
                decoration: InputDecoration(
                  labelText: tr('التصنيف', 'Categorie'),
                  prefixIcon: const Icon(Icons.category_rounded),
                ),
                items: kBlogCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.nameAr,
                        child: Text(
                          isArabic ? category.nameAr : category.nameFr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isPublishing
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedCategoryAr = value);
                      },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                minLines: 8,
                maxLines: 14,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: tr('محتوى المقال', 'Contenu'),
                  hintText: tr(
                    'اكتب مقالة طبية واضحة مع نصائح عملية للمرض.',
                    'Redigez un article clair avec des conseils pratiques.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isPublishing ? null : _publish,
                  icon: isPublishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(
                    isPublishing
                        ? tr('جاري النشر...', 'Publication...')
                        : tr('نشر المقال', 'Publier'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.blog});

  final HealthBlog blog;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryTitle = localizeBlogCategory(
      blog.category,
      isArabic: isArabic,
    );
    final excerpt = _buildExcerpt(blog.content);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? SihhaPalette.nightCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0x10000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2B2A)
                      : const Color(0xFFE9F7F4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      blogCategoryIcon(blog.category),
                      size: 16,
                      color: isDark
                          ? const Color(0xFF4EDAC7)
                          : const Color(0xFF0E9F8A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      categoryTitle,
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF4EDAC7)
                            : const Color(0xFF0E9F8A),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(blog.publishedAt),
                style: GoogleFonts.tajawal(
                  color: isDark
                      ? SihhaPalette.textMutedOnDark
                      : const Color(0xFF6A7B90),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            blog.title,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            excerpt,
            style: GoogleFonts.tajawal(
              height: 1.45,
              color: isDark
                  ? SihhaPalette.textOnDark.withValues(alpha: 0.90)
                  : const Color(0xFF2E4158),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 17,
                color: isDark
                    ? SihhaPalette.textMutedOnDark
                    : const Color(0xFF6A7B90),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  blog.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    color: isDark
                        ? SihhaPalette.textMutedOnDark
                        : const Color(0xFF6A7B90),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlogsStatusCard extends StatelessWidget {
  const _BlogsStatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? SihhaPalette.nightCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.24)
                : const Color(0x10000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year - $hour:$minute';
}

String _buildExcerpt(String content) {
  final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 220) {
    return normalized;
  }
  return '${normalized.substring(0, 220)}...';
}
