import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/blog_categories.dart';
import '../models/app_user.dart';
import '../models/blog_comment.dart';
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
    final feedVersion = context.select<BlogProvider, int>(
      (provider) => provider.feedVersion,
    );
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedFilterCategory = _selectedCategoryAr == _allCategoriesKey
        ? null
        : _selectedCategoryAr;

    return StreamBuilder<List<HealthBlog>>(
      key: ValueKey<int>(feedVersion),
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
                      tr(
                        '\u0645\u062f\u0648\u0646\u0627\u062a \u0635\u062d\u064a\u0629',
                        'Blogs sante',
                      ),
                      style: GoogleFonts.tajawal(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        '\u0645\u0642\u0627\u0644\u0627\u062a \u0645\u0648\u062b\u0648\u0642\u0629 \u0648\u0645\u0635\u0646\u0641\u0629 \u0645\u0646 \u0623\u0637\u0628\u0627\u0621 \u0627\u0644\u0645\u0646\u0635\u0629.',
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
                  labelText: tr(
                    '\u062a\u0635\u0641\u064a\u0629 \u062d\u0633\u0628 \u0627\u0644\u062a\u0635\u0646\u064a\u0641',
                    'Filtrer par categorie',
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: _allCategoriesKey,
                    child: Text(
                      tr(
                        '\u0643\u0644 \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a',
                        'Toutes les categories',
                      ),
                    ),
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
                  '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0642\u0627\u0644\u0627\u062a \u0627\u0644\u0635\u062d\u064a\u0629 \u062d\u0627\u0644\u064a\u0627\u064b.',
                  'Impossible de charger les articles de sante.',
                ),
              )
            else if (blogs.isEmpty)
              _BlogsStatusCard(
                message: selectedFilterCategory == null
                    ? tr(
                        '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0642\u0627\u0644\u0627\u062a \u0645\u0646\u0634\u0648\u0631\u0629 \u062d\u062a\u0649 \u0627\u0644\u0622\u0646.',
                        'Aucun article publie pour le moment.',
                      )
                    : tr(
                        '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0642\u0627\u0644\u0627\u062a \u0636\u0645\u0646 \u0647\u0630\u0627 \u0627\u0644\u062a\u0635\u0646\u064a\u0641.',
                        'Aucun article dans cette categorie.',
                      ),
              )
            else
              ...blogs.map(
                (blog) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BlogCard(blog: blog),
                ),
              ),
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
                  Tab(
                    text: tr(
                      '\u062a\u0635\u0641\u062d \u0627\u0644\u0645\u0642\u0627\u0644\u0627\u062a',
                      'Parcourir',
                    ),
                  ),
                  Tab(
                    text: tr(
                      '\u0625\u0646\u0634\u0627\u0621 \u0645\u0642\u0627\u0644\u0629',
                      'Nouvel article',
                    ),
                  ),
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

enum _BlogImageSlot {
  expressive1,
  expressive2,
  expressive3,
}

const String _reactionLike = 'like';
const String _reactionSupport = 'support';
const String _reactionThanks = 'thanks';

enum _SharePlatform {
  facebook,
  x,
  whatsapp,
  telegram,
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
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedCategoryAr = kBlogCategories.first.nameAr;
  String _expressiveImageUrl1 = '';
  String _expressiveImageUrl2 = '';
  String _expressiveImageUrl3 = '';
  _BlogImageSlot? _uploadingSlot;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(_BlogImageSlot slot) async {
    if (_uploadingSlot != null) {
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );

    if (pickedFile == null || !mounted) {
      return;
    }

    final provider = context.read<BlogProvider>();
    setState(() => _uploadingSlot = slot);

    try {
      final imageUrl = await provider.uploadBlogImage(filePath: pickedFile.path);
      if (!mounted) {
        return;
      }
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        final error = provider.errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
          provider.clearError();
        }
        return;
      }

      setState(() {
        switch (slot) {
          case _BlogImageSlot.expressive1:
            _expressiveImageUrl1 = imageUrl;
            break;
          case _BlogImageSlot.expressive2:
            _expressiveImageUrl2 = imageUrl;
            break;
          case _BlogImageSlot.expressive3:
            _expressiveImageUrl3 = imageUrl;
            break;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingSlot = null);
      }
    }
  }

  void _clearImage(_BlogImageSlot slot) {
    setState(() {
      switch (slot) {
        case _BlogImageSlot.expressive1:
          _expressiveImageUrl1 = '';
          break;
        case _BlogImageSlot.expressive2:
          _expressiveImageUrl2 = '';
          break;
        case _BlogImageSlot.expressive3:
          _expressiveImageUrl3 = '';
          break;
      }
    });
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
      expressiveImageUrl1: _expressiveImageUrl1,
      expressiveImageUrl2: _expressiveImageUrl2,
      expressiveImageUrl3: _expressiveImageUrl3,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _titleController.clear();
      _contentController.clear();
      setState(() {
        _selectedCategoryAr = kBlogCategories.first.nameAr;
        _expressiveImageUrl1 = '';
        _expressiveImageUrl2 = '';
        _expressiveImageUrl3 = '';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                '\u062a\u0645 \u0646\u0634\u0631 \u0627\u0644\u0645\u0642\u0627\u0644 \u0628\u0646\u062c\u0627\u062d.',
                'Article publie avec succes.',
              ),
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
    final provider = context.watch<BlogProvider>();
    final isPublishing = provider.isPublishing;
    final isBusy = isPublishing || _uploadingSlot != null || provider.isUploadingImage;

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
                tr(
                  '\u0625\u0646\u0634\u0627\u0621 \u0645\u0642\u0627\u0644 \u0635\u062d\u064a \u062c\u062f\u064a\u062f',
                  'Publier un nouvel article de sante',
                ),
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                enabled: !isBusy,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: tr(
                    '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0645\u0642\u0627\u0644',
                    'Titre de l\'article',
                  ),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryAr,
                decoration: InputDecoration(
                  labelText: tr('\u0627\u0644\u062a\u0635\u0646\u064a\u0641', 'Categorie'),
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
                onChanged: isBusy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedCategoryAr = value);
                      },
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  '\u0635\u0648\u0631 \u0627\u0644\u0645\u0642\u0627\u0644',
                  'Images de l\'article',
                ),
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  '\u062d\u062f \u0623\u0642\u0635\u0649 3 \u0635\u0648\u0631 \u0644\u0644\u0645\u062f\u0648\u0646\u0629.',
                  'Maximum 3 images pour l\'article.',
                ),
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? SihhaPalette.textMutedOnDark
                      : const Color(0xFF667A8D),
                ),
              ),
              const SizedBox(height: 8),
              _ComposerImageTile(
                title: tr(
                  '\u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u062f\u0648\u0646\u0629 1',
                  'Image article 1',
                ),
                hint: tr(
                  '\u0627\u062e\u062a\u064a\u0627\u0631\u064a\u0629',
                  'Optionnelle',
                ),
                imageUrl: _expressiveImageUrl1,
                uploading: _uploadingSlot == _BlogImageSlot.expressive1,
                icon: Icons.photo_size_select_large_rounded,
                onPick: isBusy
                    ? null
                    : () => _pickAndUploadImage(_BlogImageSlot.expressive1),
                onClear: isBusy
                    ? null
                    : () => _clearImage(_BlogImageSlot.expressive1),
              ),
              const SizedBox(height: 8),
              _ComposerImageTile(
                title: tr(
                  '\u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u062f\u0648\u0646\u0629 2',
                  'Image article 2',
                ),
                hint: tr(
                  '\u0627\u062e\u062a\u064a\u0627\u0631\u064a\u0629',
                  'Optionnelle',
                ),
                imageUrl: _expressiveImageUrl2,
                uploading: _uploadingSlot == _BlogImageSlot.expressive2,
                icon: Icons.photo_size_select_large_rounded,
                onPick: isBusy
                    ? null
                    : () => _pickAndUploadImage(_BlogImageSlot.expressive2),
                onClear: isBusy
                    ? null
                    : () => _clearImage(_BlogImageSlot.expressive2),
              ),
              const SizedBox(height: 8),
              _ComposerImageTile(
                title: tr(
                  '\u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u062f\u0648\u0646\u0629 3',
                  'Image article 3',
                ),
                hint: tr(
                  '\u0627\u062e\u062a\u064a\u0627\u0631\u064a\u0629',
                  'Optionnelle',
                ),
                imageUrl: _expressiveImageUrl3,
                uploading: _uploadingSlot == _BlogImageSlot.expressive3,
                icon: Icons.photo_size_select_large_rounded,
                onPick: isBusy
                    ? null
                    : () => _pickAndUploadImage(_BlogImageSlot.expressive3),
                onClear: isBusy
                    ? null
                    : () => _clearImage(_BlogImageSlot.expressive3),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                enabled: !isBusy,
                minLines: 8,
                maxLines: 14,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: tr(
                    '\u0645\u062d\u062a\u0648\u0649 \u0627\u0644\u0645\u0642\u0627\u0644',
                    'Contenu',
                  ),
                  hintText: tr(
                    '\u0627\u0643\u062a\u0628 \u0645\u0642\u0627\u0644\u0629 \u0637\u0628\u064a\u0629 \u0648\u0627\u0636\u062d\u0629 \u0645\u0639 \u0646\u0635\u0627\u0626\u062d \u0639\u0645\u0644\u064a\u0629 \u0644\u0644\u0645\u0631\u0636\u0649.',
                    'Redigez un article clair avec des conseils pratiques.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _publish,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_rounded),
                  label: Text(
                    isBusy
                        ? tr(
                            '\u062c\u0627\u0631\u064d \u0627\u0644\u0646\u0634\u0631...',
                            'Publication...',
                          )
                        : tr('\u0646\u0634\u0631 \u0627\u0644\u0645\u0642\u0627\u0644', 'Publier'),
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

class _ComposerImageTile extends StatelessWidget {
  const _ComposerImageTile({
    required this.title,
    required this.hint,
    required this.imageUrl,
    required this.uploading,
    required this.icon,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final String hint;
  final String imageUrl;
  final bool uploading;
  final IconData icon;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final hasImage = imageUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0x1A0B2236),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (hasImage)
                IconButton(
                  tooltip: tr(
                    '\u062d\u0630\u0641 \u0627\u0644\u0635\u0648\u0631\u0629',
                    'Supprimer l\'image',
                  ),
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _imagePlaceholder(context);
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }
                        return _imagePlaceholder(context);
                      },
                    )
                  else
                    _imagePlaceholder(context),
                  if (uploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: isDark
                  ? SihhaPalette.textMutedOnDark
                  : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                hasImage
                    ? tr(
                        '\u062a\u063a\u064a\u064a\u0631 \u0627\u0644\u0635\u0648\u0631\u0629',
                        'Remplacer l\'image',
                      )
                    : tr(
                        '\u0627\u062e\u062a\u064a\u0627\u0631 \u0635\u0648\u0631\u0629',
                        'Choisir une image',
                      ),
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF152333) : const Color(0xFFE8EEF3),
      child: Icon(
        icon,
        size: 34,
        color: isDark ? const Color(0xFF7FB4C7) : const Color(0xFF5B7486),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.blog});

  final HealthBlog blog;

  @override
  Widget build(BuildContext context) {
    final blogProvider = context.watch<BlogProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReacting = blogProvider.isReactingBlog(blog.id);
    final isSharing = blogProvider.isSharingBlog(blog.id);
    final categoryTitle = localizeBlogCategory(
      blog.category,
      isArabic: isArabic,
    );
    final excerpt = _buildExcerpt(blog.content);
    final blogImages = blog.imageUrls;

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
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFE2EBF2),
                child: blog.profileImageUrl.trim().isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        color: isDark
                            ? const Color(0xFF9FB7C7)
                            : const Color(0xFF5A7182),
                      )
                    : ClipOval(
                        child: Image.network(
                          blog.profileImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person_rounded,
                              color: isDark
                                  ? const Color(0xFF9FB7C7)
                                  : const Color(0xFF5A7182),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blog.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      _formatDate(blog.publishedAt),
                      style: GoogleFonts.tajawal(
                        color: isDark
                            ? SihhaPalette.textMutedOnDark
                            : const Color(0xFF6A7B90),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            blog.title,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (blogImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (blogImages.length == 1)
              _BlogRemoteImage(
                imageUrl: blogImages.first,
                fallbackLabel: tr(
                  '\u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u062f\u0648\u0646\u0629',
                  'Image article',
                ),
              )
            else
              Row(
                children: List.generate(blogImages.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: index == 0 ? 0 : 8,
                      ),
                      child: _BlogRemoteImage(
                        imageUrl: blogImages[index],
                        fallbackLabel: tr(
                          '\u0635\u0648\u0631\u0629 ${index + 1}',
                          'Image ${index + 1}',
                        ),
                      ),
                    ),
                  );
                }),
              ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PopupMenuButton<String>(
                onSelected: (reactionType) =>
                    _handleReaction(context, reactionType),
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<String>(
                      value: _reactionLike,
                      child: _BlogReactionMenuItem(
                        icon: Icons.thumb_up_alt_rounded,
                        label: tr(
                          '\u0625\u0639\u062c\u0627\u0628',
                          'Like',
                        ),
                        selected: blog.myReaction == _reactionLike,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: _reactionSupport,
                      child: _BlogReactionMenuItem(
                        icon: Icons.favorite_rounded,
                        label: tr(
                          '\u062f\u0639\u0645',
                          'Support',
                        ),
                        selected: blog.myReaction == _reactionSupport,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: _reactionThanks,
                      child: _BlogReactionMenuItem(
                        icon: Icons.volunteer_activism_rounded,
                        label: tr(
                          '\u0634\u0643\u0631\u0627\u064b',
                          'Thanks',
                        ),
                        selected: blog.myReaction == _reactionThanks,
                      ),
                    ),
                  ];
                },
                child: _BlogActionChip(
                  icon: Icons.favorite_rounded,
                  label: '${blog.reactionsCount}',
                  active: blog.myReaction.isNotEmpty,
                  busy: isReacting,
                ),
              ),
              _BlogActionChip(
                icon: Icons.chat_bubble_rounded,
                label: '${blog.commentsCount}',
                onTap: () => _openCommentsSheet(context),
              ),
              _BlogActionChip(
                icon: Icons.share_rounded,
                label: '${blog.sharesCount}',
                onTap: isSharing ? null : () => _openShareSheet(context),
                busy: isSharing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleReaction(BuildContext context, String reactionType) async {
    final provider = context.read<BlogProvider>();
    final success = await provider.toggleReaction(
      blogId: blog.id,
      reactionType: reactionType,
    );
    if (!success && context.mounted) {
      final message = provider.errorMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _openCommentsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlogCommentsSheet(blog: blog),
    );
  }

  Future<void> _openShareSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlogShareSheet(blog: blog),
    );
  }
}

class _BlogReactionMenuItem extends StatelessWidget {
  const _BlogReactionMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.tajawal(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        if (selected) const Icon(Icons.check_rounded, size: 18),
      ],
    );
  }
}

class _BlogActionChip extends StatelessWidget {
  const _BlogActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF20323A) : const Color(0xFFE8F7F6))
                : (isDark ? const Color(0xFF142332) : const Color(0xFFF0F5FA)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? const Color(0xFF1AB7A8)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0x290B2236)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? const Color(0xFF1AB7A8)
                      : (isDark ? const Color(0xFF9AB0BE) : const Color(0xFF5C7186)),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.8,
                  color: active
                      ? const Color(0xFF1AB7A8)
                      : (isDark ? const Color(0xFFD5E1EA) : const Color(0xFF324C66)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlogCommentsSheet extends StatefulWidget {
  const _BlogCommentsSheet({required this.blog});

  final HealthBlog blog;

  @override
  State<_BlogCommentsSheet> createState() => _BlogCommentsSheetState();
}

class _BlogCommentsSheetState extends State<_BlogCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<BlogComment> _comments = const <BlogComment>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await context.read<BlogProvider>().fetchComments(
      blogId: widget.blog.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.length < 2 || text.length > 1200) {
      final tr = context.read<AppSettingsProvider>().tr;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                '\u0627\u0644\u062a\u0639\u0644\u064a\u0642 \u064a\u062c\u0628 \u0623\u0646 \u064a\u0643\u0648\u0646 \u0628\u064a\u0646 2 \u0648 1200 \u062d\u0631\u0641\u0627\u064b.',
                'Le commentaire doit contenir entre 2 et 1200 caracteres.',
              ),
            ),
          ),
        );
      return;
    }

    final provider = context.read<BlogProvider>();
    final success = await provider.addComment(
      blogId: widget.blog.id,
      content: text,
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      final message = provider.errorMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    _commentController.clear();
    await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCommenting = context.select<BlogProvider, bool>(
      (provider) => provider.isCommentingBlog(widget.blog.id),
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 16, 12, bottomInset + 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: isDark ? SihhaPalette.nightCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          '\u0627\u0644\u062a\u0639\u0644\u064a\u0642\u0627\u062a',
                          'Commentaires',
                        ),
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            tr(
                              '\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0639\u0644\u064a\u0642\u0627\u062a \u0628\u0639\u062f.',
                              'Aucun commentaire pour le moment.',
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? SihhaPalette.textMutedOnDark
                                  : SihhaPalette.textMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _CommentTile(comment: comment);
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemCount: _comments.length,
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        enabled: !isCommenting,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: tr(
                            '\u0627\u0643\u062a\u0628 \u062a\u0639\u0644\u064a\u0642\u0643...',
                            'Ecrivez votre commentaire...',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: isCommenting ? null : _submitComment,
                      child: isCommenting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tr(
                                '\u0625\u0631\u0633\u0627\u0644',
                                'Envoyer',
                              ),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final BlogComment comment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF152434) : const Color(0xFFF4F8FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFDCE7F0),
            child: comment.userPhotoUrl.trim().isEmpty
                ? const Icon(Icons.person_rounded, size: 16)
                : ClipOval(
                    child: Image.network(
                      comment.userPhotoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person_rounded, size: 16),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName,
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(comment.createdAt),
                  style: GoogleFonts.tajawal(
                    fontSize: 11.5,
                    color: isDark
                        ? SihhaPalette.textMutedOnDark
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogShareSheet extends StatelessWidget {
  const _BlogShareSheet({required this.blog});

  final HealthBlog blog;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final tr = settings.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? SihhaPalette.nightCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          '\u0645\u0634\u0627\u0631\u0643\u0629 \u0627\u0644\u0645\u062f\u0648\u0646\u0629',
                          'Partager l article',
                        ),
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _SharePlatformTile(
                icon: Icons.facebook,
                title: 'Facebook',
                onTap: () => _share(context, _SharePlatform.facebook),
              ),
              _SharePlatformTile(
                icon: Icons.alternate_email_rounded,
                title: 'X',
                onTap: () => _share(context, _SharePlatform.x),
              ),
              _SharePlatformTile(
                icon: Icons.forum_rounded,
                title: 'WhatsApp',
                onTap: () => _share(context, _SharePlatform.whatsapp),
              ),
              _SharePlatformTile(
                icon: Icons.send_rounded,
                title: 'Telegram',
                onTap: () => _share(context, _SharePlatform.telegram),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, _SharePlatform platform) async {
    final settings = context.read<AppSettingsProvider>();
    final tr = settings.tr;
    final provider = context.read<BlogProvider>();
    final shareUrl = 'https://sihha.space/blog/${blog.id}';
    final shareText = '${blog.title}\n$shareUrl';
    final uri = _platformShareUri(
      platform: platform,
      shareUrl: shareUrl,
      shareText: shareText,
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                '\u062a\u0639\u0630\u0631 \u0641\u062a\u062d \u062a\u0637\u0628\u064a\u0642 \u0627\u0644\u0645\u0634\u0627\u0631\u0643\u0629.',
                'Impossible d ouvrir l application de partage.',
              ),
            ),
          ),
        );
      return;
    }

    final success = await provider.registerShare(
      blogId: blog.id,
      platform: _sharePlatformCode(platform),
    );
    if (!context.mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final message = provider.errorMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _SharePlatformTile extends StatelessWidget {
  const _SharePlatformTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

String _sharePlatformCode(_SharePlatform platform) {
  switch (platform) {
    case _SharePlatform.facebook:
      return 'facebook';
    case _SharePlatform.x:
      return 'x';
    case _SharePlatform.whatsapp:
      return 'whatsapp';
    case _SharePlatform.telegram:
      return 'telegram';
  }
}

Uri _platformShareUri({
  required _SharePlatform platform,
  required String shareUrl,
  required String shareText,
}) {
  final encodedUrl = Uri.encodeComponent(shareUrl);
  final encodedText = Uri.encodeComponent(shareText);
  switch (platform) {
    case _SharePlatform.facebook:
      return Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedText',
      );
    case _SharePlatform.x:
      return Uri.parse('https://twitter.com/intent/tweet?text=$encodedText');
    case _SharePlatform.whatsapp:
      return Uri.parse('https://wa.me/?text=$encodedText');
    case _SharePlatform.telegram:
      return Uri.parse(
        'https://t.me/share/url?url=$encodedUrl&text=$encodedText',
      );
  }
}

class _BlogRemoteImage extends StatelessWidget {
  const _BlogRemoteImage({
    required this.imageUrl,
    required this.fallbackLabel,
  });

  final String imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = imageUrl.trim().isNotEmpty;

    return AspectRatio(
      aspectRatio: 1.35,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _fallback(context, isDark),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return _fallback(context, isDark);
                },
              )
            : _fallback(context, isDark),
      ),
    );
  }

  Widget _fallback(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF142332) : const Color(0xFFEAF1F6),
      child: Center(
        child: Text(
          fallbackLabel,
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: isDark ? const Color(0xFF9FB2C0) : const Color(0xFF607D93),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
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
