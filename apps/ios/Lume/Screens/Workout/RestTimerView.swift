import SwiftUI

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remaining = 90
    private let total = 90
    private var mmss: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Text("Repos").font(.lumeHeadline).foregroundStyle(LumeColor.muted).padding(.top, Spacing.xl)
            ProgressRing(progress: Double(remaining) / Double(total), color: LumeColor.fat, lineWidth: 14) {
                Text(mmss).font(.system(size: 48, weight: .heavy)).foregroundStyle(LumeColor.ink).monospacedDigit()
            }.frame(width: 220, height: 220)
            HStack(spacing: Spacing.xl) {
                pill("−15 s") { remaining = max(0, remaining - 15) }
                Button { dismiss() } label: {
                    Text("Passer").font(.lumeCallout).foregroundStyle(LumeColor.surface)
                        .padding(.vertical, Spacing.md).padding(.horizontal, Spacing.xxl)
                        .background(LumeColor.ink).clipShape(Capsule())
                }.buttonStyle(.plain)
                pill("+15 s") { remaining += 15 }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(LumeColor.cream.ignoresSafeArea())
    }

    private func pill(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                .padding(.vertical, Spacing.md).padding(.horizontal, Spacing.lg)
                .background(LumeColor.surface).clipShape(Capsule()).lumeShadow(.soft)
        }.buttonStyle(.plain)
    }
}

#Preview { RestTimerView() }
