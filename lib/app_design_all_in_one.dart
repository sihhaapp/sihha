import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SihhaDesignPreviewApp());
}

class SihhaDesignPreviewApp extends StatelessWidget {
  const SihhaDesignPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E9F8A)),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تصميم صحة',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: base.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
      ),
      home: const _PreviewHome(),
    );
  }
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاية التصميم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('واجة المريض'),
              subtitle: Text('بحث ع طبيباً اختيار التخصصاً وبدء الاستشارة'),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: const ListTile(
              leading: CircleAvatar(child: Icon(Icons.medical_services)),
              title: Text('واجة الطبيب'),
              subtitle: Text('صندوق الوارداً الحالة المتاحةاً وتحديث الملف الطبي'),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: const ListTile(
              leading: CircleAvatar(child: Icon(Icons.chat_bubble)),
              title: Text('واجة الدردشة'),
              subtitle: Text('رسائل نصية وصوتية مع تصميم عربي كامل'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
