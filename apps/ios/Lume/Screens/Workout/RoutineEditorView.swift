import SwiftData
import SwiftUI

/// Création d'une routine : nom + liste d'exercices (séries/répétitions), persistée en SwiftData.
struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \RoutineModel.order) private var existing: [RoutineModel]

    @State private var name = ""
    @State private var items: [Draft] = []
    @State private var showPicker = false

    private struct Draft: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var sets: Int = 3
        var reps: String = "8-12"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    LumeCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Nom de la routine").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                            TextField("Ex. Haut du corps", text: $name)
                                .font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                                .textInputAutocapitalization(.sentences)
                        }
                    }

                    if items.isEmpty {
                        LumeEmptyState(icon: .workout, title: "Aucun exercice",
                                       message: "Ajoute des exercices à ta routine.")
                    } else {
                        ForEach($items) { $item in exerciseRow($item) }
                    }

                    Button { showPicker = true } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(appIcon: .add).lumeIcon(16, weight: .semibold)
                            Text("Ajouter un exercice").font(.lumeCallout)
                        }
                        .foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
                    }.buttonStyle(.lumePress)
                }
                .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm).padding(.bottom, 110)
            }

            PrimaryButton(title: "Enregistrer la routine", icon: .validate) { save() }
                .disabled(!canSave).opacity(canSave ? 1 : 0.5)
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Nouvelle routine", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { ex in
                items.append(Draft(exercise: ex)); showPicker = false
            }
        }
    }

    private func exerciseRow(_ item: Binding<Draft>) -> some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.wrappedValue.exercise.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                        MusclePill(group: item.wrappedValue.exercise.primary)
                    }
                    Spacer()
                    Button { items.removeAll { $0.id == item.wrappedValue.id } } label: {
                        Image(appIcon: .minusCircle).lumeIcon(22).foregroundStyle(LumeColor.negative)
                    }.buttonStyle(.lumePress)
                }
                HStack {
                    Text("Séries").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                    Spacer()
                    RoundIconButton(icon: .minus) { item.wrappedValue.sets = max(1, item.wrappedValue.sets - 1) }
                    Text("\(item.wrappedValue.sets)").font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        .monospacedDigit().frame(minWidth: 28)
                    RoundIconButton(icon: .add, filled: true) { item.wrappedValue.sets += 1 }
                }
                HStack {
                    Text("Répétitions").font(.lumeSubhead).foregroundStyle(LumeColor.textSecondary)
                    Spacer()
                    TextField("8-12", text: item.reps)
                        .multilineTextAlignment(.trailing).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                        .frame(width: 90)
                }
            }
        }
    }

    private func save() {
        let order = (existing.map(\.order).max() ?? -1) + 1
        let routine = RoutineModel(name: name.trimmingCharacters(in: .whitespaces), order: order)
        ctx.insert(routine)
        for (i, d) in items.enumerated() {
            let m = RoutineExerciseModel(exerciseName: d.exercise.name,
                                         muscleRaw: d.exercise.primary.code,
                                         equipment: d.exercise.equipment,
                                         targetSets: d.sets,
                                         targetReps: d.reps.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : d.reps,
                                         order: i)
            m.routine = routine
            ctx.insert(m)
        }
        dismiss()
    }
}

/// Sélecteur d'exercice réutilisable (éditeur de routine + séance active),
/// branché sur la bibliothèque persistée (ExerciseModel). Permet d'en ajouter un à la volée.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \ExerciseModel.name) private var exercises: [ExerciseModel]
    @State private var query = ""
    @State private var showAdd = false
    var onPick: (Exercise) -> Void

    private var filtered: [ExerciseModel] {
        query.isEmpty ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            SearchBar(text: $query, placeholder: "Rechercher un exercice").padding(.horizontal, Spacing.xl)
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    if filtered.isEmpty {
                        LumeEmptyState(icon: .search, title: "Aucun exercice",
                                       message: "Ajoute-le avec le bouton +.")
                    } else {
                        ForEach(filtered) { e in
                            Button { onPick(e.asExercise) } label: {
                                HStack(spacing: Spacing.md) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(e.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                        Text(e.equipment).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                                    }
                                    Spacer()
                                    MusclePill(group: MuscleGroup.from(code: e.muscleRaw))
                                }
                                .padding(Spacing.lg - 2).background(LumeColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
                            }.buttonStyle(.lumePress)
                        }
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Choisir un exercice", leading: .close, trailing: .add,
                   onLeading: { dismiss() }, onTrailing: { showAdd = true })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .onAppear { seedDefaultExercisesIfNeeded(ctx) }
        .sheet(isPresented: $showAdd) { ExerciseEditorView() }
    }
}

#Preview { RoutineEditorView().modelContainer(LumeStore.preview) }
