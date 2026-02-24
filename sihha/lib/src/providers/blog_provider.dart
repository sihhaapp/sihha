import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/health_blog.dart';
import '../services/api_service.dart';
import '../services/blog_service.dart';
import 'app_settings_provider.dart';

class BlogProvider extends ChangeNotifier {
  BlogProvider(this._blogService);

  final BlogService _blogService;

  bool _isPublishing = false;
  String? _errorMessage;

  bool get isPublishing => _isPublishing;
  String? get errorMessage => _errorMessage;

  Stream<List<HealthBlog>> blogsStream() {
    return _blogService.blogsStream();
  }

  Future<bool> publishBlog({
    required AppUser author,
    required String title,
    required String content,
    required String category,
  }) async {
    _errorMessage = null;

    final sanitizedTitle = title.trim();
    final sanitizedContent = content.trim();
    final sanitizedCategory = category.trim();

    if (author.role != UserRole.doctor) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'فقط الطبيب يمكن نشر المقالات.',
        'Seul le medecin peut publier des articles.',
      );
      notifyListeners();
      return false;
    }

    if (sanitizedTitle.isEmpty ||
        sanitizedContent.isEmpty ||
        sanitizedCategory.isEmpty) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'يرجى تعبئة عنوان المقال والتصنيف والمحتوى.',
        'Veuillez renseigner le titre, la categorie et le contenu.',
      );
      notifyListeners();
      return false;
    }

    if (sanitizedContent.length < 80) {
      _errorMessage = AppSettingsProvider.trGlobal(
        'محتوى المقال قصير جداً. اكتب تفاصيل أكثر قبل النشر.',
        'Le contenu est trop court. Ajoutez plus de details avant la publication.',
      );
      notifyListeners();
      return false;
    }

    _isPublishing = true;
    notifyListeners();

    try {
      await _blogService.publishBlog(
        author: author,
        title: sanitizedTitle,
        content: sanitizedContent,
        category: sanitizedCategory,
      );
      _isPublishing = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isPublishing = false;
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
            'لا توجد صلاحية لنشر المقال. النشر متاح للأطباء فقط.',
            'Autorisation refusee pour publier cet article.',
          );
        case 'network-error':
          return tr(
            'تعذر الاتصال بالخادم المحلي. تأكد أن Backend يعمل.',
            'Connexion au serveur impossible. Verifiez que le backend fonctionne.',
          );
        case 'request-timeout':
          return tr(
            'انتهت مهلة الطلب أثناء النشر.',
            'Le delai de publication a expire.',
          );
        default:
          return error.message;
      }
    }

    return tr(
      'حدث خطأ غير متوقع أثناء نشر المقال.',
      'Une erreur inattendue est survenue pendant la publication.',
    );
  }
}
