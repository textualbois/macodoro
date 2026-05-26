# PomoBar

A tiny native macOS Pomodoro app that lives in the menu bar.

## Run

```sh
swift run PomoBar
```

## Build an app bundle

```sh
./scripts/build-app.sh
open .build/PomoBar.app
```

PomoBar stores settings and history in Application Support, tracks completed focus sessions by date, shows the current date/time, and renders streak progress using tally bars where every fifth mark strikes through the group.
