import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../providers/app_settings_provider.dart';

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(
        AppSettingsProvider.trGlobal(
          'يرجى منح صلاحية الميكروفون لإرسال الرسائل الصوتية.',
          'Veuillez autoriser le microphone pour envoyer des messages vocaux.',
        ),
      );
    }

    final tempDir = await getTemporaryDirectory();
    _currentPath =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentPath!,
    );
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    final result = path ?? _currentPath;
    _currentPath = null;
    return result;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
