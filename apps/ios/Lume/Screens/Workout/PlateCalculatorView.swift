import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var target = 100
    private let bar = 20.0
    private let available: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    private var perSide: [Double] {
        PlateMath.perSide(target: Double(target), bar: bar, available: available)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LumeCard(padding: Spacing.xxl, radius: Radius.xxl) {
                    VStack(spacing: Spacing.lg) {
                        Text("Charge totale").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(target)").font(.lumeNumberXL).foregroundStyle(LumeColor.ink).monospacedDigit()
                            Text("kg").font(.lumeHeadline).foregroundStyle(LumeColor.muted)
                        }
                        HStack(spacing: Spacing.xl) {
                            RoundIconButton(icon: .minus, size: 48) { target = max(Int(bar), target - 5) }
                            RoundIconButton(icon: .add, filled: true, size: 48) { target += 5 }
                        }
                    }.frame(maxWidth: .infinity)
                }
                LumeCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Par côté (barre \(bar.clean) kg)").font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                        PlateView(perSide: perSide)
                        if perSide.isEmpty {
                            Text("Barre à vide").font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                        } else {
                            Text(perSide.map { $0.clean }.joined(separator: " + ") + " kg")
                                .font(.lumeCallout).foregroundStyle(LumeColor.textSecondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Calcul des disques", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }
}

#Preview { PlateCalculatorView() }
