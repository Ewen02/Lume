import SwiftData
import SwiftUI

struct WaterDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var logs: [WaterLog]
    @Query private var profiles: [ProfileRecord]
    @Environment(HealthManager.self) private var health

    init() {
        let dayStart = Calendar.current.startOfDay(for: Date())
        _logs = Query(filter: #Predicate<WaterLog> { $0.day >= dayStart }, sort: \WaterLog.day, order: .reverse)
    }

    /// Objectif d'hydratation (réglable, depuis le profil).
    private var total: Int { max(1, profiles.first?.waterGoalGlasses ?? 8) }
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

    /// Met à jour l'objectif d'hydratation (persisté dans le profil).
    private func setGoal(_ n: Int) {
        let clamped = min(16, max(1, n))
        if let r = profiles.first { r.waterGoalGlasses = clamped }
        else { let r = ProfileRecord(name: ""); r.waterGoalGlasses = clamped; ctx.insert(r) }
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
                        HStack {
                            Text("Objectif").font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                            Spacer()
                            Stepper("\(total) verres (≈ \(String(format: "%.1f", Double(total) * 0.25)) L)",
                                    value: Binding(get: { total }, set: { setGoal($0) }), in: 1 ... 16)
                                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink).fixedSize()
                        }
                        HStack(spacing: Spacing.sm) {
                            ForEach(Array(0 ..< total), id: \.self) { i in
                                Image(appIcon: .water).lumeIcon(18, weight: .semibold)
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
