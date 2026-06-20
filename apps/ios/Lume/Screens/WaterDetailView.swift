import SwiftData
import SwiftUI

struct WaterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var logs: [WaterLog]
    @Environment(HealthManager.self) private var health

    init() {
        let dayStart = Calendar.current.startOfDay(for: Date())
        _logs = Query(filter: #Predicate<WaterLog> { $0.day >= dayStart }, sort: \WaterLog.day, order: .reverse)
    }

    private let total = 8
    private let cal = Calendar.current

    private var todayLog: WaterLog? {
        logs.first { cal.isDate($0.day, inSameDayAs: Date()) }
    }

    private var filled: Int {
        todayLog?.glasses ?? 0
    }

    private func set(_ n: Int) {
        let clamped = max(0, min(total, n))
        let prev = filled
        if let log = todayLog { log.glasses = clamped }
        else { ctx.insert(WaterLog(day: cal.startOfDay(for: Date()), glasses: clamped)) }
        if clamped > prev { Task { await health.logWater(milliliters: Double(clamped - prev) * 250) } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                    VStack(spacing: Spacing.lg) {
                        ProgressRing(progress: Double(filled) / Double(total), color: LumeColor.fat, lineWidth: 12) {
                            VStack(spacing: 0) {
                                Text("\(filled)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink)
                                Text("/ \(total) verres").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                            }
                        }.frame(width: 180, height: 180)
                        HStack(spacing: Spacing.xl) {
                            RoundIconButton(icon: .minus, size: 52) { set(filled - 1) }
                            RoundIconButton(icon: .add, filled: true, size: 52) { set(filled + 1) }
                        }
                    }.frame(maxWidth: .infinity)
                }
                LumeCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Objectif : \(total) verres (≈ 2 L)").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                        HStack(spacing: Spacing.sm) {
                            ForEach(0 ..< total, id: \.self) { i in
                                Image(appIcon: .water).lumeIcon(20, weight: .semibold)
                                    .foregroundStyle(i < filled ? LumeColor.fat : LumeColor.faint)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(trigger: filled) { old, new in new > old ? .increase : (new < old ? .decrease : nil) }
        .safeAreaInset(edge: .top) {
            TopBar(title: "Eau", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { WaterDetailView().modelContainer(LumeStore.preview).environment(HealthManager.shared) }
