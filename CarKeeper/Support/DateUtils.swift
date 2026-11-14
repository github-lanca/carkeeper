import Foundation

extension Date {
    /// 用固定年月日时分构造日期，避免依赖字面量解析的区域设置差异
    static func make(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    /// 距今天数（按自然日计算，今天到期为 0，已过期为负数）
    var daysFromToday: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: Date().startOfDay, to: self.startOfDay).day ?? 0
    }

    var monthDayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: self)
    }

    /// 只到月日，例如「12 月 12 日」，首页大头卡用
    var monthDaySimpleText: String {
        let cal = Calendar.current
        let month = cal.component(.month, from: self)
        let day = cal.component(.day, from: self)
        return "\(month) 月 \(day) 日"
    }

    var shortDateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    var fullText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: self)
    }
}

enum Urgency {
    case expired      // 已过期
    case urgent       // 7 天内
    case soon         // 30 天内
    case normal       // 30 天以上

    var label: String {
        switch self {
        case .expired: return "已过期"
        case .urgent:  return "即将到期"
        case .soon:    return "临近到期"
        case .normal:  return "在保"
        }
    }
}

func urgencyLevel(forDays days: Int) -> Urgency {
    if days < 0 { return .expired }
    if days <= 7 { return .urgent }
    if days <= 30 { return .soon }
    return .normal
}
