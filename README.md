# A simple Timer app for Mac

[English](README.md) | [中文](README.zh-CN.md)

<img src="/screenshots/light-mode.png?raw=true" width="262" align="right">

<img src="/screenshots/dark-mode.png?raw=true" width="262" align="right">

[Download here](https://github.com/michaelvillar/timer-app/releases)

Drag the blue arrow to set a timer. Release to start! Click to pause.

When the time is up, a notification will show up with a nice sound.

Create new timers with `CMD+N`.

Press `Tab` (or `S`), or right-click the window and pick **倒计时模式** (Countdown Mode) / **秒表模式** (Stopwatch Mode), to switch every window between countdown and stopwatch (count up). Switching mode resets the clock. In stopwatch mode the clock shows elapsed time as `H:MM:SS` (e.g. `1:05:30`) instead of the countdown's `5' / 30"` style. While in stopwatch mode the window floats above all other windows — including full screen apps — so you can keep an eye on elapsed time.

Install as a [brew cask](https://caskroom.github.io) via 

```shell
brew install michaelvillar-timer
```

Inspired by the **great** [Minutes widget](http://minutes.en.softonic.com/mac) from Nitram-nunca I've been using for years. But it wasn't maintained anymore (non-retina) + it was the only widget in my dashboard :)

Timer requires macOS 14 (Sonoma) or later.

### Build

```
make
```

### Keyboard Shortcuts

Enter digits to set minutes. A decimal point specifies seconds so `2.34` is 2 minutes and 34 seconds.

| Key | Action |
|-----|--------|
| <kbd>backspace</kbd> or <kbd>escape</kbd> | Edit timer |
| <kbd>enter</kbd> | Start or pause |
| <kbd>cmd</kbd>+<kbd>n</kbd> | New timer |
| <kbd>r</kbd> | Restart with last timer |
| <kbd>+</kbd> or <kbd>↑</kbd> | Add a minute |
| <kbd>-</kbd> or <kbd>↓</kbd> | Subtract a minute |
| <kbd>shift</kbd>+<kbd>+</kbd> or <kbd>shift</kbd>+<kbd>↑</kbd> | Add 10 minutes |
| <kbd>shift</kbd>+<kbd>-</kbd> or <kbd>shift</kbd>+<kbd>↓</kbd> | Subtract 10 minutes |
| <kbd>tab</kbd> or <kbd>s</kbd> | Toggle stopwatch mode |

Timer opens in stopwatch mode by default; press <kbd>tab</kbd> to switch to countdown.

### Stopwatch mode

| Key | Action |
|-----|--------|
| <kbd>enter</kbd> or <kbd>space</kbd> | Start, pause, resume |
| <kbd>escape</kbd> | Reset to zero |
| <kbd>tab</kbd> or <kbd>s</kbd> | Back to countdown mode |

Digits, backspace, scroll wheel and ±minute keys are disabled in stopwatch mode — there is no duration to set. Elapsed time has no upper limit; the progress ring wraps around once per hour.

Once the stopwatch is running, the start time (e.g. `起始 21:30:45`) is shown under the elapsed time. It stays at the original start when you pause and resume, and disappears on reset.

### Child clocks

Right-click a window and pick **子时钟 ▸ 添加新的子时钟** (Child clock ▸ Add new child clock) to open a nested window. It looks and works exactly like the main window, keeps its own independent clock, and is labelled `子时钟1`, `子时钟2`, … by depth. The name sits outside the clock circle, below the face.

- Each clock starts and pauses on its own, so every clock has its own start time. A new child clock in stopwatch mode starts running immediately.
- Double-click a child clock's name to rename it (press <kbd>enter</kbd> to confirm, <kbd>esc</kbd> to cancel). The name is used for notifications and the Dock badge.
- Closing a child clock leaves its parent running; closing the main clock closes the whole chain.
- A child clock's countdown can never be longer than its parent's — drag or type a longer duration and it is capped at the parent's duration.
- When a child clock's countdown finishes, it closes itself together with its own children (the main clock just notifies you and stays open).
- For now children can only be nested one under another; sibling clocks are not implemented yet.

### Child clock templates

Right-click a **child** clock and pick **子时钟 ▸ 保存为模板…**. A panel shows the template (name, mode, duration) and lets you change the name before saving.

- A template remembers the name, the mode, and — for countdowns — the duration, plus whether a new clock should start running right away.
- **子时钟 ▸ 从模板选择** lists every saved template; picking one creates a child clock with that name, mode and duration in one go.
- Templates are stored in `UserDefaults`, so they survive a restart. Saving under an existing name replaces that template.
