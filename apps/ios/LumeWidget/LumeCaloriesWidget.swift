import SwiftUI
import WidgetKit

/// Widget « Calories + macros du jour ».
/// Source : `WidgetStore.load()` (snapshot écrit par l'app via App Group). Aucun accès SwiftData ici.
struct LumeCaloriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LumeCaloriesWidget", provider: SnapshotProvider()) { entry in
            LumeWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color(red: 0.99, green: 0.98, blue: 0.95) }
        }
        .configurationDisplayName("Calories & macros")
        .description("Tes calories et macros du jour.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetStore.load())
        // L'app recharge la timeline à chaque changement ; on prévoit aussi un rafraîchissement horaire.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Vue

struct LumeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    // Couleurs locales (le widget n'a pas accès au design system de l'app sauf à partager les fichiers).
    private let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
    private let proteinColor = Color(red: 0.95, green: 0.33, blue: 0.18)
    private let carbsColor = Color(red: 0.95, green: 0.66, blue: 0.20)
    private let fatColor = Color(red: 0.20, green: 0.55, blue: 0.90)

    var body: some View {
        if family == .systemSmall { small } else { medium }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lume").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            Text("\(snapshot.kcal)").font(.system(size: 34, weight: .heavy)).foregroundStyle(ink)
                .monospacedDigit()
            Text("/ \(snapshot.targetKcal) kcal").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            Text("\(max(0, snapshot.targetKcal - snapshot.kcal)) restant")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lume").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.kcal) / \(snapshot.targetKcal) kcal")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ink).monospacedDigit()
            }
            macroBar("P", snapshot.protein, snapshot.targetProtein, proteinColor)
            macroBar("G", snapshot.carbs, snapshot.targetCarbs, carbsColor)
            macroBar("L", snapshot.fat, snapshot.targetFat, fatColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroBar(_ label: String, _ value: Int, _ target: Int, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(color).frame(width: 14, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color)
                        .frame(width: progress(value, target) * geo.size.width)
                }
            }.frame(height: 8)
            Text("\(value)g").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func progress(_ value: Int, _ target: Int) -> CGFloat {
        guard target > 0 else { return 0 }
        return min(1, max(0, CGFloat(value) / CGFloat(target)))
    }
}
