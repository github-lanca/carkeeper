import SwiftUI
import SwiftData

/// 年检详情（从「年检」Tab 或车辆详情进入）
struct InspectionDetailView: View {
    @Bindable var vehicle: Vehicle

    var body: some View {
        InspectionContent(vehicle: vehicle, showsDoneButton: false)
            .navigationTitle(vehicle.plate)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// 年检信息弹窗（从车辆详情点「年检」弹出，或到期时自动弹出）
struct InspectionSheetView: View {
    @Bindable var vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InspectionContent(vehicle: vehicle, showsDoneButton: true) { dismiss() }
                .navigationTitle("年检")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}

/// 年检内容：检验规格 + 下一个检验日期
struct InspectionContent: View {
    @Bindable var vehicle: Vehicle
    var showsDoneButton: Bool = false
    var onDone: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @State private var editing = false

    private var plan: InspectionPlan { vehicle.inspectionPlan }

    var body: some View {
        List {
            Section {
                header
            }

            Section {
                infoRow("车辆类型", plan.specText)
                infoRow("检验周期", plan.periodText)
                if let action = plan.action {
                    infoRow("本次办理", action.label)
                    Text(action.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("检验规格")
            } footer: {
                Text("周期依据《机动车登记规定》与公安部年检新政：10 年内每 2 年检验 1 次，第 2、4、8 年免上线只申领标志，第 6、10 年上线检测；超过 10 年每年上线 1 次。")
            }

            Section {
                infoRow("检验有效期止", plan.validUntil?.shortDateText ?? "未录入", strong: true)
                infoRow("建议办理窗口", plan.windowText)
                if let next = plan.nextValidUntil, let nextAge = plan.nextAgeYears {
                    infoRow("下次有效期止", "\(next.shortDateText)（第 \(nextAge) 年，推算）")
                }
                if plan.status == .unknown {
                    Text("还没有录入检验有效期，可以对照行驶证副页或「交管12123」填写")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("下一个检验日期")
            } footer: {
                Text("可在检验有效期满前 3 个月内办理，提前办不浪费周期。")
            }

            Section {
                Button {
                    editing = true
                } label: {
                    Label("修改有效期与车辆类型", systemImage: "square.and.pencil")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: showsDoneButton ? 8 : 64)
        }
        .sheet(isPresented: $editing) {
            VehicleEditView(vehicle: vehicle)
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vehicle.plate)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                InspectionBadge(status: plan.status)
                Spacer()
            }

            if !vehicle.modelName.isEmpty {
                Text(vehicle.modelName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("距检验有效期止")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(bigCountdown)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(plan.status.tint)
                        .monospacedDigit()
                }
                Spacer()
                if let stage = plan.ageYears {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("检验节点")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                        Text("第 \(stage) 年")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }

            if plan.status == .soon || plan.status == .overdue {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11))
                    Text(plan.status == .overdue
                         ? "检验有效期已过，尽快办理，逾期上路会被处罚"
                         : "已进入可办理窗口，现在就能去办")
                        .font(.system(size: 11.5))
                }
                .foregroundStyle(plan.status.tint)
            }
        }
        .padding(.vertical, 6)
    }

    private var bigCountdown: String {
        guard let days = plan.daysLeft else { return "未录入" }
        if days < 0 { return "已过期 \(abs(days)) 天" }
        if days == 0 { return "今天到期" }
        return "还剩 \(days) 天"
    }

    private func infoRow(_ title: String, _ value: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: strong ? 13.5 : 13, weight: strong ? .semibold : .regular))
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}
