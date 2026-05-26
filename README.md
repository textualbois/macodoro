# PomoBar

A tiny native macOS Pomodoro app that lives in the menu bar.

## Requirements

- macOS 14 or newer
- Xcode Command Line Tools
- Apple Silicon Mac, or adjust the build target in `scripts/build-app.sh`

## Build

```sh
./scripts/build-app.sh
```

The script compiles the Swift sources directly with `swiftc` and creates:

```text
.build/PomoBar.app
```

## Run

```sh
open .build/PomoBar.app
```

To restart after rebuilding:

```sh
pkill PomoBar
open .build/PomoBar.app
```

## Features

- Menu bar Pomodoro timer with focus and break intervals
- Start, pause, reset, and skip controls
- Local focus history with daily streaks
- Focus and app activity summaries
- Optional tracked app activity with idle thresholds
- Configurable time display: all minutes or hours and minutes
- Daily activities with target counts, tally-style progress, and reminders
- Reminder popups with Done, Stop Reminding, and Later actions

## Data

PomoBar stores settings and history locally in Application Support:

```text
~/Library/Application Support/PomoBar/state.json
```

## Notes

`swift run PomoBar` may not work with every local Swift toolchain because this app is built as a menu bar `.app` bundle. Use `./scripts/build-app.sh` as the canonical build path.
