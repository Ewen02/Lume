import Testing
@testable import Lume

struct WorkoutSummaryTests {
    private func session(_ name: String, _ sets: [(Int, Double)]) -> ExerciseSession {
        ExerciseSession(exercise: Exercise(name: name, primary: .chest, equipment: "Barre"),
                        sets: sets.map { SetEntry(reps: $0.0, weight: $0.1, rpe: nil) })
    }

    @Test func aggregatesVolumeAndSets() {
        let s = WorkoutSummary(from: [session("Bench", [(10, 60), (8, 70)])], durationSec: 600)
        #expect(s.setCount == 2)
        #expect(s.exerciseCount == 1)
        // 10*60 + 8*70 = 600 + 560 = 1160
        #expect(s.totalVolume == 1160)
        #expect(s.bestOneRM > 0)
        #expect(s.bestExercise == "Bench")
    }

    @Test func ignoresEmptySets() {
        // Une série à reps=0 ne compte pas.
        let s = WorkoutSummary(from: [session("Squat", [(0, 100), (5, 100)])], durationSec: 120)
        #expect(s.setCount == 1)
        #expect(s.totalVolume == 500)
    }

    @Test func emptySessionIsZero() {
        let s = WorkoutSummary(from: [], durationSec: 0)
        #expect(s.setCount == 0)
        #expect(s.exerciseCount == 0)
        #expect(s.totalVolume == 0)
        #expect(s.bestOneRM == 0)
        #expect(s.bestExercise == nil)
    }

    @Test func durationLabelFormats() {
        #expect(WorkoutSummary(from: [], durationSec: 125).durationLabel == "2 min 5 s")
        #expect(WorkoutSummary(from: [], durationSec: 45).durationLabel == "45 s")
    }
}
