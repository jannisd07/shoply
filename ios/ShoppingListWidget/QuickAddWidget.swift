//
//  QuickAddWidget.swift
//  ShoppingListWidget
//
//  Quick-add widget: shows the user's most frequently bought items
//  (written by the app from item_purchase_stats) and lets them add one to
//  their shopping list with a single tap, without opening the app.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Model

struct RecentItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String?
    let quantity: Double
}

private let kRecentItemsKey = "widget_recent_items"
private let kSupabaseUserIdKey = "widget_supabase_user_id"

func loadRecentItems() -> [RecentItem] {
    guard let defaults = UserDefaults(suiteName: kAppGroupId),
          let jsonString = defaults.string(forKey: kRecentItemsKey),
          let jsonData = jsonString.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
        return []
    }
    return array.compactMap { dict in
        guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
        let category = dict["category"] as? String
        let quantity = (dict["quantity"] as? NSNumber)?.doubleValue ?? 1.0
        return RecentItem(id: name.lowercased(), name: name, category: category, quantity: quantity)
    }
}

// MARK: - Quick Add Intent

struct QuickAddItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Item"
    static var description = IntentDescription("Add a frequently bought item straight to your shopping list.")

    @Parameter(title: "Item Name")
    var itemName: String

    @Parameter(title: "Category")
    var category: String?

    @Parameter(title: "Quantity")
    var quantity: Double

    @Parameter(title: "List ID")
    var listId: String

    init() {}

    init(itemName: String, category: String?, quantity: Double, listId: String) {
        self.itemName = itemName
        self.category = category
        self.quantity = quantity
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        await quickAddItem(name: itemName, category: category, quantity: quantity, listId: listId)
        return .result()
    }
}

/// Inserts the item directly via the Supabase REST API — the widget
/// process has no Flutter/Dart runtime, so it uses the same
/// direct-REST-with-cached-credentials pattern as `syncToggleToSupabase`.
/// Never throws: a failed insert just means the tap silently did nothing,
/// same fail-open behavior as the existing toggle sync.
func quickAddItem(name: String, category: String?, quantity: Double, listId: String) async {
    guard !listId.isEmpty,
          let defaults = UserDefaults(suiteName: kAppGroupId),
          let supabaseUrl = defaults.string(forKey: kSupabaseUrlKey),
          let anonKey = defaults.string(forKey: kSupabaseAnonKey),
          let accessToken = defaults.string(forKey: kSupabaseAccessTokenKey),
          let userId = defaults.string(forKey: kSupabaseUserIdKey),
          !supabaseUrl.isEmpty, !anonKey.isEmpty, !accessToken.isEmpty, !userId.isEmpty else {
        print("⚠️ [Widget] Quick-add skipped: missing credentials or list")
        return
    }

    guard let url = URL(string: "\(supabaseUrl)/rest/v1/shopping_items") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("return=representation", forHTTPHeaderField: "Prefer")

    var body: [String: Any] = [
        "list_id": listId,
        "name": name,
        "quantity": quantity,
        "added_by": userId,
        "is_checked": false,
    ]
    if let category = category, !category.isEmpty {
        body["category"] = category
        body["category_id"] = category
    }
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            print("⚠️ [Widget] Quick-add failed: \(response)")
            return
        }
        print("✅ [Widget] Quick-added \"\(name)\" to list \(listId)")

        // Reflect the new item in the widget's own cached copy of this list
        // immediately, so the shopping-list widget doesn't wait up to 30
        // minutes for its next timeline refresh to show it.
        if let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let inserted = rows.first {
            appendItemToCachedList(listId: listId, inserted: inserted)
        }
    } catch {
        print("⚠️ [Widget] Quick-add error: \(error)")
    }

    WidgetCenter.shared.reloadTimelines(ofKind: "ShoppingListWidget")
}

private func appendItemToCachedList(listId: String, inserted: [String: Any]) {
    guard let defaults = UserDefaults(suiteName: kAppGroupId) else { return }
    let key = kWidgetDataPrefix + listId
    guard let jsonString = defaults.string(forKey: key),
          let jsonData = jsonString.data(using: .utf8),
          var dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          var itemsArray = dict["items"] as? [[String: Any]],
          let id = inserted["id"] as? String,
          let name = inserted["name"] as? String else {
        return
    }

    let quantity = (inserted["quantity"] as? NSNumber)?.intValue ?? 1
    itemsArray.append([
        "id": id,
        "name": name,
        "quantity": quantity,
        "isChecked": false,
    ])

    let itemCount = itemsArray.count
    let checkedCount = itemsArray.filter { $0["isChecked"] as? Bool ?? false }.count
    dict["items"] = itemsArray
    dict["itemCount"] = itemCount
    dict["checkedCount"] = checkedCount
    dict["uncheckedCount"] = itemCount - checkedCount

    if let updatedData = try? JSONSerialization.data(withJSONObject: dict),
       let updatedString = String(data: updatedData, encoding: .utf8) {
        defaults.set(updatedString, forKey: key)
        defaults.synchronize()
    }
}

// MARK: - Timeline

struct QuickAddEntry: TimelineEntry {
    let date: Date
    let items: [RecentItem]
    let listId: String
    let listName: String
}

struct QuickAddProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(
            date: Date(),
            items: [
                RecentItem(id: "milch", name: "Milch", category: "dairy", quantity: 1),
                RecentItem(id: "brot", name: "Brot", category: "bakery", quantity: 1),
                RecentItem(id: "eier", name: "Eier", category: "dairy", quantity: 6),
            ],
            listId: "placeholder",
            listName: "Einkaufsliste"
        )
    }

    func snapshot(for configuration: SelectListIntent, in context: Context) async -> QuickAddEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectListIntent, in context: Context) async -> Timeline<QuickAddEntry> {
        let e = entry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [e], policy: .after(nextUpdate))
    }

    private func entry(for configuration: SelectListIntent) -> QuickAddEntry {
        let lists = loadAvailableLists()
        let targetList = configuration.shoppingList.flatMap { selected in
            lists.first(where: { $0.id == selected.id })
        } ?? lists.first
        return QuickAddEntry(
            date: Date(),
            items: loadRecentItems(),
            listId: targetList?.id ?? "",
            listName: targetList?.name ?? "Shoply"
        )
    }
}

// MARK: - Views

private struct QuickAddRow: View {
    let item: RecentItem
    let listId: String
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var accent: Color { Color(red: 0.3, green: 0.75, blue: 0.4) }
    private var rowBg: Color { isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.045) }

    var body: some View {
        Button(intent: QuickAddItemIntent(itemName: item.name, category: item.category, quantity: item.quantity, listId: listId)) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(fg)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(rowBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct QuickAddWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuickAddEntry
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var bg: Color { isDark ? Color(white: 0.11) : .white }
    private var maxItems: Int { family == .systemSmall ? 3 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fg)
                Text("Schnell hinzufügen")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(fg)
                    .lineLimit(1)
            }

            if entry.listId.isEmpty || entry.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(muted)
                        Text(entry.listId.isEmpty ? "Keine Liste ausgewählt" : "Noch keine Vorschläge")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(muted)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                let visible = Array(entry.items.prefix(maxItems))
                ForEach(visible) { item in
                    QuickAddRow(item: item, listId: entry.listId)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Widget

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectListIntent.self, provider: QuickAddProvider()) { entry in
            if #available(iOS 17.0, *) {
                QuickAddWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                QuickAddWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Schnell hinzufügen")
        .description("Füge häufig gekaufte Artikel mit einem Tipp zu deiner Liste hinzu.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
