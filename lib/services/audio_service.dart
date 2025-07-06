import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Read audio file as bytes
  Future<Uint8List> readAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $filePath');
      }
      return await file.readAsBytes();
    } catch (e) {
      throw Exception('Failed to read audio file: $e');
    }
  }

  // Save audio bytes to local file
  Future<String> saveAudioBytes(Uint8List audioData, String fileName) async {
    try {
      final directory = Directory.systemTemp;
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save audio file: $e');
    }
  }

  // Get MIME type from file extension
  String getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      default:
        return 'audio/mpeg'; // Default to MP3
    }
  }

  // Get file name from path
  String getFileName(String filePath) {
    return path.basename(filePath);
  }

  // Get file size
  int getFileSize(String filePath) {
    try {
      return File(filePath).lengthSync();
    } catch (e) {
      return 0;
    }
  }
}