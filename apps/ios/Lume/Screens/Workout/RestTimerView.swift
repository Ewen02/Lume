import SwiftUI

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var total: Int
    @State private var finished = false
    @State private var running = true

    init(seconds: Int = 90) {
        _remaining = State(initialValue: seconds)
        _total = State(initialValue: seconds)
    }

    private var mmss: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Repos").font(.lumeHeadline).foregroundStyle(LumeColor.muted).padding(.top, Spacing.xl)
            ProgressRing(progress: Double(remaining) / Double(max(total, 1)),
                         color: remaining == 0 ? LumeColor.success : LumeColor.fat, lineWidth: 14)
            {
                Text(mmss).font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                    .contentTransition(.numericText(value: Double(remaining)))
            }
            .frame(width: 220, height: 220)
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
