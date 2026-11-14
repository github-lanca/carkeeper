import SwiftUI
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var vehicle: Vehicle

    @State private var showingAddPolicy = false
    @State private var showingEditVehicle = false
    @State private var showingInspection = false
    @State private var editingPolicy: Policy?

    private var inspectionPlan: InspectionPlan { vehicle.inspectionPlan }

    private var active: [Policy] {
        vehicle.activePolicies.sorted { $0.kind.order < $1.kind.order }
    }

    private var upcoming: [Policy] {
        vehicle.policies
            .filter { $0.isNotStarted }
            .sorted { $0.startDate < $1.startDate }
    }

    private var history: [Policy] {
        vehicle.historyPolicies
            .sorted { $0.endDate > $1.endDate }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(vehicle.plate)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(vehicle.renewalMonth) 月 \(vehicle.renewalDay) 日续保")
                            .font(.system(size: 11.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.04, green: 0.38, blue: 0.84).opacity(0.12))
                            .foregroundStyle(Color(red: 0.04, green: 0.38, blue: 0.84))
                            .clipShape(Capsule())
                    }

                    if !vehicle.modelName.isEmpty {
                        Text(vehicle.modelName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 22) {
                        infoItem("注册日期", vehicle.registerDate.shortDateText)
                        infoItem("里程", vehicle.currentMileage > 0 ? "\(vehicle.currentMileage) km" : "未填")
                        infoItem("年度保费", String(format: "¥%.0f", vehicle.currentYearPremium))
                    }
                }
                .padding(.vertical, 6)
            }

            Section("年检") {
                Button {
                    showingInspection = true
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text("检验有效期止")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(inspectionPlan.validUntil?.shortDateText ?? "未录入")
                                .font(.system(size: 13.5, weight: .semibold))
                                .monospacedDigit()
                            InspectionBadge(status: inspectionPlan.status)
                        }

                        HStack(spacing: 6) {
                            Text(inspectionPlan.stageText)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(inspectionPlan.remainText)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(inspectionPlan.status.tint)
                                .monospacedDigit()
                        }

                        Text(inspectionPlan.specText)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }

            if !active.isEmpty {
                Section("在保（\(active.count)）") {
                    ForEach(active, id: \.uid) { policy in
                        Button {
                            editingPolicy = policy
                        } label: {
                            PolicyRow(policy: policy)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(policy)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !upcoming.isEmpty {
                Section("待生效（\(upcoming.count)）") {
                    ForEach(upcoming, id: \.uid) { policy in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                KindBadge(kind: policy.kind)
                                Spacer()
                                Text("\(policy.startDate.shortDateText) 起")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(policy.startDate.shortDateText) → \(policy.endDate.shortDateText)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !history.isEmpty {
                Section("历史保单（\(history.count)）") {
                    ForEach(history, id: \.uid) { policy in
                        HStack(spacing: 8) {
                            KindBadge(kind: policy.kind)
                            Text("\(policy.startDate.shortDateText) → \(policy.endDate.shortDateText)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(policy.premium > 0 ? String(format: "¥%.0f", policy.premium) : "")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(policy)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("保养") {
                NavigationLink {
                    MaintenanceDetailView(vehicle: vehicle)
                } label: {
                    HStack {
                        Label("保养记录", systemImage: "wrench.and.screwdriver")
                        Spacer()
                        Text("\(vehicle.maintenanceRecords.count) 条")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    showingAddPolicy = true
                } label: {
                    Label("新增保单", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(vehicle.plate)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 56)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEditVehicle = true }
            }
        }
        .sheet(isPresented: $showingAddPolicy) {
            PolicyEditView(vehicle: vehicle, editing: nil)
        }
        .sheet(item: $editingPolicy) { policy in
            PolicyEditView(vehicle: vehicle, editing: policy)
        }
        .sheet(isPresented: $showingEditVehicle) {
            VehicleEditView(vehicle: vehicle)
        }
        .sheet(isPresented: $showingInspection) {
            InspectionSheetView(vehicle: vehicle)
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "openAddPolicy") {
                showingAddPolicy = true
            }
            if UserDefaults.standard.bool(forKey: "openEditVehicle") {
                showingEditVehicle = true
            }
            if UserDefaults.standard.bool(forKey: "openInspection") {
                showingInspection = true
            }
            // 进入可办理窗口（90 天内）或已过期时，自动弹出年检信息
            if inspectionPlan.status == .soon || inspectionPlan.status == .overdue {
                showingInspection = true
            }
        }
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

    private func delete(_ policy: Policy) {
        context.delete(policy)
        try? context.save()
        NotificationManager.shared.cancelAll()
        let all = (try? context.fetch(FetchDescriptor<Policy>())) ?? []
        let allVehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        NotificationManager.shared.reschedule(policies: all, vehicles: allVehicles)
    }
}
