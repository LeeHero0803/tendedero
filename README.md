# Tendedero · 通用剪贴板扩展

本分支 `feature/universal-clipboard` 基于 [Anubhav-Rai 的文字便签分支](https://github.com/Anubhav-Rai/tendedero/tree/feature/copied-text)，在原有截图晾衣绳上增加文件引用、纯文本传输修复和卡片样式改进。原项目：[alejandrobujan/tendedero](https://github.com/alejandrobujan/tendedero)。这是非官方源码扩展，目前未发布本分支的安装包。

## 本分支的更新

| 功能 | 行为 |
| --- | --- |
| 纯文本传输 | 点击或拖出文字便签时仅提供纯文本，不再把内部 `.txt` 存储文件作为附件；保留原文换行、空格和 Unicode。 |
| 文件与文件夹 | 新增「挂起复制的文件 / Hang copied files」开关，支持 Finder 多选，每个文件独立成卡；真正的 `.txt` 文件仍按文件处理。 |
| 文件内容预览 | 通过系统 Quick Look 异步请求图片、视频和支持的文档缩略图，保留文件名；不支持的格式及文件夹使用系统图标。 |
| 主题与排版 | 文字和文件卡片跟随深浅色主题，已有卡片同步更新；便签带淡横线，文字块及文件预览与文件名整体垂直居中。 |
| 类型识别 | 图片使用银色细金属夹；便签使用微暖钛色金属长尾夹，带双线手柄和梯形夹体；文件使用微冷钢色金属山形夹，带拱形弹片、圆孔和卷边夹口。保留玻璃边框与摆动风格。 |
| 生命周期 | 文件引用类型随记录保存；忽略应用自身复制，保留私密剪贴板过滤；卡片移除后取消未完成的预览请求。 |

### 使用与构建

需要 macOS 14+ 和可用的 Swift/macOS 开发工具链。先退出正在运行的旧版：

```sh
git clone -b feature/universal-clipboard https://github.com/LeeHero0803/tendedero.git
cd tendedero
scripts/test-clipboard.sh
scripts/build-app.sh
open build/Tendedero.app
```

在菜单栏按需开启「挂起复制的文字」「挂起复制的文件」和图片监听。测试正常后，将 `build/Tendedero.app` 替换到「应用程序」目录。

**文件卡片保存的是引用，不是备份。** 拖出文件卡片默认复制，原文件保留；移除卡片或容量淘汰不会删除引用的原文件。右键明确选择「Move to Trash」仍会删除原文件。源文件移动或删除后，引用会失效并被清理。原有截图卡片仍遵循上游的拖放和清理行为。

部分网页输入框可能拒绝文本拖放；文档预览取决于系统及已安装的 Quick Look 支持。便签展示会截断长文本，但复制和拖出读取完整原文；便签内部仍以明文 `.txt` 保存。

### 更新记录与验证

- **2026-10-29 · 夹子轮廓重设计**：便签改为金属长尾夹，文件改为金属山形夹，图片保留原款细夹；以银色、微暖钛色、微冷钢色做轻微光泽色差。三种夹子保持相同的 26 点高度和悬挂位置，不改变卡片间距与交互区域。

- **2026-10-29 · 便签底纹增强**：深浅色模式的横线透明度由 9% / 8% 提升到 18% / 16%，并加粗线条，改善缩略卡片上的可见度。

- **2026-10-29 · 多桌面触发恢复**：切换 Spaces 时重新同步悬浮窗口位置、菜单栏触发状态及窗口层级；展开前重新定位，即使仍在同一块物理屏幕；窗口实际不可见或不在活动 Space 时重新进入悬停触发流程。全屏桌面仍受「Over full screen apps」开关控制，默认关闭；需要在全屏中使用时须开启。本项已完成源码和静态检查，尚待 Mac 多桌面实测。

- **2026-10-25 · 左上角触发**：在「Bring the line down / 展开晾衣绳 → 悬停触发区域」中选择「仅左上角」，将悬停触发限制在每个屏幕菜单栏左侧 48 点范围；保留 0.25 秒停留延迟，偏好重启后保留，默认仍为整条菜单栏。展开后仍可移动到任意卡片操作。如希望仅悬停时展开，可同时关闭「When something new hangs」。

- **2026-10-25 · 重复便签修复**：剪贴板计数变化时，按完整 UTF-8 内容检查仍挂着的便签；划词工具恢复旧剪贴板时不再生成相同便签和冗余 `.txt`。移除便签后可以重新复制挂起，已有重复卡片不会自动删除。仅选中文字是否会临时写入剪贴板，仍取决于第三方工具；本修复抑制相同内容的重复收集。

- **2026-10-22 · 功能扩展**：修复纯文本复制/拖拽，增加文件与文件夹支持、引用持久化、主题适配及传输回归测试。
- **2026-10-22 · 视觉改进**：新增三类金属夹、淡便签横线、内容垂直居中和异步文件预览。
- 编辑环境已完成差异及 Shell 语法检查；首轮功能由使用者反馈可用。编辑环境为 Linux，未执行 macOS 编译和 UI 自动验证，第二轮视觉更新仍需实机确认。回归脚本与人工验证步骤见 [DEVELOPMENT.md](DEVELOPMENT.md)。

代码沿用上游许可证；原项目名称和图标不包含在 MIT 授权中，重新分发品牌资源前请阅读 [LICENSE](LICENSE)。

---

## 上游项目介绍

以下为上游介绍与展示图片；其中发行下载链接、浏览器演示和其他语言说明不代表本分支新增功能。

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-dark.png">
  <img src="docs/images/hero-light.png" alt="Tendedero. Screenshots, hung out to dry. Three screenshots in glass frames hang from a thin line under the macOS menu bar.">
</picture>

<h3 align="center"><a href="https://tendedero.app/?lang=en">Try it in your browser at tendedero.app&nbsp;&rsaquo;</a></h3>

<p align="center">
  Free and open source. For macOS 14 and later.
  <br>
  <a href="../../releases/latest">Download&nbsp;&rsaquo;</a>
  &nbsp;&nbsp;
  <a href="#build-from-source">Build from source&nbsp;&rsaquo;</a>
  <br><br>
  English&nbsp;·&nbsp;<a href="docs/i18n/README.es.md">Español</a>&nbsp;·&nbsp;<a href="docs/i18n/README.gl.md">Galego</a>&nbsp;·&nbsp;<a href="docs/i18n/README.fr.md">Français</a>&nbsp;·&nbsp;<a href="docs/i18n/README.pt-BR.md">Português (Brasil)</a>&nbsp;·&nbsp;<a href="docs/i18n/README.ja.md">日本語</a>&nbsp;·&nbsp;<a href="docs/i18n/README.ko.md">한국어</a>&nbsp;·&nbsp;<a href="docs/i18n/README.zh-Hans.md">简体中文</a>&nbsp;·&nbsp;<a href="docs/i18n/README.tr.md">Türkçe</a>&nbsp;·&nbsp;<a href="docs/i18n/README.az.md">Azərbaycanca</a>
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/287033?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-287033" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/287033/daily?language=Swift" alt="alejandrobujan%2Ftendedero | Trendshift" width="250" height="55"/></a>
  <a href="https://trendshift.io/repositories/287033?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-287033" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/287033/weekly?language=Swift" alt="alejandrobujan%2Ftendedero | Trendshift" width="250" height="55"/></a>
</p>

<br>

## Out of sight. Within reach.

Every screenshot you take hangs on a line just above your screen.
Rest the pointer in the menu bar and it glides down. Move away and it's gone.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/demo-dark.gif">
  <img src="docs/images/demo-light.gif" alt="The pointer rests against the top edge, the line slides down with three screenshots swinging gently, a click copies one, and the line tucks away when the pointer leaves.">
</picture>

<br>
<br>

## A gesture for everything.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/bento-dark.png">
  <img src="docs/images/bento-light.png" alt="Click to copy. Hold to mark up. Drag to share. Let it go.">
</picture>

<br>
<br>

| | |
|:--|:--|
| Click | Copy the image. |
| Press and hold | Open it in Markup. |
| Double click | Open it in Preview. |
| Force click | Take a quick look. |
| Drag into an app | Send a copy. It stays on the line. |
| Drag into a folder | Keep it there. It leaves the line. |
| Drag to the Trash, or click the cross | Let it go. |
| Rest the pointer in the menu bar | Bring the line down on that screen. |
| Click anything in the menu bar | Put it away. |
| <kbd>⌃</kbd>&thinsp;<kbd>⌥</kbd>&thinsp;<kbd>T</kbd> | Show or hide the line. Change it under Shortcut in the menu bar. |

<br>

## Your Desktop. Finally clear.

Hand Tendedero your screenshots<sup>1</sup> and they skip the Desktop
entirely. No floating thumbnail. No five-second wait. Each capture hangs
the instant you take it, and only what you drag out is kept.

Screen recordings hang there too, with a play button over them.
Press and hold one to trim it.

Same shortcuts. Same muscle memory. Just less mess.

<br>

## Copied images too.

Take a screenshot with <kbd>⌃</kbd> held, or copy an image in Preview, and it
hangs on the line like any other. Turn on Hang copied images in the menu bar
and the shirt fills in while it is on. Only images: anything copied along
with text or a file, and anything a password manager marks as private, is
left alone.

Turn on **Hang copied text** and copied text hangs as well, as a small note
card that wraps the text. Click it to copy the text again, press and hold to
open it in your text editor. Off by default.

<br>

## Private by design.

No account. No network. No analytics.
Tendedero runs entirely on your Mac, and your screenshots never leave it.

<br>

## Tech Specs

| | |
|:--|:--|
| **Compatibility** | macOS 14 Sonoma or later, on Apple silicon and Intel. Designed for macOS 27. |
| **Size** | 1.7 MB |
| **Languages** | English, Spanish, Galician, French, Portuguese (Brazil), Japanese, Korean, Chinese (Simplified), Turkish, Azerbaijani |
| **Built with** | Swift, AppKit and SwiftUI |
| **Network access** | None |
| **Price** | Free |
| **License** | MIT for the code. The name and icon are not included. |

<br>

## Install

Download the disk image from the [latest release](../../releases/latest),
open it and drag Tendedero to Applications. Or install it with Homebrew:

```sh
brew install --cask alejandrobujan/tap/tendedero
```

Tendedero is signed with a Developer ID and notarized by Apple, so it opens
like any other app.

<br>

## Build from source

```sh
git clone git@github.com:alejandrobujan/tendedero.git
cd tendedero
scripts/build-app.sh
open build/Tendedero.app
```

Requires the Swift toolchain. Xcode is optional. With the Command Line Tools for macOS 27, the script falls back to the macOS 26 SDK they install alongside, because the new SDK needs a SwiftUI macro plugin only Xcode includes. Local builds are signed ad hoc,
so macOS asks again for access to the Desktop after each rebuild.

<details>
<summary>Inside the app</summary>
<br>

| File | Role |
|:--|:--|
| `AppDelegate.swift` | Menu bar, shortcut, revealing and tucking away the line |
| `LinePanel.swift` | The transparent strip along the top of the screen |
| `LineView.swift` | The line and where each photo hangs |
| `PeggedView.swift` | One photo: glass frame, clip, swing and breeze |
| `GrabArea.swift` | Click, long press, drag and drop |
| `ScreenshotWatcher.swift` | Notices new screenshots |
| `ClipboardWatcher.swift` | Notices images and text copied to the clipboard |
| `Inbox.swift` | Takes over screenshot settings and puts them back |
| `Markup.swift` | Opens the system Markup editor and saves the result |
| `Trim.swift` | Trims a screen recording and saves the result |
| `FullScreen.swift` | Knows when to stay hidden |
| `Line.swift` | What is hanging, and what you can do with it |

Every image here, the icon included, is drawn in code by
`scripts/make-icon.swift` and `scripts/make-readme-art.swift`.
`scripts/make-dmg.sh` builds the disk image for releases.

Translations live in `Sources/Tendedero/Resources`, one `.lproj` folder per
language. `swift scripts/check-strings.swift` checks that none is missing.

</details>

<br>

---

<sub>
1. On first launch, Tendedero offers to handle your screenshots. If you accept, it turns off the floating thumbnail and saves new screenshots to its own folder, two settings also found under Options in Cmd+Shift+5. Your previous settings are saved and restored when Tendedero quits or the option is turned off from the menu bar. Tendedero hides automatically while an app is in full screen.
</sub>

<br>
<br>

<p align="center">
  <img src="docs/images/icon.png" width="64" height="64" alt="">
  <br>
  <sub>The code is MIT licensed. The Tendedero name and icon are not, so forks need their own. See <a href="LICENSE">LICENSE</a>.</sub>
  <br>
  <sub>Designed and built by <a href="https://alejandrobujan.com">Alejandro Buján</a>.</sub>
</p>
