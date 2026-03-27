import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shoply/data/models/extracted_deal_model.dart';

/// Service für die Verwaltung von Angeboten in SQLite
class DealsDatabaseService {
  static Database? _database;
  static const String _databaseName = 'shoply_deals.db';
  static const int _databaseVersion = 1;

  // Tabellen
  static const String _dealsTable = 'deals';
  static const String _scannedPdfsTable = 'scanned_pdfs';

  /// Initialisiert die Datenbank
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Erstellt und öffnet die Datenbank
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);


    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Erstellt die Datenbank-Tabellen
  static Future<void> _createDatabase(Database db, int version) async {

    // Deals Tabelle
    await db.execute('''
      CREATE TABLE $_dealsTable (
        id TEXT PRIMARY KEY,
        supermarket TEXT NOT NULL,
        productName TEXT NOT NULL,
        productBrand TEXT,
        productCategory TEXT,
        originalPrice REAL NOT NULL,
        discountedPrice REAL NOT NULL,
        discountPercentage REAL NOT NULL,
        unit TEXT,
        validFrom TEXT NOT NULL,
        validUntil TEXT NOT NULL,
        imageUrl TEXT,
        scannedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Scanned PDFs Tabelle (um doppeltes Scannen zu vermeiden)
    await db.execute('''
      CREATE TABLE $_scannedPdfsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT NOT NULL UNIQUE,
        supermarket TEXT NOT NULL,
        scannedAt TEXT NOT NULL,
        dealCount INTEGER NOT NULL
      )
    ''');

    // Indizes für Performance
    await db.execute(
      'CREATE INDEX idx_deals_supermarket ON $_dealsTable(supermarket)',
    );
    await db.execute(
      'CREATE INDEX idx_deals_category ON $_dealsTable(productCategory)',
    );
    await db.execute(
      'CREATE INDEX idx_deals_valid_until ON $_dealsTable(validUntil)',
    );
    await db.execute(
      'CREATE INDEX idx_deals_discount ON $_dealsTable(discountPercentage DESC)',
    );

  }

  /// Upgrade der Datenbank bei neuer Version
  static Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // TODO: Migrations bei Schema-Änderungen
  }

  /// Speichert ein einzelnes Angebot
  static Future<void> insertDeal(ExtractedDeal deal) async {
    final db = await database;
    await db.insert(
      _dealsTable,
      deal.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Speichert mehrere Angebote
  static Future<void> insertDeals(List<ExtractedDeal> deals) async {
    final db = await database;
    final batch = db.batch();

    for (final deal in deals) {
      batch.insert(
        _dealsTable,
        deal.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Lädt alle aktiven Angebote
  static Future<List<ExtractedDeal>> getActiveDeals() async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      _dealsTable,
      where: 'isActive = ? AND validUntil > ?',
      whereArgs: [1, now],
      orderBy: 'discountPercentage DESC',
    );

    return results.map((map) => ExtractedDeal.fromDatabase(map)).toList();
  }

  /// Lädt Angebote für einen bestimmten Supermarkt
  static Future<List<ExtractedDeal>> getDealsBySupermarket(
    String supermarket,
  ) async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      _dealsTable,
      where: 'supermarket = ? AND isActive = ? AND validUntil > ?',
      whereArgs: [supermarket, 1, now],
      orderBy: 'discountPercentage DESC',
    );

    return results.map((map) => ExtractedDeal.fromDatabase(map)).toList();
  }

  /// Lädt Angebote nach Kategorie
  static Future<List<ExtractedDeal>> getDealsByCategory(
    String category,
  ) async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      _dealsTable,
      where: 'productCategory = ? AND isActive = ? AND validUntil > ?',
      whereArgs: [category, 1, now],
      orderBy: 'discountPercentage DESC',
    );

    return results.map((map) => ExtractedDeal.fromDatabase(map)).toList();
  }

  /// Sucht Angebote nach Produktname
  static Future<List<ExtractedDeal>> searchDeals(String query) async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      _dealsTable,
      where: 'productName LIKE ? AND isActive = ? AND validUntil > ?',
      whereArgs: ['%$query%', 1, now],
      orderBy: 'discountPercentage DESC',
    );

    return results.map((map) => ExtractedDeal.fromDatabase(map)).toList();
  }

  /// Lädt Top-Angebote (höchster Rabatt)
  static Future<List<ExtractedDeal>> getTopDeals({int limit = 10}) async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      _dealsTable,
      where: 'isActive = ? AND validUntil > ?',
      whereArgs: [1, now],
      orderBy: 'discountPercentage DESC',
      limit: limit,
    );

    return results.map((map) => ExtractedDeal.fromDatabase(map)).toList();
  }

  /// Findet Angebot nach ID
  static Future<ExtractedDeal?> getDealById(String id) async {
    final db = await database;

    final results = await db.query(
      _dealsTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    return ExtractedDeal.fromDatabase(results.first);
  }

  /// Aktualisiert ein Angebot
  static Future<void> updateDeal(ExtractedDeal deal) async {
    final db = await database;

    await db.update(
      _dealsTable,
      deal.toDatabase(),
      where: 'id = ?',
      whereArgs: [deal.id],
    );

  }

  /// Deaktiviert ein Angebot
  static Future<void> deactivateDeal(String id) async {
    final db = await database;

    await db.update(
      _dealsTable,
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

  }

  /// Löscht abgelaufene Angebote
  static Future<int> deleteExpiredDeals() async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    final count = await db.delete(
      _dealsTable,
      where: 'validUntil < ?',
      whereArgs: [now],
    );

    return count;
  }

  /// Löscht alle Angebote
  static Future<void> deleteAllDeals() async {
    final db = await database;
    await db.delete(_dealsTable);
  }

  /// Markiert PDF als gescannt
  static Future<void> markPdfAsScanned(
    String fileName,
    String supermarket,
    int dealCount,
  ) async {
    final db = await database;

    await db.insert(
      _scannedPdfsTable,
      {
        'fileName': fileName,
        'supermarket': supermarket,
        'scannedAt': DateTime.now().toIso8601String(),
        'dealCount': dealCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

  }

  /// Prüft ob PDF bereits gescannt wurde
  static Future<bool> isPdfAlreadyScanned(String fileName) async {
    final db = await database;

    final results = await db.query(
      _scannedPdfsTable,
      where: 'fileName = ?',
      whereArgs: [fileName],
    );

    return results.isNotEmpty;
  }

  /// Lädt gescannte PDF-Historie
  static Future<List<Map<String, dynamic>>> getScannedPdfHistory() async {
    final db = await database;

    final results = await db.query(
      _scannedPdfsTable,
      orderBy: 'scannedAt DESC',
    );

    return results;
  }

  /// Statistiken
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    // Anzahl aktiver Angebote
    final activeCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_dealsTable WHERE isActive = 1 AND validUntil > ?',
      [now],
    );
    final activeCount = activeCountResult.first['count'] as int;

    // Anzahl nach Supermarkt
    final supermarketCounts = await db.rawQuery(
      'SELECT supermarket, COUNT(*) as count FROM $_dealsTable WHERE isActive = 1 AND validUntil > ? GROUP BY supermarket',
      [now],
    );

    // Durchschnittlicher Rabatt
    final avgDiscountResult = await db.rawQuery(
      'SELECT AVG(discountPercentage) as avg FROM $_dealsTable WHERE isActive = 1 AND validUntil > ?',
      [now],
    );
    final avgDiscount = avgDiscountResult.first['avg'] as double? ?? 0.0;

    // Top Kategorie
    final topCategoryResult = await db.rawQuery(
      'SELECT productCategory, COUNT(*) as count FROM $_dealsTable WHERE isActive = 1 AND validUntil > ? AND productCategory IS NOT NULL GROUP BY productCategory ORDER BY count DESC LIMIT 1',
      [now],
    );

    return {
      'totalActiveDeals': activeCount,
      'dealsBySupermarket': supermarketCounts,
      'averageDiscount': avgDiscount,
      'topCategory': topCategoryResult.isNotEmpty ? topCategoryResult.first['productCategory'] : null,
    };
  }

  /// Schließt die Datenbank
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
