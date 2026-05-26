import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = PomodoroStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.onFocusCompleted = { [weak self] in
            self?.showFocusCompletedAlert()
        }
        store.onDailyActivityReminder = { [weak self] activity in
            self?.showDailyActivityReminder(for: activity)
        }
        configureStatusItem()
        configurePopover()
        bindStatusTitle()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "PomoBar")
        item.button?.imagePosition = .imageLeading
        item.button?.title = store.statusTitle
        item.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(rootView: PomodoroView(store: store))
    }

    private func bindStatusTitle() {
        Publishers.CombineLatest3(store.$phase, store.$secondsRemaining, store.$isRunning)
            .sink { [weak self] _, _, _ in
                self?.statusItem?.button?.title = self?.store.statusTitle ?? "Pomo"
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showFocusCompletedAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Current streak is over"
        alert.informativeText = "Nice work. Start a new focus streak now or take your configured break."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start New Streak")
        alert.addButton(withTitle: store.state.settings.breakMinutes == 0 ? "Later" : "Start Break")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.startNewFocusStreak()
        } else {
            store.startBreak()
        }
    }

    private func showDailyActivityReminder(for activity: DailyActivity) {
        NSApp.activate(ignoringOtherApps: true)

        let count = store.dailyActivityCount(for: activity)
        let target = max(activity.targetCount, 1)
        let alert = NSAlert()
        alert.messageText = activity.title
        alert.informativeText = "Daily activity progress: \(count)/\(target)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Stop Reminding")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.completeDailyActivityToday(activity)
        } else if response == .alertSecondButtonReturn {
            store.stopRemindingDailyActivityToday(activity)
        }
    }
}
