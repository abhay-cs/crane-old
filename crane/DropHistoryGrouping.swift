//
//  DropHistoryGrouping.swift
//  crane
//

import Foundation

extension Array where Element == Drop {

    /// Groups drops (newest-first) into "Today", "Yesterday", or formatted dates.
    func groupedByDaySection(calendar: Calendar = .current) -> [(title: String, drops: [Drop])] {
        guard !isEmpty else { return [] }

        var sections: [(title: String, drops: [Drop])] = []
        var currentTitle: String?
        var bucket: [Drop] = []

        for drop in self {
            let title = Self.sectionTitle(for: drop.timestamp, calendar: calendar)
            if title != currentTitle {
                if let currentTitle, !bucket.isEmpty {
                    sections.append((currentTitle, bucket))
                }
                currentTitle = title
                bucket = [drop]
            } else {
                bucket.append(drop)
            }
        }
        if let currentTitle, !bucket.isEmpty {
            sections.append((currentTitle, bucket))
        }
        return sections
    }

    private static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
