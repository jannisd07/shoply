import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/data/models/store_flyer_model.dart';
import 'package:shoply/data/services/store_flyer_service.dart';
import 'package:shoply/presentation/screens/flyers/flyer_viewer_screen.dart';

/// Minimaler Supermarkt-Finder (GroceryDB) mit Prospekt-Integration
///
/// Damit du schnell testen kannst, nutze ich Demo-Daten. Wenn du eine
/// `assets/grocerydb.json` einbindest oder einen Server benutzt, tausche
/// die Datenlade-Funktion `_ladeDemoDaten()` gegen echtes Laden aus.
class SupermarktFinderPage extends StatefulWidget {
  const SupermarktFinderPage({super.key});

  @override
  State<SupermarktFinderPage> createState() => _SupermarktFinderPageState();
}

class _SupermarktFinderPageState extends State<SupermarktFinderPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  String _filter = 'Alle';

  @override
  void initState() {
    super.initState();
    _ladeDemoDaten();
  }

  void _ladeDemoDaten() {
    _all = [
      {
        'name': 'EDEKA Richter',
        'type': 'EDEKA',
        'street': 'Bahnhofstraße 15',
        'zip': '89073',
        'city': 'Ulm',
      },
      {
        'name': 'REWE Markt',
        'type': 'REWE',
        'street': 'Neue Straße 42',
        'zip': '89073',
        'city': 'Ulm',
      },
      {
        'name': 'Penny Markt',
        'type': 'PENNY',
        'street': 'Saarlandstraße 8',
        'zip': '89077',
        'city': 'Ulm',
      },
    ];
    _filtered = List.of(_all);
    setState(() {});
  }

  void _filterMarkets(String q) {
    q = q.toLowerCase();
    _filtered = _all.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final city = (m['city'] ?? '').toString().toLowerCase();
      final zip = (m['zip'] ?? '').toString();
      final matchesFilter = _filter == 'Alle' || (m['type'] ?? '').toString() == _filter;
      return matchesFilter && (name.contains(q) || city.contains(q) || zip.contains(q));
    }).toList();
    setState(() {});
  }

  String _mapTypeToChain(String type) {
    final t = type.toLowerCase();
    if (t.contains('edeka')) return 'edeka';
    if (t.contains('rewe')) return 'rewe';
    if (t.contains('aldi')) return 'aldi';
    if (t.contains('netto')) return 'netto';
    if (t.contains('kaufland')) return 'kaufland';
    if (t.contains('penny')) return 'penny';
    if (t.contains('real')) return 'real';
    return t;
  }

  Future<void> _showProspekteFor(Map<String, dynamic> markt) async {
    final chain = _mapTypeToChain((markt['type'] ?? '').toString());
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: double.infinity,
          height: 520,
          child: FutureBuilder<List<StoreFlyerModel>>(
            future: StoreFlyerService.getFlyersForChain(chain),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snap.hasError) return Center(child: Text('Fehler: \\${snap.error}'));
              final flyers = snap.data ?? [];
              if (flyers.isEmpty) return const Center(child: Text('Keine Prospekte gefunden'));

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${markt['name']} - Prospekte', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: flyers.length,
                      itemBuilder: (context, index) {
                        final f = flyers[index];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlyerViewerScreen(flyer: f))),
                          child: SizedBox(
                            width: 220,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(f.coverImageUrl, fit: BoxFit.cover, width: double.infinity),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(f.title ?? '', overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supermarkt Finder')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Stadt, PLZ oder Name'),
              onChanged: _filterMarkets,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final m = _filtered[i];
                return ListTile(
                  title: Text(m['name'] ?? ''),
                  subtitle: Text('${m['street'] ?? ''}, ${m['zip'] ?? ''} ${m['city'] ?? ''}'),
                  trailing: TextButton(onPressed: () => _showProspekteFor(m), child: const Text('Prospekte')),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
