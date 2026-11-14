import SwiftUI
import SwiftData

/// 保养 Tab：按车辆汇总保养状态
struct MaintenanceListView: View {
    @Query(sort: \Vehicle.plate) private var vehicles: [Vehicle]

    /// 调试用：启动参数 -startMaint <车牌> 直接进入该车保养详情
    @State private var target: Vehicle?

    var body: some View {
        NavigationStack {
            List {
                if vehicles.isEmpty {
                    EmptyHint(icon: "wrench.and.screwdriver",
                              title: "还没有车辆",
                              subtitle: "到「车辆」页添加车辆后，这里会自动出现保养提醒")
                } else {
                    Section {
                        ForEach(vehicles) { vehicle in
                            NavigationLink {
                                MaintenanceDetailView(vehicle: vehicle)
                            } label: {
                                MaintenanceSummaryRow(vehicle: vehicle)
                            }
                        }
                    } footer: {
                        Text("保养提醒按「上次保养 + 周期」推算，时间与里程分别计算，先到的一项先提醒。")
                    }
                }
            }
            .navigationTitle("保养")
            .navigationDestination(item: $target) { vehicle in
                MaintenanceDetailView(vehicle: vehicle)
            }
            .onAppear {
                guard let plate = UserDefaults.standard.string(forKey: "startMaint") else { return }
                target = vehicles.first { $0.plate == plate }
            }
        }
    }
}

/// 保养总览行
struct MaintenanceSummaryRow: View {
    let vehicle: Vehicle

    private var plan: MaintenancePlan { vehicle.maintenancePlan }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vehicle.plate)
                    .font(.system(size: 16, weight: .semibold))
                if !vehicle.modelName.isEmpty {
                    Text(vehicle.modelName)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                MaintenanceBadge(status: plan.status)
            }

            HStack(spacing: 6) {
                Text("下次")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Text(plan.nextText)
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text(plan.shortRemain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(plan.status.tint)
            }

            HStack(spacing: 6) {
                Text(lastLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("共 \(vehicle.maintenanceRecords.count) 条")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            if !vehicle.maintenanceNote.isEmpty {
                Text(vehicle.maintenanceNote)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private var lastLine: String {
        guard let last = plan.lastRecord else { return "暂无保养记录" }
        var text = "上次 \(last.date.shortDateText)"
        if let km = last.mileage { text += " · \(km) km" }
        return text
    }
}
