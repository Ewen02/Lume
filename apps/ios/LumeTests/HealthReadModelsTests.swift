import Foundation
import Testing
@testable import Lume

struct HealthReadModelsTests {
    private func workout(_ sec: Int) -> ExternalWorkout {
        ExternalWorkout(date: Date(timeIntervalSince1970: 1_700_000_000), durationSec: sec, kcal: nil, type: "Course")
    }

    @Test func durationLabelMinutesUnderHour() {
        #expect(workout(45 * 60).durationLabel == "45 min")
    }

    @Test func durationLabelHoursAndMinutes() {
        #expect(workout(65 * 60).durationLabel == "1 h 05")
    }

    @Test func durationLabelExactHour() {
        #expect(workout(120 * 60).durationLabel == "2 h 00")
    }
}
