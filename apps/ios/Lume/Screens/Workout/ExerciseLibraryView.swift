import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var group: MuscleGroup? = nil
    @State private var route: ExRoute?

    private struct ExRoute: Identifiable { let id = UUID(); let name: String }

    private var filtered: [Exercise] {
        Mock.exercises.filter { e in
            (group == nil || e.primary == group) &&
                (query.isEmpty || e.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            SearchBar(text: $query, placeholder: "Rechercher un exercice").padding(.horizontal, Spacing.xl)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    chip("Tous", group == nil) { group = nil }
                    ForEach(MuscleGroup.allCases) { g in chip(g.rawValue, group == g) { group = g } }
                }.padding(.horizontal, Spacing.xl)
            }
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(filtered) { e in
                        Button { route = ExRoute(name: e.name) } label: {
                            HStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                    Text(e.equipment).font(.lumeFootnote).foregroundStyle(LumeColor.muted)
                                }
                                Spacer()
                                MusclePill(group: e.primary)
                                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                            }
                            .padding(Spacing.lg - 2).background(LumeColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)).lumeShadow(.soft)
                        }.buttonStyle(.lumePress)
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.xxl)
            }
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Exercices", leading: .back, trailing: .add, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $route) { ExerciseProgressionView(exerciseName: $0.name) }
    }

    private func chip(_ t: String, _ active: Bool, _ a: @escaping () -> Void) -> some View {
        Text(t).font(.lumeSubhead.weight(.semibold))
            .foregroundStyle(active ? LumeColor.surface : LumeColor.textSecondary)
            .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg)
            .background(active ? LumeColor.ink : LumeColor.surface)
            .clipShape(Capsule()).lumeShadow(.soft)
            .onTapGesture { withAnimation(LumeMotion.snappy) { a() } }
    }
}

#Preview { ExerciseLibraryView() }
