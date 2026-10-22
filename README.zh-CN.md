# Timer —— 一个简洁的 Mac 计时器

<img src="/screenshots/light-mode.png?raw=true" width="262" align="right">

<img src="/screenshots/dark-mode.png?raw=true" width="262" align="right">

[English](README.md) | 中文

拖动蓝色箭头设定时长，松手即开始计时，点击可暂停。

时间到了会弹出通知并响一声提示音。

用 `CMD+N` 开一个新的计时器窗口。

按 <kbd>Tab</kbd>（或 <kbd>S</kbd>），也可以在窗口上右键选 **秒表模式**，在倒计时与秒表（正向计时）之间切换。切换模式会重置当前计时。秒表模式下时间显示为「时:分:秒」（如 `1:05:30`），而不是倒计时的 `5' / 30"` 形式。秒表模式下窗口会悬浮在所有窗口之上（包括全屏应用），方便随时看已用时长。

## 安装

从 [Releases](https://github.com/michaelvillar/timer-app/releases) 下载，或用 [brew cask](https://caskroom.github.io)：

```shell
brew install michaelvillar-timer
```

也可以自己编译安装到 `/Applications`：

```shell
make install
```

设计灵感来自 Nitram-nunca 那个非常棒的 [Minutes widget](http://minutes.en.softonic.com/mac)——我用了很多年，但它已经不再维护（也不支持 Retina），而且是我 Dashboard 里唯一留下的小组件 :)

需要 macOS 14（Sonoma）或更高版本。

## 编译

```shell
make
```

## 键盘快捷键

直接输入数字设定分钟，小数点后表示秒，所以 `2.34` 是 2 分 34 秒。

| 按键 | 作用 |
|------|------|
| <kbd>backspace</kbd> 或 <kbd>escape</kbd> | 重新编辑时长 |
| <kbd>enter</kbd> | 开始 / 暂停 |
| <kbd>cmd</kbd>+<kbd>n</kbd> | 新建计时器 |
| <kbd>r</kbd> | 用上次的时长重新开始 |
| <kbd>+</kbd> 或 <kbd>↑</kbd> | 加 1 分钟 |
| <kbd>-</kbd> 或 <kbd>↓</kbd> | 减 1 分钟 |
| <kbd>shift</kbd>+<kbd>+</kbd> 或 <kbd>shift</kbd>+<kbd>↑</kbd> | 加 10 分钟 |
| <kbd>shift</kbd>+<kbd>-</kbd> 或 <kbd>shift</kbd>+<kbd>↓</kbd> | 减 10 分钟 |
| <kbd>tab</kbd> 或 <kbd>s</kbd> | 切换秒表模式 |

打开时默认是秒表模式，按 <kbd>tab</kbd> 切回倒计时。

## 秒表模式

| 按键 | 作用 |
|------|------|
| <kbd>enter</kbd> 或 <kbd>space</kbd> | 开始 / 暂停 / 继续 |
| <kbd>escape</kbd> | 归零 |
| <kbd>tab</kbd> 或 <kbd>s</kbd> | 切回倒计时 |

秒表模式下没有时长可设，因此数字键、退格、滚轮和 ±分钟键都被禁用。计时没有上限，进度环每一小时绕满一圈。

开始计时后，大字下方会显示起始时刻（如 `起始 21:30:45`）。暂停再继续时起始时刻保持不变，按 <kbd>escape</kbd> 归零后隐藏。

## 其他

- 窗口可以拖着边缘改大小，始终保持正方形，内容等比缩放
- 右键菜单可以切换秒表模式、设置提示音、勾选在 Dock 显示角标
- VoiceOver 的时间播报是中文的
