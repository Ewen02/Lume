import SwiftUI

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var total: Int
    @State private var finished = false
    @State private var running = true
    /// Remonte la durée choisie pour la réutiliser à la prochaine série.
    var onDurationChange: (Int) -> Void = { _ in }

    private static let presets = [60, 90, 120, 180]

    init(seconds: Int = 90, onDurationChange: @escaping (Int) -> Void = { _ in }) {
        _remaining = State(initialValue: seconds)
        _total = State(initialValue: seconds)
        self.onDurationChange = onDurationChange
    }

    private var mmss: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Repos").font(.lumeHeadline).foregroundStyle(LumeColor.muted).padding(.top, Spacing.xl)

            // Présélections de durée.
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
                Button { dismiss() } label: {
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
        // Décompte réel : un tick par seconde tant qu'il reste du temps.
        .task {
            while running, remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(LumeMotion.smooth) { remaining = max(0, remaining - 1) }
                if remaining == 0 { finished = true }
            }
        }
    }

    private func label(for seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds)s"
    }

    /// Choisit une durée préréglée : réinitialise le décompte et mémorise le choix.
    private func setDuration(_ seconds: Int) {
        withAnimation(LumeMotion.snappy) {
            total = seconds
            remaining = seconds
            finished = false
        }
        onDurationChange(seconds)
    }

    private func adjust(_ delta: Int) {
        withAnimation(LumeMotion.snappy) {
            remaining = max(0, remaining + delta)
            total = max(total, remaining)
            if remaining > 0 { finished = false }
        }
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
