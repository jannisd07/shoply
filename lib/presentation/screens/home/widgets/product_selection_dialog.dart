import 'package:flutter/material.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Dialog for selecting OCR-detected products and choosing which list to add them to
class ProductSelectionDialog extends StatefulWidget {
  final List<String> products;
  final List<dynamic> lists;
  
  const ProductSelectionDialog({
    super.key,
    required this.products,
    required this.lists,
  });
  
  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  late List<bool> selectedProducts;
  String? selectedListId;
  bool createNewList = false;
  final TextEditingController newListController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    selectedProducts = List.filled(widget.products.length, true);
  }
  
  @override
  void dispose() {
    newListController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('detected_products'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Produkte Liste
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.products.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text(widget.products[index]),
                    value: selectedProducts[index],
                    onChanged: (value) {
                      setState(() {
                        selectedProducts[index] = value ?? false;
                      });
                    },
                  );
                },
              ),
            ),
            
            const Divider(height: 1),
            
            // Listen-Auswahl
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('add_to_which_list'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  
                  // Neue Liste erstellen
                  CheckboxListTile(
                    title: const Text('Neue Liste erstellen'),
                    value: createNewList,
                    onChanged: (value) {
                      setState(() {
                        createNewList = value ?? false;
                        if (createNewList) selectedListId = null;
                      });
                    },
                  ),
                  
                  if (createNewList) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: newListController,
                        decoration: const InputDecoration(
                          hintText: 'Name der neuen Liste',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Bestehende Listen
                  if (!createNewList && widget.lists.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedListId,
                      decoration: const InputDecoration(
                        labelText: 'Liste auswählen',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.lists.map((list) {
                        return DropdownMenuItem<String>(
                          value: list.id,
                          child: Text(list.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedListId = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final selected = <String>[];
                        for (int i = 0; i < widget.products.length; i++) {
                          if (selectedProducts[i]) {
                            selected.add(widget.products[i]);
                          }
                        }
                        
                        Navigator.pop(context, {
                          'products': selected,
                          'listId': selectedListId,
                          'createNew': createNewList,
                          'newListName': newListController.text.trim(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Hinzufügen'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
