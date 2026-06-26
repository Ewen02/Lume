import SwiftUI

/// Saisie d'un montant monétaire (binding en centimes Int). Gros chiffre centré façon
/// « calculatrice », clavier décimal. Parsing/format via `Money` (jamais de Double persisté).
struct AmountStepper: View {
    @Binding var cents: Int
    var tint: Color = LumeColor.ink

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                TextField("0", text: $text)
                    .font(.lumeNumberXL).foregroundStyle(tint).monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .fixedSize()
                    .onChange(of: text) { _, new in
                        if let parsed = Money.parse(new) { cents = parsed }
                        else if new.isEmpty { cents = 0 }
                    }
                    // Le pavé décimal n'a pas de touche « retour » : on ajoute un bouton « Terminé »
                    // dans la barre d'outils clavier pour pouvoir le fermer.
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Terminé") { focused = false }
                                .font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        }
                    }
                Text("€").font(.lumeTitle).foregroundStyle(LumeColor.muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear {
            // Pré-remplit depuis le binding (édition d'une transaction existante).
            if cents > 0 { text = Money.plainDecimal(cents) }
        }
        // Le binding peut changer hors saisie (ex. chips « +50 € », pré-remplissage) :
        // on resynchronise le texte affiché, avec garde anti-boucle.
        .onChange(of: cents) { _, new in
            if Money.parse(text) != new { text = new == 0 ? "" : Money.plainDecimal(new) }
        }
    }
}

#Preview {
    VStack {
        AmountStepper(cents: .constant(1250))
        AmountStepper(cents: .constant(0), tint: LumeColor.success)
    }
    .padding()
    .background(LumeColor.cream)
}
