import Foundation
import SwiftData

/// 险种
enum PolicyKind: String, Codable, CaseIterable, Identifiable {
    case compulsory = "交强险"
    case commercial = "商业险"
    case passenger  = "驾乘意外"
    case personal   = "个人意外"
    case other      = "其他"

    var id: String { rawValue }

    /// 排序权重：交强险优先
    var order: Int {
        switch self {
        case .compulsory: return 0
        case .commercial: return 1
        case .passenger:  return 2
        case .personal:   return 3
        case .other:      return 4
        }
    }
}

/// 保单
@Model
final class Policy {
    var kindRaw: String
    var insurer: String
    var policyNumber: String
    var startDate: Date
    var endDate: Date
    var premium: Double
    var note: String
    var uid: String
    var createdAt: Date

    var vehicle: Vehicle?

    init(kind: PolicyKind,
         insurer: String = "中国人民财产保险股份有限公司",
         policyNumber: String = "",
         startDate: Date,
         endDate: Date,
         premium: Double = 0,
         note: String = "") {
        self.kindRaw = kind.rawValue
        self.insurer = insurer
        self.policyNumber = policyNumber
        self.startDate = startDate
        self.endDate = endDate
        self.premium = premium
        self.note = note
        self.uid = UUID().uuidString
        self.createdAt = Date()
    }

    var kind: PolicyKind {
        get { PolicyKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var isActive: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }

    var hasExpired: Bool { endDate < Date() }

    var isNotStarted: Bool { startDate > Date() }

    /// 剩余天数：今天到期为 0，已过期为负
    var daysRemaining: Int { endDate.daysFromToday }

    var urgency: Urgency { urgencyLevel(forDays: daysRemaining) }

    /// 剩余时间短文案，列表行右侧用
    var remainShortText: String {
        if daysRemaining < 0 { return "已过期 \(abs(daysRemaining)) 天" }
        if daysRemaining == 0 { return "今天到期" }
        return "还剩 \(daysRemaining) 天"
    }

    /// 保障天数
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
    }

    /// 保障进度 0...1
    var progress: Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 1 }
        let passed = Date().timeIntervalSince(startDate)
        return min(max(passed / total, 0), 1)
    }

    /// 待办排序：先按止期，止期相同再按险种固定顺序，保证两次渲染结果一致
    static func reminderOrder(_ a: Policy, _ b: Policy) -> Bool {
        if a.endDate != b.endDate { return a.endDate < b.endDate }
        return a.kind.order < b.kind.order
    }
}
