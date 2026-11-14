import Foundation
import SwiftData

/// 车辆类型，决定年检周期
enum InspectionCategory: String, CaseIterable, Identifiable {
    case car = "小客车"
    case motorcycle = "摩托车"
    case other = "其他"

    var id: String { rawValue }

    /// 完整表述
    var fullText: String {
        switch self {
        case .car:        return "9 座以下非营运小微型载客汽车"
        case .motorcycle: return "摩托车"
        case .other:      return "其他机动车"
        }
    }

    /// 是否适用「10 年内每 2 年检验 1 次」的政策
    var usesTwoYearCycle: Bool { self != .other }

    /// 按车型名猜一个类别，用户可在编辑页改
    static func guess(from modelName: String) -> InspectionCategory {
        if modelName.contains("摩托") { return .motorcycle }
        return .car
    }
}

/// 本次到期需要办的事
enum InspectionAction {
    case onlineTest   // 上线检验
    case applyMark    // 免上线，申领检验标志

    var label: String {
        switch self {
        case .onlineTest: return "上线检验"
        case .applyMark:  return "免上线，申领标志"
        }
    }

    var detail: String {
        switch self {
        case .onlineTest: return "需到机动车检验机构上线检测，合格后申领检验标志"
        case .applyMark:  return "无需上线检测，直接在「交管12123」申领检验标志电子凭证"
        }
    }
}

/// 年检状态
enum InspectionStatus {
    case overdue      // 已过期
    case soon         // 90 天内（可办理窗口已开）
    case normal       // 正常
    case unknown      // 未录入

    var label: String {
        switch self {
        case .overdue: return "已过期"
        case .soon:    return "该办了"
        case .normal:  return "正常"
        case .unknown: return "未录入"
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

/// 年检计划：由「注册登记日期 + 车辆类型 + 检验有效期止」推出规格与下次日期
struct InspectionPlan {
    let category: InspectionCategory
    /// 当前检验有效期止
    let validUntil: Date?
    /// 车龄（年），以有效期止所在年份减去注册年份
    let ageYears: Int?
    /// 本次办理方式
    let action: InspectionAction?
    /// 建议办理窗口起始日（有效期止前 3 个月）
    let windowStart: Date?
    /// 距有效期止还有多少天（负数为已过期）
    let daysLeft: Int?
    let status: InspectionStatus
    /// 本次办理后推算的下一个有效期止
    let nextValidUntil: Date?
    /// 下次办理时的车龄
    let nextAgeYears: Int?

    init(vehicle: Vehicle) {
        let cal = Calendar.current
        let now = Date()
        let category = vehicle.inspectionCategory
        let valid = vehicle.inspectionValidUntil

        self.category = category
        self.validUntil = valid

        // 车龄按年份差算：2019-12-16 注册、有效期止 2027-12-31 → 第 8 年
        let refDate = valid ?? now
        let age = cal.component(.year, from: refDate) - cal.component(.year, from: vehicle.registerDate)
        let safeAge = max(age, 0)
        self.ageYears = valid == nil ? nil : safeAge

        // 本次办理方式
        var act: InspectionAction?
        if valid != nil {
            if !category.usesTwoYearCycle {
                act = .onlineTest
            } else if safeAge >= 10 {
                act = .onlineTest
            } else if safeAge == 6 || safeAge == 10 {
                act = .onlineTest
            } else {
                act = .applyMark
            }
        }
        self.action = act

        // 建议办理窗口：有效期止前 3 个月
        self.windowStart = valid.flatMap { cal.date(byAdding: .month, value: -3, to: $0) }

        // 剩余天数与状态
        if let valid {
            let left = valid.daysFromToday
            self.daysLeft = left
            if left < 0 {
                self.status = .overdue
            } else if left <= 90 {
                self.status = .soon
            } else {
                self.status = .normal
            }
        } else {
            self.daysLeft = nil
            self.status = .unknown
        }

        // 下一个有效期止：10 年内 2 年一检，超 10 年 1 年一检
        if let valid {
            let yearly = !category.usesTwoYearCycle || safeAge >= 10
            let step = yearly ? 1 : 2
            self.nextValidUntil = cal.date(byAdding: .year, value: step, to: valid)
            self.nextAgeYears = safeAge + step
        } else {
            self.nextValidUntil = nil
            self.nextAgeYears = nil
        }
    }

    /// 车型 + 周期的一句话规格
    var specText: String {
        category.fullText
    }

    /// 周期说明
    var periodText: String {
        if !category.usesTwoYearCycle { return "每年检验 1 次" }
        if let age = ageYears, age >= 10 { return "超过 10 年，每年上线检验 1 次" }
        return "10 年内每 2 年检验 1 次（第 6、10 年上线，其余免上线）"
    }

    /// 本次是第几年
    var stageText: String {
        guard let age = ageYears else { return "未录入检验有效期" }
        if !category.usesTwoYearCycle { return "第 \(age + 1) 年 · 每年一检" }
        if age >= 10 { return "第 \(age + 1) 年 · 每年一检" }
        if let action {
            return "第 \(age) 年 · \(action.label)"
        }
        return "第 \(age) 年"
    }

    /// 剩余时间短文案，列表行右侧用
    var remainText: String {
        guard let daysLeft else { return "未录入" }
        if daysLeft < 0 { return "已过期 \(abs(daysLeft)) 天" }
        if daysLeft == 0 { return "今天到期" }
        return "还剩 \(daysLeft) 天"
    }

    /// 第二行摘要，例如「2027-12-31 止 · 免上线，申领标志」
    var summaryText: String {
        guard let validUntil else { return "未录入检验有效期" }
        let date = validUntil.shortDateText
        guard let action else { return "\(date) 止" }
        return "\(date) 止 · \(action.label)"
    }

    /// 列表行用的短摘要，例如「2027-12-31 止 · 免上线」
    var shortSummaryText: String {
        guard let validUntil else { return "未录入检验有效期" }
        let date = validUntil.shortDateText
        switch action {
        case .applyMark:  return "\(date) 止 · 免上线"
        case .onlineTest: return "\(date) 止 · 需上线"
        case nil:         return "\(date) 止"
        }
    }

    /// 办理窗口文案
    var windowText: String {
        guard let validUntil, let windowStart else { return "—" }
        return "\(windowStart.shortDateText) 起至 \(validUntil.shortDateText)"
    }
}
