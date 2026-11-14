import SwiftUI

extension PolicyKind {
    var tint: Color {
        switch self {
        case .compulsory: return Color(red: 0.04, green: 0.38, blue: 0.84)   // 蓝
        case .commercial: return Color(red: 0.07, green: 0.44, blue: 0.25)   // 绿
        case .passenger:  return Color(red: 0.48, green: 0.25, blue: 0.63)   // 紫
        case .personal:   return Color(red: 0.69, green: 0.35, blue: 0.13)   // 橙棕
        case .other:      return Color(.systemGray)
        }
    }

    var symbol: String {
        switch self {
        case .compulsory: return "checkmark.shield.fill"
        case .commercial: return "shield.lefthalf.filled"
        case .passenger:  return "person.2.fill"
        case .personal:   return "figure.walk"
        case .other:      return "doc.text.fill"
        }
    }

    /// 是否属于法定强制险
    var isMandatory: Bool { self == .compulsory }
}

extension Urgency {
    var tint: Color {
        switch self {
        case .expired: return Color(red: 0.72, green: 0.16, blue: 0.12)
        case .urgent:  return Color(red: 0.85, green: 0.35, blue: 0.05)
        case .soon:    return Color(red: 0.72, green: 0.53, blue: 0.04)
        case .normal:  return Color(red: 0.07, green: 0.44, blue: 0.25)
        }
    }

    var symbol: String {
        switch self {
        case .expired: return "exclamationmark.triangle.fill"
        case .urgent:  return "exclamationmark.circle.fill"
        case .soon:    return "clock.fill"
        case .normal:  return "checkmark.shield.fill"
        }
    }

    /// 保险提醒行专用图标：始终是「盾牌」语义，仅在已过期/紧急时换成警示盾牌
    var policySymbol: String {
        switch self {
        case .expired, .urgent: return "exclamationmark.shield.fill"
        case .soon, .normal:    return "shield.fill"
        }
    }
}

extension MaintenanceStatus {
    var tint: Color {
        switch self {
        case .overdue: return Color(red: 0.72, green: 0.16, blue: 0.12)
        case .soon:    return Color(red: 0.85, green: 0.35, blue: 0.05)
        case .normal:  return Color(red: 0.07, green: 0.44, blue: 0.25)
        case .unknown: return Color(.systemGray)
        }
    }

    var symbol: String {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .soon:    return "clock.fill"
        case .normal:  return "wrench.and.screwdriver.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension InspectionStatus {
    var tint: Color {
        switch self {
        case .overdue: return Color(red: 0.72, green: 0.16, blue: 0.12)
        case .soon:    return Color(red: 0.85, green: 0.35, blue: 0.05)
        case .normal:  return Color(red: 0.07, green: 0.44, blue: 0.25)
        case .unknown: return Color(.systemGray)
        }
    }

    var symbol: String {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .soon:    return "exclamationmark.circle.fill"
        case .normal:  return "checkmark.seal.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
