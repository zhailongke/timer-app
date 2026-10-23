# AGENTS.md

给 AI 助手看的项目约定。动手前先读这份，再读 `README.zh-CN.md` 和 `Timer/` 下的相关源码。

## 项目是什么

macOS 计时器 App（番茄钟 / 秒表），Swift + AppKit，无故事板、纯手写 UI。
上游是 `michaelvillar/timer-app`（remote 名 `origin`，只读，不要往它推送）；
自己的 fork 是 `zhailongke/timer-app`（remote 名 `myfork`，推这里）。

- 只有一个分支 `master`，跟踪 `myfork/master`
- 界面文案、注释、提交信息：中文
- `CHANGELOG.md` 条目：英文（Keep a Changelog 格式）

## 构建与验证（Makefile）

```sh
make build     # xcodebuild build，必须 0 警告
make test      # 单元测试（TimerTests）
make lint      # swiftlint
make install   # 装到 /Applications/Timer.app 并 ad-hoc 签名
make dmg       # 打包 dmg
```

`swiftlint` 通过 mise 管理，直接跑 `swiftlint` 可能找不到，用 `make lint`。

跑 xcodebuild 一律带上 `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`，否则本地签名会失败
（`make` 里已经带好了，手写命令时要自己加）。

**改完一轮的验证链**：`make build` → `make lint`（0 violations）→ `make test`（全绿）→ `make install` → `open -a /Applications/Timer.app` 确认能跑。

## 代码风格

- `.swiftlint.yml` 开了大量 opt-in 规则（含 `force_unwrapping`、`implicitly_unwrapped_optional`、`implicit_return`、`sorted_imports`、`vertical_parameter_alignment_on_call` 等），analyzer 里开了 `explicit_self` 和 `unused_import`。写完必须 `make lint` 干净，不要靠 `:disable:` 绕过。
- 数组字面量要用类型标注避免歧义；Swift 的数组字面量有截断 bug，长数组（如配色数组）优先写成循环/算式或直接分多行。
- 注释解释「为什么」，不解释「做了什么」。中文。
- 文件拆分沿用现有约定：`MV*` 视图类，`MVClockView+XXX.swift` 是 `MVClockView` 的分类，`AppDelegate+XXX.swift` 是 AppDelegate 的分类。
- 新增 `.swift` 文件**必须手工登记**进 `Timer.xcodeproj/project.pbxproj`（本工程没开 file system synchronized group）：加 `PBXFileReference`、`PBXBuildFile`，并挂到对应 group 与 Sources build phase。改完跑 `plutil -lint Timer.xcodeproj/project.pbxproj` 确认。

## 架构速览

| 文件 | 职责 |
|---|---|
| `AppDelegate.swift` | 全局：控制器注册表、窗口置顶、最后使用的模式 |
| `AppDelegate+Commands.swift` | `timer` CLI 与 URL scheme 命令 |
| `MVTimerController.swift` | 每个时钟窗口一个；窗口、工具栏、模式切换 |
| `MVClockView.swift` + `+Behavior/Layout/Labels/Title/History/Accessibility` | 表盘本体 |
| `MVHistoryTracker.swift` | 历史记录总账（记录树、持久化） |
| `MVHistoryWindowController.swift` | 历史记录窗口 |
| `MVTemplateManager.swift` / `ChildClockTemplate.swift` | 子时钟模板 |
| `TimerLogic.swift` / `TimerMode.swift` / `ClockRecord.swift` | 计时逻辑、模式枚举、记录模型 |
| `MVWindow.swift` / `MVPinButton.swift` / `MVClockControlButton.swift` | 窗口与自定义按钮 |

## 已确定的行为约定（别改回去）

- **模式是每个时钟自己的**：`MVTimerController.setMode(_:)` 只切自己，不广播。子时钟切倒计时不该影响上级。`AppDelegate.lastUsedMode` 只是新窗口的默认值。
- **窗口浮起规则各算各的**：秒表模式或开了置顶 → `.floating` + 可加入所有 Space；否则普通窗口。
- **历史记录无感**：点开始即建记录，时长实时增长，子时钟挂到上级记录下，关时钟才收尾，退出时落盘。没有「另起一条记录」入口（已删）。
- **子时钟规则**：关闭子时钟不影响上级；关闭主时钟关掉整条链；子时钟倒计时时长受上级上限约束；新子时钟默认秒表模式并立刻起跑。
- **关闭链与父子关系**靠 `MVTimerController(parent:)` 维系，测试里可以这样直接构造，不需要 AppDelegate。

## 测试约定

- 单元测试在 `TimerTests/`，XCTest；`final class`、`override func setUp/tearDown`（`balanced_xctest_lifecycle` 会查）。
- 每个功能点一个文件：`TimerChildClockTests`、`TimerHistoryTests`、`TimerModeIndependenceTests`、`TimerStopwatchTests`、`TimerTemplateTests`、`TimerWindowControlsTests`。
- UI 测试在 `TimerUITests/`，跑 `make uitest`（需要 provisioning，本地一般跑不动）。
- 断言具体的值，不要只断言「不为空」。

## Git 约定

- 提交信息：`type: 中文说明`，正文用中文写「改了什么 + 为什么」。type 用 `feat` / `fix` / `refactor` / `style` / `perf` / `docs` / `chore`（沿用仓库历史习惯）。
- 提交前 `git status` 确认干净、只含本次改动。
- 推到 `myfork`（`git push myfork master`）。**不要**推 `origin`、不要 force push、不要自己打 tag 或发版（要发版先问）。
- 用户明确要求「提交并推送」才提交；没说就只改代码。

## 交付时的做法

1. 每完成一个可验证的小步就跑一次 build/lint/test，别攒到最后。
2. 全部完成 → `make install` → 启动确认 → 提交 → 推送到 myfork → 报告改了什么、验证结果、以及保留/删除的代码及理由。
3. 发现要改的范围比用户说的大，或要动用户说「不要动」的部分，先停下来问，不要自己扩大范围。
4. 不要做额外的视觉校验（截图比对之类），编译通过 + 冒烟即可。
