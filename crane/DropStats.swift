//
//  DropStats.swift
//  crane
//
//  Cheap, in-memory aggregates over a `[Drop]` array. Used by the menu-bar
//  dashboard. These used to hang off `DropsStore` but live as a free
//  extension now that SwiftData's `@Query` is the source of truth — any
//  view holding the (already-sorted) drops array can ask for stats
//  without going through a shared store.
//

import Foundation

extension Array where Element == Drop {

    /// Number of drops whose timestamp falls on the user's current day.
    var todayCount: Int {
        let cal = Calendar.current
        return reduce(into: 0) { count, drop in
            if cal.isDateInToday(drop.timestamp) { count += 1 }
        }
    }

    /// Consecutive days with at least one drop, counting backward from
    /// today when today has activity, otherwise from the most recent
    /// active day (so yesterday’s run still shows until you miss a day).
    var streakDays: Int {
        let cal = Calendar.current
        let buckets = Set(map { cal.startOfDay(for: $0.timestamp) })
        guard !buckets.isEmpty else { return 0 }

        let today = cal.startOfDay(for: Date())
        let cursor: Date
        if buckets.contains(today) {
            cursor = today
        } else if let latest = buckets.max() {
            cursor = latest
        } else {
            return 0
        }

        var streak = 0
        var day = cursor
        while buckets.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Drops bucketed by day for the last `days` days, oldest-first,
    /// zero-filled for empty days. Ideal as Swift Charts input.
    func dailyCounts(days: Int) -> [(date: Date, count: Int)] {
        guard days > 0 else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var counts: [Date: Int] = [:]
        for drop in self {
            let day = cal.startOfDay(for: drop.timestamp)
            counts[day, default: 0] += 1
        }

        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date: day, count: counts[day] ?? 0)
        }
    }

    /// Split of the array into thoughts vs. links, for the dashboard's
    /// type-breakdown bar.
    var typeBreakdown: (thoughts: Int, links: Int) {
        var thoughts = 0
        var links = 0
        for drop in self {
            switch drop.dropType {
            case .thought: thoughts += 1
            case .link:    links += 1
            }
        }
        return (thoughts, links)
    }

    /// Drops still waiting for FM tag extraction.
    var untaggedCount: Int {
        reduce(into: 0) { count, drop in
            if drop.aiProcessedAt == nil { count += 1 }
        }
    }

    /// Most frequent FM tags across all drops, for the dashboard chip row.
    func topTags(limit: Int) -> [(tag: String, count: Int)] {
        guard limit > 0 else { return [] }

        var counts: [String: Int] = [:]
        for drop in self {
            for tag in drop.tags {
                let key = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map { (tag: $0.key, count: $0.value) }
    }
}
