import SwiftUI
import SwiftData

/// 单台车的保养计划与保养记录
struct MaintenanceDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var vehicle: Vehicle

    @State private var editingRecord: MaintenanceRecord?
    @State private var showingAdd = false

    private var plan: MaintenancePlan { vehicle.maintenancePlan }

    /// 记录按日期升序编号，展示时倒序
    private var numbered: [(index: Int, record: MaintenanceRecord)] {
        vehicle.sortedMaintenance.enumerated().map { (index: $0.offset + 1, record: $0.element) }
    }

    var body: some View {
        List {
            Section {
                header
            }

            Section {
                if let nextDate = plan.nextDate {
                    dueRow(title: "时间",
                           value: nextDate.shortDateText,
                           detail: plan.daysLeft.map { $0 < 0 ? "已超 \(abs($0)) 天" : "还有 \($0) 天" } ?? "",
                           status: plan.status)
                }
                if let nextMileage = plan.nextMileage {
                    dueRow(title: "里程",
                           value: "\(nextMileage) km",
                           detail: plan.kmLeft.map { $0 <= 0 ? "已超 \(abs($0)) km" : "还差 \($0) km" } ?? "",
                           status: plan.status)
                }
                if plan.nextDate == nil && plan.nextMileage == nil {
                    Text("还没有设置保养周期，点右上角「编辑」补充")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("下次保养")
            } footer: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.ruleText)
                    Text("按最新里程 " + String(vehicle.latestMaintenanceMileage) + " km 计算")
                }
            }

            Section {
                if numbered.isEmpty {
                    Text("还没有保养记录")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(numbered, id: \.record.uid) { item in
                        Button {
                            editingRecord = item.record
                        } label: {
                            recordRow(no: item.index, record: item.record)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(item.record)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("保养记录（\(vehicle.maintenanceRecords.count)）")
                    Spacer()
                    if vehicle.maintenanceTotalCost > 0 {
                        Text(String(format: "累计 ¥%.0f", vehicle.maintenanceTotalCost))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("点记录可修改，左滑删除。记录里的里程会自动更新该车的最新里程。")
            }

            Section {
                Button {
                    showingAdd = true
                } label: {
                    Label("新增保养记录", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(vehicle.plate)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 56)
        }
        .sheet(isPresented: $showingAdd) {
            MaintenanceEditView(vehicle: vehicle, editing: nil)
        }
        .sheet(item: $editingRecord) { record in
            MaintenanceEditView(vehicle: vehicle, editing: record)
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "openAddMaint") {
                showingAdd = true
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vehicle.plate)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                MaintenanceBadge(status: plan.status)
            }

            if !vehicle.modelName.isEmpty {
                Text(vehicle.modelName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                infoItem("购车日期", (vehicle.purchaseDate ?? vehicle.registerDate).shortDateText)
                infoItem("最近保养", plan.lastRecord?.date.shortDateText ?? "—")
                infoItem("保养次数", "\(vehicle.maintenanceRecords.count) 次")
            }

            if !vehicle.maintenanceNote.isEmpty {
                Text(vehicle.maintenanceNote)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private func infoItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
        }
    }

    private func dueRow(title: String, value: String, detail: String, status: MaintenanceStatus) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(status.tint)
                    .monospacedDigit()
            }
        }
    }

    private func recordRow(no: Int, record: MaintenanceRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", no))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .leading)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.item.isEmpty ? "保养" : record.item)
                        .font(.system(size: 13.5, weight: .medium))
                    Spacer()
                    if record.cost > 0 {
                        Text(String(format: "¥%.0f", record.cost))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text("\(record.date.shortDateText) · \(record.mileage.map { "\($0) km" } ?? "里程未记录")")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func delete(_ record: MaintenanceRecord) {
        context.delete(record)
        try? context.save()
        NotificationManager.shared.reschedule(policies: allPolicies(), vehicles: allVehicles())
    }

    private func allPolicies() -> [Policy] {
        (try? context.fetch(FetchDescriptor<Policy>())) ?? []
    }

    private func allVehicles() -> [Vehicle] {
        (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
    }
}
