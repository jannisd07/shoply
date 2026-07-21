//
//  SavedRecipesWidget.swift
//  ShoppingListWidget
//
//  Shows the user's saved recipes for a one-tap jump back into cooking mode.
//  The App Group key + native "SavedRecipesWidget" timeline-reload call this
//  reads/reacts to already existed (AppDelegate.swift's
//  updateSavedRecipesWidget handler, wired since the widget extension was
//  first built) — this file is the WidgetKit widget that was never actually
//  built to consume that data, so the whole chain was a silent no-op.
//

import WidgetKit
import SwiftUI

// MARK: - Data Model

struct SavedRecipe: Identifiable, Hashable {
    let id: String
    let name: String
    let cookTime: Int?
    let rating: Double?
}

private let kSavedRecipesKey = "widget_saved_recipes"

func loadSavedRecipes() -> [SavedRecipe] {
    guard let defaults = UserDefaults(suiteName: kAppGroupId),
          let jsonString = defaults.string(forKey: kSavedRecipesKey),
          let jsonData = jsonString.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let array = dict["recipes"] as? [[String: Any]] else {
        return []
    }
    return array.compactMap { item in
        guard let id = item["id"] as? String,
              let name = item["name"] as? String, !name.isEmpty else { return nil }
        let cookTime = (item["cookTime"] as? NSNumber)?.intValue
        let rating = (item["rating"] as? NSNumber)?.doubleValue
        return SavedRecipe(id: id, name: name, cookTime: cookTime, rating: rating)
    }
}

// MARK: - Timeline

struct SavedRecipesEntry: TimelineEntry {
    let date: Date
    let recipes: [SavedRecipe]
}

struct SavedRecipesProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavedRecipesEntry {
        SavedRecipesEntry(
            date: Date(),
            recipes: [
                SavedRecipe(id: "1", name: "Spaghetti Carbonara", cookTime: 25, rating: 4.5),
                SavedRecipe(id: "2", name: "Gemüse-Curry", cookTime: 30, rating: 4.8),
                SavedRecipe(id: "3", name: "Pfannkuchen", cookTime: 15, rating: 4.2),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SavedRecipesEntry) -> Void) {
        completion(SavedRecipesEntry(date: Date(), recipes: loadSavedRecipes()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavedRecipesEntry>) -> Void) {
        let entry = SavedRecipesEntry(date: Date(), recipes: loadSavedRecipes())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Views

private struct SavedRecipeRow: View {
    let recipe: SavedRecipe
    let fontSize: CGFloat
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var accent: Color { Color(red: 0.3, green: 0.75, blue: 0.4) }

    var body: some View {
        Link(destination: URL(string: "shoply://recipe/\(recipe.id)")!) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accent)

                Text(recipe.name)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(fg)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let cookTime = recipe.cookTime, cookTime > 0 {
                    Text("\(cookTime) min")
                        .font(.system(size: fontSize - 2, weight: .medium, design: .rounded))
                        .foregroundColor(muted)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct SavedRecipesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SavedRecipesEntry
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var bg: Color { isDark ? Color(white: 0.11) : .white }

    private var maxItems: Int {
        switch family {
        case .systemSmall: return 3
        case .systemLarge: return 8
        default: return 4
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fg)
                Text("Rezepte")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(fg)
                    .lineLimit(1)
            }
            .padding(.bottom, 8)

            if entry.recipes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 20))
                            .foregroundColor(muted)
                        Text("Noch keine gespeicherten\nRezepte")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(muted)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                let visible = Array(entry.recipes.prefix(maxItems))
                ForEach(visible) { recipe in
                    SavedRecipeRow(recipe: recipe, fontSize: family == .systemSmall ? 12 : 13)
                }
                Spacer(minLength: 0)

                let remaining = entry.recipes.count - visible.count
                if remaining > 0 {
                    Text("+\(remaining) mehr")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Widget

struct SavedRecipesWidget: Widget {
    let kind: String = "SavedRecipesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavedRecipesProvider()) { entry in
            if #available(iOS 17.0, *) {
                SavedRecipesWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                SavedRecipesWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Gespeicherte Rezepte")
        .description("Deine gespeicherten Rezepte auf einen Blick — antippen zum Öffnen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
