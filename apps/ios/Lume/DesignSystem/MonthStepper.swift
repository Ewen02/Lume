import SwiftUI

/// Sélecteur de mois ‹ Juin 2026 › partagé (Budget + Historique). La flèche « avant » est désactivée
/// sur le mois courant (on n'autorise pas la navigation dans le futur). Le label roule (numericText).
/// Reduce Motion respecté. Source unique : évite la triple duplication de la logique de navigation.
struct MonthStepper: View {
    @Binding var month: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le mois affiché est-il le mois courant ? (borne la navigation vers le futur).
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func change(_ delta: Int) {
        guard let m = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        // Pas de futur : on borne au mois courant.
        if delta > 0, m > Date(), !Calendar.current.isDate(m, equalTo: Date(), toGranularity: .month) { return }
        withAnimation(reduceMotion ? nil : LumeMotion.snappy) { month = m }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button { change(-1) } label: {
                Image(appIcon: .back).lumeIcon(12, weight: .bold).foregroundStyle(LumeColor.muted)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.lumePress).accessibilityLabel("Mois précédent")

            Text(Formatters.monthYearFR(month)).font(.lumeSubhead.weight(.semibold))
                .foregroundStyle(LumeColor.ink).contentTransition(.numericText())
                .frame(minWidth: 110)

            Button { change(1) } label: {
                Image(appIcon: .forward).lumeIcon(12, weight: .bold)
                    .foregroundStyle(isCurrentMonth ? LumeColor.faint : LumeColor.muted)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.lumePress).disabled(isCurrentMonth).accessibilityLabel("Mois suivant")
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        MonthStepper(month: .constant(Date()))
        MonthStepper(month: .constant(Calendar.current.date(byAdding: .month, value: -2, to: Date())!))
    }
    .padding()
    .background(LumeColor.cream)
}
