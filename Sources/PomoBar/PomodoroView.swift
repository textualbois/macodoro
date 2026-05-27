import SwiftUI

struct PomodoroView: View {
    @ObservedObject var store: PomodoroStore
    @State private var showsExpandedHistory = false
    @State private var showsActivities = false
    @State private var showsDailyActivitySetup = false
    @State private var editingActivityID: DailyActivity.ID?
    @State private var editingActivityDraft: DailyActivityDraft?
    @State private var newActivityTitle = ""

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
            Text(headerDateString)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(alignment: .lastTextBaseline) {
                Text(phaseTitle)
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
                    Label(store.isRunning ? loc("timer.pause") : loc("timer.start"), systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)

                Button {
                    store.reset()
                } label: {
                    Label(loc("timer.reset"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Menu {
                    if trackMenuApps.isEmpty {
                        Text(loc("track.noApps"))
                    } else {
                        ForEach(trackMenuApps) { app in
                            if let trackedApp = trackedApp(matching: app) {
                                Menu {
                                    Button {
                                        store.toggleTrackedApp(trackedApp)
                                    } label: {
                                        Label(loc("track.stop"), systemImage: "xmark")
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
                    Label(loc("timer.track"), systemImage: "scope")
                }
                .menuIndicator(.hidden)
                .menuStyle(.button)
                .buttonStyle(.bordered)

                Button {
                    store.skip()
                } label: {
                    Label(loc("timer.skip"), systemImage: "forward.fill")
                }
                .buttonStyle(.bordered)

            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc("settings.intervals"))
                .font(.headline)

            Stepper(value: focusBinding, in: 1...180) {
                HStack {
                    Label(loc("settings.focus"), systemImage: "timer")
                    Spacer()
                    Text(timeSummary(minutes: store.state.settings.focusMinutes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Stepper(value: breakBinding, in: 0...60) {
                HStack {
                    Label(loc("settings.break"), systemImage: "cup.and.saucer.fill")
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
                Text(loc("performance.title"))
                    .font(.headline)
                Spacer()
                Text(store.localized("performance.streak", store.currentStreakDays))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 14) {
                stat(title: loc("performance.today"), value: "\(store.todaysCompletedSessions)", detail: loc("performance.sessions"))
                stat(title: loc("performance.focus"), value: timeSummary(minutes: store.todaysFocusedMinutes))
                stat(title: loc("performance.tracked"), value: timeSummary(seconds: store.todaysActiveSeconds))
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(loc("history.day"))
                        .frame(width: 34, alignment: .leading)
                    Text(loc("history.pomodoros"))
                    Spacer()
                    Text(loc("performance.focus"))
                        .frame(width: 48, alignment: .trailing)
                    Text(loc("history.active"))
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
                    Label(showsExpandedHistory ? loc("history.disableScroll") : loc("history.enableScroll"), systemImage: showsExpandedHistory ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var dailyActivities: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(loc("activities.title"))
                    .font(.headline)
                Spacer()
                Button {
                    showsActivities.toggle()
                } label: {
                    Image(systemName: showsActivities ? "eye.slash" : "eye")
                        .accessibilityLabel(showsActivities ? "Hide activities" : "Show activities")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    showsDailyActivitySetup.toggle()
                } label: {
                    Image(systemName: showsDailyActivitySetup ? "xmark" : "plus")
                        .accessibilityLabel(showsDailyActivitySetup ? "Cancel adding activity" : "Add activity")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showsDailyActivitySetup {
                HStack(spacing: 8) {
                    TextField(loc("activities.new"), text: $newActivityTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addDailyActivity)

                    Button(action: addDailyActivity) {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add activity")
                    }
                    .buttonStyle(.bordered)
                    .disabled(newActivityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if store.state.dailyActivities.isEmpty {
                Text(loc("activities.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if showsActivities {
                VStack(spacing: 8) {
                    ForEach(store.state.dailyActivities) { activity in
                        dailyActivityRow(activity)
                    }
                }
            } else {
                compactActivitiesOverview
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(loc("footer.history"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            timeFormatMenu
            Button(loc("footer.quit")) {
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
                                timeDisplayTitle(for: format),
                                systemImage: store.state.settings.timeDisplayFormat == format ? "checkmark" : ""
                            )
                        }
                    }
                    Divider()
                    Menu("Language") {
                        ForEach(AppLanguagePreference.allCases) { language in
                            Button {
                                store.updateAppLanguage(language)
                            } label: {
                                Label(
                                    language.title,
                                    systemImage: store.state.settings.appLanguage == language ? "checkmark" : ""
                                )
                            }
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
        store.state.settings.breakMinutes == 0 ? loc("settings.none") : timeSummary(minutes: store.state.settings.breakMinutes)
    }

    private var compactActivitiesOverview: some View {
        let count = store.state.dailyActivities.reduce(0) { total, activity in
            total + min(store.dailyActivityCount(for: activity), max(activity.targetCount, 1))
        }
        let target = store.state.dailyActivities.reduce(0) { total, activity in
            total + max(activity.targetCount, 1)
        }

        return HStack(spacing: 8) {
            ActivityCompletionMarks(count: count, target: target)
            Spacer()
            Text("\(count)/\(target)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(count >= target ? .green : .secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: 24)
    }

    private func dailyActivityRow(_ activity: DailyActivity) -> some View {
        let isEditing = editingActivityID == activity.id
        let count = isEditing ? editingActivityDraft?.count ?? store.dailyActivityCount(for: activity) : store.dailyActivityCount(for: activity)
        let target = isEditing ? editingActivityDraft?.targetCount ?? max(activity.targetCount, 1) : max(activity.targetCount, 1)

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
                Button {
                    incrementVisibleDailyActivity(activity, count: count, target: target, isEditing: isEditing)
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add completed activity")
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(count >= target ? .tertiary : .secondary)
                .frame(width: 18, height: 18)
                .disabled(count >= target)
                Button {
                    if isEditing {
                        saveDailyActivityDraft(for: activity)
                    } else {
                        startEditing(activity)
                    }
                } label: {
                    Text(isEditing ? loc("activities.save") : loc("activities.edit"))
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                if isEditing {
                    Button {
                        cancelEditingActivity()
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel("Cancel editing")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if isEditing {
                dailyActivityEditor(activity)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func incrementVisibleDailyActivity(_ activity: DailyActivity, count: Int, target: Int, isEditing: Bool) {
        let newCount = min(count + 1, max(target, 1))
        if isEditing {
            updateEditingActivityDraft {
                $0.count = newCount
            }
        } else {
            store.updateDailyActivityCount(activity, count: newCount)
        }
    }

    private func dailyActivityEditor(_ activity: DailyActivity) -> some View {
        let count = editingActivityDraft?.count ?? store.dailyActivityCount(for: activity)
        let target = editingActivityDraft?.targetCount ?? currentDailyActivity(activity).targetCount

        return VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                valueStepper(
                    title: loc("activities.completed"),
                    value: "\(count)",
                    valueWidth: 34,
                    binding: dailyActivityCountBinding(for: activity),
                    range: 0...max(target, 1),
                    step: 1
                )

                valueStepper(
                    title: loc("activities.target"),
                    value: "\(target)",
                    valueWidth: 34,
                    binding: dailyActivityTargetBinding(for: activity),
                    range: 1...20,
                    step: 1
                )

                Spacer()

                Button {
                    store.removeDailyActivity(activity)
                    cancelEditingActivity()
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("Remove")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: "bell")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 28)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Toggle("Reminders", isOn: dailyActivityReminderEnabledBinding(for: activity))
                    .labelsHidden()
                    .toggleStyle(.switch)

                if editingActivityDraft?.reminderEnabled ?? currentDailyActivity(activity).reminderEnabled {
                    valueStepper(
                        title: loc("activities.start"),
                        value: formattedMinuteOfDay(editingActivityDraft?.reminderStartMinutes ?? currentDailyActivity(activity).reminderStartMinutes),
                        valueWidth: 48,
                        binding: dailyActivityReminderStartBinding(for: activity),
                        range: 0...1439,
                        step: 15
                    )

                    valueStepper(
                        title: loc("activities.stop"),
                        value: formattedMinuteOfDay(editingActivityDraft?.reminderStopMinutes ?? currentDailyActivity(activity).reminderStopMinutes),
                        valueWidth: 48,
                        binding: dailyActivityReminderStopBinding(for: activity),
                        range: 0...1439,
                        step: 15
                    )

                    valueStepper(
                        title: loc("activities.interval.short"),
                        value: "\(editingActivityDraft?.reminderIntervalMinutes ?? currentDailyActivity(activity).reminderIntervalMinutes)m",
                        valueWidth: 40,
                        binding: dailyActivityReminderIntervalBinding(for: activity),
                        range: 5...240,
                        step: 5
                    )
                }
            }
        }
    }

    private func dailyActivityCountBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                editingActivityDraft?.count ?? store.dailyActivityCount(for: activity)
            },
            set: {
                let target = editingActivityDraft?.targetCount ?? currentDailyActivity(activity).targetCount
                let count = min(max($0, 0), max(target, 1))
                updateEditingActivityDraft {
                    $0.count = count
                }
            }
        )
    }

    private func dailyActivityTargetBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                editingActivityDraft?.targetCount ?? currentDailyActivity(activity).targetCount
            },
            set: {
                let targetCount = min(max($0, 1), 20)
                updateEditingActivityDraft {
                    $0.targetCount = targetCount
                    $0.count = min($0.count, targetCount)
                }
            }
        )
    }

    private func valueStepper(
        title: String,
        value: String,
        valueWidth: CGFloat,
        binding: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 0) {
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: valueWidth, height: 28)
                    .background(Color(nsColor: .controlColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Stepper(value: binding, in: range, step: step) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
    }

    private func dailyActivityReminderEnabledBinding(for activity: DailyActivity) -> Binding<Bool> {
        Binding(
            get: {
                editingActivityDraft?.reminderEnabled ?? currentDailyActivity(activity).reminderEnabled
            },
            set: { isEnabled in
                updateEditingActivityDraft {
                    $0.reminderEnabled = isEnabled
                }
            }
        )
    }

    private func dailyActivityReminderStartBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                editingActivityDraft?.reminderStartMinutes ?? currentDailyActivity(activity).reminderStartMinutes
            },
            set: {
                let minutes = min(max($0, 0), 1439)
                updateEditingActivityDraft {
                    $0.reminderStartMinutes = minutes
                }
            }
        )
    }

    private func dailyActivityReminderIntervalBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                editingActivityDraft?.reminderIntervalMinutes ?? currentDailyActivity(activity).reminderIntervalMinutes
            },
            set: {
                let minutes = min(max($0, 5), 240)
                updateEditingActivityDraft {
                    $0.reminderIntervalMinutes = minutes
                }
            }
        )
    }

    private func dailyActivityReminderStopBinding(for activity: DailyActivity) -> Binding<Int> {
        Binding(
            get: {
                editingActivityDraft?.reminderStopMinutes ?? currentDailyActivity(activity).reminderStopMinutes
            },
            set: {
                let minutes = min(max($0, 0), 1439)
                updateEditingActivityDraft {
                    $0.reminderStopMinutes = minutes
                }
            }
        )
    }

    private func currentDailyActivity(_ activity: DailyActivity) -> DailyActivity {
        store.state.dailyActivities.first(where: { $0.id == activity.id }) ?? activity
    }

    private func formattedMinuteOfDay(_ minuteOfDay: Int) -> String {
        let clampedMinute = min(max(minuteOfDay, 0), (24 * 60) - 1)
        let hour = clampedMinute / 60
        let minute = clampedMinute % 60
        return String(format: "%02d:%02d", hour, minute)
    }
    private func startEditing(_ activity: DailyActivity) {
        let currentActivity = currentDailyActivity(activity)
        editingActivityID = activity.id
        editingActivityDraft = DailyActivityDraft(
            count: store.dailyActivityCount(for: activity),
            targetCount: max(currentActivity.targetCount, 1),
            reminderEnabled: currentActivity.reminderEnabled,
            reminderStartMinutes: currentActivity.reminderStartMinutes,
            reminderIntervalMinutes: currentActivity.reminderIntervalMinutes,
            reminderStopMinutes: currentActivity.reminderStopMinutes
        )
    }

    private func cancelEditingActivity() {
        editingActivityID = nil
        editingActivityDraft = nil
    }

    private func saveDailyActivityDraft(for activity: DailyActivity) {
        guard let draft = editingActivityDraft else {
            cancelEditingActivity()
            return
        }

        store.updateDailyActivityCount(activity, count: draft.count)
        store.updateDailyActivityTarget(activity, targetCount: draft.targetCount)
        store.updateDailyActivityReminderEnabled(activity, isEnabled: draft.reminderEnabled)
        store.updateDailyActivityReminderStart(activity, minutes: draft.reminderStartMinutes)
        store.updateDailyActivityReminderInterval(activity, minutes: draft.reminderIntervalMinutes)
        store.updateDailyActivityReminderStop(activity, minutes: draft.reminderStopMinutes)
        cancelEditingActivity()
    }

    private func updateEditingActivityDraft(_ update: (inout DailyActivityDraft) -> Void) {
        guard var draft = editingActivityDraft else { return }
        update(&draft)
        editingActivityDraft = draft
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
            AwayTimeOption(title: loc("away.30s"), seconds: 30),
            AwayTimeOption(title: loc("away.2m"), seconds: 120),
            AwayTimeOption(title: loc("away.5m"), seconds: 300),
            AwayTimeOption(title: loc("away.15m"), seconds: 900),
            AwayTimeOption(title: loc("away.indefinite"), seconds: nil)
        ]
    }

    private func trackedApp(matching app: TrackedApp) -> TrackedApp? {
        store.state.trackedApps.first { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = store.appLocale
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

    private var headerDateString: String {
        let formatter = DateFormatter()
        formatter.locale = store.appLocale
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: store.currentTime)
    }

    private var phaseTitle: String {
        switch store.phase {
        case .focus:
            loc("phase.focus")
        case .breakTime:
            loc("phase.break")
        }
    }

    private func timeDisplayTitle(for format: TimeDisplayFormat) -> String {
        switch format {
        case .allMinutes:
            loc("settings.time.allMinutes")
        case .withHours:
            loc("settings.time.withHours")
        }
    }

    private func loc(_ key: String) -> String {
        store.localized(key)
    }

    private func addDailyActivity() {
        store.addDailyActivity(title: newActivityTitle)
        newActivityTitle = ""
        showsDailyActivitySetup = false
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

struct ActivityCompletionMarks: View {
    let count: Int
    let target: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<groupCount, id: \.self) { groupIndex in
                ActivityTallyGroup(
                    targetCount: targetCount(in: groupIndex),
                    filledCount: filledCount(in: groupIndex)
                )
            }
        }
        .accessibilityLabel("\(count) of \(target) completed")
    }

    private var totalCount: Int {
        max(target, 1)
    }

    private var groupCount: Int {
        max(Int(ceil(Double(totalCount) / 5.0)), 1)
    }

    private func targetCount(in groupIndex: Int) -> Int {
        let remaining = totalCount - (groupIndex * 5)
        return min(max(remaining, 0), 5)
    }

    private func filledCount(in groupIndex: Int) -> Int {
        let remaining = min(max(count, 0), totalCount) - (groupIndex * 5)
        return min(max(remaining, 0), 5)
    }
}

struct ActivityTallyGroup: View {
    let targetCount: Int
    let filledCount: Int

    var body: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(0..<verticalMarkCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(markColor(for: index))
                        .frame(width: 3, height: 16)
                }
            }

            if targetCount == 5 {
                Rectangle()
                    .fill(markColor(for: 4))
                    .frame(width: 26, height: 3)
                    .rotationEffect(.degrees(-22))
            }
        }
        .frame(width: 28, height: 18, alignment: .leading)
    }

    private var verticalMarkCount: Int {
        min(targetCount, 4)
    }

    private func markColor(for index: Int) -> Color {
        index < filledCount ? .green : .secondary.opacity(0.18)
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

private struct DailyActivityDraft {
    var count: Int
    var targetCount: Int
    var reminderEnabled: Bool
    var reminderStartMinutes: Int
    var reminderIntervalMinutes: Int
    var reminderStopMinutes: Int
}
