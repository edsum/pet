# App Store 上线准备清单

> 提审前逐项确认。本文件描述的内容属于"业务/合规"层面，不是代码。

---

## 1. App 元数据（App Store Connect 填写）

### 1.1 基本信息

| 字段 | 内容 |
|---|---|
| **App 名称** | 桌宠 DeskPet（建议中英各一版） |
| **副标题** | 一只陪你度过每一天的桌面宠物 |
| **Bundle ID** | `com.yourname.deskpet` |
| **SKU** | `deskpet` |
| **主语言** | 简体中文 |
| **主要类别** | Lifestyle（生活）/ Entertainment（娱乐） |
| **次要类别** | Personalization（个性化） |
| **关键词** | 桌宠,桌面宠物,电子宠物,养成,小组件,Widget,Live Activity,灵动岛,宠物游戏,治愈 |

### 1.2 描述（中英文，可复制到 ASC）

**简体中文：**

> 桌宠 DeskPet 是一只住在你 iPhone 桌面、锁屏、灵动岛上的电子宠物。
> 用自己拍的照片生成独一无二的卡通形象，让它真正成为你的伙伴。
>
> · 桌面/锁屏/StandBy 小组件：随时看见它在做什么
> · Live Activity：充电时在灵动岛显示"充电进食"进度
> · 系统事件互动：充电、低电量、戴耳机、夜间都会改变它的状态
> · 日程感知：开会时它会保持安静（嘘），不打扰你
> · 步数奖励：每天走够 5000 步会收到它的庆祝
> · 天气感知：下雨天它会给你打伞，冷天会缩成一团
> · 养成玩法：能量、饱腹、心情、清洁、健康五项数值
> · 互动小游戏：接球、洗澡、节拍抚摸（30 秒一局）
>
> 数据全部本地存储，不上传任何服务器。

**English:**

> DeskPet is a virtual pet that lives on your iPhone's Home Screen, Lock Screen, and Dynamic Island.
> Snap a photo of your own pet and generate a unique cartoon avatar.
>
> · Home/Lock/StandBy widgets — see what it's up to at a glance
> · Live Activities — Dynamic Island shows "charging & eating" progress
> · System events — charging, low battery, headphones, night all change its mood
> · Calendar aware — it stays quiet during your meetings
> · Step rewards — celebrate together when you reach 5,000 steps daily
> · Weather aware — rain, snow, heat all bring different reactions
> · Tamagotchi-style stats — energy, hunger, happiness, cleanliness, health
> · Mini-games — catch balls, take a bath, rhythm petting
>
> All data stays on device. Nothing is uploaded.

### 1.3 版本与版权

| 字段 | 内容 |
|---|---|
| Version | 1.0.0 |
| Copyright | © 2026 Your Name |
| 年龄分级 | 4+ （无不良内容） |
| 价格 | 免费（可选内购解锁多宠物/装扮） |

---

## 2. 隐私问卷（App Privacy）

依据 `Shared/PrivacyInfo.xcprivacy`：

### 2.1 数据采集声明

| 数据类型 | 是否采集 | 是否关联身份 | 是否追踪 | 用途 |
|---|---|---|---|---|
| Photos or Videos（照片） | ✅ 是 | ❌ 否 | ❌ 否 | App 功能（生成宠物形象） |
| Other User Content（其他用户内容） | ✅ 是 | ❌ 否 | ❌ 否 | App 功能（自定义装扮/对话） |
| Health & Fitness（健康） | ✅ 是（仅步数） | ❌ 否 | ❌ 否 | App 功能（步数奖励） |
| Location（精确位置） | ✅ 是 | ❌ 否 | ❌ 否 | App 功能（天气反应） |

> 所有数据**仅本地存储**（App Groups / UserDefaults / 文件系统），不上传服务器。
> 没有任何"关联用户身份"或"追踪"行为。

### 2.2 必需 API 声明（Required Reason API）

| API 类别 | Reason Code | 用途 |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | 存储宠物状态（养成数值） |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | 形象帧图文件时间戳 |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` | 挂起时间补偿计算 |

---

## 3. 审核要点（重要！）

### 3.1 Live Activities / 灵动岛

苹果要求 Live Activity **必须对应"真实进行中的活动"**，不能作为"装饰性常驻显示"。我们的 4 种活动都已对应真实事件：

| 活动 | 对应真实事件 | 给审核员的说明（写到 Review Note） |
|---|---|---|
| 充电进食 | `UIDevice.batteryState` 充电中 | "Live Activity appears only while device is charging, showing real battery progress. Ends when unplugged." |
| 洗澡 | 用户主动进入洗澡小游戏（30 秒） | "Appears only while user is in the bathing mini-game, automatically ends after 30s." |
| 睡觉 | 用户开启 iOS 低电量模式 | "Appears only when user enables iOS Low Power Mode. Ends when disabled." |
| 步数达标 | HealthKit 当日步数 ≥ 5000 | "Celebrates when HealthKit reports ≥ 5000 steps today. Auto-ends after 5 seconds." |

**Review Note 模板（贴到 ASC 的 Review Notes）：**

```
This app uses Live Activities in 4 scenarios, each tied to a real ongoing activity:

1. Charging: When the device is plugged in, the Dynamic Island shows the
   real battery level progress. The activity is dismissed when unplugged.

2. Bathing: Started only when the user opens the bathing mini-game, and
   automatically ends after 30 seconds.

3. Sleeping: Started when the user enables iOS Low Power Mode (a user action),
   and dismissed when Low Power Mode is turned off.

4. Step Goal: A 5-second celebration when the user reaches 5,000 steps today,
   based on HealthKit data. Auto-dismissed.

No Live Activity is purely decorative or used as a persistent notification.
```

### 3.2 Family Controls entitlement（专注模式检测）

`FocusModeProvider` 用到了 FamilyControls。审核员可能要求说明：

```
We use the FamilyControls API only to detect when Focus Mode / Do Not Disturb
is active, so the pet can show a "quiet" state. We do NOT use Screen Time API
to monitor or control any other app's usage, and we do not apply any
ManagedSettings restrictions.
```

> **注意**：如果不想申请这个 entitlement，可以删掉 `FocusModeProvider`，
> 改用低电量模式近似（代码里已经这么做了）。这样能省掉一项 entitlement 申请。

### 3.3 Image Playground（图像生成）

Image Playground 是系统 UI，所有图像生成都在设备端完成，**不上传用户照片到服务器**。审核员可能要求说明：

```
The avatar generation feature uses Apple's Image Playground API, which performs
all image generation on-device. User photos are never uploaded to any server.
```

### 3.4 权限请求文案

权限弹窗的文案需要在 Info.plist 配好（README 里已有完整 XML）。审核员会检查文案是否说明了用途：

| 权限 | Info.plist 文案 |
|---|---|
| 相册 | "用于选择宠物照片生成桌面形象" |
| 日历 | "用于在会议进行时让宠物保持安静" |
| 健康 | "用于根据步数达标给宠物奖励" |
| 位置 | "用于获取当前天气，让宠物随天气变化" |

---

## 4. 截图与预览

### 4.1 App 截图（6.7" iPhone 必备）

建议拍 6 张：

1. **主页 + 宠物 SpriteKit 主场景**（亮色背景 + 充满活力的对话）
2. **生成形象**（抠图 → Image Playground 风格选择界面）
3. **小游戏**（接球游戏中，分数飘字）
4. **桌面 Widget**（用模拟器/真机截图桌面小组件）
5. **灵动岛 Live Activity**（充电时灵动岛显示"⚡️ 87%"）
6. **StandBy 模式**（横屏充电，宠物睡觉动画）

### 4.2 App Preview 视频（30s，可选但推荐）

剧本建议：

| 秒 | 画面 |
|---|---|
| 0-5 | 拍宠物照片 → 一键生成卡通形象 |
| 5-15 | 主页互动：摸头冒爱心、拖拽、双击跳 |
| 15-20 | 接球小游戏精彩镜头 |
| 20-25 | 充电时灵动岛"⚡️ 87%" |
| 25-30 | 桌面 Widget 长按添加 |

---

## 5. 上线前自查 Checklist

### 5.1 代码侧

- [ ] `SharedStore.groupID` 已改成你的实际 App Group
- [ ] `Logger.subsystem` 已改成你的实际 bundle id
- [ ] `WidgetReloadThrottle` 阈值合理（默认 4/h、25/day）
- [ ] 移除所有 `print()` 调试语句，统一走 `Logger`
- [ ] 关闭 Debug 性能覆盖层（生产构建）
- [ ] `swift test` 全绿
- [ ] 真机测试 24 小时不崩溃

### 5.2 资源侧

- [ ] AppIcon 已配 1024 / 180 / 120 等全尺寸
- [ ] Launch Screen 配好（占位 logo）
- [ ] 截图 6 张已生成
- [ ] 中英文描述已写入 ASC

### 5.3 合规侧

- [ ] `Shared/PrivacyInfo.xcprivacy` 已加到 App 和 Widget 两个 target
- [ ] Info.plist 权限文案齐备
- [ ] App Privacy 问卷已填写
- [ ] App Tracking Transparency：**不需要**（我们不追踪）
- [ ] Review Notes 已写 Live Activity / Family Controls 说明
- [ ] Export Compliance：**不需要**（不含加密）

### 5.4 提审

- [ ] Archive → Validate → Upload to App Store Connect
- [ ] 选择"内部测试"先跑通 TestFlight
- [ ] 至少 3 个测试设备（不同 iOS 版本）跑通
- [ ] 提交审核，选择"加急审核"（首次上架一般不需要）

---

## 6. 上线后监控

- [ ] 在 Console.app 用 `subsystem:com.yourname.deskpet` 过滤，观察生产日志
- [ ] 关注 `Logger.widget` 里是否有"budget exhausted"反复出现
- [ ] App Store Connect 的 Crashes / Analytics 每周看一次
- [ ] 用户反馈"宠物不动了" → 检查是否 TimelineProvider 出错
