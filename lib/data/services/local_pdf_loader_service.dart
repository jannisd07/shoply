import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shoply/data/models/extracted_deal_model.dart';
import 'package:shoply/data/services/ocr_service.dart';
import 'package:shoply/data/services/deal_extractor_service.dart';
import 'package:shoply/data/services/deals_database_service.dart';

/// Service zum automatischen Laden und Scannen von PDFs aus dem Projekt-Ordner
class LocalPdfLoaderService {
  // Pfad zum Projekt-Ordner mit PDFs
  static const String projectPdfFolder = 'prospekte_pdfs';

  /// Lädt alle PDFs aus den Assets und scannt sie automatisch
  static Future<Map<String, List<ExtractedDeal>>> scanAllLocalPdfs({
    Function(String, double)? onProgress,
  }) async {
    final results = <String, List<ExtractedDeal>>{};

    try {
      // Lade alle PDFs aus Assets
      final pdfFiles = await _loadPdfsFromAssets();

      if (pdfFiles.isEmpty) {
        return results;
      }

      int current = 0;
      for (final entry in pdfFiles.entries) {
        current++;
        final fileName = entry.key;
        final pdfPath = entry.value;
        final supermarket = detectSupermarketFromFileName(fileName) ?? 'Unbekannt';

        if (onProgress != null) {
          onProgress(
            'Scanne ${fileName.replaceAll('.pdf', '')}...',
            current / pdfFiles.length,
          );
        }

        try {
          // OCR durchführen
          final ocrText = await OCRService.scanPdfBrochure(pdfPath);

          // Angebote extrahieren
          final deals = await DealExtractorService.extractDeals(
            ocrText,
            supermarket,
          );

          // Duplikate entfernen
          final uniqueDeals = DealExtractorService.removeDuplicates(deals);

          // In Datenbank speichern
          if (uniqueDeals.isNotEmpty) {
            await DealsDatabaseService.insertDeals(uniqueDeals);
            await DealsDatabaseService.markPdfAsScanned(
              fileName,
              supermarket,
              uniqueDeals.length,
            );
          }

          results[fileName] = uniqueDeals;
        } catch (e) {
          results[fileName] = [];
        }
      }

      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Lädt alle PDF-Dateien aus dem Assets-Ordner
  static Future<Map<String, String>> _loadPdfsFromAssets() async {
    final pdfFiles = <String, String>{};

    try {
      // Liste alle PDFs im prospekte_pdfs Ordner
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      
      // Parse Asset-Manifest (einfach nach prospekte_pdfs/*.pdf suchen)
      final lines = manifestContent.split('"');
      for (final line in lines) {
        if (line.contains('prospekte_pdfs/') && line.endsWith('.pdf')) {
          final fileName = line.split('/').last;
          
          // Kopiere PDF aus Assets in temporären Ordner
          final tempPath = await _copyAssetToTemp(line);
          if (tempPath != null) {
            pdfFiles[fileName] = tempPath;
          }
        }
      }

      return pdfFiles;
    } catch (e) {
      return {};
    }
  }

  /// Kopiert ein PDF-Asset in einen temporären Ordner
  static Future<String?> _copyAssetToTemp(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      
      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Lädt PDFs direkt aus dem Projekt-Ordner (VERALTET - nur für Entwicklung)
  static Future<List<File>> _getPdfFilesFromProjectFolder() async {
    try {
      // Für iOS: Nutze App Documents Directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final prospekteDir = Directory('${appDocDir.path}/prospekte_pdfs');

      // Erstelle Ordner falls nicht vorhanden
      if (!await prospekteDir.exists()) {
        await prospekteDir.create(recursive: true);
        return [];
      }

      final files = await prospekteDir
          .list()
          .where((entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.pdf'))
          .cast<File>()
          .toList();

      return files;
    } catch (e) {
      return [];
    }
  }

  /// Erkennt Supermarkt aus Dateinamen (PUBLIC für externe Nutzung)
  static String? detectSupermarketFromFileName(String fileName) {
    final lowerName = fileName.toLowerCase();

    if (lowerName.contains('lidl')) return 'Lidl';
    if (lowerName.contains('rewe')) return 'REWE';
    if (lowerName.contains('aldi')) return 'Aldi';
    if (lowerName.contains('edeka')) return 'Edeka';
    if (lowerName.contains('kaufland')) return 'Kaufland';
    if (lowerName.contains('penny')) return 'Penny';
    if (lowerName.contains('netto')) return 'Netto';
    if (lowerName.contains('real')) return 'Real';

    return null;
  }

  /// Scannt ein einzelnes PDF aus dem Projekt-Ordner
  static Future<List<ExtractedDeal>> scanSinglePdf(
    String fileName, {
    Function(String)? onProgress,
  }) async {
    final pdfFiles = await _getPdfFilesFromProjectFolder();
    final pdfFile = pdfFiles.firstWhere(
      (file) => file.path.endsWith(fileName),
      orElse: () => throw Exception('PDF nicht gefunden: $fileName'),
    );

    final supermarket = detectSupermarketFromFileName(fileName) ?? 'Unbekannt';

    if (onProgress != null) onProgress('Scanne $fileName...');

    // OCR
    final ocrText = await OCRService.scanPdfBrochure(pdfFile.path);

    // Angebote extrahieren
    final deals = await DealExtractorService.extractDeals(ocrText, supermarket);

    // Duplikate entfernen
    final uniqueDeals = DealExtractorService.removeDuplicates(deals);

    // Speichern
    if (uniqueDeals.isNotEmpty) {
      await DealsDatabaseService.insertDeals(uniqueDeals);
      await DealsDatabaseService.markPdfAsScanned(
        fileName,
        supermarket,
        uniqueDeals.length,
      );
    }

    return uniqueDeals;
  }

  /// Listet alle verfügbaren PDFs im Projekt-Ordner
  static Future<List<String>> listAvailablePdfs() async {
    final pdfFiles = await _getPdfFilesFromProjectFolder();
    return pdfFiles.map((file) => file.path.split('/').last).toList();
  }

  /// Prüft ob der Projekt-Ordner existiert
  static Future<bool> projectFolderExists() async {
    final pdfFiles = await _getPdfFilesFromProjectFolder();
    return pdfFiles.isNotEmpty;
  }

  /// Gibt den Pfad zum Projekt-Ordner zurück
  static Future<String?> getProjectFolderPath() async {
    final possiblePaths = [
      './prospekte_pdfs',
      '../prospekte_pdfs',
      '/Users/dominikk/Desktop/Shoply - Einkaufen/shoply/prospekte_pdfs',
    ];

    for (final path in possiblePaths) {
      final directory = Directory(path);
      if (await directory.exists()) {
        return directory.absolute.path;
      }
    }

    return null;
  }
}
