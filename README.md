# 桌宠 DeskPet — MVP 脚手架

iOS 18.2+ / SwiftUI + WidgetKit / 系统图像生成 / 电子宠物养成

> ✅ **工程已生成完毕**：`DeskPet.xcodeproj` 已可用 `xcodegen generate` 重新生成。
> ✅ **完整构建通过**：`xcodebuild ... BUILD SUCCEEDED`
> 直接用 Xcode 打开 `DeskPet.xcodeproj` 即可开始开发。

## 快速开始

```bash
# 1. 安装 xcodegen（如果没装）
brew install xcodegen

# 2. 生成 / 重新生成 Xcode 工程（修改 project.yml 后执行）
cd /Users/sunlunmao/Desktop/demo/pet
xcodegen generate

# 3. 在 Xcode 里打开
open DeskPet.xcodeproj
```

## 工程结构

```
pet/
├── DeskPet.xcodeproj             # ★ 由 xcodegen 生成的工程文件
├── project.yml                    # ★ xcodegen 配置（修改 target / 依赖 / 设置 后重新生成）
├── DESIGN.md / README.md / SHIPPING.md
│
├── Packages/DeskPetKit/           # 本地 Swift Package（App + Widget + Watch 共享）
│
├── DeskPet/                       # 主 App target
│   ├── Resources/
│   │   ├── Assets.xcassets/       # ★ AppIcon + AccentColor
│   │   ├── Info.plist             # ★ 权限文案 / Live Activity / 后台模式
│   │   └── DeskPet.entitlements   # ★ App Groups / iCloud / HealthKit
│   ├── (Swift 源码)
│
├── DeskPetWidget/                 # Widget Extension target
│   ├── Resources/...
│
├── DeskPetWatch/                  # watchOS App target
│   ├── Resources/...
│
├── Shared/PrivacyInfo.xcprivacy
├── Scripts/                       # TestFlight + AppIcon 渲染
└── Resources/AppIcon/             # SVG 源文件（已生成 PNG）
```

## 工程配置说明

### project.yml（xcodegen 配置）

工程通过 `project.yml` 定义，关键内容：

- **3 个 target**：DeskPet（App）/ DeskPetWidgetExtension（Widget）/ DeskPetWatch（watchOS）
- **1 个 Package**：DeskPetKit（本地 Swift Package，被三个 target 共享）
- **iOS 18.2+** / **watchOS 10.0+**
- **Mac Catalyst** 已启用（同一个 iOS App 编译到 macOS）
- **Swift 5 语言模式**（避免 Swift 6 strict concurrency 误报 ActivityKit API）

修改 `project.yml` 后执行 `xcodegen generate` 即可重新生成 `.xcodeproj`。

### App Group 配置（关键）

工程默认用 `group.com.eavic.test` 作为 App Group。你需要：

1. 在 [Apple Developer Portal](https://developer.apple.com) 创建这个 App Group
2. Xcode → App target → Signing & Capabilities → 确认 App Groups capability 已勾选
3. 把 `DeskPetKit/Sources/DeskPetKit/Storage/SharedStore.swift` 里的 `groupID` 改成你的：

```swift
public static let groupID = "group.com.eavic.test"   // ← 改成你的
```

entitlements 文件已经预置好（`DeskPet/Resources/DeskPet.entitlements`），打开 Xcode 后会自动关联。

### Bundle ID

| Target | Bundle ID |
|---|---|
| App | `com.eavic.test` |
| Widget | `com.eavic.test.widget` |
| Watch | `com.eavic.test.watch` |

如果要用你自己的 Bundle ID，改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER` 然后重新生成。

## 开发流程

```bash
# 改了 project.yml（加 target / 改依赖 / 改设置）后
xcodegen generate

# 改了 DeskPetKit 的代码（不需要重新生成工程）
# 直接在 Xcode 里 Cmd+B 即可

# 改了 App / Widget / Watch 的 Swift 文件
# 不需要重新生成工程，直接 Cmd+B
```

## 已验证

```
✅ xcodebuild -scheme DeskPet build → BUILD SUCCEEDED
✅ swift build (DeskPetKit) → Build complete!
✅ swift test → 11 tests, 0 failures
```

## 注意事项

1. **Apple Watch App 暂未嵌入主 App**
   - 因为 xcodegen 对 "Embed Watch App" 的支持有限
   - 如果要测试 Watch：用 `DeskPetWatch` scheme 单独 build 到手表
   - 完整集成需要在 Xcode UI 里手动添加 "Embed in DeskPet"（General → Targets → 嵌入）

2. **签名 / Provisioning**
   - 命令行 build 时用了 `CODE_SIGNING_ALLOWED=NO`
   - 在 Xcode 里运行真机前，需要：
     - 选择你的 Development Team
     - Bundle ID 改成你的（避免冲突）
     - App Group 在你的 Team 下注册

3. **Image Playground**
   - 真机需要 Apple Intelligence 机型（iPhone 15 Pro+ / iPad Pro M 系列）
   - 模拟器不可用
   - 代码里用 `ImagePlaygroundViewController.isAvailable` 做了兜底

4. **DeskPetKit 用 Swift 5 语言模式**
   - 原因：Swift 6 strict concurrency 会把 ActivityKit 的 `activity.end()` 误报成数据竞争
   - 工程其他 target 用项目级 `SWIFT_STRICT_CONCURRENCY=minimal` 控制

## 目录结构

```
pet/
├── DESIGN.md                      # 完整技术方案（先读这个）
├── README.md                      # 本文件
│
├── Packages/
│   └── DeskPetKit/                # ★ 共享 Swift Package（App + Widget 都依赖）
│       ├── Package.swift
│       └── Sources/DeskPetKit/
│           ├── Models/            # PetState / PetStats / PetMood / PetEvent
│           ├── Storage/           # App Groups 共享存储
│           ├── Rules/             # 事件规则引擎
│           └── Rendering/         # SwiftUI 视图（App & Widget 复用）
│
├── DeskPet/                       # App target 源码
│   ├── DeskPetApp.swift           # @main
│   ├── PetViewModel.swift         # 状态管理
│   ├── EventEngine.swift          # 系统事件监听
│   ├── RootView.swift             # TabView
│   └── Views/
│       ├── HomeView.swift         # 主页（SpriteKit 占位，先 SwiftUI）
│       ├── GenerateAvatarView.swift  # 抠图 + Image Playground
│       ├── GamesView.swift        # 喂食/小游戏入口
│       └── SettingsView.swift
│
└── DeskPetWidget/                 # Widget Extension target 源码
    ├── DeskPetWidgetBundle.swift  # @main
    ├── HomePetWidget.swift        # 桌面 Widget + TimelineProvider
    ├── LockScreenPetWidget.swift  # 锁屏 Widget
    └── PetIntents.swift           # AppIntent（Widget 上点"喂食"）
```

## 导入到 Xcode 的步骤（已被 xcodegen 取代，保留作历史参考）

> ⚠️ 本节内容已经过时，工程现在用 `xcodegen generate` 生成。
> 只需：`brew install xcodegen && cd pet && xcodegen generate && open DeskPet.xcodeproj`

### 1. 创建主工程

1. Xcode → File → New → Project → **App**
2. Product Name: `DeskPet`
3. Interface: **SwiftUI**，Language: **Swift**，Storage: **None**
4. Minimum Deployments: **iOS 18.2**
5. 保存到 `pet/` 下，会生成 `DeskPet.xcodeproj`

### 2. 把现有源码导入主 target

- 在 Xcode 里删掉模板生成的 `ContentView.swift`、`DeskPetApp.swift`
- 用 Finder 把 `pet/DeskPet/` 里的所有 `.swift` 拖进 Xcode 的 `DeskPet` group
- 勾选 **Copy items if needed** + target **DeskPet**

### 3. 添加 Widget Extension target

1. File → New → Target → **Widget Extension**
2. Name: `DeskPetWidget`
3. 勾选 ✅ **Include Live Activity**（以后要用），不勾 Include Configuration App Intent
4. 删掉模板生成的 `DeskPetWidget.swift`，把 `pet/DeskPetWidget/` 里的文件拖进去
- target 选 `DeskPetWidget`

### 4. 添加本地 Swift Package

1. File → Add Packages Dependencies… → **Add Local…**
2. 选 `pet/Packages/DeskPetKit/`
3. Add Package 后，把 `DeskPetKit` 勾给 **两个 target**：`DeskPet` 和 `DeskPetWidget`

### 5. 配置 App Groups（关键！）

1. Apple Developer Portal 创建一个 App Group：`group.com.yourname.deskpet`
2. Xcode → Signing & Capabilities：
   - 给 `DeskPet` 和 `DeskPetWidget` 都加 **App Groups** capability
   - 都勾上 `group.com.yourname.deskpet`
3. 把 `Packages/DeskPetKit/Sources/DeskPetKit/Storage/SharedStore.swift` 里的：
   ```swift
   public static let groupID = "group.com.yourname.deskpet"
   ```
   改成你实际的 group id

### 6. Info.plist 权限文案

`DeskPet` 的 Info.plist 加：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>用于选择宠物照片生成桌面形象</string>
<key>NSCalendarsUsageDescription</key>
<string>用于在会议进行时让宠物保持安静</string>
<key>NSHealthShareUsageDescription</key>
<string>用于根据步数达标给宠物奖励</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于获取当前天气，让宠物随天气变化</string>
<key>NSSupportsLiveActivities</key>
<true/>
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

### 7. 跑起来

1. 选 `DeskPet` scheme 跑真机（Widget 建议真机，模拟器部分能力受限）
2. 长按桌面 → 加 Widget → 找到"桌宠"
3. App 内切到"形象"Tab → 选照片 → 抠图 → 生成

## 当前能跑的功能（M0+M1+M2）

- ✅ 完整数据模型（PetState / 五项数值 / 等级 / 经验）
- ✅ 挂起时间补偿（关闭 App 几小时后再打开，数值会按时间衰减）
- ✅ 桌面 Widget（小/中/大三种尺寸）+ 锁屏 Widget（圆形/矩形）
- ✅ 充电 → mood 变"eating"；低电量 → "tired"；低电量模式 → "sleeping"；戴耳机 → "dancing"
- ✅ App 内喂食、摸摸、洗澡、小游戏入口（数值完整结算）
- ✅ 抠图（Vision 前景实例分割）
- ✅ **SpriteKit 主场景**：宠物会呼吸、眨眼、有物理重力，能拖拽投掷
- ✅ **手势交互**：单击摸头（冒爱心）/ 双击跳跃（冒星星）/ 长按喂食（冒小鱼）/ 拖拽投掷
- ✅ **粒子效果**：摸头爱心 ❤️ / 跳跃星星 ✨ / 喂食小鱼 🐟 / 充电闪电 ⚡ / 戴耳机音符 🎵 / 睡觉 Zzz
- ⚠️ Image Playground 调用：API 在 iOS 18.2 是私有的 `ImagePlaygroundViewController`，
       真机测试时可能需要等苹果公开 Swift 接口，或用 `NSClassFromString` 桥接。
       已在代码中预留 `presentImagePlayground()`，注释里说明了调用方式。

## SpriteKit 场景架构（M2）

```
DeskPet/Scene/
├── PetScene.swift       # SKScene：物理世界 + 地面/墙壁 + 粒子工厂 + 手势路由
├── PetSceneView.swift   # SwiftUI 包装：SpriteView + DragGesture + TapGesture
└── PetNode.swift        # SKNode：宠物角色（形象/眼睛/嘴/呼吸/眨眼/物理体）
```

### 交互手势（在 HomeView 主舞台上）

| 手势 | 效果 | 数值结算 |
|---|---|---|
| **单击宠物** | 摸头反应 + ❤️ 爱心粒子 | happiness +8, energy -2, exp +3 |
| **单击空白** | 朝该方向轻推宠物 | — |
| **双击** | 跳跃（物理冲量）+ ✨ 星星 | — |
| **长按宠物** | 喂食 + 🐟 小鱼粒子 | hunger +30, happiness +3, exp +5, coins -5 |
| **拖拽宠物** | 跟随手指移动，松手按速度投掷 | — |

### 系统事件 → 场景效果

| 事件 | 场景反应 |
|---|---|
| 充电接入 | ⚡ 闪电粒子 + mood 变 eating |
| 戴耳机 | 🎵 音符粒子持续 8 秒 + mood 变 dancing |
| 夜晚/低电量模式 | mood 变 sleeping + 持续冒 💤 Zzz |
| 低电量 | mood 变 tired（半闭眼） |

### 程序化兜底形象

没有生成形象前，`PetNode` 会用 `SKShapeNode` 程序化绘制一只圆滚滚的小生物：
- 圆形身体（颜色随心情变）
- 两只圆眼睛（会随机眨眼，睡觉时闭眼）
- 嘴型随心情变（笑/哭/o/-）
- 呼吸时身体正弦缩放

等用户通过"形象"Tab 生成真实形象后，会自动切换到 `SKSpriteNode` 显示 PNG 帧图。

## 还没做（按 DESIGN.md 路线图）

- [ ] M2 后半：把更多 mood 接上对应的程序化动画（吃东西/洗澡/跳舞的独立动作）
- [x] **M3：接球/洗澡/节拍抚摸三个真正可玩的小游戏**（已完成）
- [x] **M4：日程/步数/勿扰/天气 四类系统事件接入**（已完成）
- [x] **M5：StandBy 横屏 + Live Activity（灵动岛/锁屏实时）**（已完成）
- [x] **M6：性能节流、日志、性格化对话、隐私清单、审核准备**（已完成）
- [x] **M7：TestFlight 脚本、App Icon、200+ 对话、iCloud 同步**（已完成）
- [x] **M8：多宠物、统计图表、Onboarding、Apple Watch 配套**（已完成）
- [x] **M9：签到/成就、商店、宠物进化、macOS Catalyst**（已完成）

## M9 养成深度 + macOS（已完成）

### M9.1 签到 + 成就

**架构**：
```
DeskPetKit/Models/
├── CheckIn.swift                  # 签到数据模型 + 规则（7 天循环，第 7 天大奖）
├── Achievement.swift              # 15 个内置成就 + 检测器
└── ProgressionManager.swift       # 统一进度管理（签到/成就/商店）

DeskPet/Progression/
├── CheckInView.swift              # 月历 + 连续天数 + 签到按钮
└── AchievementsView.swift         # 已解锁/未解锁两区 + 进度条
```

**签到规则**：连续 7 天循环，第 7 天大奖（+100💰 +50EXP）
**成就系统**：15 个成就（喂食/游戏/洗澡/摸头/等级/签到/步数/宠物数）

### M9.2 商店

**架构**：
```
DeskPetKit/Models/ShopItem.swift   # 12 个内置商品（食物/装扮/背景/增益）
DeskPet/Progression/ShopView.swift # 分类筛选 + 购买 UI
```

**商品分类**：
- 🍗 食物（4 种）：一次性加饱腹/心情
- 🎀 装扮（5 种）：蝴蝶结/皇冠/派对帽/耳机/墨镜（部分需等级）
- 🌱 背景（3 种）：草地/太空/海滩（部分需等级）
- ⚡️ 增益（2 种）：能量饮料/药水

### M9.3 宠物进化

**架构**：
```
DeskPetKit/Models/PetForm.swift         # 4 阶形态：幼年/成长/成年/终极
DeskPet/Progression/EvolutionView.swift # 进化路线 + 历史
DeskPet/Scene/PetNode.swift             # 形态影响颜色/尺寸/光晕
```

**4 阶进化**：

| 形态 | 等级 | 体型 | 颜色 | 特效 |
|---|---|---|---|---|
| 🥚 幼年 | Lv.1-4 | 0.75x | 米白 | — |
| 🐤 成长 | Lv.5-9 | 0.9x | 浅金 | — |
| 🐱 成年 | Lv.10-19 | 1.0x | 橙色 | 长出装饰 |
| ✨ 终极 | Lv.20+ | 1.1x | 金色 | 光晕脉动 |

升级到下一形态时自动触发进化动画（放大-缩小特效）+ 记录进化历史。

### M9.4 macOS（Mac Catalyst + MenuBar）

**架构**：
```
DeskPet/Platform/
├── Platform.swift             # 平台判断工具
├── MacAppDelegate.swift       # Catalyst 的 NSApplicationDelegate
├── MenuBarPetView.swift       # Catalyst 的 MenuBar 状态栏
└── MacAdaptations.swift       # SwiftUI 适配工具
```

**两种运行模式**：

1. **Mac Catalyst**（"在 Mac 上跑这个 iOS App"）
   - 同一份 iOS 代码用 Catalyst 编译到 macOS
   - 顶部状态栏放宠物图标，右键弹快捷菜单（摸摸头/喂食/睡觉/退出）
   - 自定义菜单栏快捷键：⌘P 摸头 / ⌘F 喂食 / ⌘S 睡觉

2. **macOS 原生 MenuBarExtra**（如果用 SwiftUI App lifecycle 编译为 macOS）
   - 顶部菜单栏点击宠物图标 → 弹下拉菜单
   - 显示宠物名/等级/心情/金币 + 3 个操作按钮

**Catalyst 配置**：
1. Xcode → App target → General → Deployment → 勾选 **Mac Catalyst**
2. 选 "Mac (Catalyst)" 设备 → Build & Run
3. 不需要额外 entitlement；App Groups 自动跨平台共享数据

### M9 集成入口

新加的 Tab："**养成**"（取代原 Settings 的位置）
```
养成 Tab →
├── 每日签到（月历 + 连续天数 + 签到按钮）
├── 成就（15 个成就，已解锁/未解锁分区）
├── 商店（4 类商品分类）
└── 进化（4 阶形态路线 + 进化历史）
```

### 构建 + 测试验证

```
swift build  →  Build complete! ✓
swift test   →  11 tests, 0 failures ✓
```

## M8 高级功能（已完成）

### M8.1 多宠物支持

**架构**：
```
DeskPetKit/Models/PetManager.swift         # 多宠物管理（最多 5 只）
DeskPetKit/Storage/PetStorage.swift         # 多宠物持久化 + 老数据迁移
DeskPet/Views/PetSwitcherView.swift         # 切换/添加/删除 UI
```

**用法**：
- 顶部右上角"卡片堆叠"图标 → 打开 `PetSwitcherView`
- 切换当前宠物 → Widget 和 Watch 自动跟随
- 长按列表项删除（至少保留 1 只）
- 添加新宠物时可选 4 种性格（活泼/高冷/黏人/憨厚）

**自动迁移**：M7 单宠物用户升级到 M8 后，旧数据自动迁移成多宠物数组。

### M8.2 统计图表（Swift Charts）

**架构**：
```
DeskPetKit/Models/PetEventLogEntry.swift     # 事件日志条目
DeskPetKit/Storage/EventLogStore.swift        # 日志持久化（最多 1000 条，90 天）
DeskPetKit/Models/StatsAggregator.swift       # 聚合计算
DeskPet/Views/StatsView.swift                 # 图表 UI
```

**显示内容**：
- 顶部 4 张卡片：总互动 / 喂食 / 游戏 / 升级
- 柱状图：过去 30 天每日互动次数
- 饼图：互动类型分布（喂食/游戏/洗澡/摸头/...）
- 连续打卡：🔥 当前 + 最长连续天数

**事件采集**：用户互动 + 关键系统事件（充电/步数达标/升级）都自动入日志。

### M8.3 Onboarding 引导

**架构**：
```
DeskPet/Onboarding/OnboardingView.swift      # 4 页引导
DeskPet/RootView.swift                       # 首次启动路由
```

**4 页内容**：
1. 欢迎页（ pawprint 动画）
2. 互动玩法（摸头/喂食/洗澡）
3. 系统事件（充电/夜间/步数/耳机）
4. 生成形象（Image Playground 引导）

完成标记存 `@AppStorage("hasFinishedOnboarding")`，下次启动直接进主页。

### M8.4 Apple Watch 配套 App

**架构**：
```
DeskPetWatch/                            # 新增 watchOS target
├── DeskPetWatchApp.swift                # @main
├── WatchStore.swift                     # WCSession 接收 iOS 推送
└── WatchContentView.swift               # 3 页：形象 / 数值 / 心情

DeskPetKit/Sync/WatchSync.swift          # iOS → Watch 推送
```

**3 个页面**（左右滑动切换）：
1. **主界面**：宠物形象 + 心情对话 + 等级
2. **数值环**：5 项数值进度条
3. **同步状态**：心情图标 + 最近同步时间

**数据流**：iOS 端每次状态变化 → `WatchSync.shared.push()` → Watch 接收并刷新。Watch 不在线时缓存为 applicationContext，下次激活自动同步。

### M8 配置补充

| 资源 | 配置 |
|---|---|
| Apple Watch | Xcode → Add Target → watchOS App → SwiftUI |
| WatchConnectivity | 不需要 entitlement，iOS 和 Watch 都开 WatchConnectivity capability |
| Watch 与主 App 共享数据 | 通过 WatchSync 推送，**不通过 App Groups**（Watch 没法访问 App Groups） |

## M7 工具链与扩展（已完成）

### 1. TestFlight 发布脚本

`Scripts/upload_testflight.sh` —— 一条命令完成 archive + upload：

```bash
./scripts/upload_testflight.sh                    # 默认：递增 build、archive、上传
./scripts/upload_testflight.sh --notes "修复..."   # 附带测试说明
./scripts/upload_testflight.sh --skip-bump        # 不递增 build 号
./scripts/upload_testflight.sh --watch            # 上传后轮询处理状态
```

**凭据配置（三选一）**：

```bash
# 推荐：App Store Connect API Key
export API_KEY_ID="ABC1234567"
export API_ISSUER_ID="12345678-1234-1234-1234-123456789012"
export API_KEY_PATH="/Users/you/AuthKey_ABC1234567.p8"

# 或：App Store Connect 账号 + App-Specific Password
export APP_STORE_USER="you@email.com"
export APP_STORE_PASS="xxxx-xxxx-xxxx-xxxx"

# 或：什么都不设 → 脚本会打开 Xcode Organizer 让你手动上传
```

### 2. App Icon 资源

`Resources/AppIcon/` 下两个 SVG 占位：

- **AppIcon.svg** —— 主图标（暖橙渐变 + 圆滚滚宠物 + 爪印 + 闪光）
- **AppIcon-Tinted.svg** —— iOS 18 单色 Tinted 版本（系统自动着色）

**生成全尺寸 PNG**（推荐用 Pillow 版本，无需额外安装）：

```bash
# 推荐：用 Pillow 直接生成（Python3 + Pillow，无需 SVG 解析器）
python3 scripts/render_app_icon_pillow.py
# 输出到 Resources/AppIcon/AppIcon.appiconset/

# 备选：基于 SVG 生成（需要 brew install librsvg）
./scripts/render_app_icon.sh

# 然后把 AppIcon.appiconset 拖到 Xcode 的 Asset Catalog
```

**已生成的图标效果**（1024x1024 主图）：

- 背景：暖橙渐变（#FFB347 → #FF8C42，iOS squircle 圆角）
- 主体：圆滚滚米白色小宠物（#FFE4C4），居中略偏下
- 耳朵：左右两只三角耳，内耳粉色（#FFB6B6）
- 脸部：黑色眼睛 + 高光 / 黑色小鼻子 / 笑嘴 / 腮红
- 装饰：右下角白色爪印 / 左上角闪光
- 顶部：柔和暖白高光

涵盖 15 个尺寸（20/29/40/60/76/83.5/1024 + @1x/@2x/@3x），
`Contents.json` 已自动生成，可直接拖入 Xcode Asset Catalog 使用。

像素验证（采样 1024 主图）：

| 位置 | 实测 RGBA | 应为 |
|---|---|---|
| 背景顶部 (512, 50) | (255, 177, 70) | ✅ #FFB347 |
| 背景底部 (512, 980) | (255, 141, 66) | ✅ #FF8C42 |
| 身体中心 (512, 720) | (255, 228, 196) | ✅ #FFE4C4 |
| 左眼 (425, 540) | (61, 40, 23) | ✅ #3D2817 |
| 鼻尖 (512, 588) | (61, 40, 23) | ✅ #3D2817 |
| 闪光 (225, 240) | (255, 255, 255, 200) | ✅ 半透明白色 |

### 3. 200+ 性格化对话文案

`PetDialogue.swift` 现在有 **240 条** 对话：15 种 mood × 4 种性格 × 4 条。

调用方式不变：`PetMood.happy.line(personality: .clingy)` 会按性格返回不同语气。

### 4. iCloud 同步

`DeskPetKit/Sync/CloudSync.swift` —— 多设备共享同一只宠物：

```swift
// App 启动时合并远端
state = CloudSync.shared.mergeWithLocal(state)

// 本地变更后自动上传
CloudSync.shared.upload(state)

// 监听远端变化
CloudSync.shared.onSyncComplete = { remoteState in ... }
```

**配置**：
1. Xcode → Signing & Capabilities → 加 **iCloud** capability
2. 勾选 **Key-Value Storage**（免费、足够存 PetState）
3. 大文件（形象帧图）同步留作 V2，目前每台设备独立

**已自动接入**：`PetViewModel.bootstrap()` 启动时合并，`persist()` 每次写盘时上传。

## M6 打磨与提审（已完成）

### 性能优化

**Widget reload 节流器**（`WidgetReloadThrottle`）

系统给每个 Widget 每天 ~40 次 reload 预算。我们做了分层节流：

| 事件类型 | 是否节流 | 上限 |
|---|---|---|
| **重要事件**（充电/低电量/步数达标） | ❌ 不节流，立即 reload | — |
| **普通事件**（用户互动、时间校准） | ✅ 节流 | 4 次/小时，25 次/天（留 15 次给系统） |
| **时间相关状态**（昼夜、能量衰减） | 用 Timeline 预制 entries，**完全不消耗预算** | — |

可在 `WidgetReloadThrottle.shared.remainingBudget()` 查询剩余预算（Debug 覆盖层会显示）。

### 日志系统（`Logger`）

按子系统分类的 OSLog 封装，方便在 Console.app 过滤：

```swift
Logger.app.info("PetVM bootstrap")      // subsystem: app
Logger.widget.warn("budget exhausted")   // subsystem: widget
Logger.event.info("handle event: ...")   // subsystem: event
Logger.game.info("play score=80")        // subsystem: game
Logger.activity.info("start charging")   // subsystem: activity
Logger.perf.warn("frame dropped")        // subsystem: perf
```

在 Console.app 用 `subsystem:com.yourname.deskpet` 过滤即可。

### 性格化对话（`PetDialogue`）

15 种 mood × 4 种性格（lively/calm/clingy/goofy）= 60+ 条对话文案：

| 性格 | 示例（happy） |
|---|---|
| 🌟 活泼 lively | "好开心！" / "最喜欢你了！" |
| 🐱 高冷 calm | "还不错" / "还可以吧" |
| 🐶 黔人 clingy | "你真好～" / "再陪我一会儿嘛" |
| 🐻 憨厚 goofy | "嘿嘿嘿嘿～" / "肚皮给你摸" |

用户在设置页选性格后，对话语气立即变化。

### 隐私清单（`Shared/PrivacyInfo.xcprivacy`）

符合 Apple Required Reason API 要求：

- ✅ 不追踪用户（`NSPrivacyTracking = false`）
- ✅ 所有数据仅本地存储（不上传服务器）
- ✅ 声明了 4 类采集数据（照片/健康/位置/其他用户内容），全部仅用于 App 功能
- ✅ 声明了 3 类 Required Reason API（UserDefaults / FileTimestamp / SystemBootTime）

### Debug 性能覆盖层（`DebugOverlay`）

仅在 DEBUG 构建显示，左上角实时显示：
- 当前 FPS（绿/橙/红 三色）
- Widget reload 剩余预算（4/4 25/25）

### App Store 审核准备

详见 [`SHIPPING.md`](./SHIPPING.md)，包含：
- App 元数据（中英文标题/描述/关键词）
- 隐私问卷填写指南
- **Live Activity 审核说明模板**（4 种活动分别对应真实事件，避免被拒）
- Family Controls entitlement 说明
- 截图与 App Preview 剧本
- 上线前 Checklist（代码/资源/合规/提审）

## 上线 Checklist 速览

### 代码
- [ ] `SharedStore.groupID` → 你的实际 App Group
- [ ] `Logger.subsystem` → 你的实际 bundle id
- [ ] 移除所有 `print()` 调试语句
- [ ] `swift test` 全绿
- [ ] 真机 24 小时稳定性测试

### 资源
- [ ] AppIcon 全尺寸
- [ ] 6 张截图（含 SpriteKit 主场景 + 灵动岛 + StandBy）
- [ ] 中英文描述

### 合规
- [ ] `PrivacyInfo.xcprivacy` 加到 App + Widget target
- [ ] Info.plist 权限文案（相册/日历/健康/位置）
- [ ] App Privacy 问卷
- [ ] Review Notes 写 Live Activity / Family Controls 说明

## M5 多表面 + Live Activity（已完成）

### 架构

```
DeskPetWidget/
├── DeskPetWidgetBundle.swift     # 入口：注册 4 个 Widget
├── HomePetWidget.swift           # 桌面（小/中/大）
├── LockScreenPetWidget.swift     # 锁屏（圆形/矩形/Inline）
├── StandByPetWidget.swift        # ★ StandBy 横屏大图（床头柜模式）
└── LiveActivity/
    └── PetLiveActivity.swift     # ★ 锁屏卡片 + 灵动岛 3 态

DeskPetKit/Sources/DeskPetKit/
├── Models/PetActivityAttributes.swift   # ★ Live Activity 数据模型
└── ActivityController.swift             # ★ 启动/更新/结束 统一管理
```

### 4 个 Widget 表面

| Widget | 用途 |
|---|---|
| **HomePetWidget** | 桌面主舞台（小/中/大），显示数值条与对话 |
| **LockScreenPetWidget** | 锁屏圆形/矩形/Inline |
| **StandByPetWidget** | iPhone 横屏充电时的床头柜大图，显示睡觉动画 + 时间 |
| **PetLiveActivity** | Live Activity（锁屏卡片 + 灵动岛） |

### 4 种 Live Activity 活动

| 活动 | 触发 | 灵动岛/锁屏显示 |
|---|---|---|
| **充电进食** 🔋 | 插入充电器 | 进度条 = 电量百分比，"⚡️ 87%" |
| **洗澡** 🚿 | 进入洗澡小游戏 | 30 秒进度条，"快好了，香喷喷～" |
| **睡觉** 💤 | 低电量模式开启 | "Zzz… 休息中"，StandBy 自动显示 |
| **步数达标** 🎉 | 当日步数 ≥ 5000 | "今日走了 5000 步！"，5 秒后自动结束 |

### Live Activity 灵动岛布局

- **紧凑态**：左侧 🍃 图标 + 右侧百分比
- **最小态**：仅图标
- **扩展态**（长按）：图标 + 大百分比 + 进度条 + 副标题

### 配置

`DeskPet` 的 Info.plist 必须包含：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

Live Activity 默认在锁屏可见；灵动岛仅 iPhone 14 Pro 及以上机型显示。
StandBy 需要 iPhone 8 Plus 及以上机型，且横屏充电时自动激活。

## M4 系统事件（已完成）

### 架构

```
DeskPet/Events/
├── SystemEventProvider.swift       # 协议 + 统一信号 SystemSignal
├── SystemEventOrchestrator.swift   # 统一编排：请求权限 → 启动 → 路由信号
├── CalendarProvider.swift          # EventKit
├── HealthProvider.swift            # HealthKit（步数）
├── FocusModeProvider.swift         # FamilyControls（勿扰，需 entitlement）
└── WeatherProvider.swift           # WeatherKit + CoreLocation
```

每个 Provider 实现 `SystemEventProvider` 协议，由 `SystemEventOrchestrator` 在 App 启动时按需请求权限、启动监听，并把信号转成 PetEvent 喂给 PetViewModel。

### 接入的事件

| Provider | 触发条件 | 宠物反应 |
|---|---|---|
| **CalendarProvider** | 日历里有"正在进行的会议"（带 ±5min 缓冲，不算全天事件） | mood → `.quiet`（嘘，安静陪伴） |
| **HealthProvider** | 当日步数 ≥ 5000（每天封顶 1 次） | `.stepGoalReached`：happiness +10, coins +15, exp +30 |
| **FocusModeProvider** | 低电量模式开关（开发期近似，正式版用 FamilyActivities 检测专注模式） | 开启 → `.quiet`；关闭 → 重算 mood |
| **WeatherProvider** | 天气变化（30 分钟拉一次） | 雨 ☔️ / 雪 ❄️ / 热 → `.tired` / 冷 → `.sleeping` |

### 需要配置的权限与 entitlement

| 资源 | 配置 |
|---|---|
| 日程 | Info.plist: `NSCalendarsUsageDescription` |
| 健康 | Info.plist: `NSHealthShareUsageDescription` |
| 勿扰 | Apple Developer 后台申请 **Family Controls** entitlement |
| 天气 | Apple Developer 后台启用 **WeatherKit** 服务 + Info.plist `NSLocationWhenInUseUsageDescription` |

### 设计要点

- **统一协议**：所有 provider 实现 `SystemEventProvider`，新增事件源只需加一个文件 + 在 Orchestrator 里注册
- **权限降级**：每个 provider 单独请求，用户拒绝只影响对应功能，不会阻塞其他
- **省电策略**：日程/天气/勿扰用 30-60s 轮询，健康用 `HKObserverQuery` 由系统唤起，不会空转
- **防抖**：步数奖励用 `stepRewardedToday` 标记，防止一天反复触发；日程/勿扰用 `wasBusy/wasActive` 状态对比，只在状态翻转时上抛

## M3 小游戏（已完成）

### 架构

```
DeskPet/Games/
├── MinigameScene.swift        # 基类：30s 倒计时 + 计分 + 状态机骨架
├── MinigameContainer.swift    # SwiftUI 包装：SpriteView + 顶部 HUD + 触摸路由
├── CatchBallScene.swift       # 接球
├── BathScene.swift            # 洗澡
└── RhythmScene.swift          # 节拍抚摸
```

### 三个游戏玩法

**🎮 接球 CatchBall**
- 拖动屏幕底部的宠物左右移动
- 接住 🎾 网球 +10 分 / ⭐️ 金球 +30 分 / 💣 炸弹 -20 分
- 球下落速度随时间加快，难度递增

**💧 洗澡 Bath**
- 在宠物身上画圈擦泡泡
- 每转 1 整圈擦掉 1 个 🫧 泡泡 +10 分
- 全部擦完会再生成 10 个，期间留水珠 💧 拖尾

**🎵 节拍抚摸 Rhythm**
- 4 条彩色轨道，节拍圆环从顶部下落
- 圆环到达判定线时点对应轨道 → Perfect(+30) / Great(+20) / Good(+10)
- 连击有加成（分数 = 基础分 + 当前 combo）

### 数值结算

游戏结束后调 `vm.play(game:score:)`，由 `PetState.apply(.userPlayed)` 统一结算：
- 基础经验（接球 20 / 洗澡 10 / 节拍 8）+ score / 5
- happiness +15
- energy -15
- coins += score / 3（封顶 30）

每局游戏 30 秒，结束自动结算并返回游戏列表。

## 运行测试（验证养成数值逻辑）

DeskPetKit 自带单元测试，可以在 Xcode 里 `Cmd+U` 跑 `DeskPetKitTests`，
覆盖：衰减、睡觉恢复、健康联动、等级、喂食扣金币、规则引擎。

## 常见问题

**Q: Widget 显示"pawprint"占位图，没出现我生成的宠物？**
A: 因为还没有形象帧图。需要先在 App 里完成"生成形象"流程；
   或临时把 `PetAvatarView` 里的兜底分支换成你想要的默认形象。

**Q: 真机报错 "Cannot find type 'ImagePlaygroundViewController'"？**
A: 这是已知问题——iOS 18.2 的 Swift 接口尚未完全公开。两种解法：
   1. 等 iOS 18.3+ 公开接口（最稳）
   2. 用 `NSClassFromString("ImagePlayground.ImagePlaygroundViewController")` 桥接 Objective-C 私有类，
      通过 KVC 设置 sourceImage / concepts（仅供本机调试，**不能上架**）

**Q: Widget 刷新太频繁被系统限流？**
A: 我们已经用"预制 Timeline + 事件 reload"策略避开预算（40 次/天）。
   如果还触发限流，检查是不是在 `PetViewModel.persist()` 里频繁调用了 `reloadAllTimelines()`。

## 下一步建议

1. 按上面"导入步骤"在 Xcode 里把工程建起来，确认 Widget 能在桌面显示占位宠物
2. 把 `SharedStore.groupID` 改成你的实际 group id
3. 真机测试抠图流程（这部分现在就能用）
4. 然后我们继续做 M2：把 HomeView 换成 SpriteKit Scene，宠物真的"动起来"
```
