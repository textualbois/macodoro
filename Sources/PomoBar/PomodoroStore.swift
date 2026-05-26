import AppKit
import Foundation
import IOKit
import SwiftUI

@MainActor
final class PomodoroStore: ObservableObject {
    @Published var state: PomodoroState {
        didSet { save() }
    }

    @Published var phase: PomodoroPhase = .focus
    @Published var isRunning = false
    @Published var secondsRemaining: Int
    @Published var currentTime = Date()
    @Published var availableApps: [TrackedApp] = []

    var onFocusCompleted: (() -> Void)?
    var onDailyActivityReminder: ((DailyActivity) -> Void)?

    private var focusStartedAt: Date?
    private var tickTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var lastActivitySampleAt: Date?
    private var lastDailyActivityReminderAt: [UUID: Date] = [:]
    private let calendar = Calendar.autoupdatingCurrent
    private let stateURL: URL

    init() {
        let url = Self.makeStateURL()
        let loadedState = Self.load(from: url)
        stateURL = url
        state = loadedState
        secondsRemaining = loadedState.settings.focusMinutes * 60
        refreshAvailableApps()
        startAppTracking()
        startClock()
    }

    deinit {
        tickTimer?.invalidate()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    var statusTitle: String {
        phase == .focus
            ? Self.timerFormat(seconds: secondsRemaining, format: state.settings.timeDisplayFormat)
            : "B \(Self.timerFormat(seconds: secondsRemaining, format: state.settings.timeDisplayFormat))"
    }

    var progress: Double {
        let total = max(totalSeconds(for: phase), 1)
        return 1 - (Double(secondsRemaining) / Double(total))
    }

    var todaysCompletedSessions: Int {
        sessions(on: currentTime).count
    }

    var todaysFocusedMinutes: Int {
        sessions(on: currentTime).reduce(0) { $0 + $1.plannedMinutes }
    }

    var todaysActiveSeconds: Int {
        activeSeconds(on: currentTime)
    }

    var currentStreakDays: Int {
        let activeDays = Set(state.sessions.map { calendar.startOfDay(for: $0.endedAt) })
        var day = calendar.startOfDay(for: currentTime)
        var streak = 0

        if !activeDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }

        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    var recentDays: [DayPerformance] {
        recentDays(limit: 15)
    }

    func recentDays(limit: Int) -> [DayPerformance] {
        (0..<limit).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: currentTime)) else {
                return nil
            }

            let daySessions = sessions(on: date)
            return DayPerformance(
                date: date,
                sessions: daySessions.count,
                minutes: daySessions.reduce(0) { $0 + $1.plannedMinutes },
                completedSessions: daySessions,
                activeSeconds: activeSeconds(on: date)
            )
        }
    }

    var trackedAppIDs: Set<String> {
        Set(state.trackedApps.map(\.bundleIdentifier))
    }

    func toggleRunning() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        if phase == .focus, focusStartedAt == nil {
            focusStartedAt = Date()
        }
        isRunning = true
    }

    func pause() {
        isRunning = false
    }

    func reset() {
        isRunning = false
        phase = .focus
        focusStartedAt = nil
        secondsRemaining = totalSeconds(for: .focus)
    }

    func skip() {
        completePhase(completedBySkip: true)
    }

    func startNewFocusStreak() {
        phase = .focus
        secondsRemaining = totalSeconds(for: .focus)
        focusStartedAt = Date()
        isRunning = true
    }

    func startBreak() {
        phase = .breakTime
        secondsRemaining = totalSeconds(for: .breakTime)
        focusStartedAt = nil
        isRunning = secondsRemaining > 0
    }

    func updateFocusMinutes(_ minutes: Int) {
        state.settings.focusMinutes = min(max(minutes, 1), 180)
        if phase == .focus, !isRunning {
            secondsRemaining = totalSeconds(for: .focus)
        }
    }

    func updateBreakMinutes(_ minutes: Int) {
        state.settings.breakMinutes = min(max(minutes, 0), 60)
        if phase == .breakTime, !isRunning {
            secondsRemaining = totalSeconds(for: .breakTime)
        }
    }

    func updateTimeDisplayFormat(_ format: TimeDisplayFormat) {
        state.settings.timeDisplayFormat = format
    }

    func addDailyActivity(title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        state.dailyActivities.append(DailyActivity(title: trimmedTitle))
    }

    func removeDailyActivity(_ activity: DailyActivity) {
        state.dailyActivities.removeAll { $0.id == activity.id }
        state.dailyActivityCompletions.removeAll { $0.activityID == activity.id }
        state.dailyActivityReminderSilences.removeAll { $0.activityID == activity.id }
        lastDailyActivityReminderAt.removeValue(forKey: activity.id)
    }

    func updateDailyActivityTarget(_ activity: DailyActivity, targetCount: Int) {
        guard let index = state.dailyActivities.firstIndex(where: { $0.id == activity.id }) else { return }
        state.dailyActivities[index].targetCount = min(max(targetCount, 1), 20)
    }

    func dailyActivityCount(for activity: DailyActivity, on date: Date? = nil) -> Int {
        let day = calendar.startOfDay(for: date ?? currentTime)
        return state.dailyActivityCompletions.first {
            $0.activityID == activity.id && calendar.isDate($0.day, inSameDayAs: day)
        }?.count ?? 0
    }

    func updateDailyActivityCount(_ activity: DailyActivity, count: Int) {
        setDailyActivityCount(for: activity, count: count)
    }

    func incrementDailyActivity(_ activity: DailyActivity) {
        updateDailyActivityCount(for: activity, by: 1)
    }

    func decrementDailyActivity(_ activity: DailyActivity) {
        updateDailyActivityCount(for: activity, by: -1)
    }

    func completeDailyActivityToday(_ activity: DailyActivity) {
        setDailyActivityCount(for: activity, count: max(activity.targetCount, 1))
    }

    func stopRemindingDailyActivityToday(_ activity: DailyActivity) {
        let day = calendar.startOfDay(for: currentTime)
        guard !state.dailyActivityReminderSilences.contains(where: {
            $0.activityID == activity.id && calendar.isDate($0.day, inSameDayAs: day)
        }) else { return }

        state.dailyActivityReminderSilences.append(
            DailyActivityReminderSilence(activityID: activity.id, day: day)
        )
    }

    func updateDailyActivityReminderEnabled(_ activity: DailyActivity, isEnabled: Bool) {
        guard let index = state.dailyActivities.firstIndex(where: { $0.id == activity.id }) else { return }
        state.dailyActivities[index].reminderEnabled = isEnabled
    }

    func updateDailyActivityReminderStart(_ activity: DailyActivity, minutes: Int) {
        guard let index = state.dailyActivities.firstIndex(where: { $0.id == activity.id }) else { return }
        state.dailyActivities[index].reminderStartMinutes = clampedMinuteOfDay(minutes)
    }

    func updateDailyActivityReminderInterval(_ activity: DailyActivity, minutes: Int) {
        guard let index = state.dailyActivities.firstIndex(where: { $0.id == activity.id }) else { return }
        state.dailyActivities[index].reminderIntervalMinutes = min(max(minutes, 5), 240)
    }

    func updateDailyActivityReminderStop(_ activity: DailyActivity, minutes: Int) {
        guard let index = state.dailyActivities.firstIndex(where: { $0.id == activity.id }) else { return }
        state.dailyActivities[index].reminderStopMinutes = clampedMinuteOfDay(minutes)
    }

    func toggleTrackedApp(_ app: TrackedApp) {
        if let index = state.trackedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            state.trackedApps.remove(at: index)
        } else {
            state.trackedApps.append(app)
            state.trackedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func updateAwayThreshold(for app: TrackedApp, seconds: Int?) {
        guard let index = state.trackedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return
        }

        state.trackedApps[index].awayThresholdSeconds = seconds
    }

    func sessions(on date: Date) -> [PomodoroSession] {
        state.sessions.filter { calendar.isDate($0.endedAt, inSameDayAs: date) }
    }

    func activeSeconds(on date: Date) -> Int {
        state.appActivity
            .filter { calendar.isDate($0.day, inSameDayAs: date) }
            .reduce(0) { $0 + $1.seconds }
    }

    private func startClock() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func startAppTracking() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAvailableApps()
            }
        }
    }

    private func tick() {
        currentTime = Date()
        recordTrackedAppActivity(at: currentTime)
        checkDailyActivityReminders(at: currentTime)

        guard isRunning else { return }

        if secondsRemaining > 0 {
            secondsRemaining -= 1
        }

        if secondsRemaining == 0 {
            completePhase(completedBySkip: false)
        }
    }

    private func completePhase(completedBySkip: Bool) {
        if phase == .focus {
            let end = Date()
            let start = focusStartedAt ?? end.addingTimeInterval(TimeInterval(-totalSeconds(for: .focus)))
            state.sessions.append(
                PomodoroSession(
                    startedAt: start,
                    endedAt: end,
                    plannedMinutes: state.settings.focusMinutes,
                    completedBySkip: completedBySkip
                )
            )
            focusStartedAt = nil
            isRunning = false
            phase = state.settings.breakMinutes > 0 ? .breakTime : .focus
            secondsRemaining = totalSeconds(for: phase)
            onFocusCompleted?()
        } else {
            startNewFocusStreak()
        }
    }

    private func recordTrackedAppActivity(at now: Date) {
        defer { lastActivitySampleAt = now }

        guard let lastActivitySampleAt else { return }
        let elapsed = max(0, min(Int(now.timeIntervalSince(lastActivitySampleAt).rounded()), 5))
        guard elapsed > 0,
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = app.bundleIdentifier,
              let trackedApp = state.trackedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              shouldTrackActivity(for: trackedApp) else {
            return
        }

        let appName = trackedApp.name
        addActivity(seconds: elapsed, for: bundleIdentifier, appName: appName, at: now)
    }

    private func shouldTrackActivity(for app: TrackedApp) -> Bool {
        guard let awayThresholdSeconds = app.awayThresholdSeconds else { return true }
        return systemIdleSeconds() < TimeInterval(awayThresholdSeconds)
    }

    private func addActivity(seconds: Int, for bundleIdentifier: String, appName: String, at date: Date) {
        let day = calendar.startOfDay(for: date)
        if let index = state.appActivity.firstIndex(where: {
            calendar.isDate($0.day, inSameDayAs: day) && $0.bundleIdentifier == bundleIdentifier
        }) {
            state.appActivity[index].seconds += seconds
            state.appActivity[index].appName = appName
        } else {
            state.appActivity.append(
                AppActivity(
                    day: day,
                    bundleIdentifier: bundleIdentifier,
                    appName: appName,
                    seconds: seconds
                )
            )
        }
    }

    private func updateDailyActivityCount(for activity: DailyActivity, by delta: Int) {
        setDailyActivityCount(for: activity, count: dailyActivityCount(for: activity) + delta)
    }

    private func setDailyActivityCount(for activity: DailyActivity, count: Int) {
        let day = calendar.startOfDay(for: currentTime)
        let newCount = max(0, count)
        if let index = state.dailyActivityCompletions.firstIndex(where: {
            $0.activityID == activity.id && calendar.isDate($0.day, inSameDayAs: day)
        }) {
            state.dailyActivityCompletions[index].count = newCount
        } else if newCount > 0 {
            state.dailyActivityCompletions.append(
                DailyActivityCompletion(
                    activityID: activity.id,
                    day: day,
                    count: newCount
                )
            )
        }
    }

    private func checkDailyActivityReminders(at now: Date) {
        guard onDailyActivityReminder != nil else { return }

        for activity in state.dailyActivities where isDailyActivityReminderDue(for: activity, at: now) {
            lastDailyActivityReminderAt[activity.id] = now
            onDailyActivityReminder?(activity)
            break
        }
    }

    private func isDailyActivityReminderDue(for activity: DailyActivity, at now: Date) -> Bool {
        guard activity.reminderEnabled,
              dailyActivityCount(for: activity, on: now) < max(activity.targetCount, 1),
              isDailyActivityReminderActive(for: activity, at: now),
              !isDailyActivityReminderSilenced(activity, at: now) else {
            return false
        }

        if let lastReminder = lastDailyActivityReminderAt[activity.id],
           calendar.isDate(lastReminder, inSameDayAs: now) {
            let interval = TimeInterval(max(activity.reminderIntervalMinutes, 5) * 60)
            return now.timeIntervalSince(lastReminder) >= interval
        }

        return true
    }

    private func isDailyActivityReminderActive(for activity: DailyActivity, at date: Date) -> Bool {
        let minute = minuteOfDay(for: date)
        let start = clampedMinuteOfDay(activity.reminderStartMinutes)
        let stop = clampedMinuteOfDay(activity.reminderStopMinutes)

        if start <= stop {
            return minute >= start && minute <= stop
        } else {
            return minute >= start || minute <= stop
        }
    }

    private func isDailyActivityReminderSilenced(_ activity: DailyActivity, at date: Date) -> Bool {
        state.dailyActivityReminderSilences.contains {
            $0.activityID == activity.id && calendar.isDate($0.day, inSameDayAs: date)
        }
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private func clampedMinuteOfDay(_ minutes: Int) -> Int {
        min(max(minutes, 0), (24 * 60) - 1)
    }

    private func refreshAvailableApps() {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> TrackedApp? in
            guard app.activationPolicy == .regular,
                  let bundleIdentifier = app.bundleIdentifier,
                  let name = app.localizedName else {
                return nil
            }
            return TrackedApp(bundleIdentifier: bundleIdentifier, name: name)
        }

        var seen: Set<String> = []
        availableApps = apps
            .filter { seen.insert($0.bundleIdentifier).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func systemIdleSeconds() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        let propertiesResult = IORegistryEntryCreateCFProperties(
            entry,
            &properties,
            kCFAllocatorDefault,
            0
        )
        guard propertiesResult == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any],
              let idleNanoseconds = dictionary["HIDIdleTime"] as? UInt64 else {
            return 0
        }

        return TimeInterval(idleNanoseconds) / 1_000_000_000
    }

    private func totalSeconds(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus:
            state.settings.focusMinutes * 60
        case .breakTime:
            state.settings.breakMinutes * 60
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.pomoBar.encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            print("Could not save PomoBar state: \(error)")
        }
    }

    private static func load(from url: URL) -> PomodoroState {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder.pomoBar.decode(PomodoroState.self, from: data)
        } catch {
            return PomodoroState()
        }
    }

    private static func makeStateURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appending(path: "PomoBar", directoryHint: .isDirectory)
            .appending(path: "state.json")
    }

    static func timerFormat(seconds: Int, format: TimeDisplayFormat) -> String {
        let totalMinutes = seconds / 60
        let remainingSeconds = seconds % 60

        switch format {
        case .allMinutes:
            return String(format: "%02d:%02d", totalMinutes, remainingSeconds)
        case .withHours:
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            guard hours > 0 else {
                return String(format: "%02d:%02d", minutes, remainingSeconds)
            }
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
    }

    static func durationFormat(minutes: Int, format: TimeDisplayFormat) -> String {
        switch format {
        case .allMinutes:
            return "\(minutes)m"
        case .withHours:
            guard minutes >= 60 else { return "\(minutes)m" }
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h\(remainingMinutes)m"
        }
    }

    static func durationFormat(seconds: Int, format: TimeDisplayFormat) -> String {
        durationFormat(minutes: seconds / 60, format: format)
    }
}

struct DayPerformance: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let sessions: Int
    let minutes: Int
    let completedSessions: [PomodoroSession]
    let activeSeconds: Int
}

private extension JSONEncoder {
    static var pomoBar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var pomoBar: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
