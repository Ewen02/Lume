import Testing
@testable import Lume

struct ProfileMappingTests {
    @Test func activityRoundTrip() {
        for a in ActivityLevel.allCases {
            #expect(ProfileRecord.activity(ProfileRecord.raw(a)) == a)
        }
    }
    @Test func goalRoundTrip() {
        for g in [Goal.lose, .maintain, .gain] {
            #expect(ProfileRecord.goal(ProfileRecord.raw(g)) == g)
        }
    }
    @Test @MainActor func profileRecordRoundTrip() {
        let p = UserProfile(name: "Ewen", sex: .male, age: 24, heightCm: 178, weightKg: 74, activity: .active, goal: .gain)
        let restored = ProfileRecord(from: p).profile
        #expect(restored.name == "Ewen")
        #expect(restored.sex == .male)
        #expect(restored.activity == .active)
        #expect(restored.goal == .gain)
        #expect(abs(restored.weightKg - 74) < 0.001)
    }
}
