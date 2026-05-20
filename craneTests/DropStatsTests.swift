//
//  DropStatsTests.swift
//  craneTests
//

import XCTest
@testable import crane

final class DropStatsTests: XCTestCase {

    func testStreakFromToday() {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let drops = [
            Drop(text: "a", dropType: .thought, timestamp: today),
            Drop(text: "b", dropType: .thought, timestamp: yesterday),
        ]
        XCTAssertEqual(drops.streakDays, 2)
        XCTAssertTrue(drops.hasDropToday)
    }

    func testStreakFromLastActiveDayWithoutToday() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let drops = [Drop(text: "a", dropType: .thought, timestamp: yesterday)]
        XCTAssertEqual(drops.streakDays, 1)
        XCTAssertFalse(drops.hasDropToday)
    }
}
