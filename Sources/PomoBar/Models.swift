import Foundation

enum PomodoroPhase: String, Codable {
    case focus
    case breakTime

    var title: String {
        switch self {
        case .focus: "Focus"
        case .breakTime: "Break"
        }
    }
}

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    var timeDisplayFormat: TimeDisplayFormat = .withHours

    enum CodingKeys: String, CodingKey {
        case focusMinutes
        case breakMinutes
        case timeDisplayFormat
    }

    init(
        focusMinutes: Int = 25,
        breakMinutes: Int = 5,
        timeDisplayFormat: TimeDisplayFormat = .withHours
    ) {
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.timeDisplayFormat = timeDisplayFormat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
        breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5
        timeDisplayFormat = try container.decodeIfPresent(TimeDisplayFormat.self, forKey: .timeDisplayFormat) ?? .withHours
    }
}

enum TimeDisplayFormat: String, Codable, CaseIterable, Identifiable {
    case allMinutes
    case withHours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allMinutes: "All Minutes"
        case .withHours: "With Hours"
        }
    }
}

struct PomodoroSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var plannedMinutes: Int
    var completedBySkip: Bool = false

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        plannedMinutes: Int,
        completedBySkip: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.completedBySkip = completedBySkip
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case plannedMinutes
        case completedBySkip
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        plannedMinutes = try container.decode(Int.self, forKey: .plannedMinutes)
        completedBySkip = try container.decodeIfPresent(Bool.self, forKey: .completedBySkip) ?? false
    }
}

struct PomodoroState: Codable, Equatable {
    var settings = PomodoroSettings()
    var sessions: [PomodoroSession] = []
    var trackedApps: [TrackedApp] = []
    var appActivity: [AppActivity] = []
    var dailyActivities: [DailyActivity] = []
    var dailyActivityCompletions: [DailyActivityCompletion] = []
    var dailyActivityReminderSilences: [DailyActivityReminderSilence] = []

    init(
        settings: PomodoroSettings = PomodoroSettings(),
        sessions: [PomodoroSession] = [],
        trackedApps: [TrackedApp] = [],
        appActivity: [AppActivity] = [],
        dailyActivities: [DailyActivity] = [],
        dailyActivityCompletions: [DailyActivityCompletion] = [],
        dailyActivityReminderSilences: [DailyActivityReminderSilence] = []
    ) {
        self.settings = settings
        self.sessions = sessions
        self.trackedApps = trackedApps
        self.appActivity = appActivity
        self.dailyActivities = dailyActivities
        self.dailyActivityCompletions = dailyActivityCompletions
        self.dailyActivityReminderSilences = dailyActivityReminderSilences
    }

    enum CodingKeys: String, CodingKey {
        case settings
        case sessions
        case trackedApps
        case appActivity
        case dailyActivities
        case dailyActivityCompletions
        case dailyActivityReminderSilences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decodeIfPresent(PomodoroSettings.self, forKey: .settings) ?? PomodoroSettings()
        sessions = try container.decodeIfPresent([PomodoroSession].self, forKey: .sessions) ?? []
        trackedApps = try container.decodeIfPresent([TrackedApp].self, forKey: .trackedApps) ?? []
        appActivity = try container.decodeIfPresent([AppActivity].self, forKey: .appActivity) ?? []
        dailyActivities = try container.decodeIfPresent([DailyActivity].self, forKey: .dailyActivities) ?? []
        dailyActivityCompletions = try container.decodeIfPresent([DailyActivityCompletion].self, forKey: .dailyActivityCompletions) ?? []
        dailyActivityReminderSilences = try container.decodeIfPresent([DailyActivityReminderSilence].self, forKey: .dailyActivityReminderSilences) ?? []
    }
}

struct DailyActivity: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var targetCount: Int = 1
    var reminderEnabled: Bool = false
    var reminderStartMinutes: Int = 9 * 60
    var reminderIntervalMinutes: Int = 60
    var reminderStopMinutes: Int = 17 * 60

    init(
        id: UUID = UUID(),
        title: String,
        targetCount: Int = 1,
        reminderEnabled: Bool = false,
        reminderStartMinutes: Int = 9 * 60,
        reminderIntervalMinutes: Int = 60,
        reminderStopMinutes: Int = 17 * 60
    ) {
        self.id = id
        self.title = title
        self.targetCount = targetCount
        self.reminderEnabled = reminderEnabled
        self.reminderStartMinutes = reminderStartMinutes
        self.reminderIntervalMinutes = reminderIntervalMinutes
        self.reminderStopMinutes = reminderStopMinutes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case targetCount
        case reminderEnabled
        case reminderStartMinutes
        case reminderIntervalMinutes
        case reminderStopMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        targetCount = try container.decodeIfPresent(Int.self, forKey: .targetCount) ?? 1
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderStartMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderStartMinutes) ?? 9 * 60
        reminderIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderIntervalMinutes) ?? 60
        reminderStopMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderStopMinutes) ?? 17 * 60
    }
}

struct DailyActivityCompletion: Codable, Identifiable, Equatable {
    var id: String { "\(day.timeIntervalSince1970)-\(activityID.uuidString)" }
    var activityID: UUID
    var day: Date
    var count: Int
}

struct DailyActivityReminderSilence: Codable, Identifiable, Equatable {
    var id: String { "\(day.timeIntervalSince1970)-\(activityID.uuidString)" }
    var activityID: UUID
    var day: Date
}

struct TrackedApp: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var name: String
    var awayThresholdSeconds: Int?

    init(bundleIdentifier: String, name: String, awayThresholdSeconds: Int? = 120) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.awayThresholdSeconds = awayThresholdSeconds
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case name
        case awayThresholdSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        name = try container.decode(String.self, forKey: .name)
        awayThresholdSeconds = try container.decodeIfPresent(Int.self, forKey: .awayThresholdSeconds) ?? 120
    }
}

struct AppActivity: Codable, Identifiable, Equatable {
    var id: String { "\(day.timeIntervalSince1970)-\(bundleIdentifier)" }
    var day: Date
    var bundleIdentifier: String
    var appName: String
    var seconds: Int
}
