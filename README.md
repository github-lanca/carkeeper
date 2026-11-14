# CarKeeper（车管家）

一个跑在 iPhone 上的车辆管家，把「保险、保养、年检」这三件最容易忘的事放在一个首页里管起来。纯本地存储，不需要账号，不联网。

## 特性

- **首页最近动作**：自动从保险 / 保养 / 年检里挑出离到期最近的一件事，放大在顶部卡片上，下面的三块提醒也按紧急程度动态排序。
- **保险**：按车辆聚合多头保单（交强险、商业险、驾乘意外、个人意外），同一辆车的多份保单只占一行并带数量角标，点进去看明细；到期日精确到时分，可编辑、可左滑删除。
- **保养**：按「时间或里程，先到为准」推算下次保养，记录每次进店的日期、里程、项目、花费、门店。
- **年检**：按车辆类型与注册登记日期推算本次是第几年、要不要上线、建议办理窗口，以及下一个检验有效期止。
- **本地通知**：保单 30/15/7/1 天、统一续保日前 7 天、保养 15/7/1 天、年检 90/30/7 天各提醒一次，全部走 `UNUserNotificationCenter`，不发任何网络请求。
- **统一续保日**：把多台车的续保锚点对齐到同一天，交强险不断保、商业险允许几天空窗的前提下提前出单。

## 技术栈

- SwiftUI + SwiftData（iOS 18 及以上），无任何第三方依赖，全部为系统框架。
- 工程由手写的 `project.pbxproj` 维护，使用 `PBXFileSystemSynchronizedRootGroup`，新增 Swift 文件不需要改工程文件。
- 通知、日期推算、种子数据均在 `CarKeeper/Support` 下，UI 在 `CarKeeper/Views` 下。

## 目录结构

```
CarKeeper/
├── CarKeeper.xcodeproj
├── CarKeeper/
│   ├── CarKeeperApp.swift          # 入口、ModelContainer、种子数据
│   ├── Models/                     # Vehicle / Policy / MaintenanceRecord / Inspection
│   ├── Support/                    # 种子数据、通知调度、日期工具
│   └── Views/                      # 首页、车辆、保养、年检、设置
├── Tools/
│   └── gen_icons.swift             # 用 CoreGraphics 矢量绘制 App 图标（1024，sRGB 去 alpha）
└── .gitignore
```

## 运行

1. 用 Xcode 打开 `CarKeeper.xcodeproj`。
2. 在 target 的 Signing & Capabilities 里选择你自己的 Team，并把 Bundle Identifier 改成你自己的。
3. 选一台 iOS 18+ 的模拟器或真机运行。

首次启动会写入两台演示车辆、六份保单和几条保养记录，方便直接看到界面效果。这些演示数据在 `CarKeeper/Support/SeedData.swift` 里，想清空可在「设置 → 清空数据」里操作。

## 数据与隐私

- 所有数据存放在 App 沙盒内的 SwiftData 数据库，不联网、不上传、无账号体系。
- 仓库里不含任何真实车主信息：`SeedData.swift` 中的车牌、保单号均为占位值，截图与真机调试产物不随仓库分发。
- App 不做任何埋点与统计。

## 年检规则说明

代码里用的是「9 座以下非营运小微型载客汽车与摩托车」的通用规则：注册登记 10 年内每 2 年检验 1 次（第 2/4/8 年免上线只申领检验标志，第 6/10 年上线检测），超过 10 年每年上线 1 次，可在检验有效期满前 3 个月内办理。

各地执行细则与免检车型范围可能有差异，**结果仅供参考，请以「交管 12123」与当地车管所口径为准**。

## 图标

`Tools/gen_icons.swift` 直接画出 1024×1024 的图标（深蓝底、里程环、指针），不依赖设计软件：

```bash
swift Tools/gen_icons.swift ./AppIcon
```

输出 PNG 后拖进 `Assets.xcassets/AppIcon.appiconset` 即可。

## License

MIT
