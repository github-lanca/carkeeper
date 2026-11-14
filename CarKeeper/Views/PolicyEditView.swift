import SwiftUI
import SwiftData

struct PolicyEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let vehicle: Vehicle
    let editing: Policy?

    @State private var kind: PolicyKind = .compulsory
    @State private var insurer: String = "中国人民财产保险股份有限公司"
    @State private var policyNumber: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var premiumText: String = ""
    @State private var note: String = ""
    @State private var loaded = false

    private var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("险种", selection: $kind) {
                        ForEach(PolicyKind.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    DatePicker("起期", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("止期", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("保障 \(durationDays) 天 · 距止期还有 \(endDate.daysFromToday) 天")
                }

                Section("费用") {
                    HStack {
                        Text("保费")
                        Spacer()
                        TextField("0.00", text: $premiumText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text("元").foregroundStyle(.secondary)
                    }
                }

                Section("保单信息") {
                    TextField("保险公司", text: $insurer)
                    TextField("保单号", text: $policyNumber)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let editing {
                    Section {
                        Button(role: .destructive) {
                            context.delete(editing)
                            try? context.save()
                            rescheduleNotifications()
                            dismiss()
                        } label: {
                            Label("删除这份保单", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新增保单" : "编辑保单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(endDate <= startDate)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let editing {
                    kind = editing.kind
                    insurer = editing.insurer
                    policyNumber = editing.policyNumber
                    startDate = editing.startDate
                    endDate = editing.endDate
                    premiumText = editing.premium > 0 ? String(format: "%.2f", editing.premium) : ""
                    note = editing.note
                }
            }
        }
    }

    private func save() {
        let premium = Double(premiumText.replacingOccurrences(of: ",", with: "")) ?? 0
        if let editing {
            editing.kind = kind
            editing.insurer = insurer
            editing.policyNumber = policyNumber
            editing.startDate = startDate
            editing.endDate = endDate
            editing.premium = premium
            editing.note = note
        } else {
            let policy = Policy(
                kind: kind,
                insurer: insurer,
                policyNumber: policyNumber,
                startDate: startDate,
                endDate: endDate,
                premium: premium,
                note: note
            )
            context.insert(policy)
            policy.vehicle = vehicle
        }
        try? context.save()
        rescheduleNotifications()
        dismiss()
    }

    private func rescheduleNotifications() {
        let policies = (try? context.fetch(FetchDescriptor<Policy>())) ?? []
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        NotificationManager.shared.reschedule(policies: policies, vehicles: vehicles)
    }
}
