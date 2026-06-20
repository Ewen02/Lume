import SwiftUI

// MARK: - Séries

struct SetHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Série").frame(width: 44, alignment: .leading)
            Text("Kg").frame(maxWidth: .infinity)
            Text("Reps").frame(maxWidth: .infinity)
            Text("RPE").frame(maxWidth: .infinity)
            Color.clear.frame(width: 40)
        }
        .font(.lumeCaption).foregroundStyle(LumeColor.muted)
    }
}

struct SetRow: View {
    var index: Int
    @Binding var set: SetEntry
    var body: some View {
        HStack(spacing: 0) {
            Text("\(index)")
                .font(.lumeCallout).foregroundStyle(LumeColor.textSecondary)
                .frame(width: 44, alignment: .leading)
            Text(set.weight.clean).font(.lumeCallout).foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).monospacedDigit()
            Text("\(set.reps)").font(.lumeCallout).foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).monospacedDigit()
            Text(set.rpe.map { "\($0)" } ?? "—").font(.lumeCallout).foregroundStyle(LumeColor.muted).frame(maxWidth: .infinity).monospacedDigit()
            Button { set.done.toggle() } label: {
                Image(appIcon: .validate)
                    .lumeIcon(22, weight: .bold)
                    .foregroundStyle(set.done ? LumeColor.success : LumeColor.faint)
            }.buttonStyle(.plain).frame(width: 40)
        }
        .padding(.vertical, Spacing.sm)
    }
}

extension Double {
    /// "60" plutôt que "60.0", "22.5" conservé.
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
}

// MARK: - Carte exercice (séance active)

struct ExerciseSessionCard: View {
    @Binding var session: ExerciseSession
    private var oneRM: Int {
        let best = session.sets.filter { $0.done }.map { OneRepMax.estimate(weight: $0.weight, reps: $0.reps) }.max()
        return best ?? 0
    }

    var body: some View {
        LumeCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.exercise.name).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                        MusclePill(group: session.exercise.primary)
                    }
                    Spacer()
                    if oneRM > 0 {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(oneRM) kg").font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.ink)
                            Text("1RM est.").font(.lumeCaption).foregroundStyle(LumeColor.muted)
                        }
                    }
                }
                SetHeaderRow()
                ForEach(Array(session.sets.enumerated()), id: \.element.id) { i, _ in
                    SetRow(index: i + 1, set: $session.sets[i])
                    if i < session.sets.count - 1 { Divider().background(LumeColor.border) }
                }
                Button {
                    let last = session.sets.last
                    session.sets.append(SetEntry(reps: last?.reps ?? 10, weight: last?.weight ?? 20, rpe: nil))
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(appIcon: .addSet).lumeIcon(16, weight: .semibold)
                        Text("Ajouter une série").font(.lumeSubhead.weight(.semibold))
                    }.foregroundStyle(LumeColor.ink).frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
                        .background(LumeColor.cream).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
    }
}

struct MusclePill: View {
    var group: MuscleGroup
    var body: some View {
        Text(group.rawValue)
            .font(.lumeCaption).foregroundStyle(group.tint)
            .padding(.vertical, 4).padding(.horizontal, 10)
            .background(group.tint.opacity(0.14)).clipShape(Capsule())
    }
}

// MARK: - Carte routine

struct RoutineCard: View {
    var routine: Routine
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(appIcon: .workout).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                    .frame(width: 46, height: 46).background(LumeColor.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                    Text("\(routine.exercises.count) exercices · \(routine.muscles)")
                        .font(.lumeFootnote).foregroundStyle(LumeColor.muted).lineLimit(1)
                }
                Spacer()
                Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
            }
            .padding(Spacing.lg - 2)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .lumeShadow(.soft)
        }.buttonStyle(.plain)
    }
}

// MARK: - Timer de repos (pilule)

struct RestTimerPill: View {
    var seconds: Int
    private var mmss: String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(appIcon: .restTimer).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.fat)
            Text("Repos").font(.lumeSubhead.weight(.semibold)).foregroundStyle(LumeColor.ink)
            Text(mmss).font(.lumeCallout.weight(.bold)).foregroundStyle(LumeColor.fat).monospacedDigit()
        }
        .padding(.vertical, Spacing.sm + 2).padding(.horizontal, Spacing.lg)
        .background(LumeColor.fat.opacity(0.12)).clipShape(Capsule())
    }
}

// MARK: - Disques (calcul barre)

struct PlateView: View {
    var perSide: [Double] // disques d'un côté, du plus lourd au plus léger
    static func color(_ w: Double) -> Color {
        switch w {
        case 25: LumeColor.protein
        case 20: LumeColor.fat
        case 15: LumeColor.carbs
        case 10: LumeColor.success
        case 5: LumeColor.muted
        default: LumeColor.ink
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Capsule().fill(LumeColor.ink).frame(width: 30, height: 8) // manchon
            ForEach(Array(perSide.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Self.color(w))
                    .frame(width: 14, height: 36 + CGFloat(min(w, 25)) * 2.2)
                    .overlay(Text(w.clean).font(.system(size: 8, weight: .bold)).foregroundStyle(.white).rotationEffect(.degrees(-90)))
            }
            Spacer()
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
