import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service zum Herunterladen und Einrichten der Tesseract Trainingsdaten
class TesseractSetup {
  static bool _isInitialized = false;

  /// Initialisiert Tesseract mit deutschen und englischen Trainingsdaten
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }


    try {
      await downloadGermanLanguageData();
      await downloadEnglishLanguageData();

      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Lädt deutsche Trainingsdaten herunter
  static Future<void> downloadGermanLanguageData() async {
    final dir = await getApplicationDocumentsDirectory();
    final tessDataDir = Directory('${dir.path}/tessdata');

    if (!await tessDataDir.exists()) {
      await tessDataDir.create(recursive: true);
    }

    final trainedDataPath = '${tessDataDir.path}/deu.traineddata';
    final file = File(trainedDataPath);

    // Prüfen ob bereits vorhanden
    if (await file.exists()) {
      final size = await file.length();
      return;
    }


    // Tesseract Trainingsdaten von GitHub
    const url = 'https://github.com/tesseract-ocr/tessdata/raw/main/deu.traineddata';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final size = response.bodyBytes.length;
      } else {
        throw Exception('Download fehlgeschlagen: HTTP ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Lädt englische Trainingsdaten herunter (als Fallback)
  static Future<void> downloadEnglishLanguageData() async {
    final dir = await getApplicationDocumentsDirectory();
    final tessDataDir = Directory('${dir.path}/tessdata');

    if (!await tessDataDir.exists()) {
      await tessDataDir.create(recursive: true);
    }

    final trainedDataPath = '${tessDataDir.path}/eng.traineddata';
    final file = File(trainedDataPath);

    // Prüfen ob bereits vorhanden
    if (await file.exists()) {
      final size = await file.length();
      return;
    }


    const url = 'https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final size = response.bodyBytes.length;
      } else {
        throw Exception('Download fehlgeschlagen: HTTP ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Gibt den Pfad zum Tessdata-Ordner zurück
  static Future<String> getTessDataPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/tessdata';
  }

  /// Prüft ob alle Sprachdaten vorhanden sind
  static Future<bool> isInitialized() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tessDataDir = Directory('${dir.path}/tessdata');

      if (!await tessDataDir.exists()) {
        return false;
      }

      final deuFile = File('${tessDataDir.path}/deu.traineddata');
      final engFile = File('${tessDataDir.path}/eng.traineddata');

      return await deuFile.exists() && await engFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Löscht alle heruntergeladenen Sprachdaten
  static Future<void> cleanup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tessDataDir = Directory('${dir.path}/tessdata');

      if (await tessDataDir.exists()) {
        await tessDataDir.delete(recursive: true);
        _isInitialized = false;
      }
    } catch (e) {
    }
  }
}
