import Foundation
import SwiftData

/// 保养记录：一次进店保养/换机油
@Model
final class MaintenanceRecord {
    var date: Date
    /// 里程（km）。历史记录里可能有缺失，用 nil 表示未记录
    var mileage: Int?
    /// 项目，例如「常规保养」「换机油」
    var item: String
    var cost: Double
    var shop: String
    var note: String
    var uid: String
    var createdAt: Date

    var vehicle: Vehicle?

    init(date: Date,
         mileage: Int? = nil,
         item: String = "常规保养",
         cost: Double = 0,
         shop: String = "",
         note: String = "") {
        self.date = date
        self.mileage = mileage
        self.item = item
        self.cost = cost
        self.shop = shop
        self.note = note
        self.uid = UUID().uuidString
        self.createdAt = Date()
    }
}

/// 保养状态
enum MaintenanceStatus {
    case overdue      // 已超期
    case soon         // 临近（30 天内 / 500 km 内）
    case normal       // 正常
    case unknown      // 没有设置周期

    var label: String {
        switch self {
        case .overdue: return "该保养了"
        case .soon:    return "即将到期"
        case .normal:  return "正常"
        case .unknown: return "未设周期"
        }
    }

    var order: Int {
        switch self {
        case .overdue: return 0
        case .soon:    return 1
        case .unknown: return 2
        case .normal:  return 3
        }
    }
}

/// 保养计划：由「上次保养 + 周期」推出的下次保养时间/里程
struct MaintenancePlan {
    let lastRecord: MaintenanceRecord?
    let nextDate: Date?
    let nextMileage: Int?
    /// 距下次保养还有多少天（负数为已超期）
    let daysLeft: Int?
    /// 距下次保养里程还差多少 km（负数为已超）
    let kmLeft: Int?
    let status: MaintenanceStatus

    init(vehicle: Vehicle) {
        let records = vehicle.sortedMaintenance
        let last = records.last
        let baseDate = last?.date ?? vehicle.purchaseDate ?? vehicle.registerDate
        let baseMileage = vehicle.latestMaintenanceMileage

        self.lastRecord = last

        if vehicle.maintenanceIntervalMonths > 0 {
            let date = Calendar.current.date(byAdding: .month,
                                             value: vehicle.maintenanceIntervalMonths,
                                             to: baseDate)
            self.nextDate = date
            self.daysLeft = date?.daysFromToday
        } else {
            self.nextDate = nil
            self.daysLeft = nil
        }

        if vehicle.maintenanceIntervalKm > 0 {
            let target = baseMileage + vehicle.maintenanceIntervalKm
            self.nextMileage = target
            self.kmLeft = target - vehicle.currentMileage
        } else {
            self.nextMileage = nil
            self.kmLeft = nil
        }

        let d = self.daysLeft
        let k = self.kmLeft
        if d == nil && k == nil {
            self.status = .unknown
        } else if (d.map { $0 < 0 } ?? false) || (k.map { $0 <= 0 } ?? false) {
            self.status = .overdue
        } else if (d.map { $0 <= 30 } ?? false) || (k.map { $0 <= 500 } ?? false) {
            self.status = .soon
        } else {
            self.status = .normal
        }
    }

    /// 距离上次保养多少天（没有记录时为 nil）
    var daysSinceLast: Int? {
        guard let last = lastRecord else { return nil }
        return -last.date.daysFromToday
    }

    /// 「先到为准」的说明文本
    var ruleText: String {
        var parts: [String] = []
        if nextDate != nil { parts.append("时间") }
        if nextMileage != nil { parts.append("里程") }
        if parts.count == 2 { return "时间或里程，先到为准" }
        if parts.count == 1 { return "按\(parts[0])计算" }
        return "未设置保养周期"
    }

    /// 下次保养目标，例如「2027-03-26 或 68960 km」
    var nextText: String {
        var parts: [String] = []
        if let nextDate { parts.append(nextDate.shortDateText) }
        if let nextMileage { parts.append("\(nextMileage) km") }
        return parts.isEmpty ? "未设置" : parts.joined(separator: " 或 ")
    }

    /// 剩余量，例如「还有 116 天 · 还差 3000 km」
    var remainText: String {
        var parts: [String] = []
        if let daysLeft {
            parts.append(daysLeft < 0 ? "已超 \(abs(daysLeft)) 天" : "还有 \(daysLeft) 天")
        }
        if let kmLeft {
            parts.append(kmLeft <= 0 ? "已超 \(abs(kmLeft)) km" : "还差 \(kmLeft) km")
        }
        return parts.joined(separator: " · ")
    }

    /// 最紧急的那一项，列表里用
    var shortRemain: String {
        if let daysLeft, daysLeft < 0 { return "已超 \(abs(daysLeft)) 天" }
        if let kmLeft, kmLeft <= 0 { return "已超 \(abs(kmLeft)) km" }
        if let daysLeft, daysLeft <= 30 { return "还有 \(daysLeft) 天" }
        if let kmLeft, kmLeft <= 500 { return "还差 \(kmLeft) km" }
        if let daysLeft { return "还有 \(daysLeft) 天" }
        if let kmLeft { return "还差 \(kmLeft) km" }
        return "—"
    }
}
