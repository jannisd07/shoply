//
//  ShoppingListWidget.swift
//  ShoppingListWidget
//
//  Created by Dominik Klossika on 3/28/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group Constants

let kAppGroupId = "group.com.shoply.app"
let kWidgetDataKey = "widget_shopping_list"
let kPendingTogglesKey = "widget_pending_toggles"

// MARK: - Data Models

struct ShoppingListData {
    let listId: String
    let listName: String
    let items: [ShoppingItem]
    let itemCount: Int
    let checkedCount: Int
    let uncheckedCount: Int
    let updatedAt: Date?

    static let placeholder = ShoppingListData(
        listId: "placeholder",
        listName: "Einkaufsliste",
        items: [
            ShoppingItem(id: "1", name: "Milch", quantity: 1, isChecked: false),
            ShoppingItem(id: "2", name: "Brot", quantity: 2, isChecked: false),
            ShoppingItem(id: "3", name: "Eier", quantity: 6, isChecked: false),
            ShoppingItem(id: "4", name: "Butter", quantity: 1, isChecked: false),
            ShoppingItem(id: "5", name: "Tomaten", quantity: 4, isChecked: false),
            ShoppingItem(id: "6", name: "Käse", quantity: 1, isChecked: true),
        ],
        itemCount: 6,
        checkedCount: 1,
        uncheckedCount: 5,
        updatedAt: Date()
    )

    static let empty = ShoppingListData(
        listId: "",
        listName: "Shoply",
        items: [],
        itemCount: 0,
        checkedCount: 0,
        uncheckedCount: 0,
        updatedAt: nil
    )
}

struct ShoppingItem: Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let isChecked: Bool
}

// MARK: - Data Loading Helpers

func loadWidgetData() -> ShoppingListData {
    guard let defaults = UserDefaults(suiteName: kAppGroupId),
          let jsonString = defaults.string(forKey: kWidgetDataKey),
          let jsonData = jsonString.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
        return .empty
    }

    let listId = dict["listId"] as? String ?? ""
    let listName = dict["listName"] as? String ?? "Einkaufsliste"
    let itemCount = dict["itemCount"] as? Int ?? 0
    let checkedCount = dict["checkedCount"] as? Int ?? 0
    let uncheckedCount = dict["uncheckedCount"] as? Int ?? 0

    var items: [ShoppingItem] = []
    if let itemsArray = dict["items"] as? [[String: Any]] {
        items = itemsArray.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            let quantity = item["quantity"] as? Int ?? 1
            let isChecked = item["isChecked"] as? Bool ?? false
            return ShoppingItem(id: id, name: name, quantity: quantity, isChecked: isChecked)
        }
    }

    return ShoppingListData(
        listId: listId,
        listName: listName,
        items: items,
        itemCount: itemCount,
        checkedCount: checkedCount,
        uncheckedCount: uncheckedCount,
        updatedAt: Date()
    )
}

func toggleItemInDefaults(itemId: String) {
    guard let defaults = UserDefaults(suiteName: kAppGroupId),
          let jsonString = defaults.string(forKey: kWidgetDataKey),
          let jsonData = jsonString.data(using: .utf8),
          var dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          var itemsArray = dict["items"] as? [[String: Any]] else {
        return
    }

    // Toggle the item
    for i in 0..<itemsArray.count {
        if itemsArray[i]["id"] as? String == itemId {
            let wasChecked = itemsArray[i]["isChecked"] as? Bool ?? false
            itemsArray[i]["isChecked"] = !wasChecked
            break
        }
    }

    // Recalculate counts
    let checkedCount = itemsArray.filter { $0["isChecked"] as? Bool ?? false }.count
    let uncheckedCount = itemsArray.count - checkedCount

    dict["items"] = itemsArray
    dict["checkedCount"] = checkedCount
    dict["uncheckedCount"] = uncheckedCount

    // Save back
    if let updatedData = try? JSONSerialization.data(withJSONObject: dict),
       let updatedString = String(data: updatedData, encoding: .utf8) {
        defaults.set(updatedString, forKey: kWidgetDataKey)
    }

    // Store pending toggle for Flutter to sync
    var pendingToggles = defaults.array(forKey: kPendingTogglesKey) as? [[String: Any]] ?? []
    pendingToggles.append([
        "itemId": itemId,
        "timestamp": Date().timeIntervalSince1970,
    ])
    defaults.set(pendingToggles, forKey: kPendingTogglesKey)
    defaults.synchronize()
}

// MARK: - Toggle Intent

struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Shopping Item"
    static var description = IntentDescription("Check or uncheck a shopping list item")

    @Parameter(title: "Item ID")
    var itemId: String

    init() {}

    init(itemId: String) {
        self.itemId = itemId
    }

    func perform() async throws -> some IntentResult {
        toggleItemInDefaults(itemId: itemId)
        return .result()
    }
}

// MARK: - Timeline Provider

struct ShoppingListProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingListEntry {
        ShoppingListEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> Void) {
        let data = loadWidgetData()
        completion(ShoppingListEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> Void) {
        let data = loadWidgetData()
        let entry = ShoppingListEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct ShoppingListEntry: TimelineEntry {
    let date: Date
    let data: ShoppingListData
}

// MARK: - Shared Styles

private let checkboxSize: CGFloat = 20
private let itemSpacing: CGFloat = 2

// MARK: - Item Row View (Interactive)

struct ItemRowView: View {
    let item: ShoppingItem
    let fontSize: CGFloat
    let showQuantity: Bool
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var green: Color { Color(red: 0.3, green: 0.75, blue: 0.4) }

    var body: some View {
        Button(intent: ToggleItemIntent(itemId: item.id)) {
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    if item.isChecked {
                        Circle()
                            .fill(green)
                            .frame(width: checkboxSize, height: checkboxSize)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(muted, lineWidth: 1.5)
                            .frame(width: checkboxSize, height: checkboxSize)
                    }
                }
                .frame(width: checkboxSize, height: checkboxSize)

                // Item name + quantity
                HStack(spacing: 0) {
                    if showQuantity && item.quantity > 1 {
                        Text("\(item.quantity)x ")
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundColor(item.isChecked ? muted : fg)
                    }
                    Text(item.name)
                        .font(.system(size: fontSize, weight: item.isChecked ? .regular : .medium))
                        .foregroundColor(item.isChecked ? muted : fg)
                        .strikethrough(item.isChecked, color: muted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, itemSpacing)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: ShoppingListEntry
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var bg: Color { isDark ? Color(white: 0.11) : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fg)
                Text(entry.data.listName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(fg)
                    .lineLimit(1)
                Spacer()
                if entry.data.itemCount > 0 {
                    Text("\(entry.data.checkedCount)/\(entry.data.itemCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(muted)
                }
            }
            .padding(.bottom, 6)

            if entry.data.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(muted)
                        Text("All done!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(muted)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Show unchecked first, then checked — max items that fit
                let unchecked = entry.data.items.filter { !$0.isChecked }
                let checked = entry.data.items.filter { $0.isChecked }
                let allSorted = unchecked + checked
                let visibleItems = Array(allSorted.prefix(5))

                ForEach(visibleItems, id: \.id) { item in
                    ItemRowView(item: item, fontSize: 12, showQuantity: false)
                }

                Spacer(minLength: 0)

                let remaining = entry.data.itemCount - visibleItems.count
                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: ShoppingListEntry
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var bg: Color { isDark ? Color(white: 0.11) : .white }
    private var cardBg: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(fg)
                    Text(entry.data.listName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(fg)
                        .lineLimit(1)
                }
                Spacer()
                if entry.data.itemCount > 0 {
                    Text("\(entry.data.checkedCount)/\(entry.data.itemCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(cardBg)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 8)

            if entry.data.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 22))
                            .foregroundColor(muted)
                        Text("All done!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(muted)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                let unchecked = entry.data.items.filter { !$0.isChecked }
                let checked = entry.data.items.filter { $0.isChecked }
                let allSorted = unchecked + checked
                let maxItems = 8
                let visibleItems = Array(allSorted.prefix(maxItems))

                // Two-column layout
                let leftItems = Array(visibleItems.prefix((visibleItems.count + 1) / 2))
                let rightItems = Array(visibleItems.dropFirst(leftItems.count))

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(leftItems, id: \.id) { item in
                            ItemRowView(item: item, fontSize: 12, showQuantity: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !rightItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(rightItems, id: \.id) { item in
                                ItemRowView(item: item, fontSize: 12, showQuantity: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)

                let remaining = entry.data.itemCount - visibleItems.count
                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(muted)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: ShoppingListEntry
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var fg: Color { isDark ? .white : .black }
    private var muted: Color { isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35) }
    private var bg: Color { isDark ? Color(white: 0.11) : .white }
    private var cardBg: Color { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03) }
    private var green: Color { Color(red: 0.3, green: 0.75, blue: 0.4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(fg)
                    Text(entry.data.listName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(fg)
                        .lineLimit(1)
                }
                Spacer()
                if entry.data.itemCount > 0 {
                    Text("\(entry.data.checkedCount)/\(entry.data.itemCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(cardBg)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 4)

            // Progress bar
            if entry.data.itemCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cardBg)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(green)
                            .frame(width: geo.size.width * CGFloat(entry.data.checkedCount) / CGFloat(max(entry.data.itemCount, 1)), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 10)
            }

            if entry.data.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(green)
                        Text("All done!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(fg)
                        Text("Your list is empty")
                            .font(.system(size: 12))
                            .foregroundColor(muted)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Show unchecked first, then checked
                let unchecked = entry.data.items.filter { !$0.isChecked }
                let checked = entry.data.items.filter { $0.isChecked }
                let allSorted = unchecked + checked
                let maxItems = 14
                let visibleItems = Array(allSorted.prefix(maxItems))

                ForEach(visibleItems, id: \.id) { item in
                    ItemRowView(item: item, fontSize: 14, showQuantity: true)
                }

                Spacer(minLength: 0)

                let remaining = entry.data.itemCount - visibleItems.count
                if remaining > 0 {
                    Text("+\(remaining) more items")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(muted)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}

// MARK: - Widget Entry View

struct ShoppingListWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ShoppingListEntry

    private var deepLink: URL? {
        let listId = entry.data.listId
        guard !listId.isEmpty else { return nil }
        return URL(string: "shoply://list/\(listId)")
    }

    var body: some View {
        let view: AnyView
        switch family {
        case .systemSmall:
            view = AnyView(SmallWidgetView(entry: entry))
        case .systemMedium:
            view = AnyView(MediumWidgetView(entry: entry))
        case .systemLarge:
            view = AnyView(LargeWidgetView(entry: entry))
        default:
            view = AnyView(MediumWidgetView(entry: entry))
        }

        if let deepLink = deepLink {
            return AnyView(view.widgetURL(deepLink))
        } else {
            return AnyView(view)
        }
    }
}

// MARK: - Widget

struct ShoppingListWidget: Widget {
    let kind: String = "ShoppingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShoppingListProvider()) { entry in
            if #available(iOS 17.0, *) {
                ShoppingListWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                ShoppingListWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Shopping List")
        .description("View and check off your shopping list items.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct ShoppingListWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShoppingListWidget()
    }
}
