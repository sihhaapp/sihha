import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/blog_comment.dart';
import '../models/health_blog.dart';
import '../services/api_service.dart';
import '../services/blog_service.dart';
import 'app_settings_provider.dart';

class BlogProvider extends ChangeNotifier {
  BlogProvider(this._blogService);

  final BlogService _blogService;

  bool _isPublishing = false;
  bool _isUploadingImage = false;
  int _feedVersion = 0;
  String? _errorMessage;
  final Set<String> _reactingBlogIds = <String>{};
  final Set<String> _commentingBlogIds = <String>{};
  final Set<String> _sharingBlogIds = <String>{};

  bool get isPublishing => _isPublishing;
  bool get isUploadingImage => _isUploadingImage;
  int get feedVersion => _feedVersion;
  String? get errorMessage => _errorMessage;

  bool isReactingBlog(String blogId) => _reactingBlogIds.contains(blogId);
  bool isCommentingBlog(String blogId) => _commentingBlogIds.contains(blogId);
  bool isSharingBlog(String blogId) => _sharingBlogIds.contains(blogId);

  Stream<List<HealthBlog>> blogsStream() {
    return _blogService.blogsStream();
  }

  Future<bool> publishBlog({
    required AppUser author,
    required String title,
    required String content,
    required String category,
    required String expressiveImageUrl1,
    required String expressiveImageUrl2,
    required String expressiveImageUrl3,
  }) async {
    _errorMessage = null;

    final sanitizedTitle = title.trim();
    final sanitizedContent = content.trim();
    final sanitizedCategory = category.trim();
    final sanitizedExpressiveImageUrl1 = expressiveImageUrl1.trim();
    final sanitizedExpressiveImageUrl2 = expressiveImageUrl2.trim();
    final sanitizedExpressiveImageUrl3 = expressiveImageUrl3.trim();

    if (author.role != UserRole.doctor) {
      _errorMessage = AppSettingsProvider.trGlobal(
        '\u0641\u0642\u0637 \u0627\u0644\u0637\u0628\u064a\u0628 \u064a\u0645\u0643\u0646 \u0646\u0634\u0631 \u0627\u0644\u0645\u0642\u0627\u0644\u0627\u062a.',
        'Seul le medecin peut publier des articles.',
      );
      notifyListeners();
      return false;
    }

    if (sanitizedTitle.isEmpty ||
        sanitizedContent.isEmpty ||
        sanitizedCategory.isEmpty) {
      _errorMessage = AppSettingsProvider.trGlobal(
        '\u064a\u0631\u062c\u0649 \u062a\u0639\u0628\u0626\u0629 \u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0645\u0642\u0627\u0644 \u0648\u0627\u0644\u062a\u0635\u0646\u064a\u0641 \u0648\u0627\u0644\u0645\u062d\u062a\u0648\u0649.',
        'Veuillez renseigner le titre, la categorie et le contenu.',
      );
      notifyListeners();
      return false;
    }

    if (sanitizedContent.length < 80) {
      _errorMessage = AppSettingsProvider.trGlobal(
        '\u0645\u062d\u062a\u0648\u0649 \u0627\u0644\u0645\u0642\u0627\u0644 \u0642\u0635\u064a\u0631 \u062c\u062f\u0627\u064b. \u0627\u0643\u062a\u0628 \u062a\u0641\u0627\u0635\u064a\u0644 \u0623\u0643\u062b\u0631 \u0642\u0628\u0644 \u0627\u0644\u0646\u0634\u0631.',
        'Le contenu est trop court. Ajoutez plus de details avant la publication.',
      );
      notifyListeners();
      return false;
    }

    _isPublishing = true;
    notifyListeners();

    try {
      await _blogService.publishBlog(
        title: sanitizedTitle,
        content: sanitizedContent,
        category: sanitizedCategory,
        expressiveImageUrl1: sanitizedExpressiveImageUrl1,
        expressiveImageUrl2: sanitizedExpressiveImageUrl2,
        expressiveImageUrl3: sanitizedExpressiveImageUrl3,
      );
      _isPublishing = false;
      _bumpFeedVersion();
      return true;
    } catch (error) {
      _isPublishing = false;
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadBlogImage({required String filePath}) async {
    _errorMessage = null;
    _isUploadingImage = true;
    notifyListeners();
    try {
      final imageUrl = await _blogService.uploadBlogImage(filePath: filePath);
      _isUploadingImage = false;
      notifyListeners();
      return imageUrl;
    } catch (error) {
      _isUploadingImage = false;
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> toggleReaction({
    required String blogId,
    required String reactionType,
  }) async {
    if (_reactingBlogIds.contains(blogId)) {
      return false;
    }
    _errorMessage = null;
    _reactingBlogIds.add(blogId);
    notifyListeners();
    try {
      await _blogService.toggleReaction(
        blogId: blogId,
        reactionType: reactionType,
      );
      _reactingBlogIds.remove(blogId);
      _bumpFeedVersion();
      return true;
    } catch (error) {
      _reactingBlogIds.remove(blogId);
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return false;
    }
  }

  Future<List<BlogComment>> fetchComments({required String blogId}) async {
    _errorMessage = null;
    try {
      return await _blogService.fetchComments(blogId: blogId);
    } catch (error) {
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return const <BlogComment>[];
    }
  }

  Future<bool> addComment({
    required String blogId,
    required String content,
  }) async {
    if (_commentingBlogIds.contains(blogId)) {
      return false;
    }
    _errorMessage = null;
    _commentingBlogIds.add(blogId);
    notifyListeners();
    try {
      await _blogService.addComment(blogId: blogId, content: content);
      _commentingBlogIds.remove(blogId);
      _bumpFeedVersion();
      return true;
    } catch (error) {
      _commentingBlogIds.remove(blogId);
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerShare({
    required String blogId,
    required String platform,
  }) async {
    if (_sharingBlogIds.contains(blogId)) {
      return false;
    }
    _errorMessage = null;
    _sharingBlogIds.add(blogId);
    notifyListeners();
    try {
      await _blogService.registerShare(
        blogId: blogId,
        platform: platform,
      );
      _sharingBlogIds.remove(blogId);
      _bumpFeedVersion();
      return true;
    } catch (error) {
      _sharingBlogIds.remove(blogId);
      _errorMessage = _mapPublishError(error);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapPublishError(Object error) {
    String tr(String ar, String fr) => AppSettingsProvider.trGlobal(ar, fr);

    if (error is ApiException) {
      switch (error.code) {
        case 'forbidden':
          return tr(
            '\u0644\u0627 \u062a\u0648\u062c\u062f \u0635\u0644\u0627\u062d\u064a\u0629 \u0644\u062a\u0646\u0641\u064a\u0630 \u0627\u0644\u0639\u0645\u0644\u064a\u0629.',
            'Autorisation refusee pour cette operation.',
          );
        case 'network-error':
          return tr(
            '\u062a\u0639\u0630\u0631 \u0627\u0644\u0627\u062a\u0635\u0627\u0644 \u0628\u0627\u0644\u062e\u0627\u062f\u0645 \u0627\u0644\u0645\u062d\u0644\u064a. \u062a\u0623\u0643\u062f \u0623\u0646 Backend \u064a\u0639\u0645\u0644.',
            'Connexion au serveur impossible. Verifiez que le backend fonctionne.',
          );
        case 'request-timeout':
          return tr(
            '\u0627\u0646\u062a\u0647\u062a \u0645\u0647\u0644\u0629 \u0627\u0644\u0637\u0644\u0628.',
            'Le delai de la requete a expire.',
          );
        case 'blog-not-found':
          return tr(
            '\u0627\u0644\u0645\u062f\u0648\u0646\u0629 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f\u0629.',
            'Le blog est introuvable.',
          );
        case 'blog-comment-length-invalid':
          return tr(
            '\u064a\u062c\u0628 \u0623\u0646 \u064a\u0643\u0648\u0646 \u0627\u0644\u062a\u0639\u0644\u064a\u0642 \u0628\u064a\u0646 2 \u06481200 \u062d\u0631\u0641.',
            'Le commentaire doit contenir entre 2 et 1200 caracteres.',
          );
        case 'blog-reaction-invalid':
          return tr(
            '\u0646\u0648\u0639 \u0627\u0644\u062a\u0641\u0627\u0639\u0644 \u063a\u064a\u0631 \u0635\u0627\u0644\u062d.',
            'Type de reaction invalide.',
          );
        case 'blog-share-platform-invalid':
          return tr(
            '\u0645\u0646\u0635\u0629 \u0627\u0644\u0645\u0634\u0627\u0631\u0643\u0629 \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645\u0629.',
            'Plateforme de partage non prise en charge.',
          );
        default:
          return error.message;
      }
    }

    return tr(
      '\u062d\u062f\u062b \u062e\u0637\u0623 \u063a\u064a\u0631 \u0645\u062a\u0648\u0642\u0639 \u0623\u062b\u0646\u0627\u0621 \u062a\u0646\u0641\u064a\u0630 \u0627\u0644\u0639\u0645\u0644\u064a\u0629.',
      'Une erreur inattendue est survenue pendant l operation.',
    );
  }

  void _bumpFeedVersion() {
    _feedVersion += 1;
    notifyListeners();
  }
}
