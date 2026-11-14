import SwiftUI
import SwiftData

/// 年检 Tab：按车辆汇总年检状态
struct InspectionListView: View {
    @Query(sort: \Vehicle.plate) private var vehicles: [Vehicle]

    /// 调试用：启动参数 -startInspect <车牌> 直接进入该车年检详情
    @State private var target: Vehicle?

    /// 先按状态紧急度，再按剩余天数
    private var sorted: [Vehicle] {
        vehicles.sorted {
            let a = $0.inspectionPlan.status.order
            let b = $1.inspectionPlan.status.order
            if a != b { return a < b }
            let da = $0.inspectionPlan.daysLeft ?? 99999
            let db = $1.inspectionPlan.daysLeft ?? 99999
            if da != db { return da < db }
            return $0.plate < $1.plate
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if vehicles.isEmpty {
                    EmptyHint(icon: "checkmark.seal",
                              title: "还没有车辆",
                              subtitle: "到「车辆」页添加车辆后，这里会自动出现年检提醒")
                } else {
                    Section {
                        ForEach(sorted) { vehicle in
                            NavigationLink {
                                InspectionDetailView(vehicle: vehicle)
                            } label: {
                                InspectionSummaryRow(vehicle: vehicle)
                            }
                        }
                    } footer: {
                        Text("9 座以下非营运小客车与摩托车：10 年内每 2 年检验 1 次，第 6、10 年上线，其余免上线只申领标志；超过 10 年每年上线 1 次。")
                    }
                }
            }
            .navigationTitle("年检")
            .navigationDestination(item: $target) { vehicle in
                InspectionDetailView(vehicle: vehicle)
            }
            .onAppear {
                guard let plate = UserDefaults.standard.string(forKey: "startInspect") else { return }
                target = vehicles.first { $0.plate == plate }
            }
        }
    }
}

/// 年检列表行
struct InspectionSummaryRow: View {
    let vehicle: Vehicle

    private var plan: InspectionPlan { vehicle.inspectionPlan }

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
                InspectionBadge(status: plan.status)
            }

            HStack(spacing: 6) {
                Text("有效期止")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                Text(plan.validUntil?.shortDateText ?? "未录入")
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text(plan.remainText)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(plan.status.tint)
                    .monospacedDigit()
            }

            Text(plan.stageText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

/// 年检状态徽标
struct InspectionBadge: View {
    let status: InspectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(status.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(status.tint)
        .background(status.tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
