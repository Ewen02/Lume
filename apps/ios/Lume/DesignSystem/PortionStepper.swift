import SwiftUI

struct PortionStepper: View {
    @Binding var grams: Int
    var step: Int = 10
    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundIconButton(icon: .minus) { grams = max(0, grams - step) }
            Text("\(grams) g").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
                .monospacedDigit().frame(minWidth: 44)
            RoundIconButton(icon: .add, filled: true) { grams += step }
        }
        .padding(Spacing.xs)
        .background(LumeColor.cream)
        .clipShape(Capsule())
    }
}
