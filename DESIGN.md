# 桌宠 (DeskPet) — 详细技术设计

> 一只住在你 iPhone 桌面/锁屏/灵动岛上的电子宠物，可用自家宠物照片生成形象，
> 并随充电、电量、夜间、日程等系统事件改变状态；偏养成玩法（能量/饥饿/心情/小游戏）。

---

## 0. 关键决策（已锁定）

| 项 | 决定 | 影响 |
|---|---|---|
| 最低系统 | **iOS 18.2+** | 可用 Image Playground、最新 Vision API、`@Entry` Widget 等 |
| 形象生成 | **系统 Image Playground API** | 零自研模型、App Store 风险低、风格固定（动画/插画/粘土） |
| 体验侧重 | **电子宠物养成** | 需要数值系统、喂食/互动小游戏、等级与成长 |

---

## 1. 工程结构

单 Xcode 工程包含 **3 个 target**，共享代码通过 **本地 Swift Package（`DeskPetKit`）** 引入，避免 target 循环依赖。

```
DeskPet.xcodeproj
├── DeskPet/                          # App target（主程序）
│   ├── App/
│   │   ├── DeskPetApp.swift
│   │   └── RootView.swift            # TabView: 家 / 相册 / 设置 / 小游戏
│   ├── Features/
│   │   ├── Onboarding/               # 首次启动：拍照生成形象
│   │   ├── Home/                     # 主页 SpriteKit Scene，互动入口
│   │   ├── Generate/                 # 抠图 + Image Playground 生成形象
│   │   ├── Games/                    # 喂食 / 接球 / 抚摸 等小游戏
│   │   └── Settings/                 # 装扮、性格、对话文案自定义
│   ├── Engine/
│   │   ├── EventEngine.swift         # 系统事件监听 + 规则匹配
│   │   └── PetClock.swift            # 养成数值衰减调度（后台 token + 挂起补偿）
│   ├── Resources/
│   └── Info.plist                    # 权限文案：相册/通知/健康…
│
├── DeskPetWidget/                    # Widget Extension target
│   ├── DeskPetWidget.swift           # WidgetBundle 入口
│   ├── HomeWidget/                   # 桌面中等/大尺寸
│   ├── LockScreenWidget/             # 锁屏圆形/矩形
│   ├── StandByWidget/                # StandBy 横屏大图（systemSmall/medium）
│   ├── Timeline/
│   │   └── PetTimelineProvider.swift # 统一 Provider，按 family 渲染
│   ├── Assets.xcassets               # 形象帧图（从 App Groups 同步）
│   └── Info.plist
│
├── DeskPetWidgetConfig/              # (可选) Configurable Widget 的 Intent
│
├── Packages/
│   └── DeskPetKit/                   # 本地 Swift Package（共享）
│       └── Sources/DeskPetKit/
│           ├── Models/
│           │   ├── PetState.swift        # 唯一数据源
│           │   ├── PetStats.swift        # 能量/饥饿/心情/清洁/经验
│           │   ├── PetAppearance.swift   # 形象帧、装扮、性格
│           │   └── PetEvent.swift        # 事件类型与规则
│           ├── Storage/
│           │   ├── SharedStore.swift     # App Groups 容器封装
│           │   └── AssetStore.swift      # 形象帧图读写
│           ├── Rendering/
│           │   ├── MoodFrames.swift      # mood → 帧图选择
│           │   └── AvatarView.swift      # SwiftUI 视图（App 与 Widget 复用）
│           └── Rules/
│               └── EventRuleEngine.swift # 事件 → 状态映射规则
│
└── Shared/
    ├── AppGroup.xcconfig             # DEVELOPMENT_TEAM / PRODUCT_BUNDLE_IDENTIFIER
    └── Entitlements/
        ├── DeskPet.entitlements
        └── DeskPetWidget.entitlements
```

### 1.1 App Groups 配置

两个 target 都要开启：

```xml
<!-- DeskPet.entitlements / DeskPetWidget.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourname.deskpet</string>
</array>
```

`SharedStore` 在 `DeskPetKit` 里统一访问：

```swift
public enum SharedStore {
    public static let groupID = "group.com.yourname.deskpet"

    public static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)!
    }

    /// UserDefaults 共享实例
    public static var defaults: UserDefaults {
        .init(suiteName: groupID)!
    }

    /// 形象帧图目录
    public static var avatarsDir: URL {
        let url = containerURL.appendingPathComponent("Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

### 1.2 必需的 Entitlements / Info.plist 权限

| 用途 | 配置 |
|---|---|
| App Groups | `com.apple.security.application-groups` |
| 形象生成 | Info.plist 不需要权限；调起 Image Playground 系统弹窗 |
| 抠图（选图） | `NSPhotoLibraryUsageDescription`（Image Playground 内部自取，但自家抠图路径需要） |
| 充电/电量 | `UIBackgroundModes = ["processing"]`（后台处理 token） |
| 日程 | `NSCalendarsUsageDescription` + EventKit |
| 健康/运动 | `NSHealthShareUsageDescription` + HealthKit |
| 通知 | `UNUserNotificationCenter`（喂食提醒、低能量提醒） |
| Live Activities | Info.plist: `NSSupportsLiveActivities = YES` |

---

## 2. 数据模型与养成数值系统（核心）

### 2.1 PetState — 全 App + Widget 唯一数据源

所有显示层都从这里渲染；事件引擎和小游戏都更新它。

```swift
public struct PetState: Codable, Equatable {
    public var petID: UUID
    public var name: String
    public var appearance: PetAppearance

    // —— 养成数值 ——
    public var stats: PetStats
    public var level: Int                  // 等级
    public var exp: Int                    // 经验
    public var coins: Int                  // 互动奖励，可换装扮

    // —— 状态机 ——
    public var mood: PetMood               // 当前情绪（决定动画与对话）
    public var lastUpdate: Date            // 用于"挂起时间"衰减补偿

    // —— 长期记忆 ——
    public var createdAt: Date
    public var totalInteractions: Int
    public var streakDays: Int             // 连续打开天数（养成粘性）

    public init(petID: UUID = UUID(),
                name: String = "小毛",
                appearance: PetAppearance = .default,
                stats: PetStats = .initial,
                level: Int = 1, exp: Int = 0, coins: Int = 100,
                mood: PetMood = .idle,
                lastUpdate: Date = .now,
                createdAt: Date = .now,
                totalInteractions: Int = 0, streakDays: Int = 0) {
        self.petID = petID; self.name = name; self.appearance = appearance
        self.stats = stats; self.level = level; self.exp = exp; self.coins = coins
        self.mood = mood; self.lastUpdate = lastUpdate
        self.createdAt = createdAt; self.totalInteractions = totalInteractions
        self.streakDays = streakDays
    }
}

public enum PetMood: String, Codable, CaseIterable {
    case idle, happy, excited, curious
    case hungry, sleepy, tired, sick
    case eating, playing, sleeping, dirty
}
```

### 2.2 PetStats — 五项基础数值

```swift
public struct PetStats: Codable, Equatable {
    public var energy: Int      // 体力 0-100   玩游戏/走动消耗
    public var hunger: Int      // 饱腹 0-100   时间衰减，喂食上升（"100 = 很饱"）
    public var happiness: Int   // 心情 0-100   互动上升，忽略下降
    public var cleanliness: Int // 清洁 0-100   时间衰减
    public var health: Int      // 健康 0-100   其他项过低会扣健康

    public static let initial = PetStats(energy: 80, hunger: 70,
                                         happiness: 80, cleanliness: 80, health: 100)
}
```

### 2.3 衰减与恢复（数值平衡表）

> 设计原则：**1 小时小幅度衰减，1 天不打开会"饿晕"但不会"死亡"**；养成不焦虑、不挫败。

**每 1 小时被动衰减（在 PetClock.tick(now:) 里执行）：**

| 数值 | 每小时变化 | 备注 |
|---|---|---|
| `energy` | -2 | 睡觉中改为 +8 |
| `hunger` | -3 | 进食中 +6（充电视为"充电进食"） |
| `happiness` | -2 | 互动时 +5~+15 |
| `cleanliness` | -1 | 洗澡小游戏 +40 |
| `health` | 看其他项 | 任一项 ≤ 10 时 -3/h；全 ≥ 60 时 +1/h（自愈） |

**关键动作效果：**

| 动作 | 触发点 | 效果 | 冷却 |
|---|---|---|---|
| 喂食（选食物） | App 内按钮 / Widget 点击 → App | hunger +25, coins -5 | 5 min |
| 抚摸 | App 内拖动 | happiness +8, energy -2 | 无 |
| 小游戏：接球 | App 内 SpriteKit | exp +20, happiness +15, energy -15, coins +10 | 无 |
| 洗澡小游戏 | App 内 | cleanliness +40, happiness +5 | 30 min |
| 睡觉 | 手动或夜间自动 | energy 每分钟 +2，期间不可互动 | 唤醒 |
| 充电"进食" | 系统事件 | hunger +6/min（边充电边吃） | 自动 |

**等级公式：**

```swift
/// 升级所需经验：第 n 级需要 n*100 经验
public func expToNext(level: Int) -> Int { level * 100 }

public mutating func addExp(_ amount: Int) {
    exp += amount
    while exp >= expToNext(level: level) {
        exp -= expToNext(level: level)
        level += 1
        // 升级奖励：解锁装扮、提高各项上限
    }
}
```

### 2.4 挂起时间补偿（解决"后台不能常驻"）

iOS 不会让 App 持续跑，所以宠物状态用**懒计算**：每次 App 冷启动 / Widget 刷新时，根据 `lastUpdate` 与 `now` 的差值，一次性把衰减结算掉。

```swift
public extension PetState {
    /// 把"从上次更新到现在"的被动变化一次性结算
    public mutating func reconcile(now: Date = .now) {
        let hours = max(0, now.timeIntervalSince(lastUpdate) / 3600)
        guard hours > 0 else { return }

        let sleeping = isNight(now) || mood == .sleeping
        stats.energy  = clamp(stats.energy  + Int(hours * (sleeping ? 8  : -2)), 0, 100)
        stats.hunger  = clamp(stats.hunger  - Int(hours * 3),  0, 100)
        stats.happiness   = clamp(stats.happiness   - Int(hours * 2),  0, 100)
        stats.cleanliness = clamp(stats.cleanliness - Int(hours * 1),  0, 100)
        // 健康联动
        let lows = [stats.energy, stats.hunger, stats.happiness, stats.cleanliness]
                    .filter { $0 <= 10 }.count
        stats.health = clamp(stats.health + (lows > 0 ? -3*Int(hours) : Int(hours)), 0, 100)

        mood = computeMood()         // 根据数值重新决策情绪
        lastUpdate = now
    }
}
```

`computeMood()` 决策表：

| 优先级 | 条件 | mood |
|---|---|---|
| 1 | health ≤ 20 | `.sick` |
| 2 | hunger ≤ 20 | `.hungry` |
| 3 | cleanliness ≤ 20 | `.dirty` |
| 4 | energy ≤ 20 | `.tired` |
| 5 | 夜间 22:00–7:00 且 energy < 80 | `.sleeping` |
| 6 | happiness ≤ 30 | `.sad`（建议加进 enum） |
| 7 | 充电中 | `.eating` |
| 8 | 默认 | `.idle`（happiness ≥ 70 时 50% 概率 `.happy`） |

---

## 3. 形象生成管线

### 3.1 总流程

```
PhotosPicker ──▶ [① 抠图] ──▶ [② Image Playground 风格化] ──▶ [③ 切帧/导出] ──▶ [④ 入库]
```

### 3.2 ① 主体抠图（Vision，去背景）

```swift
import Vision
import CoreImage

/// 用"长按抬出主体"同款 API 抠出透明背景图
func removeBackground(from input: UIImage) async throws -> UIImage {
    guard let cgImage = input.cgImage else { throw NSError(domain: "img", code: 0) }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])

    guard let result = request.results?.first else { throw NSError(domain: "mask", code: 0) }
    let maskedPixelbuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances,
                                                                  from: handler)
    // 用 mask 合成透明 PNG
    let ciInput = CIImage(cgImage: cgImage)
    let mask = CIImage(cvPixelBuffer: maskedPixelbuffer)
    let blended = ciInput.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputMaskImageKey: mask,
        "inputBackgroundImage": CIImage.empty()
    ])
    let context = CIContext()
    let cgOut = context.createCGImage(blended, from: ciInput.extent)!
    return UIImage(cgImage: cgOut, scale: input.scale, orientation: input.imageOrientation)
}
```

### 3.3 ② Image Playground 风格化（iOS 18.2+）

`ImagePlaygroundViewController` 是系统 UI，用户可以在里面写关键词、选风格（动画/插画/粘土）。

```swift
import AppIntents
import ImagePlayground

final class AvatarGeneratorVC: UIViewController, ImagePlaygroundViewControllerDelegate {
    private let originalImage: UIImage

    init(original: UIImage) { self.originalImage = original; super.init(nibName: nil, bundle: nil) }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard IPImagePlaygroundViewController.isAvailable() else {
            // 兜底：iOS 18.2 但机型不支持（如 iPad 无 Apple Intelligence）
            showFallback()
            return
        }
        let vc = ImagePlaygroundViewController(sourceImage: originalImage,
                                              concepts: ["cartoon pet", "clay style"])
        vc.delegate = self
        present(vc, animated: true)
    }

    func imagePlayground(_ imagePlaygroundViewController: ImagePlaygroundViewController,
                         didCreateImageAt imageURL: URL) {
        Task { await finalize(imageURL: imageURL) }
        imagePlaygroundViewController.dismiss(animated: true)
    }
}
```

> **概念（Concepts）很关键**：传 `.text("my cat, clay figure, kawaii")` 和 `.image(originalImage)` 一起，能显著提升相似度与风格一致性。

### 3.4 ③ 帧拆分与导出

Image Playground 输出一张静态图。要让宠物"会动"，需要：

**A. 程序化变形动画（推荐 MVP，零额外美术）**

不做真"帧动画"，而是用 SwiftUI/SpriteKit 对同一张图做轻微的**呼吸/眨眼/晃动**，就能营造活感：

```swift
struct BreathingAvatar: View {
    let mood: PetMood
    @State private var breathe = false

    var body: some View {
        Image(uiImage: mood.frame)
            .scaleEffect(breathe ? 1.03 : 1.0, anchor: .bottom)
            .rotationEffect(.degrees(breathe ? 1 : -1), anchor: .bottom)
            .animation(.easeInOut(duration: mood == .sleeping ? 3 : 1.6)
                        .repeatForever(autoreverses: true), value: breathe)
            .onAppear { breathe = true }
    }
}
```

**B. 多帧 sprite sheet（进阶）**

如要"走路/睡觉"多帧，在生成时让 Image Playground **批量生成 4 张同概念不同动作**的图（提示词加 "sleeping / sitting / waving / running"），存成 `appearance.frames[mood] = [UIImage]`，Widget 里用 Timeline 逐帧切。

### 3.5 ④ 入库

```swift
public enum AssetStore {
    public static func saveAvatar(_ images: [PetMood: UIImage], for petID: UUID) throws {
        let dir = SharedStore.avatarsDir.appendingPathComponent(petID.uuidString,
                                                                isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (mood, img) in images {
            let png = img.pngData()!
            try png.write(to: dir.appendingPathComponent("\(mood.rawValue).png"))
        }
    }

    public static func loadAvatar(mood: PetMood, petID: UUID) -> UIImage? {
        let url = SharedStore.avatarsDir
            .appendingPathComponent(petID.uuidString)
            .appendingPathComponent("\(mood.rawValue).png")
        return UIImage(contentsOfFile: url.path)
    }
}
```

---

## 4. 显示层（Widget / StandBy / 灵动岛）

### 4.1 WidgetBundle

```swift
@main
struct DeskPetWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomePetWidget()
        LockScreenPetWidget()
        StandByPetWidget()          // 同一 systemMedium，靠 StandBy 自动放大
    }
}
```

### 4.2 TimelineProvider（统一数据源）

```swift
struct PetTimelineProvider: TimelineProvider {
    func placeholder(in ctx: Context) -> PetEntry { .preview }
    func getSnapshot(in ctx: Context, completion: @escaping (PetEntry) -> Void) {
        completion(.make())
    }

    func getTimeline(in ctx: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        var state = PetStore.load()        // 从 App Groups 读
        state.reconcile()                  // 结算挂起时间 ★ 关键

        // 生成未来 6 小时的 entry，每 15 分钟一个，覆盖昼夜/能量变化
        var entries: [PetEntry] = []
        var now = Date.now
        for i in 0..<24 {
            let t = now.addingTimeInterval(TimeInterval(i) * 15 * 60)
            var s = state
            s.reconcile(now: t)            // 预演未来状态（用于自动睡觉/起床）
            entries.append(PetEntry(date: t, state: s))
        }
        PetStore.save(state)               // 把当前结算结果写回
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6*3600))))
    }
}
```

> **为什么预演未来 entry**：这样系统在白天/夜晚会自动显示对应 mood，不消耗 reload 预算。

### 4.3 主桌面 Widget（systemMedium）

```swift
struct HomePetView: View {
    let entry: PetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(colors: entry.state.backgroundColors, startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                BreathingAvatar(mood: entry.state.mood)
                    .frame(height: 120)

                // 五项数值进度条（养成感）
                StatBars(stats: entry.state.stats)
                    .frame(maxWidth: .infinity)

                // 一句话对话
                Text(entry.state.line)        // 根据 mood 抽取
                    .font(.caption)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
```

### 4.4 Widget 上的互动（跳 App + 加数值）

Widget 不能做复杂手势，但支持 `Button(intent:)` 和 `Link`：

```swift
Link(destination: URL(string: "deskpet://action/feed")!) {
    Label("喂食", systemImage: "fork.knife")
}
Button(intent: PlayWithPetIntent()) { Label("摸摸", systemImage: "hand.draw") }
```

`AppIntent` 在 App Extension 进程里能直接改 `PetState` 并 `WidgetCenter.shared.reloadAllTimelines()`，用户点了立刻看到反应。

---

## 5. 事件感知引擎

### 5.1 监听的事件

| 事件 | 监听方式 | 应用 |
|---|---|---|
| 充电接入/拔出 | `UIDevice.current.batteryMonitoringEnabled = true` + `.batteryStateDidChangeNotification` | mood → `.eating`，开 Live Activity；拔出 +10 心情 |
| 电量变化 | `.batteryLevelDidChangeNotification` | ≤ 20% → `.tired` |
| 低电量模式 | `ProcessInfo.processInfo` + `.powerStateDidChange` | → `.sleeping` |
| 耳机/蓝牙音频路由 | `AVAudioSession.routeChangeNotification` | → `.dancing`，5 分钟 |
| 夜间 | Timeline entry 时间 | 自动 `.sleeping` |
| 日程进行中 | EventKit `EKEventStore` + 定时查询 | → `.quiet`（嘘） |
| 应用回到前台 | `UIScenePhase` | reconcile + 随机打招呼 |
| 健康/步数 | HealthKit `HKObserverQuery` | 步数 > 5000 → `.excited`，奖励 coins |

### 5.2 规则引擎

```swift
public struct EventRule {
    public let condition: (PetState, Environment) -> Bool
    public let apply: (inout PetState) -> Void
}

public final class EventRuleEngine {
    public static let shared = EventRuleEngine()

    public var rules: [EventRule] = [
        EventRule(condition: { _, env in env.isCharging },
                  apply: { $0.mood = .eating; $0.stats.hunger = min(100, $0.stats.hunger + 6) }),
        EventRule(condition: { state, _ in state.stats.hunger <= 15 },
                  apply: { $0.mood = .hungry }),
        EventRule(condition: { _, env in env.isLowPowerMode },
                  apply: { $0.mood = .sleeping }),
        // …
    ]

    public func process(_ event: PetEvent, into state: inout PetState) {
        let env = Environment.current()
        for rule in rules where rule.condition(state, env) {
            rule.apply(&state)
        }
    }
}
```

### 5.3 刷新策略（避免超预算）

| 类型 | 方式 | 是否计入预算 |
|---|---|---|
| 时间相关（昼夜、能量衰减） | Timeline 预制 entry | ❌ 免费 |
| 重要系统事件（充电、低电量） | `WidgetCenter.reloadAllTimelines()` | ❌ **不计入**（苹果对此类"重要变化"豁免） |
| 用户互动（喂食、摸摸） | `AppIntent` 内 reload | ✅ 计入，但频率低 |
| 后台定时校准（每小时） | Background processing task | — App 端跑，结算后存盘 |

**重要**：不要每秒 reload Widget。养成数值的"活着感"靠 Timeline entry 预演 + 重要事件触发，足够了。

---

## 6. App 内互动小游戏（养成核心）

用 SpriteKit（60fps，适合动效 + 物理）：

| 游戏 | 玩法 | 奖励 |
|---|---|---|
| **接球** | 拖动宠物接住下落的球，30s 计分 | exp +20, happiness +15, energy -15, coins +score |
| **抚摸** | 在宠物身上画圈，节奏游戏 | happiness +8，无冷却 |
| **洗澡** | 擦泡泡，擦完清洁+40 | cleanliness +40, happiness +5, coins +5 |
| **投食** | 选择不同食物，影响不同数值 | hunger +20~30 |
| **散步（联动步数）** | 读取 HealthKit 步数，兑换散步奖励 | 每天封顶 1 次 |

**前台主界面**用 SpriteKit Scene：
- 宠物随 mood 播对应动画
- 拖拽宠物有物理回弹
- 双指捏合喂食、单击摸头
- 顶部 HUD 显示五项数值 + 等级 + 金币

---

## 7. Live Activity（灵动岛 + 锁屏实时）

用于"充电中宠物在吃饭""洗澡中"等**短暂进行中**的活动。

```swift
// ActivityAttributes
struct PetActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var mood: PetMood
        public var progress: Double      // 0~1，比如充电进度
        public var subtitle: String
    }
    public var petName: String
}

// 充电时启动
let activity = try Activity.request(
    attributes: PetActivityAttributes(petName: state.name),
    content: .init(state: .init(mood: .eating, progress: 0, subtitle: "充电进食中…"),
                   staleDate: nil)
)

// 电量变化时更新
await activity.update(.init(state: .init(mood: .eating, progress: batteryLevel/100,
                                         subtitle: "吃饱 \(Int(batteryLevel*100))%")))
// 拔出时结束
await activity.end(nil, dismissalPolicy: .immediate)
```

> 审核要点：Live Activity 必须对应真实"进行中"的活动，把"充电/洗澡/散步"包装成活动即可过审。

---

## 8. 后台存活与耗电控制

| 机制 | 用途 |
|---|---|
| `BGProcessingTask` | 每小时跑一次 reconcile，结算数值并写盘 |
| 挂起时间补偿 | App 前台 / Widget 刷新时一次性补算，不需要常驻 |
| Widget Timeline | 大部分时间靠系统回调 Provider，App 完全不跑 |
| 重要事件监听 | 只在 App 前台或刚启动时订阅，不长期持有 |

**耗电估算**：
- Widget 每次刷新 < 50ms CPU
- Image Playground 仅在用户主动生成时调用
- 后台 reconcile 每小时 < 100ms
→ 预计对续航无可感知影响。

---

## 9. 开发路线图

| 阶段 | 周期 | 交付 |
|---|---|---|
| **M0 脚手架** | 3 天 | Xcode 工程、3 target、App Groups、空 Widget 能显示 |
| **M1 静态宠物** | 1 周 | PetState + reconcile + 桌面 Widget 显示数值与对话 |
| **M2 形象生成** | 1.5 周 | 抠图 + Image Playground + 呼吸动画 |
| **M3 养成互动** | 2 周 | 喂食/抚摸/接球小游戏 + App HUD + 等级 |
| **M4 系统事件** | 1.5 周 | 充电/电量/低电量模式/夜间/日程 |
| **M5 多表面** | 1.5 周 | 锁屏 / StandBy / Live Activity |
| **M6 打磨与提审** | 1 周 | 性能、文案、隐私审核、App Store 截图 |

---

## 10. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| Image Playground 设备支持不全（需 Apple Intelligence 机型） | 部分用户用不了 | 机型检测 + 降级为滤镜卡通化（Core Image）兜底 |
| Widget 刷新预算 40/天 | 状态不实时 | 预制 Timeline + 只在重要事件 reload |
| 来电/全局触摸不可监听 | 体验打折 | 文案上说明，用充电/电量等可监听事件替代 |
| App 审核拒 Live Activity | 上线延迟 | 严格对应真实活动，避免"装饰性"使用 |
| Image Playground 输出风格不稳定 | 形象不一致 | 同一 concepts 多次生成供用户挑选；提供预设风格模板 |
| 后台过久 reconcile 数值崩坏 | 用户流失 | 数值下限 0、上限 100，"饿晕"但不"死亡"；连续 3 天不打开推送提醒 |

---

## 11. 后续可扩展（V2）

- 多宠物（一个 App 养多只）
- 互动联系（Live Activity 之间简单表情互动）
- iCloud 同步（多设备同一只宠物）
- Widget Configurable（用户选宠上桌面）
- 桌面 AI 对话（接 Apple Foundation Models）
