import SwiftUI

struct RoutineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var start = false
    var routine: Routine = Mock.pushRoutine

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
                        Text(routine.muscles).font(.lumeSubhead).foregroundStyle(LumeColor.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(routine.exercises) { ex in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.exercise.name).font(.lumeCallout).foregroundStyle(LumeColor.ink)
                                MusclePill(group: ex.exercise.primary)
                            }
                            Spacer()
                            Text("\(ex.targetSets) × \(ex.targetReps)")
                                .font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.textSecondary)
                        }
                        .padding(Spacing.lg - 2)
                        .background(LumeColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        .lumeShadow(.soft)
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
            }
            PrimaryButton(title: "Démarrer la séance", icon: .workout) { start = true }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Routine", leading: .back, trailing: .edit, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(isPresented: $start) { ActiveSessionView() }
    }
}

#Preview { RoutineDetailView() }
