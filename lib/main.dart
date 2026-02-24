import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Avoid path_provider calls in background/headless engines.
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const SihhaApp());
}
