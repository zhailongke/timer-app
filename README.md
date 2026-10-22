# A simple Timer app for Mac

<img src="/screenshots/light-mode.png?raw=true" width="262" align="right">

<img src="/screenshots/dark-mode.png?raw=true" width="262" align="right">

[Download here](https://github.com/michaelvillar/timer-app/releases)

Drag the blue arrow to set a timer. Release to start! Click to pause.

When the time is up, a notification will show up with a nice sound.

Create new timers with `CMD+N`.

Press `S`, or right-click the window and pick **秒表模式** (Stopwatch Mode), to switch a window between countdown and stopwatch (count up). Switching mode resets the clock. In stopwatch mode the clock shows elapsed time as `H:MM:SS` (e.g. `1:05:30`) instead of the countdown's `5' / 30"` style. While in stopwatch mode the window floats above all other windows — including full screen apps — so you can keep an eye on elapsed time.

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
| <kbd>s</kbd> | Toggle stopwatch mode |

### Stopwatch mode

| Key | Action |
|-----|--------|
| <kbd>enter</kbd> or <kbd>space</kbd> | Start, pause, resume |
| <kbd>escape</kbd> | Reset to zero |

Digits, backspace, scroll wheel and ±minute keys are disabled in stopwatch mode — there is no duration to set. Elapsed time has no upper limit; the progress ring wraps around once per hour.
