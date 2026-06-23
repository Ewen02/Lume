import SwiftData
import SwiftUI

/// Ajout d'un exercice custom à la bibliothèque (nom + groupe musculaire + équipement).
struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func save() {
        let eq = equipment.trimmingCharacters(in: .whitespaces)
        ctx.insert(ExerciseModel(name: trimmedName, muscleRaw: muscle.code,
                                 equipment: eq.isEmpty ? "Libre" : eq, isCustom: true))
        dismiss()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                LumeCard {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        field("Nom") {
                            TextField("Ex. Rowing barre", text: $name)
                                .textInputAutocapitalization(.sentences)
                        }
                        field("Équipement") {
                            TextField("Ex. Barre, Haltères, Machine…", text: $equipment)
                                .textInputAutocapitalization(.sentences)
                        }
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Groupe musculaire").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.sm) {
                                    ForEach(MuscleGroup.allCases) { g in
                                        let active = g == muscle
                                        Text(g.rawValue).font(.lumeSubhead.weight(.semibold))
                                            .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
                                            .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg)
                                            .background(active ? LumeColor.ink : LumeColor.cream)
                                            .clipShape(Capsule())
                                            .onTapGesture { withAnimation(LumeMotion.snappy) { muscle = g } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, Spacing.xxl)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Nouvel exercice", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Ajouter", icon: .validate) { save() }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
    }

    private func field(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
            content()
                .font(.lumeSubhead).foregroundStyle(LumeColor.ink)
                .padding(Spacing.md).background(LumeColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}

#Preview { ExerciseEditorView().modelContainer(LumeStore.preview) }
