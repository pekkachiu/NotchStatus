<p align="center">
  <img src="images/icon.png" width="128" alt="NotchStatus icon">
</p>

<h1 align="center">NotchStatus</h1>

<p align="center">
  把 <a href="https://claude.com/claude-code">Claude Code</a> 的狀態顯示在 MacBook 瀏海上——不用盯著終端機，也知道 Claude 在忙、在等你，還是已經做完。
</p>

<p align="center">
  <a href="../README.md">English</a> ｜ <b>繁體中文</b>
</p>

<p align="center">
  <img src="images/demo-notch.gif" width="512" alt="NotchStatus 示範：處理中、等你確認、完成，以及滑鼠移上去時的所有 session 清單">
</p>

---

## 功能

| 狀態 | 瀏海上的樣子 | 什麼時候 |
|---|---|---|
| 處理中 | 瀏海左側藍色呼吸點 + 右側專案名 | Claude 正在思考或執行工具 |
| 等你確認 | 瀏海往下展開「⚠ 等你確認 · 專案名」，常駐 | Claude 在等你授權或回答 |
| 完成 | 展開「✓ 完成 · 專案名」3 秒，之後收成灰點 | 這一輪跑完了 |
| 閒置 | 灰點 + 專案名 | 跑完之後在等下一個指令 |

- **多個 session**：同時開好幾個 Claude Code 時，瀏海顯示最急的那個（等你確認 > 處理中 > 跑完了），同一級取最新的。
- **Hover 清單**：滑鼠移到瀏海上，展開列出所有 session 的狀態。
- **沒有瀏海的螢幕**：合上 MacBook 只用外接螢幕時，改用選單列下方的黑色浮動膠囊顯示。
- **外接螢幕設為主螢幕**也沒問題：瀏海永遠顯示在 MacBook 內建螢幕上，插拔螢幕後會自動移回來。
- **自動清理**：直接關掉終端機（沒有正常結束 session）時，會依行程是否還在自動移除該 session。
- **開機自動啟動**，沒有 Dock 圖示、不搶焦點、可顯示在全螢幕 App 上。

<p align="center">
  <img src="images/demo-pill.gif" width="440" alt="沒有瀏海的螢幕上使用的浮動膠囊"><br>
  <sub>沒有瀏海時（合上 MacBook、只用外接螢幕），同樣的狀態改用浮動膠囊顯示。</sub>
</p>

## 運作方式

```
Claude Code hooks ──寫檔──▶ ~/.claude/notch/state/<session_id>.json ──FSEvents──▶ NotchStatus.app
```

1. Claude Code 的 [hooks](https://code.claude.com/docs/en/hooks) 在事件發生時執行 `hooks/state.sh`，把每個 session 的狀態寫成一個 JSON 檔。
2. NotchStatus.app 監看這個資料夾，聚合所有 session，用 [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) 畫在瀏海上。

兩邊只透過資料夾溝通，所以可以各自獨立測試：手動寫一個 JSON 檔，就能看到瀏海的變化。

| Hook 事件 | 寫入的狀態 |
|---|---|
| `UserPromptSubmit`、`PostToolUse`、`PostToolUseFailure` | `working` |
| `Notification`（`permission_prompt`、`agent_needs_input`） | `waiting` |
| `Notification`（`idle_prompt`） | `idle` |
| `Stop` | `done` |
| `SessionEnd` | 刪除狀態檔 |

## 系統需求

- macOS 13 以上
- 有瀏海的 MacBook（沒有瀏海也能用，會改用浮動膠囊）
- [Claude Code](https://claude.com/claude-code)
- Xcode Command Line Tools（`xcode-select --install`）——**不需要完整的 Xcode**
- `jq`（macOS 15 以上內建；較舊版本請 `brew install jq`）

## 安裝

### 1. 下載原始碼

```bash
git clone https://github.com/pekkachiu/NotchStatus.git
cd NotchStatus
```

### 2. 安裝 hook 腳本

把 `hooks/state.sh` 以 symlink 連到 `~/.claude/notch/`：

```bash
mkdir -p ~/.claude/notch
ln -sf "$PWD/hooks/state.sh" ~/.claude/notch/state.sh
```

> 之後如果搬移了這個資料夾，要重新執行上面的 `ln` 指令。

### 3. 在 Claude Code 設定中加入 hooks

下面的指令會先備份 `~/.claude/settings.json`，再把 NotchStatus 的 hooks **附加**進去，原本的設定和其他 hooks 都會保留：

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
jq --arg s '$HOME/.claude/notch/state.sh' '
  def h($a): [{hooks: [{type: "command", command: "\($s) \($a)", async: true}]}];
  def m($pat; $a): [{matcher: $pat, hooks: [{type: "command", command: "\($s) \($a)", async: true}]}];
    .hooks.UserPromptSubmit   += h("working")
  | .hooks.PostToolUse        += h("working")
  | .hooks.PostToolUseFailure += h("working")
  | .hooks.Notification       += m("permission_prompt|agent_needs_input"; "waiting") + m("idle_prompt"; "idle")
  | .hooks.Stop               += h("done")
  | .hooks.SessionEnd         += h("end")
' ~/.claude/settings.json.bak > ~/.claude/settings.json
```

> 這個指令只要執行一次，重複執行會加入重複的 hooks。如果還沒有 `~/.claude/settings.json`，先執行 `echo '{}' > ~/.claude/settings.json`。

新開的 Claude Code session 就會套用；已經開著的 session 需要重新啟動。

### 4. 建置並安裝 App

```bash
cd NotchStatus
./build.sh --install
```

App 會安裝到 `~/Applications/NotchStatus.app` 並立刻啟動；如果你之後把它移到 `/Applications`，下次會改為更新那一份。第一次啟動時會註冊成登入項目，之後每次開機都會自動執行（macOS 會跳出一次通知，告知有新的登入項目）。

## 使用

安裝完就不用管它了，開 Claude Code 照常工作，瀏海會自動反映狀態。

- **看所有 session**：滑鼠移到瀏海（或浮動膠囊）上。
- **暫時關閉**：`pkill -x NotchStatus`；要再開啟就在「應用程式」資料夾點 NotchStatus。
- **取消開機啟動**：「系統設定 → 一般 → 登入項目」中關閉 NotchStatus。

App 沒有 Dock 圖示、沒有選單，也沒有設定畫面；在執行中再點一次圖示不會有任何反應，這是正常的。

## 解除安裝

```bash
pkill -x NotchStatus
rm -rf ~/Applications/NotchStatus.app /Applications/NotchStatus.app ~/.claude/notch
```

接著：
1. 到「系統設定 → 一般 → 登入項目」移除 NotchStatus。
2. 從 `~/.claude/settings.json` 的 `hooks` 中刪除所有指向 `~/.claude/notch/state.sh` 的項目（或用安裝時留下的 `settings.json.bak` 還原）。

## 開發

所有指令都在 `NotchStatus/` 下執行：

| 指令 | 用途 |
|---|---|
| `./build.sh` | 建置 `NotchStatus.app`（不安裝） |
| `./build.sh --install` | 建置並安裝（`/Applications` 已有就更新那份，否則裝到 `~/Applications`），重新啟動 |
| `./test.sh` | 執行 Swift 測試（`./test.sh --filter AggregatorTests` 只跑一組） |
| `../tests/test_state.sh` | 執行 hook 腳本的測試 |
| `./Icon/make-icon.sh` | 修改 `Icon/draw-icon.swift` 後重新產生圖示 |

**不用開 Claude Code 就能測 UI**：讓 App 改看測試資料夾，再手動寫 JSON：

```bash
mkdir -p /tmp/notch-test
NOTCH_STATE_DIR=/tmp/notch-test "$PWD/NotchStatus.app/Contents/MacOS/NotchStatus" &
echo '{"state":"waiting","project":"demo","ts":1}' > /tmp/notch-test/a.json
```

再加上 `NOTCH_FORCE_NO_NOTCH=1`，可以在有瀏海的 MacBook 上模擬沒有瀏海的浮動膠囊。測完用 `pkill -f "$PWD/NotchStatus.app"` 只關掉測試版（`pkill -x` 會連正式版一起關掉）。

**專案結構**

```
hooks/state.sh                 寫入狀態檔的 hook 腳本
tests/test_state.sh            hook 腳本的測試
NotchStatus/
├── Sources/NotchStatusCore/   純邏輯：解析、聚合、顯示形態（有完整測試）
├── Sources/NotchStatus/       App：檔案監看、瀏海與膠囊的畫面
├── Tests/                     Swift Testing 測試
├── Vendor/DynamicNotchKit/    修改過的 DynamicNotchKit（見 VENDOR.md）
└── Icon/                      圖示原始碼與 .icns
```

**只用 Command Line Tools 建置的注意事項**：CLT 沒有 SwiftUI 巨集插件（`@Entry`、`#Preview` 無法編譯），也沒有 XCTest。所以 DynamicNotchKit 放了一份修改版在 `Vendor/`，測試使用 Swift Testing，並由 `test.sh` 補上 framework 路徑。

更多設計決策與已知問題，請見 [CLAUDE.md](../CLAUDE.md)。

## 已知限制

- 瀏海一次只顯示一個 session；另一個 session 還在處理時，看不到剛完成的那個的「完成」提示（hover 清單可以看到全部）。
- Claude Code 的 `idle_prompt` 通知不一定會觸發，所以「跑完了」的灰點是由「完成」收起後直接顯示，而不是依賴它。
- `Notification` hook 有時會比 `Stop` 晚 1–2 秒觸發，狀態可能短暫落後。
- 沒有選單可以結束 App，只能用 `pkill`。

## 致謝

- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)（MIT License）by Kai Azim——瀏海視窗的基礎。本專案在 `NotchStatus/Vendor/` 放了一份修改版，修改內容見 [VENDOR.md](../NotchStatus/Vendor/DynamicNotchKit/VENDOR.md)。

NotchStatus 是獨立專案，與 Anthropic 無關，也未經其認可。

## 授權

[MIT](../LICENSE) © pekkachiu
