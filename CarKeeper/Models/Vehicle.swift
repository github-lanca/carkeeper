import Foundation
import SwiftData

/// 车辆档案
@Model
final class Vehicle {
    var plate: String            // 车牌号
    var modelName: String        // 车型描述
    var vin: String              // 车架号
    var registerDate: Date       // 注册登记日期
    var currentMileage: Int      // 当前里程 km
    var renewalMonth: Int        // 统一续保日 - 月
    var renewalDay: Int          // 统一续保日 - 日
    var note: String
    var createdAt: Date

    // MARK: 保养参数
    /// 购车日期（与注册登记日期区分，保养周期从这天起算）
    var purchaseDate: Date? = nil
    /// 时间周期（月），0 表示不按时间
    var maintenanceIntervalMonths: Int = 0
    /// 里程周期（km），0 表示不按里程
    var maintenanceIntervalKm: Int = 0
    /// 周期说明，例如「每半年或 5000 公里保养一次」
    var maintenanceNote: String = ""

    // MARK: 年检参数
    /// 车辆类型（决定年检周期），见 InspectionCategory
    var inspectionCategoryRaw: String = InspectionCategory.car.rawValue
    /// 检验有效期止
    var inspectionValidUntil: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \Policy.vehicle)
    var policies: [Policy] = []

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.vehicle)
    var maintenanceRecords: [MaintenanceRecord] = []

    init(plate: String,
         modelName: String = "",
         vin: String = "",
         registerDate: Date = Date(),
         currentMileage: Int = 0,
         renewalMonth: Int = 12,
         renewalDay: Int = 12,
         note: String = "") {
        self.plate = plate
        self.modelName = modelName
        self.vin = vin
        self.registerDate = registerDate
        self.currentMileage = currentMileage
        self.renewalMonth = renewalMonth
        self.renewalDay = renewalDay
        self.note = note
        self.createdAt = Date()
    }

    /// 当前仍在保的保单
    var activePolicies: [Policy] {
        policies.filter { $0.isActive }.sorted { $0.endDate < $1.endDate }
    }

    /// 已过期的保单（历史记录）
    var historyPolicies: [Policy] {
        policies.filter { $0.hasExpired }.sorted { $0.endDate > $1.endDate }
    }

    /// 最紧迫的一份保单（未过期里到期最近的；同一天到期时交强险优先）
    var nearestPolicy: Policy? {
        policies.filter { !$0.hasExpired }.sorted(by: Policy.reminderOrder).first
    }

    /// 统一续保日（今年的，若已过则顺延到明年）
    var nextRenewalDate: Date {
        let cal = Calendar.current
        let now = Date()
        var comps = DateComponents()
        comps.year = cal.component(.year, from: now)
        comps.month = renewalMonth
        comps.day = renewalDay
        guard let thisYear = cal.date(from: comps) else { return now }
        if thisYear.startOfDay < now.startOfDay {
            return cal.date(byAdding: .year, value: 1, to: thisYear) ?? thisYear
        }
        return thisYear
    }

    var renewalCountdown: Int { nextRenewalDate.daysFromToday }

    /// 本年度总保费
    var currentYearPremium: Double {
        activePolicies.reduce(0) { $0 + $1.premium }
    }

    // MARK: - 保养

    /// 保养记录按日期升序
    var sortedMaintenance: [MaintenanceRecord] {
        maintenanceRecords.sorted { $0.date < $1.date }
    }

    /// 最近一次保养
    var lastMaintenance: MaintenanceRecord? { sortedMaintenance.last }

    /// 最新已知里程：记录里的最大里程与手填里程取大者
    var latestMaintenanceMileage: Int {
        let fromRecords = maintenanceRecords.compactMap { $0.mileage }.max() ?? 0
        return max(fromRecords, currentMileage)
    }

    /// 保养累计花费
    var maintenanceTotalCost: Double {
        maintenanceRecords.reduce(0) { $0 + $1.cost }
    }

    /// 保养计划（下次时间/里程、状态）
    var maintenancePlan: MaintenancePlan { MaintenancePlan(vehicle: self) }

    // MARK: - 年检

    var inspectionCategory: InspectionCategory {
        get { InspectionCategory(rawValue: inspectionCategoryRaw) ?? .car }
        set { inspectionCategoryRaw = newValue.rawValue }
    }

    /// 年检计划（规格、下次日期、状态）
    var inspectionPlan: InspectionPlan { InspectionPlan(vehicle: self) }
}
