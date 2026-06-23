import SwiftData
import SwiftUI

/// Création OU édition d'une routine : nom + liste d'exercices (séries/répétitions), persistée en SwiftData.
struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \RoutineModel.order) private var existing: [RoutineModel]

    /// Routine à éditer (nil = création).
    private let editing: RoutineModel?
    @State private var name = ""
    @State private var items: [Draft] = []
    @State private var showPicker = false
    @State private var loaded = false

    init(editing: RoutineModel? = nil) {
        self.editing = editing
    }

    private struct Draft: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var sets: Int = 3
        var reps: String = "8-12"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty
    }

    private var isEditing: Bool {
        editing != nil
    }

    @State private var confirmDelete = false

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                Section {
                    nameField.lumeRow()
                }
                Section {
                    if items.isEmpty {
                        LumeEmptyState(icon: .workout, title: "Aucun exercice",
                                       message: "Ajoute des exercices à ta routine.")
                            .lumeRow()
                    } else {
                        ForEach($items) { $item in
                            exerciseRow($item).lumeRow()
                        }
                        .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { items.remove(atOffsets: $0) }
                    }
                    addButton.lumeRow()
                } header: {
                    HStack {
                        Text("Exercices").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                        Spacer()
                        if items.count > 1 {
                            Text("appui long pour réordonner · glisser ← pour supprimer")
                                .font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        }
                    }.textCase(nil)
                }
                if isEditing {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            HStack {
                                Spacer()
                                Image(appIcon: .trash).lumeIcon(16, weight: .semibold)
                                Text("Supprimer la routine").font(.lumeCallout.weight(.semibold))
                                Spacer()
                            }.foregroundStyle(LumeColor.negative).padding(.vertical, Spacing.sm)
                        }.lumeRow()
                    }
                }
                Color.clear.frame(height: 80).listRowSeparator(.hidden).listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            PrimaryButton(title: isEditing ? "Enregistrer les modifications" : "Enregistrer la routine", icon: .validate) { save() }
                .disabled(!canSave).opacity(canSave ? 1 : 0.5)
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: isEditing ? "Modifier la routine" : "Nouvelle routine", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .onAppear(perform: loadIfNeeded)
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { ex in
                items.append(Draft(exercise: ex)); showPicker = false
            }
        }
        .confirmationDialog("Supprimer cette routine ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let r = editing { ctx.delete(r) }
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var nameField: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Nom de la routine").font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                TextField("Ex. Haut du corps", text: $name)
                    .font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private var addButton: some View {
        Button { showPicker = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(appIcon: .add).lumeIcon(16, weight: .semibold)
                Text("Ajouter un exercice").font(.lumeCallout)
            }
            .foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
        }.buttonStyle(.lumePress)
    }

    /// Au 1er affichage en mode édition : pré-remplit le nom et les exercices depuis le modèle.
    private func loadIfNeeded() {
        guard !loaded, let r = editing else { loaded = true; return }
        name = r.name
        items = r.orderedExercises.map {
            Draft(exercise: Exercise(name: $0.exerciseName,
                                     primary: MuscleGroup.from(code: $0.muscleRaw),
                                     equipment: $0.equipment),
                  sets: $0.targetSets, reps: $0.targetReps)
        }
        loaded = true
    }

    private func exerciseRow(_ item: Binding<Draft>) -> some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(item.wrappedValue.exercise.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                MusclePill(group: item.wrappedValue.exercise.primary)
                HStack(spacing: Spacing.md) {
                    // Séries — stepper compact.
                    HStack(spacing: Spacing.sm) {
                        RoundIconButton(icon: .minus, size: 22) { item.wrappedValue.sets = max(1, item.wrappedValue.sets - 1) }
                        VStack(spacing: 0) {
                            Text("\(item.wrappedValue.sets)").font(.lumeBodyMed).foregroundStyle(LumeColor.ink).monospacedDigit()
                            Text("séries").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        }.frame(minWidth: 44)
                        RoundIconButton(icon: .add, filled: true, size: 22) { item.wrappedValue.sets += 1 }
                    }
                    Spacer()
                    // Répétitions — champ visiblement éditable.
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("répétitions").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        TextField("8-12", text: item.reps)
                            .multilineTextAlignment(.center).font(.lumeBodyMed).foregroundStyle(LumeColor.ink)
                            .frame(width: 80).padding(.vertical, Spacing.xs)
                            .background(LumeColor.cream).clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                }
            }
        }
    }

    private func save() {
        let routine: RoutineModel
        if let r = editing {
            // Édition : on met à jour le nom et on remplace les exercices.
            r.name = name.trimmingCharacters(in: .whitespaces)
            for old in r.orderedExercises {
                ctx.delete(old)
            }
            routine = r
        } else {
            let order = (existing.map(\.order).max() ?? -1) + 1
            routine = RoutineModel(name: name.trimmingCharacters(in: .whitespaces), order: order)
            ctx.insert(routine)
        }
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

private extension View {
    /// Ligne de `List` au look Lume : pas d'insets ni de fond système, espacement vertical doux.
    func lumeRow() -> some View {
        listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xl, bottom: Spacing.xs, trailing: Spacing.xl))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
