// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart'; // Disabled - causes iOS build issues
import 'package:pdf_render/pdf_render.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
// import 'package:shoply/data/services/tesseract_setup.dart'; // Disabled - depends on flutter_tesseract_ocr

/// Service für OCR (Optical Character Recognition) auf PDF-Prospekten
class OCRService {
  static bool _isInitialized = false;

  /// Initialisiert den OCR Service
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // OCR temporarily disabled due to iOS build issues with SwiftyTesseract
    throw UnimplementedError('OCR functionality is temporarily disabled');
    
    // try {
    //   // Tesseract Sprachdaten herunterladen
    //   await TesseractSetup.initialize();
    //   _isInitialized = true;
    // } catch (e) {
    //   rethrow;
    // }
  }

  /// Konvertiert ein PDF zu einzelnen Bildern
  /// Gibt eine Liste mit Pfaden zu den generierten Bildern zurück
  static Future<List<String>> convertPdfToImages(String pdfPath) async {
    List<String> imagePaths = [];


    try {
      // PDF Dokument öffnen
      final doc = await PdfDocument.openFile(pdfPath);
      final pageCount = doc.pageCount;


      // Temporären Ordner für Bilder erstellen
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagesDir = Directory('${tempDir.path}/ocr_images_$timestamp');

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Jede Seite konvertieren
      for (int i = 1; i <= pageCount; i++) {

        final page = await doc.getPage(i);

        // Seite als Bild rendern (300 DPI für gute OCR-Qualität)
        // Höhere Auflösung = bessere OCR-Ergebnisse
        final pageImage = await page.render(
          width: (page.width * 3).toInt(),  // 3x für ~300 DPI
          height: (page.height * 3).toInt(),
        );

        // Bild speichern
        final imagePath = '${imagesDir.path}/page_$i.png';
        final file = File(imagePath);

        final bytes = await pageImage.createImageDetached();
        final byteData = await bytes.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final imageBytes = byteData.buffer.asUint8List();
          await file.writeAsBytes(imageBytes);
          imagePaths.add(imagePath);
        } else {
        }
      }
    } catch (e) {
      rethrow;
    }

    return imagePaths;
  }

  /// Extrahiert Text aus einem Bild mit Tesseract OCR
  static Future<String> extractTextFromImage(
    String imagePath, {
    Function(double)? onProgress,
  }) async {

    // OCR temporarily disabled due to iOS build issues
    throw UnimplementedError('OCR functionality is temporarily disabled');
    
    // try {
    //   // Tesseract OCR ausführen
    //   // PSM 6 = Assume a single uniform block of text (gut für strukturierte Prospekte)
    //   // PSM 3 = Fully automatic page segmentation (Alternative)
    //   final text = await FlutterTesseractOcr.extractText(
    //     imagePath,
    //     language: 'deu+eng', // Deutsch + Englisch für beste Ergebnisse
    //     args: {
    //       "psm": "6", // Page Segmentation Mode
    //       "preserve_interword_spaces": "1",
    //     },
    //   );
    //
    //   if (onProgress != null) {
    //     onProgress(1.0);
    //   }
    //
    //   return text;
    // } catch (e) {
    //   rethrow;
    // }
  }

  /// Scannt ein komplettes PDF-Prospekt
  /// Gibt den extrahierten Text aller Seiten zurück
  static Future<String> scanPdfBrochure(
    String pdfPath, {
    Function(double, String)? onProgress,
  }) async {
    await initialize();


    try {
      // PDF zu Bildern konvertieren
      if (onProgress != null) onProgress(0.1, 'Konvertiere PDF...');

      final imagePaths = await convertPdfToImages(pdfPath);

      if (imagePaths.isEmpty) {
        throw Exception('Keine Seiten aus PDF extrahiert');
      }

      // OCR auf allen Bildern durchführen
      StringBuffer fullText = StringBuffer();
      final totalPages = imagePaths.length;

      for (int i = 0; i < imagePaths.length; i++) {
        final pageNumber = i + 1;
        final progressPercent = 0.1 + (0.8 * (i / totalPages)); // 10% - 90%

        if (onProgress != null) {
          onProgress(progressPercent, 'Scanne Seite $pageNumber/$totalPages...');
        }


        final pageText = await extractTextFromImage(imagePaths[i]);

        fullText.writeln('--- SEITE $pageNumber ---');
        fullText.writeln(pageText);
        fullText.writeln();

        // Temporäre Bilddatei löschen
        try {
          await File(imagePaths[i]).delete();
        } catch (e) {
        }
      }

      // Temporären Ordner aufräumen
      try {
        final firstImageDir = File(imagePaths.first).parent;
        if (await firstImageDir.exists()) {
          await firstImageDir.delete(recursive: true);
        }
      } catch (e) {
      }

      if (onProgress != null) onProgress(1.0, 'Scan abgeschlossen!');


      return fullText.toString();
    } catch (e) {
      rethrow;
    }
  }

  /// Bildqualität verbessern vor OCR (optional)
  /// TODO: Implementiere Bildvorverarbeitung für bessere OCR-Qualität:
  /// - Kontrast erhöhen
  /// - Graustufen konvertieren
  /// - Rauschen entfernen
  /// - Schärfen
  /// - Binarisierung
  static Future<String> preprocessAndExtractText(
    String imagePath, {
    Function(double)? onProgress,
  }) async {
    // Für jetzt: Direkt OCR ohne Vorverarbeitung
    // Später: image package für Bildverbesserung nutzen
    return await extractTextFromImage(imagePath, onProgress: onProgress);
  }

  /// Extrahiert Text aus mehreren Bildern parallel
  static Future<List<String>> extractTextFromImages(
    List<String> imagePaths, {
    Function(int, int)? onProgress,
  }) async {
    await initialize();

    List<String> texts = [];

    for (int i = 0; i < imagePaths.length; i++) {
      if (onProgress != null) {
        onProgress(i + 1, imagePaths.length);
      }

      final text = await extractTextFromImage(imagePaths[i]);
      texts.add(text);
    }

    return texts;
  }

  /// Prüft ob der OCR Service initialisiert ist
  static Future<bool> isInitialized() async {
    // OCR temporarily disabled
    return false;
    // return await TesseractSetup.isInitialized();
  }
}
