import SwiftUI
import SwiftData

/// 新增/编辑保养记录
struct MaintenanceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let vehicle: Vehicle
    let editing: MaintenanceRecord?

    @State private var date: Date = Date()
    @State private var mileageText: String = ""
    @State private var item: String = "常规保养"
    @State private var costText: String = ""
    @State private var shop: String = ""
    @State private var note: String = ""
    @State private var loaded = false

    private let presets = ["常规保养", "换机油", "大保养", "换轮胎", "刹车保养", "年检", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: [.date])
                    HStack {
                        Text("里程")
                        Spacer()
                        TextField("可不填", text: $mileageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                        Text("km").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("里程留空也可以保存，历史记录里确实有没记里程的情况。")
                }

                Section("项目") {
                    HStack {
                        TextField("保养项目", text: $item)
                        Menu {
                            ForEach(presets, id: \.self) { preset in
                                Button(preset) { item = preset }
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0", text: $costText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                        Text("元").foregroundStyle(.secondary)
                    }
                    TextField("门店", text: $shop)
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let editing {
                    Section {
                        Button(role: .destructive) {
                            context.delete(editing)
                            try? context.save()
                            reschedule()
                            dismiss()
                        } label: {
                            Label("删除这条记录", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "新增保养" : "编辑保养")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(item.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let editing {
            date = editing.date
            mileageText = editing.mileage.map(String.init) ?? ""
            item = editing.item
            costText = editing.cost > 0 ? String(format: "%.2f", editing.cost) : ""
            shop = editing.shop
            note = editing.note
        } else if let last = vehicle.lastMaintenance {
            // 新增时默认沿用上次里程，方便往上调
            mileageText = last.mileage.map(String.init) ?? ""
        }
    }

    private func save() {
        let mileage = Int(mileageText.trimmingCharacters(in: .whitespaces))
        let cost = Double(costText.trimmingCharacters(in: .whitespaces)) ?? 0

        if let editing {
            editing.date = date
            editing.mileage = mileage
            editing.item = item
            editing.cost = cost
            editing.shop = shop
            editing.note = note
        } else {
            let record = MaintenanceRecord(date: date,
                                           mileage: mileage,
                                           item: item,
                                           cost: cost,
                                           shop: shop,
                                           note: note)
            context.insert(record)
            record.vehicle = vehicle
        }

        // 记录里的里程大于车辆当前里程时，同步更新车辆里程
        if let mileage, mileage > vehicle.currentMileage {
            vehicle.currentMileage = mileage
        }

        try? context.save()
        reschedule()
        dismiss()
    }

    private func reschedule() {
        let policies = (try? context.fetch(FetchDescriptor<Policy>())) ?? []
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        NotificationManager.shared.reschedule(policies: policies, vehicles: vehicles)
    }
}
