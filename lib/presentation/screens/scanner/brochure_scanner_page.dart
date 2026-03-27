import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shoply/data/models/extracted_deal_model.dart';
import 'package:shoply/data/services/ocr_service.dart';
import 'package:shoply/data/services/deal_extractor_service.dart';
import 'package:shoply/data/services/deals_database_service.dart';
import 'package:shoply/data/services/local_pdf_loader_service.dart';

/// Screen zum Scannen von PDF-Prospekten
class BrochureScannerPage extends StatefulWidget {
  const BrochureScannerPage({super.key});

  @override
  State<BrochureScannerPage> createState() => _BrochureScannerPageState();
}

class _BrochureScannerPageState extends State<BrochureScannerPage> {
  bool isScanning = false;
  double progress = 0.0;
  String statusMessage = '';
  List<ExtractedDeal> extractedDeals = [];
  String? selectedSupermarket;

  // Verfügbare Supermärkte
  final supermarkets = [
    'Lidl',
    'REWE',
    'Aldi',
    'Edeka',
    'Kaufland',
    'Penny',
    'Netto',
    'Real',
  ];

  @override
  void initState() {
    super.initState();
    _initializeOCR();
  }

  Future<void> _initializeOCR() async {
    try {
      final isInitialized = await OCRService.isInitialized();
      if (!isInitialized) {
        setState(() {
          statusMessage = 'Lade Sprachdaten herunter...';
        });
        await OCRService.initialize();
        setState(() {
          statusMessage = 'Bereit zum Scannen!';
        });
      } else {
        setState(() {
          statusMessage = 'Bereit zum Scannen!';
        });
      }

      // Prüfe ob Projekt-Ordner existiert
      _checkProjectFolder();
    } catch (e) {
      setState(() {
        statusMessage = 'Fehler bei Initialisierung: $e';
      });
    }
  }

  Future<void> _checkProjectFolder() async {
    final folderPath = await LocalPdfLoaderService.getProjectFolderPath();
    if (folderPath != null) {
      await LocalPdfLoaderService.listAvailablePdfs();
    }
  }

  Future<void> _scanAllLocalPdfs() async {
    setState(() {
      isScanning = true;
      progress = 0.0;
      statusMessage = 'Lade PDFs aus Projekt-Ordner...';
      extractedDeals = [];
    });

    try {
      // Versuche erst aus dem lokalen Ordner zu laden
      final results = await LocalPdfLoaderService.scanAllLocalPdfs(
        onProgress: (message, percent) {
          setState(() {
            progress = percent;
            statusMessage = message;
          });
        },
      );

      // Wenn keine PDFs gefunden: Biete File Picker an
      if (results.isEmpty) {
        setState(() {
          isScanning = false;
          statusMessage = '';
        });

        final shouldUsePicker = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keine PDFs gefunden'),
            content: const Text(
              'Im App-Ordner wurden keine PDF-Dateien gefunden.\n\n'
              'Möchtest du PDFs manuell auswählen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('PDFs auswählen'),
              ),
            ],
          ),
        );

        if (shouldUsePicker == true) {
          await _scanMultiplePdfs();
        }
        return;
      }

      final totalDeals = results.values.fold<int>(0, (sum, list) => sum + list.length);
      final allDeals = results.values.expand((list) => list).toList();

      setState(() {
        progress = 1.0;
        statusMessage = '✅ $totalDeals Angebote aus ${results.length} PDFs!';
        extractedDeals = allDeals;
        isScanning = false;
      });

      _showSuccessDialog(totalDeals);
    } catch (e) {
      setState(() {
        isScanning = false;
        statusMessage = 'Fehler: $e';
      });
      _showErrorDialog('Scan fehlgeschlagen: $e');
    }
  }

  Future<void> _pickAndScanPDF() async {
    if (selectedSupermarket == null) {
      _showErrorDialog('Bitte wähle erst einen Supermarkt aus!');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final pdfPath = result.files.single.path!;
        final fileName = result.files.single.name;
        await _scanPDF(pdfPath, fileName);
      }
    } catch (e) {
      _showErrorDialog('Fehler beim Auswählen der Datei: $e');
    }
  }

  /// Scannt mehrere PDFs auf einmal (für iOS-Workaround)
  Future<void> _scanMultiplePdfs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        isScanning = true;
        progress = 0.0;
        extractedDeals = [];
      });

      final allDeals = <ExtractedDeal>[];
      int current = 0;

      for (final file in result.files) {
        if (file.path == null) continue;

        current++;
        final fileName = file.name;
        final supermarket = LocalPdfLoaderService.detectSupermarketFromFileName(fileName) ?? 'Unbekannt';

        setState(() {
          progress = current / result.files.length * 0.5;
          statusMessage = 'Scanne $fileName...';
        });

        try {
          // OCR durchführen
          final ocrText = await OCRService.scanPdfBrochure(file.path!);

          // Angebote extrahieren
          final deals = await DealExtractorService.extractDeals(
            ocrText,
            supermarket,
          );

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

          allDeals.addAll(uniqueDeals);
        } catch (e) {
        }
      }

      setState(() {
        progress = 1.0;
        statusMessage = '✅ ${allDeals.length} Angebote aus ${result.files.length} PDFs!';
        extractedDeals = allDeals;
        isScanning = false;
      });

      if (allDeals.isNotEmpty) {
        _showSuccessDialog(allDeals.length);
      }
    } catch (e) {
      setState(() {
        isScanning = false;
        statusMessage = '';
      });
      _showErrorDialog('Fehler: $e');
    }
  }

  Future<void> _scanPDF(String pdfPath, String fileName) async {
    setState(() {
      isScanning = true;
      progress = 0.0;
      statusMessage = 'Starte Scan...';
      extractedDeals = [];
    });

    try {
      // 1. OCR durchführen
      final ocrText = await OCRService.scanPdfBrochure(
        pdfPath,
        onProgress: (percent, message) {
          setState(() {
            progress = percent * 0.7; // 0-70% für OCR
            statusMessage = message;
          });
        },
      );

      // 2. Angebote extrahieren
      setState(() {
        progress = 0.75;
        statusMessage = 'Extrahiere Angebote...';
      });

      final deals = await DealExtractorService.extractDeals(
        ocrText,
        selectedSupermarket!,
        onProgress: (message) {
          setState(() {
            statusMessage = message;
          });
        },
      );

      // 3. Duplikate entfernen
      final uniqueDeals = DealExtractorService.removeDuplicates(deals);

      setState(() {
        progress = 0.9;
        statusMessage = 'Speichere Angebote...';
      });

      // 4. In Datenbank speichern
      if (uniqueDeals.isNotEmpty) {
        await DealsDatabaseService.insertDeals(uniqueDeals);
        await DealsDatabaseService.markPdfAsScanned(
          fileName,
          selectedSupermarket!,
          uniqueDeals.length,
        );
      }

      setState(() {
        progress = 1.0;
        statusMessage = '✅ ${uniqueDeals.length} Angebote gefunden!';
        extractedDeals = uniqueDeals;
        isScanning = false;
      });

      _showSuccessDialog(uniqueDeals.length);
    } catch (e) {
      setState(() {
        isScanning = false;
        statusMessage = 'Fehler: $e';
      });
      _showErrorDialog('Scan fehlgeschlagen: $e');
    }
  }

  Future<bool> _showRescanDialog(String fileName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF bereits gescannt'),
            content: Text('$fileName wurde bereits gescannt. Erneut scannen?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Neu scannen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessDialog(int dealCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Scan erfolgreich!'),
        content: Text('$dealCount Angebote wurden gefunden und gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Fehler'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prospekt Scanner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status & Progress
            if (isScanning || statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    if (isScanning) ...[
                      CupertinoActivityIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      statusMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Supermarkt-Auswahl
            if (!isScanning) ...[
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Wähle den Supermarkt:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: supermarkets.map((market) {
                    final isSelected = selectedSupermarket == market;
                    return ChoiceChip(
                      label: Text(market),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedSupermarket = selected ? market : null;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Scan Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: selectedSupermarket != null ? _pickAndScanPDF : null,
                  icon: const Icon(Icons.document_scanner, size: 28),
                  label: const Text(
                    'PDF Prospekt scannen',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Scan All Local PDFs Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: _scanAllLocalPdfs,
                  icon: const Icon(Icons.folder_open, size: 24),
                  label: const Text(
                    '📂 Alle PDFs aus Projekt-Ordner scannen',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            // Gefundene Angebote
            if (extractedDeals.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Gefundene Angebote:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: extractedDeals.length,
                  itemBuilder: (context, index) {
                    final deal = extractedDeals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Text(
                            deal.formattedDiscount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          deal.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${deal.supermarket}${deal.productCategory != null ? " • ${deal.productCategory}" : ""}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  deal.formattedOriginalPrice,
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  deal.formattedDiscountedPrice,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.local_offer, color: Colors.orange),
                            const SizedBox(height: 4),
                            Text(
                              deal.formattedSavings,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (!isScanning) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scanne ein Prospekt-PDF\num Angebote zu finden',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
