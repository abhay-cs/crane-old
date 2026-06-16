//
//  DummyDataSeeder.swift
//  crane
//
//  DEBUG-only helper that fills SwiftData with a week of realistic drops
//  (10–15 per day) so dashboard, history, and stats can be exercised
//  without manual capture.
//

#if DEBUG
import Foundation
import SwiftData

enum DummyDataSeeder {

    /// Roughly one week of heavy use: 10–15 drops per day, including today.
    static let days = 7
    static let minDropsPerDay = 10
    static let maxDropsPerDay = 15

    /// Inserts sample drops. When `clearFirst` is true, deletes every existing drop.
    @MainActor
    @discardableResult
    static func seedWeekOfUsage(in context: ModelContext, clearFirst: Bool = true) throws -> Int {
        if clearFirst {
            try clearAll(in: context)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var inserted = 0
        var contentIndex = 0

        for dayOffset in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let count = Int.random(in: minDropsPerDay...maxDropsPerDay)
            let timestamps = randomTimestamps(on: day, count: count, calendar: calendar)

            for timestamp in timestamps {
                let template = contentPool[contentIndex % contentPool.count]
                contentIndex += 1

                let drop = Drop(
                    id: UUID(),
                    text: template.text,
                    dropType: template.type,
                    timestamp: timestamp,
                    sourceApp: template.sourceApp,
                    tags: template.tags,
                    aiProcessedAt: template.tags.isEmpty ? nil : timestamp.addingTimeInterval(45),
                    aiTaggingFailed: false
                )
                context.insert(drop)
                inserted += 1
            }
        }

        // Leave a handful of recent drops untagged so the “Tagging…” UI is visible.
        let recent = FetchDescriptor<Drop>(
            sortBy: [SortDescriptor(\Drop.timestamp, order: .reverse)]
        )
        var recentDescriptor = recent
        recentDescriptor.fetchLimit = 4
        let untaggedCandidates = try context.fetch(recentDescriptor)
        for drop in untaggedCandidates.prefix(3) {
            drop.tags = []
            drop.aiProcessedAt = nil
            drop.aiTaggingFailed = false
        }

        try context.save()
        return inserted
    }

    @MainActor
    static func clearAll(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Drop>()
        let existing = try context.fetch(descriptor)
        for drop in existing {
            context.delete(drop)
        }
        if !existing.isEmpty {
            try context.save()
        }
    }

    // MARK: - Timestamps

    private static func randomTimestamps(on day: Date, count: Int, calendar: Calendar) -> [Date] {
        guard count > 0 else { return [] }

        // Weight toward work hours; occasional late-night captures.
        let hourWeights: [(hour: Int, weight: Int)] = [
            (7, 2), (8, 4), (9, 6), (10, 8), (11, 7),
            (12, 5), (13, 4), (14, 8), (15, 9), (16, 8),
            (17, 6), (18, 4), (19, 3), (20, 4), (21, 3), (22, 2), (23, 1)
        ]
        let totalWeight = hourWeights.reduce(0) { $0 + $1.weight }

        var stamps: [Date] = []
        stamps.reserveCapacity(count)

        for _ in 0..<count {
            var pick = Int.random(in: 0..<totalWeight)
            var hour = 9
            for entry in hourWeights {
                pick -= entry.weight
                if pick < 0 {
                    hour = entry.hour
                    break
                }
            }
            let minute = Int.random(in: 0..<60)
            let second = Int.random(in: 0..<60)
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            components.second = second
            if let date = calendar.date(from: components) {
                stamps.append(date)
            }
        }

        return stamps.sorted()
    }

    // MARK: - Content pool

    private struct Template {
        let text: String
        let type: DropType
        let sourceApp: String?
        let tags: [String]
    }

    private static let contentPool: [Template] = [
        Template(
            text: "Reply to Sarah about the auth middleware PR — she asked about token refresh timing",
            type: .thought,
            sourceApp: "Slack",
            tags: ["work", "follow-up"]
        ),
        Template(
            text: "https://developer.apple.com/documentation/swiftdata",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "reference"]
        ),
        Template(
            text: "Idea: show streak on menu bar icon when ≥3 days",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["ideas", "crane"]
        ),
        Template(
            text: "https://github.com/JohnSundell/Plot",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "reading"]
        ),
        Template(
            text: "Dentist Thursday 2pm — bring insurance card",
            type: .thought,
            sourceApp: "Notes",
            tags: ["personal", "errands"]
        ),
        Template(
            text: "The overlay should dismiss on outside click but not when dragging a selection",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "ux"]
        ),
        Template(
            text: "https://news.ycombinator.com/item?id=40123456",
            type: .link,
            sourceApp: "Google Chrome",
            tags: ["reading"]
        ),
        Template(
            text: "Ask design about cream line opacity in dark mode",
            type: .thought,
            sourceApp: "Slack",
            tags: ["work", "design"]
        ),
        Template(
            text: "https://www.swiftbysundell.com/articles/swiftdata-queries/",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "reading"]
        ),
        Template(
            text: "Weekly sync moved to 10:30 — update calendar",
            type: .thought,
            sourceApp: "Calendar",
            tags: ["work"]
        ),
        Template(
            text: "Recipe: miso butter pasta with chili crisp",
            type: .thought,
            sourceApp: "Safari",
            tags: ["personal", "food"]
        ),
        Template(
            text: "https://linear.app/team/issue/CRN-42/history-search-debounce",
            type: .link,
            sourceApp: "Linear",
            tags: ["work", "crane"]
        ),
        Template(
            text: "Consider lazy `@Query` fetch limits for history scroll performance",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "performance"]
        ),
        Template(
            text: "https://daringfireball.net/2026/05/on_menu_bar_apps",
            type: .link,
            sourceApp: "Safari",
            tags: ["reading", "mac"]
        ),
        Template(
            text: "Mom's birthday gift — bookshop voucher or plants?",
            type: .thought,
            sourceApp: "Messages",
            tags: ["personal"]
        ),
        Template(
            text: "Refactor DropStatistics to share logic with DropStats extension",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "refactor"]
        ),
        Template(
            text: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            type: .link,
            sourceApp: "Google Chrome",
            tags: ["personal"]
        ),
        Template(
            text: "Standup: blocked on FM availability in CI — use mock for unit tests",
            type: .thought,
            sourceApp: "Slack",
            tags: ["work", "ai"]
        ),
        Template(
            text: "Keyboard shortcut cheat sheet for beta testers",
            type: .thought,
            sourceApp: "Notes",
            tags: ["crane", "docs"]
        ),
        Template(
            text: "https://developer.apple.com/design/human-interface-guidelines/menu-bar-extras",
            type: .link,
            sourceApp: "Safari",
            tags: ["design", "reference"]
        ),
        Template(
            text: "Run migration test on corrupted store recovery path",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "testing"]
        ),
        Template(
            text: "Coffee with Alex next week — talk about SwiftUI performance",
            type: .thought,
            sourceApp: "Messages",
            tags: ["personal", "networking"]
        ),
        Template(
            text: "https://github.com/pointfreeco/swift-composable-architecture",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "architecture"]
        ),
        Template(
            text: "Empty state copy feels right; maybe soften “Nothing held yet”",
            type: .thought,
            sourceApp: "Figma",
            tags: ["crane", "copy"]
        ),
        Template(
            text: "Order standing desk mat before WFH week",
            type: .thought,
            sourceApp: "Safari",
            tags: ["personal", "shopping"]
        ),
        Template(
            text: "https://mastodon.social/@swiftlang/123456789",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "reading"]
        ),
        Template(
            text: "Tag chips should truncate long FM tags gracefully",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "ui"]
        ),
        Template(
            text: "Investigate why MenuBarExtra closes on alert in dashboard delete flow",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "bug"]
        ),
        Template(
            text: "https://www.nytimes.com/2026/05/18/technology/apple-intelligence-on-device.html",
            type: .link,
            sourceApp: "Safari",
            tags: ["reading", "ai"]
        ),
        Template(
            text: "Podcast idea: building menu bar utilities on modern macOS",
            type: .thought,
            sourceApp: "Notes",
            tags: ["ideas"]
        ),
        Template(
            text: "Send invoice to client by EOD Friday",
            type: .thought,
            sourceApp: "Mail",
            tags: ["work", "follow-up"]
        ),
        Template(
            text: "https://stackoverflow.com/questions/78901234/swiftdata-predicate-enum",
            type: .link,
            sourceApp: "Google Chrome",
            tags: ["swift", "reference"]
        ),
        Template(
            text: "Stretch break every hour — set a gentle reminder",
            type: .thought,
            sourceApp: "Reminders",
            tags: ["personal", "health"]
        ),
        Template(
            text: "Chart tooltip should show count on hover for activity section",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "ui"]
        ),
        Template(
            text: "https://github.com/raycast/script-commands",
            type: .link,
            sourceApp: "Safari",
            tags: ["mac", "tools"]
        ),
        Template(
            text: "Read chapter 4 of Designing Data-Intensive Applications",
            type: .thought,
            sourceApp: "Books",
            tags: ["reading"]
        ),
        Template(
            text: "Backup drops before testing store recovery",
            type: .thought,
            sourceApp: "Terminal",
            tags: ["crane", "testing"]
        ),
        Template(
            text: "https://www.apple.com/newsroom/2026/05/macos-update/",
            type: .link,
            sourceApp: "Safari",
            tags: ["mac", "news"]
        ),
        Template(
            text: "Team lunch Friday — vegetarian option at the usual place",
            type: .thought,
            sourceApp: "Slack",
            tags: ["work", "personal"]
        ),
        Template(
            text: "Global hotkey lost after sleep — verify reregister path",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "bug"]
        ),
        Template(
            text: "https://cursor.com/docs",
            type: .link,
            sourceApp: "Cursor",
            tags: ["tools", "reference"]
        ),
        Template(
            text: "Write release notes for v0.2 — highlight SwiftData migration",
            type: .thought,
            sourceApp: "Notes",
            tags: ["crane", "docs"]
        ),
        Template(
            text: "Pick up dry cleaning on the way home",
            type: .thought,
            sourceApp: "Reminders",
            tags: ["personal", "errands"]
        ),
        Template(
            text: "https://www.hackingwithswift.com/quick-start/swiftdata",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "tutorial"]
        ),
        Template(
            text: "Reduce motion: check spring animations on overlay transitions",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "accessibility"]
        ),
        Template(
            text: "Flight check-in opens 24h before — SFO to JFK May 28",
            type: .thought,
            sourceApp: "Mail",
            tags: ["personal", "travel"]
        ),
        Template(
            text: "https://github.com/abhaycs/crane/pull/12",
            type: .link,
            sourceApp: "Safari",
            tags: ["crane", "work"]
        ),
        Template(
            text: "Interesting pattern: capture bar as mirror text over hidden TextField",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "ideas"]
        ),
        Template(
            text: "Renew domain before it lapses in June",
            type: .thought,
            sourceApp: "Safari",
            tags: ["personal", "follow-up"]
        ),
        Template(
            text: "https://www.reddit.com/r/macapps/comments/example/crane_like_apps",
            type: .link,
            sourceApp: "Safari",
            tags: ["research", "mac"]
        ),
        Template(
            text: "Add privacy manifest entries before App Store submission",
            type: .thought,
            sourceApp: "Xcode",
            tags: ["crane", "release"]
        ),
        Template(
            text: "Morning pages — what's worth capturing vs. letting go?",
            type: .thought,
            sourceApp: "Notes",
            tags: ["personal", "ideas"]
        ),
        Template(
            text: "https://developer.apple.com/videos/play/wwdc2025/101/",
            type: .link,
            sourceApp: "Safari",
            tags: ["swift", "wwdc"]
        ),
        Template(
            text: "Sync with PM on two-binary plan doc",
            type: .thought,
            sourceApp: "Slack",
            tags: ["work", "crane"]
        ),
        Template(
            text: "Try geist mono for stat card numbers only",
            type: .thought,
            sourceApp: "Figma",
            tags: ["design", "crane"]
        ),
        Template(
            text: "https://jsonformatter.org/",
            type: .link,
            sourceApp: "Google Chrome",
            tags: ["tools"]
        ),
        Template(
            text: "Untagged drop — FM should pick this up on next backfill",
            type: .thought,
            sourceApp: "Xcode",
            tags: []
        ),
        Template(
            text: "https://example.com/article/on-focus-and-attention",
            type: .link,
            sourceApp: "Safari",
            tags: []
        ),
        Template(
            text: "Another pending tag extraction",
            type: .thought,
            sourceApp: "Notes",
            tags: []
        ),
    ]
}
#endif
