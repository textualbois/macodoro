import SwiftUI

struct PomodoroView: View {
    @ObservedObject var store: PomodoroStore
    @State private var showsExpandedHistory = false
    @State private var newActivityTitle = ""

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                timerPanel
                settings
                dailyActivities
                history
                footer
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360, height: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: store.currentTime))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(alignment: .lastTextBaseline) {
                Text(store.phase.title)
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Text(timerText(seconds: store.secondsRemaining))
                    .font(.system(.title, design: .monospaced, weight: .semibold))
            }
        }
    }

    private var timerPanel: some View {
        VStack(spacing: 14) {
            ProgressView(value: store.progress)
                .progressViewStyle(.linear)

            HStack(spacing: 8) {
                Button {
                    store.toggleRunning()
                } label: {
                    Label(store.isRunning ? "Pause" : "Start", systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)

                Button {
                    store.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Menu {
                    if trackMenuApps.isEmpty {
                        Text("No apps available")
                    } else {
                        ForEach(trackMenuApps) { app in
                            if let trackedApp = trackedApp(matching: app) {
                                Menu {
                                    Button {
                                        store.toggleTrackedApp(trackedApp)
                                    } label: {
                                        Label("Stop Tracking", systemImage: "xmark")
                                    }

                                    Divider()

                                    ForEach(awayTimeOptions) { option in
                                        Button {
                                            store.updateAwayThreshold(for: trackedApp, seconds: option.seconds)
                                        } label: {
                                            Label(
                                                option.title,
                                                systemImage: trackedApp.awayThresholdSeconds == option.seconds ? "checkmark" : ""
                                            )
                                        }
                                    }
                                } label: {
                                    Label(trackedApp.name, systemImage: "checkmark")
                                }
                            } else {
                                Button {
                                    store.toggleTrackedApp(app)
                                } label: {
                                    Label(app.name, systemImage: "")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Track", systemImage: "scope")
                }
                .menuIndicator(.hidden)
                .menuStyle(.button)
                .buttonStyle(.bordered)

                Button {
                    store.skip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)

            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intervals")
                .font(.headline)

            Stepper(value: focusBinding, in: 1...180) {
                HStack {
                    Label("Focus", systemImage: "timer")
                    Spacer()
                    Text(timeSummary(minutes: store.state.settings.focusMinutes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Stepper(value: breakBinding, in: 0...60) {
                HStack {
                    Label("Break", systemImage: "cup.and.saucer.fill")
                    Spacer()
                    Text(breakLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Performance")
                    .font(.headline)
                Spacer()
                Text("Streak \(store.currentStreakDays)d")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 14) {
                stat(title: "Today", value: "\(store.todaysCompletedSessions)", detail: "sessions")
                stat(title: "Focus", value: timeSummary(minutes: store.todaysFocusedMinutes))
                stat(title: "Tracked", value: timeSummary(seconds: store.todaysActiveSeconds))
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("Day")
                        .frame(width: 34, alignment: .leading)
                    Text("Pomodoros")
                    Spacer()
                    Text("Focus")
                        .frame(width: 48, alignment: .trailing)
                    Text("Active")
                        .frame(width: 48, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

                Group {
                    if showsExpandedHistory {
                        ScrollView {
                            historyRows
                        }
                        .frame(height: historyScrollHeight)
                    } else {
                        historyRows
                    }
                }

                Button {
                    showsExpandedHistory.toggle()
                } label: {
                    Label(showsExpandedHistory ? "Disable scroll" : "Enable scroll", systemImage: showsExpandedHistory ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var dailyActivities: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Activities")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("New activity", text: $newActivityTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDailyActivity)

                Button(action: addDailyActivity) {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add activity")
                }
                .buttonStyle(.bordered)
                .disabled(newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if store.state.dailyActivities.isEmpty {
                Text("No daily activities yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.state.dailyActivities) { activity in
                        dailyActivityRow(activity)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("History is saved locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            timeFormatMenu
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func stat(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeFormatMenu: some View {
        Menu {
            ForEach(TimeDisplayFormat.allCases) { format in
                Button {
                    store.updateTimeDisplayFormat(format)
                } label: {
                    Label(
                        format.title,
                        systemImage: store.state.settings.timeDisplayFormat == format ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .accessibilityLabel("Settings")
        }
        .menuIndicator(.hidden)
        .menuStyle(.button)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var focusBinding: Binding<Int> {
        Binding(
            get: { store.state.settings.focusMinutes },
            set: { store.updateFocusMinutes($0) }
        )
    }

    private var breakBinding: Binding<Int> {
        Binding(
            get: { store.state.settings.breakMinutes },
            set: { store.updateBreakMinutes($0) }
        )
    }

    private var breakLabel: String {
        store.state.settings.breakMinutes == 0 ? "none" : timeSummary(minutes: store.state.settings.breakMinutes)
    }

    private func dailyActivityRow(_ activity: DailyActivity) -> some View {
        let count = store.dailyActivityCount(for: activity)
        let target = max(activity.targetCount, 1)
        let progress = min(Double(count) / Double(target), 1)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(activity.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text("\(count)/\(target)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(count >= target ? .green : .secondary)
                    .frame(width: 42, alignment: .trailing)
            }

            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Button {
                    store.decrementDailyActivity(activity)
                } label: {
                    Image(systemName: "minus")
                        .accessibilityLabel("Decrease")
                }
                .buttonStyle(.borderless)
                .disabled(count == 0)

                Button {
                    store.incrementDailyActivity(activity)
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Increase")
                }
                .buttonStyle(.borderless)

                Stepper(
                    value: dailyActivityTargetBinding(for: activity),
                    in: 1...20
                ) {
                    EmptyView()
                }
                .labelsHidden()

                Button {
                    store.removeDailyActivity(activity)
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("Remove")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: dailyActivityReminderEnabledBinding(for: activity)) {
                    Label("Remind", systemImage: "bell")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(.switch)

                if currentDailyActivity(activity).reminderEnabled {
                    HStack(spacing: 6) {
                        DatePicker(
                            "From",
                            selection: dailyActivityReminderStartBinding(for: activity),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()

                        Stepper(
                            value: dailyActivityReminderIntervalBinding(for: activity),
                            in: 5...240,
                            step: 5
                        ) {
                            Text("Every \(currentDailyActivity(activity).reminderIntervalMinutes)m")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                        }

                        DatePicker(
                            "Until",
                            selection: dailyActivityReminderStopBinding(for: activity),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func dailyActivityTargetBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                store.state.dailyActivities.first(where: { $0.id == activity.id })?.targetCount ?? activity.targetCount
            },
            set: {
                store.updateDailyActivityTarget(activity, targetCount: $0)
            }
        )
    }

    private func dailyActivityReminderEnabledBinding(for activity: DailyActivity) -> Binding<Bool> {
        Binding(
            get: {
                currentDailyActivity(activity).reminderEnabled
            },
            set: {
                store.updateDailyActivityReminderEnabled(activity, isEnabled: $0)
            }
        )
    }

    private func dailyActivityReminderStartBinding(for activity: DailyActivity) -> Binding<Date> {
        Binding(
            get: {
                dateForMinuteOfDay(currentDailyActivity(activity).reminderStartMinutes)
            },
            set: {
                store.updateDailyActivityReminderStart(activity, minutes: minuteOfDay(for: $0))
            }
        )
    }

    private func dailyActivityReminderIntervalBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                currentDailyActivity(activity).reminderIntervalMinutes
            },
            set: {
                store.updateDailyActivityReminderInterval(activity, minutes: $0)
            }
        )
    }

    private func dailyActivityReminderStopBinding(for activity: DailyActivity) -> Binding<Date> {
        Binding(
            get: {
                dateForMinuteOfDay(currentDailyActivity(activity).reminderStopMinutes)
            },
            set: {
                store.updateDailyActivityReminderStop(activity, minutes: minuteOfDay(for: $0))
            }
        )
    }

    private func currentDailyActivity(_ activity: DailyActivity) -> DailyActivity {
        store.state.dailyActivities.first(where: { $0.id == activity.id }) ?? activity
    }

    private func dateForMinuteOfDay(_ minuteOfDay: Int) -> Date {
        let clampedMinute = min(max(minuteOfDay, 0), (24 * 60) - 1)
        let hour = clampedMinute / 60
        let minute = clampedMinute % 60
        return Calendar.autoupdatingCurrent.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: store.currentTime
        ) ?? store.currentTime
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private var trackMenuApps: [TrackedApp] {
        var apps = store.availableApps
        for trackedApp in store.state.trackedApps where !apps.contains(where: { $0.bundleIdentifier == trackedApp.bundleIdentifier }) {
            apps.append(trackedApp)
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var historyDays: [DayPerformance] {
        store.recentDays(limit: showsExpandedHistory ? 15 : 8)
    }

    private var historyRows: some View {
        VStack(alignment: .leading, spacing: historyRowSpacing) {
            ForEach(historyDays) { day in
                HStack(spacing: 8) {
                    Text(dayLabel(for: day.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    TallyMarks(sessions: day.completedSessions)
                        .frame(height: 18)
                    Spacer()
                    Text(timeSummary(minutes: day.minutes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                    Text(timeSummary(seconds: day.activeSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                .frame(height: historyRowHeight)
            }
        }
    }

    private var historyRowHeight: CGFloat {
        24
    }

    private var historyRowSpacing: CGFloat {
        6
    }

    private var historyScrollHeight: CGFloat {
        (historyRowHeight * 8) + (historyRowSpacing * 7)
    }

    private var awayTimeOptions: [AwayTimeOption] {
        [
            AwayTimeOption(title: "30 seconds", seconds: 30),
            AwayTimeOption(title: "2 minutes", seconds: 120),
            AwayTimeOption(title: "5 minutes", seconds: 300),
            AwayTimeOption(title: "15 minutes", seconds: 900),
            AwayTimeOption(title: "Indefinite", seconds: nil)
        ]
    }

    private func trackedApp(matching app: TrackedApp) -> TrackedApp? {
        store.state.trackedApps.first { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func timeSummary(seconds: Int) -> String {
        PomodoroStore.durationFormat(seconds: seconds, format: store.state.settings.timeDisplayFormat)
    }

    private func timeSummary(minutes: Int) -> String {
        PomodoroStore.durationFormat(minutes: minutes, format: store.state.settings.timeDisplayFormat)
    }

    private func timerText(seconds: Int) -> String {
        PomodoroStore.timerFormat(seconds: seconds, format: store.state.settings.timeDisplayFormat)
    }

    private func addDailyActivity() {
        store.addDailyActivity(title: newActivityTitle)
        newActivityTitle = ""
    }
}

struct TallyMarks: View {
    let sessions: [PomodoroSession]

    var body: some View {
        HStack(spacing: 5) {
            if count == 0 {
                Capsule()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 28, height: 3)
            } else {
                ForEach(0..<groupCount, id: \.self) { groupIndex in
                    TallyGroup(sessions: sessionsInGroup(groupIndex))
                }
            }
        }
        .accessibilityLabel("\(count) completed sessions")
    }

    private var count: Int {
        sessions.count
    }

    private var groupCount: Int {
        max(Int(ceil(Double(count) / 5.0)), 1)
    }

    private func sessionsInGroup(_ index: Int) -> [PomodoroSession] {
        let start = index * 5
        let end = min(start + 5, count)
        guard start < end else { return [] }
        return Array(sessions[start..<end])
    }
}

struct TallyGroup: View {
    let sessions: [PomodoroSession]

    var body: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(Array(sessions.prefix(4))) { session in
                    TallyMark(session: session)
                }
            }

            if count == 5 {
                Rectangle()
                    .fill(markColor(for: sessions[4]))
                    .frame(width: 26, height: 3)
                    .rotationEffect(.degrees(-22))
            }
        }
        .frame(width: 28, height: 18, alignment: .leading)
    }

    private var count: Int {
        sessions.count
    }
}

struct TallyMark: View {
    let session: PomodoroSession

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(markColor(for: session))
            .frame(width: 3, height: 16)
            .overlay {
                if session.completedBySkip {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                }
            }
    }
}

private func markColor(for session: PomodoroSession) -> Color {
    session.completedBySkip ? .white : .orange
}

private struct AwayTimeOption: Identifiable {
    var id: String { seconds.map(String.init) ?? "indefinite" }
    let title: String
    let seconds: Int?
}
