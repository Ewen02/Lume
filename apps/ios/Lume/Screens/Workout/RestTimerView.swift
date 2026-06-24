import SwiftUI

/// Minuteur de repos robuste : ancré sur une `endDate`, donc juste même si l'app passe en
/// arrière-plan ou est fermée (le décompte se recalcule depuis l'heure réelle), et notifie
/// la fin via une notification locale `time-sensitive`.
struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var total: Int
    @State private var endDate: Date
    @State private var finished = false
    @State private var now = Date()
    /// Remonte la durée choisie pour la réutiliser à la prochaine série.
    var onDurationChange: (Int) -> Void = { _ in }

    private static let presets = [60, 90, 120, 180]
    /// Tick d'affichage (le temps réel vient de `endDate`, pas de l'accumulation de ticks).
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(seconds: Int = 90, onDurationChange: @escaping (Int) -> Void = { _ in }) {
        _total = State(initialValue: seconds)
        _endDate = State(initialValue: Date().addingTimeInterval(TimeInterval(seconds)))
        self.onDurationChange = onDurationChange
    }

    /// Secondes restantes, calculées depuis l'heure réelle (jamais en retard/avance).
    private var remaining: Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    private var mmss: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Repos").font(.lumeHeadline).foregroundStyle(LumeColor.muted).padding(.top, Spacing.xl)

            HStack(spacing: Spacing.sm) {
                ForEach(Self.presets, id: \.self) { sec in
                    let active = total == sec
                    Button { setDuration(sec) } label: {
                        Text(label(for: sec)).font(.lumeSubhead.weight(.semibold))
                            .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
                            .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.md)
                            .background(active ? LumeColor.ink : LumeColor.surface)
                            .clipShape(Capsule()).lumeShadow(.soft)
                    }.buttonStyle(.lumePress)
                }
            }

            ProgressRing(progress: Double(remaining) / Double(max(total, 1)),
                         color: remaining == 0 ? LumeColor.success : LumeColor.fat, lineWidth: 14)
            {
                Text(mmss).font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    .contentTransition(.numericText(value: Double(remaining)))
            }
            .frame(width: 200, height: 200)
            .scaleEffect(finished ? 1.06 : 1)
            .animation(LumeMotion.celebrate, value: finished)

            HStack(spacing: Spacing.xl) {
                pill("−15 s") { adjust(-15) }
                Button { stopAndDismiss() } label: {
                    Text(remaining == 0 ? "Terminé" : "Passer").font(.lumeCallout).foregroundStyle(LumeColor.surface)
                        .padding(.vertical, Spacing.md).padding(.horizontal, Spacing.xxl)
                        .background(LumeColor.ink).clipShape(Capsule())
                }.buttonStyle(.lumePress)
                pill("+15 s") { adjust(15) }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: finished)
        .sensoryFeedback(.selection, trigger: total)
        .onAppear { NotificationManager.scheduleRestEnd(in: remaining) }
        .onDisappear { NotificationManager.cancelRestEnd() }
        .onReceive(tick) { date in
            now = date
            if remaining == 0, !finished { finished = true }
        }
    }

    private func label(for seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds)s"
    }

    /// Choisit une durée préréglée : réancre la fin et reprogramme la notification.
    private func setDuration(_ seconds: Int) {
        withAnimation(LumeMotion.snappy) {
            total = seconds
            endDate = Date().addingTimeInterval(TimeInterval(seconds))
            finished = false
        }
        NotificationManager.scheduleRestEnd(in: seconds)
        onDurationChange(seconds)
    }

    private func adjust(_ delta: Int) {
        let newRemaining = max(0, remaining + delta)
        withAnimation(LumeMotion.snappy) {
            endDate = Date().addingTimeInterval(TimeInterval(newRemaining))
            total = max(total, newRemaining)
            if newRemaining > 0 { finished = false }
        }
        NotificationManager.scheduleRestEnd(in: newRemaining)
        onDurationChange(total)
    }

    private func stopAndDismiss() {
        NotificationManager.cancelRestEnd()
        dismiss()
    }

    private func pill(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                .padding(.vertical, Spacing.md).padding(.horizontal, Spacing.lg)
                .background(LumeColor.surface).clipShape(Capsule()).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }
}

#Preview { RestTimerView() }
