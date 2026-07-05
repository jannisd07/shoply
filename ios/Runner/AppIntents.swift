import Foundation
import AppIntents
import UIKit
import SwiftUI

// MARK: - Shared App Group Helpers
//
// The Flutter app already keeps a live cache of the user's real lists in the
// App Group (`WidgetService.updateAvailableLists`, written on every list load
// — see `ShoppingListWidget.swift`'s `loadAvailableLists()` for the sibling
// reader in the widget extension target). Siri/Shortcuts reads that same
// cache instead of a separate, never-populated key.
private let kShoplyAppGroupId = "group.com.shoply.app"
private let kShoplyAvailableListsKey = "widget_available_lists"

private func loadShoplyListNames() -> [String] {
    guard let defaults = UserDefaults(suiteName: kShoplyAppGroupId),
          let jsonString = defaults.string(forKey: kShoplyAvailableListsKey),
          let jsonData = jsonString.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: String]] else {
        return []
    }
    return array.compactMap { $0["name"] }
}

// MARK: - Item Name Entity
@available(iOS 16.0, *)
struct ItemNameEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Artikel"
    static var defaultQuery = ItemNameQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 16.0, *)
struct ItemNameQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ItemNameEntity] {
        return identifiers.map { ItemNameEntity(id: $0) }
    }
    
    func suggestedEntities() async throws -> [ItemNameEntity] {
        // Suggest common items
        return [
            "Milch", "Brot", "Eier", "Butter", "Käse",
            "Äpfel", "Bananen", "Tomaten", "Kartoffeln"
        ].map { ItemNameEntity(id: $0) }
    }
}

// MARK: - List Name Entity
@available(iOS 16.0, *)
struct ListNameEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Liste"
    static var defaultQuery = ListNameQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 16.0, *)
struct ListNameQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ListNameEntity] {
        return identifiers.map { ListNameEntity(id: $0) }
    }
    
    func suggestedEntities() async throws -> [ListNameEntity] {
        var lists = loadShoplyListNames()
        if lists.isEmpty { lists = ["Einkaufsliste"] }

        // Add "New List" option at the end
        lists.append("➕ Neue Liste erstellen")

        return lists.map { ListNameEntity(id: $0) }
    }

    func defaultResult() async -> ListNameEntity? {
        return ListNameEntity(id: loadShoplyListNames().first ?? "Einkaufsliste")
    }
}

// MARK: - Add Item Intent
@available(iOS 16.0, *)
struct AddItemToListIntent: AppIntent {
    static var title: LocalizedStringResource = "Artikel zur Einkaufsliste hinzufügen"
    static var description = IntentDescription("Fügt einen Artikel zu deiner Shoply Einkaufsliste hinzu")
    static var openAppWhenRun: Bool = true // App öffnen!
    
    @Parameter(title: "Artikelname", requestValueDialog: IntentDialog("Welches Produkt möchtest du hinzufügen?"))
    var itemName: ItemNameEntity
    
    @Parameter(title: "Liste", requestValueDialog: IntentDialog("Zu welcher Liste soll ich \(\.$itemName) hinzufügen?"))
    var listName: ListNameEntity
    
    @Parameter(title: "Menge", default: 1.0)
    var quantity: Double?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Füge \(\.$itemName) zu \(\.$listName) hinzu") {
            \.$quantity
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var targetList = listName.id
        let item = itemName.id
        
        // Check if user wants to create a new list
        if targetList == "➕ Neue Liste erstellen" {
            // Ask for new list name using requestDisambiguation with a text field
            let dialog = IntentDialog("Wie soll die neue Liste heißen?")
            
            // Request a new list name as text input
            let newListEntity = try await $listName.requestValue(dialog)
            
            // If they entered text, use it as the new list name
            let newListName = newListEntity.id
            
            // Only proceed if it's not the placeholder; the Flutter side creates
            // the list on the fly if no existing list has this name (see
            // DeepLinkService's add-item handler), so no App Group bookkeeping
            // is needed here beyond passing the chosen name along.
            if newListName != "➕ Neue Liste erstellen" && !newListName.isEmpty {
                targetList = newListName
            }
        }

        // Hand off to the Flutter app via a deep link — mirrors the working
        // pattern used by the recipe intents below (URL-open), instead of the
        // old App Group "pending_items" queue that Flutter never read (it
        // lived in a different UserDefaults suite with different key names,
        // so items added via Siri silently vanished).
        var components = URLComponents(string: "shoply://add-item")!
        components.queryItems = [
            URLQueryItem(name: "name", value: item),
            URLQueryItem(name: "list", value: targetList),
            URLQueryItem(name: "quantity", value: "\(quantity ?? 1.0)"),
        ]
        if let url = components.url {
            await UIApplication.shared.open(url)
        }

        return .result(
            dialog: IntentDialog("\(item) wurde zu \(targetList) hinzugefügt"),
            view: AddItemResultView(itemName: item, listName: targetList)
        )
    }
}

// MARK: - Result View
@available(iOS 16.0, *)
struct AddItemResultView: View {
    let itemName: String
    let listName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("✓ Hinzugefügt")
                .font(.headline)
            
            Text("\(itemName)")
                .font(.title2)
                .bold()
            
            Text("zu \(listName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Create List Intent
@available(iOS 16.0, *)
struct CreateListIntent: AppIntent {
    static var title: LocalizedStringResource = "Neue Einkaufsliste erstellen"
    static var description = IntentDescription("Erstellt eine neue Einkaufsliste in Shoply")
    static var openAppWhenRun: Bool = true // App öffnen!
    
    @Parameter(title: "Listenname")
    var listName: ListNameEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Erstelle Liste \(\.$listName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = listName.id
        let alreadyExists = loadShoplyListNames().contains { $0.caseInsensitiveCompare(name) == .orderedSame }

        var components = URLComponents(string: "shoply://create-list")!
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        if let url = components.url {
            await UIApplication.shared.open(url)
        }

        return .result(dialog: alreadyExists
            ? "Liste '\(name)' existiert bereits — ich öffne sie"
            : "Liste '\(name)' wird erstellt")
    }
}

// MARK: - Show Shopping Lists Intent
@available(iOS 16.0, *)
struct ShowShoppingListsIntent: AppIntent {
    static var title: LocalizedStringResource = "Einkaufslisten anzeigen"
    static var description = IntentDescription("Zeigt deine Shoply Einkaufslisten an")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Open the app
        if let url = URL(string: "shoply://lists") {
            await UIApplication.shared.open(url)
        }
        return .result(dialog: "Öffne deine Einkaufslisten")
    }
}

// MARK: - Recipe Search Query Entity
@available(iOS 16.0, *)
struct RecipeQueryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Rezeptsuche"
    static var defaultQuery = RecipeQueryQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 16.0, *)
struct RecipeQueryQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RecipeQueryEntity] {
        return identifiers.map { RecipeQueryEntity(id: $0) }
    }
    
    func suggestedEntities() async throws -> [RecipeQueryEntity] {
        return [
            "Pasta", "Salat", "Suppe", "Hähnchen", "Vegetarisch",
            "Schnell", "Gesund", "Dessert", "Frühstück"
        ].map { RecipeQueryEntity(id: $0) }
    }
}

// MARK: - Search Recipes Intent
@available(iOS 16.0, *)
struct SearchRecipesIntent: AppIntent {
    static var title: LocalizedStringResource = "Rezepte suchen"
    static var description = IntentDescription("Sucht nach Rezepten in Shoply")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Suchbegriff", requestValueDialog: IntentDialog("Wonach möchtest du suchen?"))
    var searchQuery: RecipeQueryEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Suche nach \(\.$searchQuery) Rezepten")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let query = searchQuery.id

        // Open app with search — DeepLinkService parses the `q` query param
        // and passes it straight to RecipesScreen's search field.
        if let url = URL(string: "shoply://recipes/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") {
            await UIApplication.shared.open(url)
        }
        
        return .result(
            dialog: IntentDialog("Suche nach \(query) Rezepten..."),
            view: SearchRecipeResultView(query: query)
        )
    }
}

@available(iOS 16.0, *)
struct SearchRecipeResultView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("🔍 Suche")
                .font(.headline)
            
            Text(query)
                .font(.title2)
                .bold()
            
            Text("Rezepte werden gesucht...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Show Saved Recipes Intent
@available(iOS 16.0, *)
struct ShowSavedRecipesIntent: AppIntent {
    static var title: LocalizedStringResource = "Gespeicherte Rezepte anzeigen"
    static var description = IntentDescription("Zeigt deine gespeicherten Rezepte in Shoply an")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Open app to saved recipes — DeepLinkService routes this to
        // /recipes/saved directly.
        if let url = URL(string: "shoply://recipes/saved") {
            await UIApplication.shared.open(url)
        }
        
        return .result(
            dialog: IntentDialog("Öffne deine gespeicherten Rezepte"),
            view: SavedRecipesResultView()
        )
    }
}

@available(iOS 16.0, *)
struct SavedRecipesResultView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundColor(.pink)
            
            Text("❤️ Gespeicherte Rezepte")
                .font(.headline)
            
            Text("Öffne deine Favoriten")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Show Recipes Intent
@available(iOS 16.0, *)
struct ShowRecipesIntent: AppIntent {
    static var title: LocalizedStringResource = "Rezepte anzeigen"
    static var description = IntentDescription("Öffnet die Rezepte-Seite in Shoply")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let url = URL(string: "shoply://recipes") {
            await UIApplication.shared.open(url)
        }
        return .result(dialog: "Öffne Rezepte")
    }
}

// MARK: - App Shortcuts Provider
@available(iOS 16.0, *)
struct ShoplyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddItemToListIntent(),
            phrases: [
                "Füge \(\.$itemName) zu \(.applicationName) hinzu",
                "Trage \(\.$itemName) in \(.applicationName) ein",
                "Schreib \(\.$itemName) auf \(.applicationName)",
                "Add \(\.$itemName) to \(.applicationName)"
            ],
            shortTitle: "Artikel hinzufügen",
            systemImageName: "cart.badge.plus"
        )
        
        AppShortcut(
            intent: CreateListIntent(),
            phrases: [
                "Erstelle \(.applicationName) Liste \(\.$listName)",
                "Neue \(.applicationName) Liste \(\.$listName)",
                "Create \(.applicationName) list \(\.$listName)"
            ],
            shortTitle: "Liste erstellen",
            systemImageName: "list.bullet.circle"
        )
        
        AppShortcut(
            intent: ShowShoppingListsIntent(),
            phrases: [
                "Zeige meine \(.applicationName) Listen",
                "Öffne \(.applicationName)",
                "Open \(.applicationName)",
                "Show my \(.applicationName) lists"
            ],
            shortTitle: "Listen anzeigen",
            systemImageName: "list.bullet"
        )
        
        AppShortcut(
            intent: SearchRecipesIntent(),
            phrases: [
                "Suche \(\.$searchQuery) Rezepte in \(.applicationName)",
                "Finde \(\.$searchQuery) Rezept in \(.applicationName)",
                "Search \(\.$searchQuery) recipes in \(.applicationName)",
                "Find \(\.$searchQuery) recipe in \(.applicationName)"
            ],
            shortTitle: "Rezepte suchen",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: ShowSavedRecipesIntent(),
            phrases: [
                "Zeige gespeicherte Rezepte in \(.applicationName)",
                "Meine Lieblingsrezepte in \(.applicationName)",
                "Show saved recipes in \(.applicationName)",
                "My favorite recipes in \(.applicationName)"
            ],
            shortTitle: "Gespeicherte Rezepte",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: ShowRecipesIntent(),
            phrases: [
                "Zeige Rezepte in \(.applicationName)",
                "Öffne Rezepte in \(.applicationName)",
                "Show recipes in \(.applicationName)"
            ],
            shortTitle: "Rezepte",
            systemImageName: "book.fill"
        )
    }
}

