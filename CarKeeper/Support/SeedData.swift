import Foundation
import SwiftData

/// 首次启动时写入两台演示车辆及其在保保单
/// 注意：这里全部是示例数据，车牌、保单号均为占位值，真实用户数据只存在各自设备本地
enum SeedData {

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Vehicle>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // MARK: 京A12345（5 座客车，演示数据）
        let yu = Vehicle(
            plate: "京A12345",
            modelName: "5 座客车 · 排量 1.498L",
            registerDate: .make(2019, 12, 16),
            renewalMonth: 12,
            renewalDay: 12,
            note: "本年度：交强险 12-13 到期，商业险与驾乘险 11-29 到期"
        )
        context.insert(yu)

        let yuPolicies: [Policy] = [
            Policy(
                kind: .compulsory,
                policyNumber: "PDZA000000000000000001",
                startDate: .make(2025, 12, 13, 16, 0),
                endDate: .make(2026, 12, 13, 16, 0),
                premium: 665
            ),
            Policy(
                kind: .commercial,
                startDate: .make(2025, 11, 30, 0, 0),
                endDate: .make(2026, 11, 29, 23, 59),
                premium: 1402.73
            ),
            Policy(
                kind: .passenger,
                startDate: .make(2025, 11, 30, 0, 0),
                endDate: .make(2026, 11, 29, 23, 59),
                premium: 520
            )
        ]
        for policy in yuPolicies {
            context.insert(policy)
            policy.vehicle = yu
        }

        // MARK: 沪C67890（摩托车，演示数据）
        let chuan = Vehicle(
            plate: "沪C67890",
            modelName: "摩托车 · 排量 149cc",
            registerDate: .make(2023, 8, 8),
            renewalMonth: 12,
            renewalDay: 12,
            note: "本年度三险同日到期，适合作为统一续保锚点"
        )
        context.insert(chuan)

        let chuanPolicies: [Policy] = [
            Policy(
                kind: .compulsory,
                startDate: .make(2025, 12, 12, 0, 0),
                endDate: .make(2026, 12, 11, 23, 59),
                premium: 120
            ),
            Policy(
                kind: .commercial,
                startDate: .make(2025, 12, 12, 0, 0),
                endDate: .make(2026, 12, 11, 23, 59),
                premium: 121.33
            ),
            Policy(
                kind: .personal,
                startDate: .make(2025, 12, 12, 0, 0),
                endDate: .make(2026, 12, 11, 23, 59),
                premium: 200
            )
        ]
        for policy in chuanPolicies {
            context.insert(policy)
            policy.vehicle = chuan
        }

        try? context.save()
    }

    /// 增量补种保养数据：已存在的车只补缺失的参数与记录，不覆盖用户改动
    static func seedMaintenanceIfNeeded(context: ModelContext) {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        guard !vehicles.isEmpty else { return }

        for vehicle in vehicles {
            switch vehicle.plate {
            case "京A12345":
                if vehicle.maintenanceIntervalMonths == 0 && vehicle.maintenanceIntervalKm == 0 {
                    vehicle.purchaseDate = .make(2019, 12, 13)
                    vehicle.maintenanceIntervalMonths = 6
                    vehicle.maintenanceIntervalKm = 5000
                    vehicle.maintenanceNote = "每半年或 5000 公里保养一次"
                }
                if vehicle.currentMileage == 0 { vehicle.currentMileage = 63960 }
                if vehicle.maintenanceRecords.isEmpty {
                    // 原始保养台账（2022-08 起），第 03 条里程在原始记录中就是空白的
                    let history: [(year: Int, month: Int, day: Int, mileage: Int?)] = [
                        (2022, 8, 14, 41549),
                        (2023, 2, 18, 46179),
                        (2023, 11, 18, nil),
                        (2025, 2, 9, 59038),
                        (2025, 9, 21, 60684),
                        (2026, 9, 26, 63960)
                    ]
                    for row in history {
                        let record = MaintenanceRecord(
                            date: .make(row.year, row.month, row.day),
                            mileage: row.mileage,
                            item: "常规保养",
                            note: row.mileage == nil ? "原始记录未填写里程" : ""
                        )
                        context.insert(record)
                        record.vehicle = vehicle
                    }
                }

            case "沪C67890":
                if vehicle.maintenanceIntervalMonths == 0 && vehicle.maintenanceIntervalKm == 0 {
                    vehicle.purchaseDate = .make(2023, 8, 8)
                    vehicle.maintenanceIntervalMonths = 0
                    vehicle.maintenanceIntervalKm = 3000
                    vehicle.maintenanceNote = "机油更换周期每 3000 公里"
                }
                if vehicle.currentMileage == 0 { vehicle.currentMileage = 5146 }
                if vehicle.maintenanceRecords.isEmpty {
                    let record = MaintenanceRecord(
                        date: .make(2025, 2, 15),
                        mileage: 5146,
                        item: "换机油"
                    )
                    context.insert(record)
                    record.vehicle = vehicle
                }

            default:
                continue
            }
        }

        try? context.save()
    }

    /// 增量补种年检数据：只填空白项，不覆盖用户改动
    static func seedInspectionIfNeeded(context: ModelContext) {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        guard !vehicles.isEmpty else { return }

        for vehicle in vehicles {
            switch vehicle.plate {
            case "京A12345":
                if vehicle.inspectionValidUntil == nil {
                    vehicle.inspectionCategory = .car
                    vehicle.inspectionValidUntil = .make(2027, 12, 31)
                }

            case "沪C67890":
                if vehicle.inspectionValidUntil == nil {
                    vehicle.inspectionCategory = .motorcycle
                    vehicle.inspectionValidUntil = .make(2027, 8, 31)
                }

            default:
                continue
            }
        }

        try? context.save()
    }
}
