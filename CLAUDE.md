# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案：NotchStatus

常駐在 MacBook 瀏海（notch）的 Claude Code 狀態指示器，讓使用者不用盯著終端機也知道每個 session 的狀態：`working`（忙碌）、`waiting`（卡住等使用者授權/回答）、`done`（本輪完成，展開 3 秒後收成灰點）、`idle`（`idle_prompt` 寫入，外觀與收起後的 done 相同）。沒有瀏海的螢幕上改用黑色浮動膠囊顯示。

原始規格的 Phase 0–4 皆已完成並合併進 `main`，另加了 hover 清單與浮動膠囊。目前是維護 / 小功能迭代階段。

**非目標**：待辦清單、檔案拖放、剪貼簿、媒體控制、設定介面（設定直接改原始碼）、App Store 上架、簽章公證。

## 工作守則

- **新功能先列計畫、等使用者確認**再動手；做完停下來讓使用者親自驗證，並用一句話說明「現在該怎麼驗證」。UI 外觀改動要等使用者看過。
- **不確定的 API 一律查證**，特別是 DynamicNotchKit（vendor 在 `NotchStatus/Vendor/DynamicNotchKit/`）——先讀原始碼，不要憑印象寫。
- 實際情況與規格衝突時以實際為準，但要告知使用者差異。
- **不擴充範圍**：有改進想法先提出詢問，不要直接實作。
- `main` 只透過 PR 合併；新工作開新分支（`feat/…`、`fix/…`、`docs/…`）照常 commit，但**不要主動 push 或開 PR，完成時也不用詢問**——維護者要推 GitHub 時會主動說。Repo：https://github.com/pekkachiu/NotchStatus（公開，MIT）。
- 改完程式後，使用者日常用的是安裝好的正式版（目前在 `/Applications`）：確認沒問題後用 `./build.sh --install` 更新它。

## 公開 repo 與隱私（必讀）

這個 repo 是公開的。原本的開發歷史在另一個私人 repo（`pekkachiu/NotchStatus-dev`），裡面的 commit 帶有維護者的個人 email 與 Claude session 連結，所以公開版是從內容快照重新建立、沒有那段歷史。

- 🔴 **絕對不要把私人 repo 加回這個資料夾的 remote**，也不要從 `~/Desktop/NotchStatus-dev-git-backup`（舊 `.git` 備份）fetch、merge 或 cherry-pick。兩邊歷史一旦混在一起，push 時就可能把舊 commit 連同個人 email 推上公開 repo，而且推上去後無法完全清除。需要參考舊歷史時，只讀取、不要合併。
- 🔴 **commit 作者一律用 GitHub noreply 信箱**。本 repo 已設定 `git config user.email 169379702+pekkachiu@users.noreply.github.com`（repo 層級；全域設定仍是個人 email，不要改用全域的）。push 前可用 `git log origin/main..HEAD --format='%ae'` 確認只有 noreply。
- **commit 訊息與 PR 說明不要附 `Claude-Session` 連結**（維護者的決定，優先於預設的 attribution 規則）；`Co-Authored-By` 可以保留。
- 🔴 **不要用 GitHub 網頁或 `gh pr merge` 合併 PR**：GitHub 產生的合併 commit 作者用的是帳號設定的 email，不是 repo 的 noreply 設定，可能把個人 email 寫進公開歷史（私人 repo 的合併 commit 就發生過）。改在本機合併：`git checkout main && git pull --ff-only && git merge --no-ff <branch> -m "Merge pull request #N from pekkachiu/<branch>"`，確認 `git log origin/main..main --format='%ae'` 只有 noreply 後再 `git push origin main`；GitHub 會自動把 PR 標成已合併。
- 公開內容不要出現個人 email、本機路徑（`/Users/<name>/…`）、錢包以外的個人資訊。

## 架構

三個部分只透過狀態檔目錄耦合，可各自獨立測試：

```
Claude Code hooks ──寫檔──▶ ~/.claude/notch/state/<session_id>.json ──FSEvents──▶ Swift App（瀏海 / 膠囊）
```

- Hook 端用 `cat` 驗證；App 端用 shell 手動寫 JSON 就能測 UI，不需要跑 Claude。
- 狀態檔格式：`{"state": "working|waiting|idle|done", "project": "<cwd 的 basename>", "ts": <unix 秒>, "pid": <Claude Code 行程 pid 或 null>}`
- `project` 是 hook 觸發當下 Claude 所在目錄的名稱，Claude `cd` 進子目錄後會跟著變。
- `state.sh` 先寫 `.<sid>.json.tmp` 再 `mv`，App 不會讀到寫一半的檔案；App 讀檔時忽略 `.` 開頭的檔案。

### Hook 事件對應

| 狀態 | Hook 事件 | matcher |
|---|---|---|
| `working` | `UserPromptSubmit` | 不支援 |
| `working` | `PostToolUse`、`PostToolUseFailure` | 不設（全部工具） |
| `waiting` | `Notification` | `permission_prompt\|agent_needs_input` |
| `idle` | `Notification` | `idle_prompt` |
| `done` | `Stop` | 不支援 |
| 刪除狀態檔 | `SessionEnd` | 不支援 |

所有 hook 都是 `{"type": "command", "command": "$HOME/.claude/notch/state.sh <狀態>", "async": true}`，`SessionEnd` 的參數是 `end`。

- `UserPromptSubmit` 是必要的——少了它無法得知「正在忙」，瀏海會停在上一次的狀態。
- `PostToolUse` / `PostToolUseFailure` 用來離開 `waiting`：使用者授權或回答後 Claude 會繼續工作，但其他事件都不會觸發，沒有這兩個 hook 狀態會卡在 `waiting` 直到 `Stop`。
- `idle_prompt` 刻意不併入 `waiting`：若併入，多 session 時紅燈會變常態，真正需要授權時反而分不出來。
- ⚠️ **`idle_prompt` 不可靠**：實測有時在 Stop 後 60 秒觸發，有時閒置超過 60 秒也不觸發（官方文件未說明條件）。所以「跑完了」的顯示**不依賴它**，而是由 App 把收起後的 `done` 直接顯示成灰點；`idle` 檔案只是剛好外觀相同。

### 實測的 payload（Phase 0）

- Notification：`{"notification_type": "idle_prompt", "message": "Claude is waiting for your input", ...}`
- SessionEnd：`{"reason": "other" | "prompt_input_exit" | ...}`
- 所有事件都有 `session_id`、`cwd`、`hook_event_name`；Stop 另帶 `last_assistant_message`（可能很大，不要整包記錄）。

### 多 session 聚合（App 端）

一個 session 一個檔案。優先序 **waiting > working > idle = done**（idle 與 done 都是「跑完了」，同級，讓剛完成的能蓋過較早閒置的）；同一級取 `ts` 最大（最近觸發）的 session，顯示它的 `project`；目錄空 → 隱藏。FSEvents 的 latency（100ms）兼作 debounce。

限制（使用者已知、未處理）：一次只顯示一個 session；另一個 session 還在 working 時，剛完成的 session 不會展開「✓ 完成」。hover 清單可看到全部。

### 顯示行為

| 狀態 | 有瀏海 | 沒有瀏海（只剩外接螢幕） |
|---|---|---|
| `working` | compact：吉祥物走路 + 專案名 | 膠囊「吉祥物 專案名」 |
| `idle` / 收起後的 `done` | compact：吉祥物閉眼呼吸、旁邊飄 Z + 專案名 | 膠囊內同樣的內容 |
| `waiting` | expanded：單行「吉祥物 · 等你確認 · 專案名」，吉祥物定時跳一下，常駐直到狀態改變 | 膠囊內同樣的單行 |
| `done` | expanded：單行「吉祥物 · 完成 · 專案名」，吉祥物蹲下蓄力、大跳並迸出火花、再兩下小彈跳，3 秒後收成睡著的樣子；同一筆 done 不再展開，新的 done 會 | 膠囊內同樣的單行，3 秒後縮回 |
| 無資料 | hidden | 無膠囊 |
| 滑鼠停在上面 | expanded：所有 session 的清單（順序同聚合規則，`Aggregator.sortedForList`），移開後復原 | 膠囊本身長成清單 |

- 形態由 `Presentation.mode` 決定；畫在 DynamicNotch 還是膠囊由 `Presentation.surface` 決定。
- 狀態指示是 `Mascot.swift` 裡用 `Canvas` 依格子畫的 pixel art 吉祥物：大耳朵、小尾巴的老鼠（13 × 9 格，高 18pt 剛好一格 2pt），各狀態播不同動作。顏色一律是焦糖色系，只用明暗與飽和度分辨狀態（`Theme.Palette`）。原本是類似 Claude Code 吉祥物（Clawd）的造型與陶土橘，為了避免被誤認為 Anthropic 官方角色而改掉——新造型也不要做得像 Clawd 或其他知名角色（例如皮卡丘）。hover 清單維持色點——四隻一起動太吵，行高也會被撐大。
- ⚠️ 瀏海 compact 的內容區只有 `notchSize.height`（實測 28pt）扣掉安全區上 4 下 8 = **16pt**。吉祥物 18pt 已略為超出但看起來正常；再加高（例如想讓 Z 往上飄）就會掉出瀏海下緣。expanded 則是內容緊貼瀏海下緣，往上跳會被實體瀏海遮住，所以 `MascotView` 在自己的框上方預留 `Theme.mascotHeadroom`，跳躍發生在框內。
- 瀏海的 hover 來自 DynamicNotch 的 `isHovering`；`transitionConfiguration.skipIntermediateHides = true` 讓 compact ↔ expanded 直接變形，避免先收起再展開造成閃爍。
- 從清單收起時，清單要留到收起動畫結束才換回單行內容，否則會閃出聚合狀態（例如「✓ 完成」）。
- 狀態名稱跟隨 macOS 偏好語言（`DisplayLanguage`，App 啟動時決定一次）：繁體中文（`zh-Hant`、`zh-TW/HK/MO`）顯示「處理中 / 等你確認 / 閒置 / 完成」，其他語言一律英文「Working / Needs you / Idle / Done」；簡體中文不支援、退回英文。翻譯直接寫在 `SessionState.title(in:)`，不用 `.lproj`（CLT 手動組 .app 打包資源很麻煩）。新增文字時兩種語言都要補、並補測試。測英文畫面不用改系統語言：啟動時加 `-AppleLanguages '(en)'`。

### App 程式結構（`NotchStatus/`）

- `NotchStatusCore`（library，不依賴 UI）：`SessionStatus` 解析、`Aggregator` 聚合與清單排序、`StateStore` 讀目錄並刪除已結束 session 的檔案、`ProcessLiveness`、`Presentation`（`NotchMode`、`NotchSurface`）、`DisplayLanguage`（畫面語言與狀態名稱）。**所有規則邏輯放這裡並先寫測試**。
- `NotchStatus`（executable）：
  - `main.swift`：`StateWatcher`（FSEvents）與每 10 秒的計時器 → `StateStore.load` → `NotchController.update`
  - `NotchController`：依序呼叫 DynamicNotch 的 `hide/compact/expand` 或 `PillWindow`，一次只套一個，套完再追最新狀態；處理 hover、done 3 秒收起、螢幕變化
  - `NotchView`：`NotchModel`（DynamicNotch 在 init 時就固定了 view，內容要透過它更新）、`StatusLine`、`SessionListView`、`StatusDot`
  - `PillWindow`：沒有瀏海時的黑色膠囊（自己的 `NSPanel`）
  - `LoginItem`：開機啟動
- 型別命名避開 SwiftUI 既有名稱（例如 SwiftUI 已有 `PresentationMode`，所以用 `NotchMode`）。

## 檔案位置

- Hook 腳本原始碼在 repo 的 `hooks/`（`state.sh` 正式腳本、`probe.sh` Phase 0 事件探針），以 symlink 連到 `~/.claude/notch/`。settings.json 指向 `~/.claude/notch/*.sh`，所以 **repo 搬家後要重建 symlink**：
  `ln -sf "$PWD/hooks/state.sh" ~/.claude/notch/state.sh`
- Hook 測試：`./tests/test_state.sh`（用暫存 `HOME` 隔離，不影響真正的狀態目錄）
- README demo 錄影：`./scripts/demo.sh`（`--no-notch` 錄膠囊、`--yes` 跳過確認），用假的專案名稱依序播放各狀態；執行期間會暫停正在跑的正式版（依實際行程路徑，不假設安裝位置），結束後重開同一個。需先 `NotchStatus/build.sh`。
- Hooks 掛在使用者全域設定 `~/.claude/settings.json`——修改時必須**合併**，不可覆蓋既有內容。自動模式的分類器會擋下 Claude 修改此檔，需請使用者自行套用（給他一行 `! ...` 指令）。
- Swift App：`NotchStatus/`（`Package.swift`、`Sources/NotchStatusCore/`、`Sources/NotchStatus/`、`Tests/`、`Vendor/`、`Icon/`、`Info.plist`、`build.sh`、`test.sh`）。
- App 圖示：`NotchStatus/Icon/draw-icon.swift` 用 AppKit 畫 1024 PNG（藍色漸層 + 黑色膠囊 + 藍點），`./Icon/make-icon.sh` 用 `sips` + `iconutil` 轉成 `Icon/AppIcon.icns`（有進版控，`build.sh` 直接複製、`Info.plist` 的 `CFBundleIconFile` 指向它）。改設計後要重跑 `make-icon.sh`，並同步更新 README 用的 `docs/images/icon.png`（`sips -s format png -z 256 256 Icon/AppIcon.icns --out ../docs/images/icon.png`）。
- README：英文版 `README.md`（主要）、繁體中文版 `docs/README.zh-TW.md`，頂端互相連結。功能或安裝步驟改變時兩份要同步更新；README 裡的 hooks 安裝指令是用 `jq` 附加，改 hook 設定時也要一併更新。

## 建置環境

- 只用 Xcode Command Line Tools + Swift Package Manager，**沒有完整 Xcode**。純 SwiftUI 可以編譯，但 **CLT 沒有 SwiftUI 巨集插件**：不能使用 `@Entry`、`#Preview` 等 SwiftUI 巨集。
- DynamicNotchKit 因此 vendor 在 `NotchStatus/Vendor/DynamicNotchKit/`（上游 1.1.0），所有修改標有 `NotchStatus patch`，差異與升級步驟見該目錄的 `VENDOR.md`。不要改回用 URL 依賴。
- 在 `NotchStatus/` 下執行：
  - 建置並打包：`./build.sh`（`swift build -c release` → 組 `NotchStatus.app` → `codesign -s -` ad-hoc 簽章）
  - 安裝（日常使用的版本）：`./build.sh --install` → 已裝在 `/Applications` 就更新那份，否則裝到 `~/Applications`，並啟動（兩處都有時會提醒刪掉 `~/Applications` 那份）。App 只有從 Applications 資料夾執行時才會用 `SMAppService.mainApp` 註冊開機啟動（開發版與測試不會）；關閉請到「系統設定 → 一般 → 登入項目」。
  - 只編譯：`swift build`
  - 測試：`./test.sh`（單一測試：`./test.sh --filter AggregatorTests`）。CLT 內建 Swift Testing，但 `swift test` 找不到它，`test.sh` 會補上 framework 路徑與 rpath；**XCTest 在 CLT 下不可用**，一律用 Swift Testing。
  - 隔離測試 UI：`NOTCH_STATE_DIR=/tmp/notch-test "$PWD/NotchStatus.app/Contents/MacOS/NotchStatus"`，改看別的目錄，不受正在跑的 Claude session 干擾；每次切換形態會 `NSLog` 一行 `NotchStatus: <state> <project> -> <mode>`（啟動時把 stdout/stderr 導到檔案即可讀取）。
  - 模擬沒有瀏海（測膠囊）：再加 `NOTCH_FORCE_NO_NOTCH=1`。沒有瀏海時全部由膠囊顯示、不經過 DynamicNotch，所以在 MacBook 上模擬的結果就等於真實情況。
  - ⚠️ `pkill -x NotchStatus` 會連使用者日常在跑的正式版一起關掉。測試時用**絕對路徑**啟動開發版，再用 `pkill -f "$PWD/NotchStatus.app"` 只關它——用相對路徑 `./NotchStatus.app/...` 啟動的行程比對不到，會殘留在背景。若不小心關了正式版，測完要重新 `open` 它（目前在 `/Applications/NotchStatus.app`；使用者可能自行移動，先確認位置）。
  - 不要用 `sfltool dumpbtm` 檢查登入項目，它會跳出管理員密碼視窗。
- `Info.plist` 設 `LSUIElement = 1`，`main.swift` 也呼叫 `NSApp.setActivationPolicy(.accessory)`，確保不出現在 Dock。App 沒有選單，只能用 `pkill` 結束。
- DynamicNotchKit 的 panel 是半個螢幕大的透明視窗（`.screenSaver` 層級、`canJoinAllSpaces`、`fullScreenAuxiliary`），瀏海形狀畫在裡面；`PillWindow` 同樣是比膠囊大的透明視窗（360×240）。

## 已知陷阱

- 🔴 **所有 hook 腳本結尾必須 `exit 0`**。`Stop` hook 回傳 exit 2 會阻止 Claude 停下、造成無限循環。這行不能刪或「優化」掉。
- 🟡 Hook 在非互動 shell 執行但仍會 source `~/.zshrc`，其中的 `echo` 會污染 stdout。目前腳本只寫檔不靠 stdout，若改成輸出 JSON 會變成 bug。
- 🟡 `Notification` hook 可能比 `Stop` 晚 1–2 秒觸發（issue #23383，使用者回報），不是 bug，不用 debug。若使用者在延遲期間就按了授權，延遲寫入的 `waiting` 可能短暫蓋掉 `PostToolUse` 寫的 `working`，直到下一個工具執行完或 `Stop`。暫不處理。
- 🟡 直接關掉終端機不會觸發 `SessionEnd`。`state.sh` 會往上找名為 `claude` 的祖先行程寫入 `pid`，App 讀檔時刪掉 pid 已結束的狀態檔，並每 10 秒重讀一次（關終端機不會產生檔案事件）。沒有 `pid` 的舊檔案不會被刪。
- 🟡 DynamicNotch 預設顯示在 `NSScreen.screens[0]`（主螢幕）；外接螢幕設為主螢幕時那台沒有瀏海，所以 `NotchController` 會明確指定有瀏海的螢幕。vendor 版已拿掉 DynamicNotchKit 在螢幕變化時自行重建到主螢幕的邏輯，改由 `NotchController` 監聽 `didChangeScreenParametersNotification` 後收起再重新顯示。
- 🟡 DynamicNotchKit 在沒有瀏海的螢幕上是 floating 樣式：**不支援 compact**（會直接隱藏），而且是系統 popover 材質（跟黑色不一致、白字在淺色模式看不清）。所以沒有瀏海時完全不用 DynamicNotch，全部畫在 `PillWindow`；膠囊的 hover 清單也在同一個視窗內完成，避免兩個視窗交接 hover 造成閃爍。
- 🟡 compact 會往右偏（右側專案名比左側色點寬，DynamicNotchKit 位移整條以保持瀏海位置），展開時回到置中，看起來像「往左偏」——這是正常的，使用者已決定不改。用截圖判斷位置時，要以選單列文字為基準，不能用圖片中心（截圖裁切範圍不一定一致）。
- 🟡 expanded 的黑色區塊大小由 DynamicNotchKit 決定（上方預留瀏海高度、下方與左右各 15pt），內容請維持單行、不加 padding，否則會變成大方塊。
- 🟡 App 不應需要 Accessibility 權限；若發現需要，代表做法錯了，停下來問使用者。

## 尚未實機驗證

以下已實作，但使用者還沒回報實測結果：

- 開機自動啟動（「系統設定 → 一般 → 登入項目」是否出現 NotchStatus）
- 插拔外接螢幕後瀏海回到 MacBook
- 全螢幕 App 時仍看得到
- 直接關掉終端機後 10 秒內清掉該 session
- 合上 MacBook、只接外接螢幕時膠囊出現在外接螢幕上
- Claude 問問題（非授權）時是否觸發 `agent_needs_input` → 顯示 waiting

## 參考

- Hooks 官方文件：https://code.claude.com/docs/en/hooks
- DynamicNotchKit 上游：https://github.com/MrKai77/DynamicNotchKit
- 純 CLI 建 SwiftUI app 範例：https://github.com/mabino/HelloSwiftGUI
- 同類專案（MIT，可參考 hook 處理）：https://github.com/m1ckc3s/claude-status-bar
