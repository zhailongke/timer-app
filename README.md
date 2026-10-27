# A simple Timer app for Mac

[English](README.md) | [中文](README.zh-CN.md)

<img src="/screenshots/light-mode.png?raw=true" width="262" align="right">

<img src="/screenshots/dark-mode.png?raw=true" width="262" align="right">

[Download here](https://github.com/michaelvillar/timer-app/releases)

Drag the blue arrow to set a timer. Release to start! Click to pause.

When the time is up, a notification will show up with a nice sound.

Create new timers with `CMD+N`.

Press `Tab` (or `S`), or right-click the window and pick **倒计时模式** (Countdown Mode) / **秒表模式** (Stopwatch Mode), to switch that window between countdown and stopwatch (count up). Each clock keeps its own mode: switching a child clock never touches its parent. Switching mode resets the clock. In stopwatch mode the clock shows elapsed time as `H:MM:SS` (e.g. `1:05:30`) instead of the countdown's `5' / 30"` style. Windows float above all other windows — including full screen apps — so you can keep an eye on the time; click the pin button at the top right, next to the pause button (blue pin = on top, slashed pin = not; or **窗口 ▸ 窗口置顶**) to turn that off and let other windows cover them.

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

Besides <kbd>enter</kbd>, you can **click the clock face** to start/pause, or use the **blue round button in the top-right corner**: it shows a pause symbol while the clock is running (click to pause) and a play symbol when it is stopped (click to resume). A child clock's name is drawn in white below the circle.

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
- Click the blue button to the right of a child clock's name to rename it: the name turns into an input field in place (short by default, it grows as you type; press <kbd>enter</kbd> to confirm, <kbd>esc</kbd> to cancel, clicking away also confirms). The name is used for notifications and the Dock badge. The button sits next to the name, aligned with the text; hovering brightens it and underlines the name. Keys typed while renaming no longer reach the clock shortcuts.
- Closing a child clock leaves its parent running; closing the main clock closes the whole chain.
- A child clock's countdown can never be longer than its parent's — drag or type a longer duration and it is capped at the parent's duration.
- When a child clock's countdown finishes, it closes itself together with its own children (the main clock just notifies you and stays open).
- For now children can only be nested one under another; sibling clocks are not implemented yet.

### Child clock templates

Right-click a **child** clock and pick **子时钟 ▸ 保存为模板…**. A panel shows the template (name, mode, duration) and lets you change the name before saving.

- A template remembers the name, the mode, and — for countdowns — the duration, plus whether a new clock should start running right away.
- Tick **记录下级子时钟** (record child clocks) to also capture this clock's descendants; a second panel then lists every descendant so you can rename them and set whether each starts immediately. Clocks created from such a template come back with the whole chain attached.
- That option is greyed out when the clock has no descendants.
- **子时钟 ▸ 从模板选择** lists every saved template; picking one creates a child clock with that name, mode and duration in one go.
- **子时钟 ▸ 管理模板…** opens a management window listing every template

### History

Every clock session is recorded with its **start time, duration and end time**, named after its start time by default.

- **A record appears the moment you start timing**: the start time is when it started, the duration grows every second, and closing the clock ends it (the end time is set then)
- **Creating a child clock attaches it under its parent's record**; if the parent hasn't started, its record is created first (nested, level by level), so the history always shows the whole tree as it is right now
- **历史记录…** opens a separate window (not a menu list). Its root level is one row per main clock session; **click into a row** to see the child clock records under it, and keep drilling down level by level
- Select a row to **rename** or **delete** it; a 返回 button and a breadcrumb show where you are
- A clock that never actually ran (under 1 second) and has no child records leaves nothing behind
- Records live in `~/Library/Application Support/Timer/history.json`; the most recent 2000 records are kept (child clock records included): select one and press 修改… (or double-click) to change its name, mode (countdown / stopwatch), duration and "start immediately"; press 删除 to remove it. Edits are stored by id, so renaming never leaves a stale copy behind.
- Templates are stored in `UserDefaults`, so they survive a restart. Saving under an existing name replaces that template.

### Key dates

Mark the dates that matter (for example `考研 · 12 月 19 日`) and the clock face counts the days down to them.

- Right-click **事件进度…** to open a window where events can be added, changed and removed. Each event can carry its own hours-per-day for the total-hours line (blank falls back to the global value), and the face shows just the one picked in the 表盘 column, picked from **倒计时显示 ▸** in the context menu, or rotates through them every 5 seconds with **轮播显示**
- Up to three upcoming dates show at once, soonest first: **the nearest date sits on top**
- A date that is today reads 今天; dates that have passed drop off by themselves
- Dates live in `UserDefaults`, so they survive a restart. Tick 指定时刻 in the editor and pick an hour and minute to make the countdown exact: the clock face then counts down to the hour and minute (2天2时 / 5时20分) and shows the total hours left (50小时) on a line below, instead of counting whole days. The key dates window has a 总小时数按一天 __ 小时算 field at the bottom: set it to 10 and 55 days counts as 550 hours instead of 1320, for estimating in terms of the hours you actually have per day. The blue ring around the clock face means the hour marks in countdown mode, and how much of your day is already used in stopwatch mode: the time actually timed today, taken from the history (the running session included; a session that crosses midnight is cut per day, so the second day starts over from 0:00; a main clock and a child clock running at the same time are merged instead of added up) over that same per-day length (24 by default), filling the ring once you reach it. Six faint ticks divide the ring into six
