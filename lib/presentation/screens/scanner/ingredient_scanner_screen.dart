import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/core/utils/category_detector.dart';

/// Screen zum Scannen von Zutatenlisten via Foto
class IngredientScannerScreen extends ConsumerStatefulWidget {
  const IngredientScannerScreen({super.key});

  @override
  ConsumerState<IngredientScannerScreen> createState() => _IngredientScannerScreenState();
}

class _IngredientScannerScreenState extends ConsumerState<IngredientScannerScreen> {
  bool _isScanning = false;
  double _progress = 0.0;
  String _statusMessage = '';
  List<String> _detectedIngredients = [];
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zutaten scannen'),
        elevation: 0,
      ),
      body: SafeArea(
        child: _selectedImage == null
            ? _buildSelectImageView(context)
            : _buildScanResultView(context),
      ),
    );
  }

  /// View zum Auswählen eines Bildes
  Widget _buildSelectImageView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 80,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 32),
            // Title
            Text(
              'Zutaten erkennen',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'Mache ein Foto von einer Zutatenliste oder wähle ein vorhandenes Bild aus. Die KI erkennt automatisch alle Produkte.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Bild auswählen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// View mit Scan-Ergebnis
  Widget _buildScanResultView(BuildContext context) {
    return Column(
      children: [
        // Bild Preview
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: _selectedImage != null
                ? DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),

        // Status
        if (_isScanning) ...[
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CupertinoActivityIndicator(),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],

        // Erkannte Zutaten
        if (_detectedIngredients.isNotEmpty && !_isScanning) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_detectedIngredients.length} Zutaten gefunden',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _detectedIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = _detectedIngredients[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: Text(ingredient),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Button zum Hinzufügen
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _selectListAndAdd(context),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Zu Liste hinzufügen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],

        // Scan-Button
        if (_selectedImage != null && !_isScanning && _detectedIngredients.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanImage,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Mit KI analysieren'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Bild auswählen
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Auswählen: $e')),
        );
      }
    }
  }

  /// Bild mit Gemini AI scannen
  Future<void> _scanImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isScanning = true;
      _progress = 0.1;
      _statusMessage = 'Lade Bild...';
    });

    try {
      // Gemini AI konfigurieren
      const apiKey = 'REDACTED_FIREBASE_KEY'; // Dein API Key
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      setState(() {
        _progress = 0.3;
        _statusMessage = 'Analysiere Bild mit KI...';
      });

      // Bild laden
      final imageBytes = await _selectedImage!.readAsBytes();

      setState(() {
        _progress = 0.5;
        _statusMessage = 'Erkenne Zutaten...';
      });

      // Prompt für Zutatenerkennung
      final prompt = '''
Analysiere dieses Bild und extrahiere alle Lebensmittel, Zutaten oder Produkte, die darauf zu sehen sind.

WICHTIG:
- Gib NUR die Produktnamen zurück, jeweils in einer neuen Zeile
- KEINE Mengenangaben, KEINE Nummern, KEINE zusätzlichen Texte
- Nur die reinen Produktnamen
- Keine Duplikate
- Deutsche Namen verwenden

Beispiel Output:
Milch
Eier
Butter
Mehl
Zucker
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);

      setState(() {
        _progress = 0.8;
        _statusMessage = 'Verarbeite Ergebnisse...';
      });

      // Text parsen
      final text = response.text ?? '';
      final lines = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();

      setState(() {
        _progress = 1.0;
        _statusMessage = 'Fertig!';
        _detectedIngredients = lines;
        _isScanning = false;
      });

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine Zutaten gefunden')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Scannen: $e')),
        );
      }
    }
  }

  /// Liste auswählen und Zutaten hinzufügen
  Future<void> _selectListAndAdd(BuildContext context) async {
    final listsAsync = ref.read(listsNotifierProvider);
    final lists = listsAsync.value ?? [];

    if (lists.isEmpty) {
      // Keine Listen vorhanden - neue erstellen
      await _createNewListAndAdd(context);
      return;
    }

    // Liste auswählen oder neue erstellen
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildListSelectionSheet(context, lists),
    );

    if (selectedAction == null) return;

    if (selectedAction == 'NEW') {
      await _createNewListAndAdd(context);
    } else {
      // Zu existierender Liste hinzufügen
      await _addToList(selectedAction);
    }
  }

  /// Bottom Sheet zur Listenauswahl
  Widget _buildListSelectionSheet(BuildContext context, List<ShoppingListModel> lists) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Liste auswählen',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            // Listen
            ...lists.map((list) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_cart, color: Colors.blue),
                  ),
                  title: Text(
                    list.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${list.itemCount ?? 0} Artikel'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => Navigator.pop(context, list.id),
                )),
            const Divider(height: 1),
            // Neue Liste Button
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.green),
              ),
              title: const Text(
                'Neue Liste erstellen',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.green),
              onTap: () => Navigator.pop(context, 'NEW'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Neue Liste erstellen und Zutaten hinzufügen
  Future<void> _createNewListAndAdd(BuildContext context) async {
    final controller = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Liste'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'z.B. Wocheneinkauf',
            labelText: 'Listenname',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true || controller.text.trim().isEmpty) return;

    final listName = controller.text.trim();

    try {
      // Liste erstellen
      await ref.read(listsNotifierProvider.notifier).createList(listName.trim());

      // Kurz warten bis Liste erstellt ist
      await Future.delayed(const Duration(milliseconds: 500));

      // Liste finden
      ref.invalidate(listsNotifierProvider);
      await Future.delayed(const Duration(milliseconds: 300));

      final lists = ref.read(listsNotifierProvider).value ?? [];
      final newList = lists.cast<dynamic>().firstWhere(
            (l) => l.name == listName.trim(),
            orElse: () => null,
          );

      if (newList != null) {
        await _addToList(newList.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Erstellen: $e')),
        );
      }
    }
  }

  /// Zutaten zu Liste hinzufügen
  Future<void> _addToList(String listId) async {
    try {
      int added = 0;

      for (final ingredient in _detectedIngredients) {
        final category = await CategoryDetector.detectCategory(ingredient);
        
        await ref.read(itemsNotifierProvider(listId).notifier).addItem(
              name: ingredient,
              quantity: 1.0,
              unit: '',
              category: category,
            );
        
        added++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $added Artikel hinzugefügt!'),
            backgroundColor: Colors.green,
          ),
        );

        // Zurück zur Liste navigieren
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }
}
