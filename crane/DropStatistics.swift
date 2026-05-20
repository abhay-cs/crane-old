//
//  DropStatistics.swift
//  crane
//
//  Store-wide aggregates via fetchCount / bounded fetches so dashboard stats
//  stay correct when list UI is capped at `Persistence.maxFetchedDrops`.
//

import Foundation
import SwiftData

struct DropStatistics {
    let totalCount: Int
    let todayCount: Int
    let streakDays: Int
    let hasDropToday: Bool
    let dailyCounts: [(date: Date, count: Int)]
    let typeBreakdown: (thoughts: Int, links: Int)
    let topTags: [(tag: String, count: Int)]

    static let empty = DropStatistics(
        totalCount: 0,
        todayCount: 0,
        streakDays: 0,
        hasDropToday: false,
        dailyCounts: [],
        typeBreakdown: (0, 0),
        topTags: []
    )

    @MainActor
    static func compute(in context: ModelContext) -> DropStatistics {
        do {
            let total = try context.fetchCount(FetchDescriptor<Drop>())
            let today = try todayCount(in: context)
            let (streak, hasToday) = try streakDays(in: context)
            let daily = try dailyCounts(days: 14, in: context)
            let breakdown = try typeBreakdown(in: context)
            let tags = try topTags(limit: 8, in: context)
            return DropStatistics(
                totalCount: total,
                todayCount: today,
                streakDays: streak,
                hasDropToday: hasToday,
                dailyCounts: daily,
                typeBreakdown: breakdown,
                topTags: tags
            )
        } catch {
            #if DEBUG
            print("crane: DropStatistics.compute failed: \(error)")
            #endif
            return .empty
        }
    }

    // MARK: - Queries

    private static func todayCount(in context: ModelContext) throws -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Drop>(
            predicate: #Predicate<Drop> { $0.timestamp >= start }
        )
        return try context.fetchCount(descriptor)
    }

    private static func streakDays(in context: ModelContext) throws -> (days: Int, hasDropToday: Bool) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let hasToday = try dropCount(on: today, in: context) > 0

        var cursor: Date
        if hasToday {
            cursor = today
        } else {
            var latest = FetchDescriptor<Drop>(
                sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
            )
            latest.fetchLimit = 1
            guard let drop = try context.fetch(latest).first else {
                return (0, false)
            }
            cursor = cal.startOfDay(for: drop.timestamp)
        }

        var streak = 0
        var day = cursor
        while try dropCount(on: day, in: context) > 0 {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return (streak, hasToday)
    }

    private static func dropCount(on day: Date, in context: ModelContext) throws -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let descriptor = FetchDescriptor<Drop>(
            predicate: #Predicate<Drop> { $0.timestamp >= start && $0.timestamp < end }
        )
        return try context.fetchCount(descriptor)
    }

    private static func dailyCounts(days: Int, in context: ModelContext) throws -> [(date: Date, count: Int)] {
        guard days > 0 else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var points: [(date: Date, count: Int)] = []
        for offset in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let count = try dropCount(on: day, in: context)
            points.append((date: day, count: count))
        }
        return points
    }

    private static func typeBreakdown(in context: ModelContext) throws -> (thoughts: Int, links: Int) {
        let thoughts = try context.fetchCount(
            FetchDescriptor<Drop>(predicate: #Predicate<Drop> { $0.dropType.rawValue == "thought" })
        )
        let links = try context.fetchCount(
            FetchDescriptor<Drop>(predicate: #Predicate<Drop> { $0.dropType.rawValue == "link" })
        )
        return (thoughts, links)
    }

    /// Aggregates tags from a bounded sample of tagged drops (newest first).
    private static func topTags(limit: Int, in context: ModelContext) throws -> [(tag: String, count: Int)] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Persistence.maxFetchedDrops
        let sample = try context.fetch(descriptor).filter { !$0.tags.isEmpty }
        return sample.topTags(limit: limit)
    }
}
