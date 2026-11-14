import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Query(sort: \Vehicle.plate) private var vehicles: [Vehicle]
    @Query(sort: \Policy.endDate) private var policies: [Policy]
    @Environment(\.modelContext) private var context

    /// 调试用：通过启动参数 -startReminder <车牌> 直接进入待办详情
    @State private var reminderTarget: Vehicle?

    /// 未过期保单，按紧迫程度排序
    private var upcoming: [Policy] {
        policies.filter { !$0.hasExpired }
            .sorted { $0.endDate < $1.endDate }
    }

    /// 60 天内到期，进预警区
    private var expiringSoon: [Policy] {
        upcoming.filter { $0.daysRemaining <= 60 }
    }

    /// 按车辆聚合后的待办，顺序按该车最早到期日
    private var reminderGroups: [VehicleReminder] {
        var bucket: [String: [Policy]] = [:]
        var plateOrder: [String] = []
        for policy in expiringSoon {
            guard let vehicle = policy.vehicle else { continue }
            if bucket[vehicle.plate] == nil { plateOrder.append(vehicle.plate) }
            bucket[vehicle.plate, default: []].append(policy)
        }
        return plateOrder.compactMap { plate in
            guard let list = bucket[plate], let vehicle = list.first?.vehicle else { return nil }
            return VehicleReminder(vehicle: vehicle, policies: list.sorted(by: Policy.reminderOrder))
        }
    }

    private var nextRenewalDays: Int {
        vehicles.map(\.renewalCountdown).min() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink {
                        heroDestination
                    } label: {
                        heroCard
                    }
                    .buttonStyle(.plain)
                    .disabled(vehicles.isEmpty)

                    // 三块提醒按「离到期最近」排序，最近的在最上面，与顶部大头卡一致
                    ForEach(orderedBlocks) { block in
                        switch block {
                        case .insurance:
                            if expiringSoon.isEmpty {
                                insuranceAllClearCard
                            } else {
                                warningSection
                            }
                        case .maintenance:
                            if !vehicles.isEmpty { maintenanceSection }
                        case .inspection:
                            if !vehicles.isEmpty { inspectionSection }
                        }
                    }

                    vehicleSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 84)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("车管家")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $reminderTarget) { vehicle in
                ReminderDetailView(vehicle: vehicle)
            }
            .onAppear {
                guard let plate = UserDefaults.standard.string(forKey: "startReminder") else { return }
                reminderTarget = vehicles.first { $0.plate == plate }
            }
            .task {
                NotificationManager.shared.reschedule(policies: policies, vehicles: vehicles)
            }
        }
    }

    private var insuranceAllClearCard: some View {
        SectionCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.07, green: 0.44, blue: 0.25))
                VStack(alignment: .leading, spacing: 2) {
                    Text("60 天内没有到期保单")
                        .font(.system(size: 14, weight: .semibold))
                    Text("两车保障都在有效期内")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - 顶部大头卡：最近要做的一件事

    /// 没有数据时用的「很远」，保证这类提醒排在最后
    private let farFuture = 99999

    /// 三块提醒的先后：谁离到期最近谁在上
    private var orderedBlocks: [ReminderBlock] {
        ReminderBlock.allCases.sorted { lhs, rhs in
            let l = blockDays(lhs)
            let r = blockDays(rhs)
            if l != r { return l < r }
            return lhs.rawValue < rhs.rawValue
        }
    }

    private func blockDays(_ block: ReminderBlock) -> Int {
        switch block {
        case .insurance:
            // 用全部未过期保单的最早止期，避免「60 天内没有到期」时排序失真
            return upcoming.map(\.daysRemaining).min() ?? farFuture

        case .maintenance:
            let days = vehicles.map { vehicle -> Int in
                let plan = vehicle.maintenancePlan
                // 里程先到视为今天到期，优先于还有多少天
                if let km = plan.kmLeft, km <= 0 { return 0 }
                return plan.daysLeft ?? farFuture
            }
            return days.min() ?? farFuture

        case .inspection:
            return vehicles.compactMap { $0.inspectionPlan.daysLeft }.min() ?? farFuture
        }
    }

    /// 全部候选中最近的一件事（保险 / 保养 / 年检各算一个候选）
    private var nextAction: NextAction? {
        var candidates: [NextAction] = []

        for vehicle in vehicles {
            if let policy = vehicle.nearestPolicy {
                candidates.append(
                    NextAction(kind: .policy,
                               vehicle: vehicle,
                               dateText: policy.endDate.monthDaySimpleText,
                               subtitle: "\(vehicle.plate) · \(policy.kind.rawValue)",
                               valueText: "\(abs(policy.daysRemaining))",
                               unitText: policy.daysRemaining < 0 ? "天前到期" : "天后",
                               sortDays: policy.daysRemaining,
                               caption: policyCaption(policy.kind),
                               symbol: policy.kind.symbol)
                )
            }

            let maint = vehicle.maintenancePlan
            if maint.nextDate != nil || maint.nextMileage != nil {
                var caption = maint.ruleText
                if let km = maint.kmLeft {
                    caption += km <= 0 ? " · 已超 \(abs(km)) km" : " · 还差 \(km) km"
                }

                let value: String
                let unit: String
                if let days = maint.daysLeft {
                    value = "\(abs(days))"
                    unit = days < 0 ? "天前到期" : "天后"
                } else if let km = maint.kmLeft {
                    value = "\(abs(km))"
                    unit = km < 0 ? "km 已超" : "km 后"
                } else {
                    value = "—"
                    unit = ""
                }

                let mileageFirst = maint.kmLeft.map { $0 <= 0 } ?? false
                candidates.append(
                    NextAction(kind: .maintenance,
                               vehicle: vehicle,
                               dateText: maint.nextDate?.monthDaySimpleText
                                   ?? maint.nextMileage.map { "\($0) km" }
                                   ?? "未设置",
                               subtitle: "\(vehicle.plate) · 保养",
                               valueText: value,
                               unitText: unit,
                               sortDays: mileageFirst ? 0 : (maint.daysLeft ?? farFuture),
                               caption: caption,
                               symbol: "wrench.and.screwdriver.fill")
                )
            }

            let inspection = vehicle.inspectionPlan
            if let valid = inspection.validUntil {
                let days = inspection.daysLeft
                candidates.append(
                    NextAction(kind: .inspection,
                               vehicle: vehicle,
                               dateText: valid.monthDaySimpleText,
                               subtitle: "\(vehicle.plate) · 年检",
                               valueText: days.map { "\(abs($0))" } ?? "—",
                               unitText: days.map { $0 < 0 ? "天前到期" : "天后" } ?? "",
                               sortDays: days ?? farFuture,
                               caption: "\(inspection.action?.label ?? "年检") · 有效期止前 3 个月可办",
                               symbol: "checkmark.seal.fill")
                )
            }
        }

        return candidates.min { $0.sortDays < $1.sortDays }
    }

    private func policyCaption(_ kind: PolicyKind) -> String {
        switch kind {
        case .compulsory:            return "交强险不能断保，提前出单最稳"
        case .commercial:            return "商业险可留几天空窗，提前出单最稳"
        case .passenger, .personal:  return "意外险到期即失效，建议提前续保"
        case .other:                 return "保障到期即失效，建议提前续保"
        }
    }

    private var heroCard: some View {        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(nextAction?.subtitle ?? "续保日",
                          systemImage: nextAction?.symbol ?? "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(nextAction?.dateText ?? renewalDateText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(heroValueText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(heroUnitText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Divider().overlay(.white.opacity(0.25))

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(heroCaption)
                    .font(.system(size: 11))
                    .lineLimit(2)
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.38, blue: 0.84),
                         Color(red: 0.10, green: 0.55, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heroValueText: String {
        if let action = nextAction { return action.valueText }
        return vehicles.isEmpty ? "—" : "\(max(nextRenewalDays, 0))"
    }

    private var heroUnitText: String {
        if let action = nextAction { return action.unitText }
        return vehicles.isEmpty ? "" : "天后"
    }

    private var heroCaption: String {
        let renewal = "续保日 \(renewalDateText)"
        guard let action = nextAction else {
            return "交强险不可断保，商业险可留几天空窗 · \(renewal)"
        }
        return "\(action.caption) · \(renewal)"
    }

    @ViewBuilder
    private var heroDestination: some View {
        if let action = nextAction {
            switch action.kind {
            case .policy:      ReminderDetailView(vehicle: action.vehicle)
            case .maintenance: MaintenanceDetailView(vehicle: action.vehicle)
            case .inspection:  InspectionDetailView(vehicle: action.vehicle)
            }
        } else if let first = vehicles.first {
            VehicleDetailView(vehicle: first)
        } else {
            EmptyView()
        }
    }

    private var renewalDateText: String {
        guard let vehicle = vehicles.min(by: { $0.renewalCountdown < $1.renewalCountdown }) else {
            return "未设置"
        }
        return "\(vehicle.renewalMonth) 月 \(vehicle.renewalDay) 日"
    }

    // MARK: - 到期预警

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("保险提醒",
                          detail: "\(reminderGroups.count) 台车 · \(expiringSoon.count) 项")

            SectionCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(reminderGroups.enumerated()), id: \.element.id) { index, group in
                        NavigationLink {
                            ReminderDetailView(vehicle: group.vehicle)
                        } label: {
                            reminderRow(group)
                        }
                        .buttonStyle(.plain)

                        if index != reminderGroups.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    private func reminderRow(_ group: VehicleReminder) -> some View {
        let nearest = group.nearest
        let tint = nearest.urgency.tint
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: nearest.urgency.policySymbol)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.vehicle.plate)
                        .font(.system(size: 15, weight: .semibold))
                    if group.policies.count > 1 {
                        CountBadge(count: group.policies.count, tint: tint)
                    }
                    Spacer(minLength: 4)
                    UrgencyBadge(urgency: nearest.urgency)
                }

                HStack(spacing: 6) {
                    Text(group.kindSummary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(nearest.remainShortText)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - 保养提醒

    /// 保养待办顺序：先按状态紧急度，再按剩余天数
    private var maintenanceVehicles: [Vehicle] {
        vehicles.sorted {
            let a = $0.maintenancePlan.status.order
            let b = $1.maintenancePlan.status.order
            if a != b { return a < b }
            let da = $0.maintenancePlan.daysLeft ?? 9999
            let db = $1.maintenancePlan.daysLeft ?? 9999
            if da != db { return da < db }
            return $0.plate < $1.plate
        }
    }

    private var maintenanceSection: some View {
        let list = maintenanceVehicles
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("保养提醒", detail: "\(list.count) 台车")

            SectionCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.plate) { index, vehicle in
                        NavigationLink {
                            MaintenanceDetailView(vehicle: vehicle)
                        } label: {
                            maintenanceRow(vehicle)
                        }
                        .buttonStyle(.plain)

                        if index != list.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    private func maintenanceRow(_ vehicle: Vehicle) -> some View {
        let plan = vehicle.maintenancePlan
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(plan.status.tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: plan.status.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(plan.status.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(vehicle.plate)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 4)
                    MaintenanceBadge(status: plan.status)
                }

                HStack(spacing: 6) {
                    Text(plan.nextText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(plan.shortRemain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(plan.status.tint)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - 年检提醒

    /// 年检待办顺序：先按状态紧急度，再按剩余天数
    private var inspectionVehicles: [Vehicle] {
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

    private var inspectionSection: some View {
        let list = inspectionVehicles
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("年检提醒", detail: "\(list.count) 台车")

            SectionCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.plate) { index, vehicle in
                        NavigationLink {
                            InspectionDetailView(vehicle: vehicle)
                        } label: {
                            inspectionRow(vehicle)
                        }
                        .buttonStyle(.plain)

                        if index != list.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    private func inspectionRow(_ vehicle: Vehicle) -> some View {
        let plan = vehicle.inspectionPlan
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(plan.status.tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: plan.status.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(plan.status.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(vehicle.plate)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 4)
                    InspectionBadge(status: plan.status)
                }

                HStack(spacing: 6) {
                    Text(plan.shortSummaryText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(plan.remainText)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(plan.status.tint)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - 车辆

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("我的车辆", detail: "\(vehicles.count) 台")

            if vehicles.isEmpty {
                SectionCard {
                    EmptyHint(icon: "car", title: "还没有车辆", subtitle: "到「车辆」页添加你的第一台车")
                }
            } else {
                ForEach(vehicles) { vehicle in
                    NavigationLink {
                        VehicleDetailView(vehicle: vehicle)
                    } label: {
                        vehicleCard(vehicle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        SectionCard(padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(vehicle.plate)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(vehicle.activePolicies.count) 份在保")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(vehicle.modelName.isEmpty ? "未填写车型" : vehicle.modelName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, -8)

                if let nearest = vehicle.nearestPolicy {
                    HStack(spacing: 8) {
                        KindBadge(kind: nearest.kind)
                        Text("最近到期 \(nearest.endDate.shortDateText)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        DaysBadge(policy: nearest)
                    }
                    PolicyProgressBar(progress: nearest.progress, tint: nearest.urgency.tint)
                } else {
                    Text("没有有效保单")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.12))
                }

                HStack(spacing: 18) {
                    metric("年度保费", String(format: "¥%.0f", vehicle.currentYearPremium))
                    metric("历史保单", "\(vehicle.historyPolicies.count) 份")
                    metric("续保倒计时", "\(vehicle.renewalCountdown) 天")
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}

/// 同一辆车的待办聚合
struct VehicleReminder: Identifiable {
    let vehicle: Vehicle
    /// 已按止期升序
    let policies: [Policy]

    var id: String { vehicle.plate }

    var nearest: Policy { policies[0] }

    /// 险种摘要，按紧急程度排序
    var kindSummary: String {
        let kinds = policies.map { $0.kind.rawValue }
        var seen: [String] = []
        for kind in kinds where !seen.contains(kind) { seen.append(kind) }
        return seen.joined(separator: "、")
    }
}

/// 首页的三块提醒，渲染顺序按各自最近的到期时间动态调整
enum ReminderBlock: Int, CaseIterable, Identifiable {
    case insurance
    case maintenance
    case inspection

    var id: Int { rawValue }
}

/// 顶部大头卡展示的「最近一件事」
struct NextAction {
    enum Kind {
        case policy
        case maintenance
        case inspection
    }

    let kind: Kind
    let vehicle: Vehicle
    /// 主标题，例如「11 月 29 日」
    let dateText: String
    /// 上方小标签，例如「京A12345 · 交强险」
    let subtitle: String
    let valueText: String
    let unitText: String
    /// 排序用的剩余天数，越小越近
    let sortDays: Int
    /// 底部一句话提示
    let caption: String
    let symbol: String
}
