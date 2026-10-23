# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Stopwatch mode: press `Tab` (or `S`), or right-click the window and choose 秒表模式, to count up instead of down (#stopwatch)
- Stopwatch is now the default mode at launch; `Tab` switches back to countdown
- Chinese README (`README.zh-CN.md`), linked from the English one
- Stopwatch shows the start time (`起始 21:30:45`) under the elapsed time once running
- Child clocks: right-click ▸ 添加子时钟 opens a nested window with the same look and behaviour, labelled 子时钟1/2/… by depth (#child-clock)
- Child clock rules: independent timing, closing a child spares its parent while closing the main clock closes the whole chain, countdown duration capped by the parent, and a finished child countdown closes itself
- A new child clock starts running right away in stopwatch mode
- Context menu now has separate 倒计时模式 / 秒表模式 entries, grouped under a single 计时模式 submenu
- Child clock name moved outside the clock circle (below the face); double-click it to rename
- Child clock templates: save a child clock (name, mode, duration, auto-start) via 子时钟 ▸ 保存为模板…, then rebuild one from 子时钟 ▸ 从模板选择
- Renaming is now triggered by the pencil button beside the name instead of double-clicking (double-click left the field stuck in edit mode, which killed the keyboard shortcuts)
- Hovering the name no longer makes it jump to the left
- Renaming swaps in a real `NSTextField` over the same spot instead of making the label editable in place: clicking the pencil now always gives a working input field with a visible box, select-all, enter to confirm, esc to cancel
- The click that ends a rename no longer also starts/stops the clock
- The rename affordance is now a blue round button (pencil symbol) aligned with the name text, matching the top-right pause button
- Templates can now be managed
- New history feature: every clock session is recorded (start time, duration, end time), named after its start time; closing a clock ends one record
- History records are created the moment a clock starts (not only when they are closed): the duration grows live, child clocks attach under their parent's record right away, and missing ancestor records are created automatically so a running child always has somewhere to hang
- History no longer disappears on close: records live in one persisted tree from start to finish, are flushed to disk on quit, and the open history window refreshes itself every second
- 历史记录… opens a window instead of a menu list: root level is one row per main clock session, click into a row to drill down through its child clock records, with rename and delete: 子时钟 ▸ 管理模板… opens a window listing every template with 修改… (name / mode / duration / auto-start, plus child names) and 删除 (with confirmation)
- The rename input field starts short and grows with the typed name instead of always spanning the full width
- Pressing enter to confirm a rename no longer leaks its key-up to the clock and toggles start/stop: the attributed string used for the underline now carries the centered paragraph style (without it, `attributedStringValue` overrides the label's `alignment`)
- The pencil click ends an in-progress rename instead of doing nothing, and a rename that fails to focus the field rolls back instead of leaving a stuck edit state
- Renaming no longer leaks keys to the clock shortcuts: digits / s / enter typed in the title field stay in the field
- A dim pencil beside a child clock's name hints that it is editable; hovering brightens the pencil and underlines the name
- Blue round control button in the top-right corner: shows pause while running and play when stopped, and clicking it toggles like clicking the clock face
- Child clock name is now drawn in white
- Templates can record a child clock's descendants: tick 记录下级子时钟 in the save panel to edit and store the whole chain; creating from the template rebuilds every level
- Closing the last window quits the app, so reopening starts from a single clean clock
- Stopwatch shows elapsed time as 时:分:秒 (`1:05:30`), with the font auto-shrinking to fit; dock badge and VoiceOver include hours past 1h
- Chinese UI: main menu, context menu and VoiceOver descriptions are now in Chinese
- Switching between countdown and stopwatch resets the clock
- Stopwatch windows float above every other window, including full screen apps
- Duration-setting input (digits, backspace, scroll wheel, ±minutes) is disabled in stopwatch mode
- Minimize button next to the close button at the top left, so a clock can be tucked into the Dock and brought back
- A pin button next to the pause button at the top right (same size, blue filled pin when pinned, slashed pin when not) toggles 窗口置顶 for every window; it is on by default, so windows still float above others (and follow you to every Space) until you unpin them, and the 窗口 ▸ 窗口置顶 menu item stays in sync
- Each clock keeps its own mode: switching a child clock (Tab / S / right-click 倒计时模式 / 秒表模式) no longer switches or resets its parent or any other window; a window floats above others when that window itself is in stopwatch mode, and new windows open in the mode used last

## [2.1.0] - 2026-02-07

### Added

- URL scheme support — e.g. `open "timer://5"`, `open "timer://2:30?window=2"` (#51)
- Launch argument support — e.g. `open -a Timer --args 5 --window 2` (#51)
- AppleScript support with scripting definition — e.g. `tell app "Timer" to start timer "5"` (#105)
- CLI wrapper script (`timer-cli`) with `make install-cli` target (#51)
- Commands: start, stop, reset, pause, new — all with optional window targeting
- Time input formats: `5` (5 min), `2.5` (2m30s fractional), `2:30` (2m30s colon)
- Scroll wheel input for setting timer duration (#140)
- Open/closed hand cursor feedback on arrow control (#139)

### Fixed

- Label colors now use Apple Lead (#191919) instead of pure black for better contrast

## [2.0.0] - 2026-02-07

### Added

- 43 unit tests and 38 UI tests
- Xcode schemes for running tests; `make test` and `make uitest` targets
- `make lint`, `make analyze`, and `make format` targets
- CI test step in build workflow
- Sound choice persists across launches
- Dark mode color support
- VoiceOver accessibility for timer state and arrow control

### Changed

- Upgraded to Swift 6
- Raised deployment target to macOS 14 (Sonoma)
- Replaced deprecated `NSUserNotification` with `UNUserNotificationCenter`
- Adopted `async`/`await` throughout (timers, notifications, authorization)
- Improved keyboard input to use character-based matching (better international keyboard support)
- Reduced per-frame allocations by caching gradients, images, paths, and formatters
- Extracted reusable logic into `TimerLogic` for testability
- Split large files to stay within default SwiftLint thresholds
- Modernized Xcode project settings and build configuration
- Expanded SwiftLint opt-in rules from 6 to 73
- General code cleanup: tightened access control, removed force unwraps, reduced Obj-C surface

### Removed

- `Keycodes.swift` (replaced by character-based key matching)
- ~500 lines of unused XIB menus and dead code
- Deprecated `Info.plist` keys

### Fixed

- Window occlusion detection now checks actual visibility, not just window ordering
- Secondary timer windows no longer overwrite the primary window's saved position

### CI

- Updated all GitHub Actions to current versions
- Replaced deprecated SwiftLint and release actions

## [1.6.0] - 2021-01-08

### Added

- Sound selection menu: choose between 3 sounds or no sound (#107)

### Changed

- Updated cask install instructions (#106)
- Updated brew cask command format (#98)

## [1.5.5] - 2020-07-16

### Fixed

- Simplified and fixed countdown display skipping seconds (#94)

### Changed

- Added SwiftLint for code style enforcement (#87)

## [1.5.4] - 2020-07-09

### Changed

- Use fixed-width font for less jittery countdown display (#86)

## [1.5.3] - 2020-04-23

### Changed

- Switch to `AVAudioPlayer` for playing the alert sound (#80)

## [1.5.2] - 2020-04-12

### Added

- Press `R` to restart with the last timer after Escape or completion (#75)

### Changed

- Updated text for "Show in Dock" menu option (#74)

## [1.5.1] - 2020-04-11

### Fixed

- Fixed buggy mouse control (#72)

## [1.5.0] - 2020-04-11

### Added

- Dark mode support (#67)
- GitHub Actions for build and release (#62)
- Issue templates and Code of Conduct (#63, #64)
- Keyboard shortcuts documented in README (#65)
- Makefile for build process (#47)

### Changed

- Updated window layout for Mojave compatibility (#50)
- Improved battery life with timer tolerance and reduced display updates (#44)
- Improved countdown precision to ~1/30 second with pre-timer for seconds-boundary alignment (#44)
- Reduced CPU usage by 20x when window is hidden by tracking visibility (#44)
- Window position auto-saved and restored across launches (#39)
- Locale-aware time formatting with small-caps AM/PM (#38)
- Migrated to Swift 4.1 (#37)
- Windows properly deallocated when closed with weak references (#39)

### Fixed

- Fixed crash when reopening dock timer after switching dock assignment (#39)
- Fixed memory leak in mouse event handling (#45)
- Dock badge properly removed when unchecking "Show in Dock" (#42)

## [1.4] - 2018-08-08

### Added

- Keypad Enter support (#35)
- Dock badge with timer countdown (#29)
- Context menu with dock badge toggle (#29)
- Current time label when idle (#27)
- LICENSE file (#18)
- `.gitignore` (#33)

### Changed

- Hidden unused menus (#34)
- Compressed image assets (#32)

### Fixed

- Replaced `CGFloat(M_PI)` with `.pi` (#30)

## [1.3] - 2017-06-01

### Added

- Type seconds from keyboard — e.g., `.150` sets timer to 2:30 (#14)
- Accept second values up to 599 (#14)

### Fixed

- Reduced beeping on key down (#15)

## [1.2] - 2017-02-13

### Added

- Homebrew cask install instructions
- Stay on Top toggle with preference persistence (#9)

### Changed

- Migrated to Swift 3 (#8)

## [1.1.0] - 2016-05-18

### Added

- Keyboard input support
- macOS 10.10 support

### Fixed

- Fixed countdown timing

## [1.0.2] - 2016-03-30

### Changed

- README updates

## [1.0.1] - 2016-03-30

### Fixed

- Fixed crash on launch

[Unreleased]: https://github.com/michaelvillar/timer-app/compare/2.1.0...HEAD
[2.1.0]: https://github.com/michaelvillar/timer-app/compare/2.0.0...2.1.0
[2.0.0]: https://github.com/michaelvillar/timer-app/compare/1.6.0...2.0.0
[1.6.0]: https://github.com/michaelvillar/timer-app/compare/1.5.5...1.6.0
[1.5.5]: https://github.com/michaelvillar/timer-app/compare/1.5.4...1.5.5
[1.5.4]: https://github.com/michaelvillar/timer-app/compare/1.5.3...1.5.4
[1.5.3]: https://github.com/michaelvillar/timer-app/compare/1.5.2...1.5.3
[1.5.2]: https://github.com/michaelvillar/timer-app/compare/1.5.1...1.5.2
[1.5.1]: https://github.com/michaelvillar/timer-app/compare/1.5.0...1.5.1
[1.5.0]: https://github.com/michaelvillar/timer-app/compare/1.4...1.5.0
[1.4]: https://github.com/michaelvillar/timer-app/compare/1.3...1.4
[1.3]: https://github.com/michaelvillar/timer-app/compare/1.2...1.3
[1.2]: https://github.com/michaelvillar/timer-app/compare/1.1.0...1.2
[1.1.0]: https://github.com/michaelvillar/timer-app/compare/1.0.2...1.1.0
[1.0.2]: https://github.com/michaelvillar/timer-app/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/michaelvillar/timer-app/releases/tag/1.0.1
