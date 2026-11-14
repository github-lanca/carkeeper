import SwiftUI
import SwiftData

/// 单台车的待办到期明细
struct ReminderDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var vehicle: Vehicle

    @State private var editingPolicy: Policy?

    /// 60 天内到期的保单，按止期升序
    private var items: [Policy] {
        vehicle.policies
            .filter { !$0.hasExpired && $0.daysRemaining <= 60 }
            .sorted(by: Policy.reminderOrder)
    }

    private var tint: Color {
        items.first?.urgency.tint ?? Color(red: 0.07, green: 0.44, blue: 0.25)
    }

    var body: some View {
        List {
            Section {
                header
            }

            if items.isEmpty {
                Section {
                    EmptyHint(icon: "checkmark.seal.fill",
                              title: "60 天内没有到期保单",
                              subtitle: "这辆车的保障都在有效期内")
                }
            } else {
                Section {
                    ForEach(items, id: \.uid) { policy in
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
                } header: {
                    Text("到期明细（\(items.count)）")
                } footer: {
                    Text("点任意一项可修改止期、保费，或直接续保。")
                }
            }

            Section {
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    Label("查看该车全部保单", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .navigationTitle("保险提醒")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 56)
        }
        .sheet(item: $editingPolicy) { policy in
            PolicyEditView(vehicle: vehicle, editing: policy)
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vehicle.plate)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if items.count > 1 {
                    CountBadge(count: items.count, tint: tint)
                }
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
                infoItem("最早到期", items.first?.endDate.shortDateText ?? "—")
                infoItem("涉及险种", "\(items.count) 项")
                infoItem("合计保费", String(format: "¥%.0f", items.reduce(0) { $0 + $1.premium }))
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

    private func delete(_ policy: Policy) {
        context.delete(policy)
        try? context.save()
        NotificationManager.shared.cancelAll()
        let all = (try? context.fetch(FetchDescriptor<Policy>())) ?? []
        let allVehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        NotificationManager.shared.reschedule(policies: all, vehicles: allVehicles)
    }
}
