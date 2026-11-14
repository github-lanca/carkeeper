import SwiftUI
import SwiftData

struct VehicleEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let vehicle: Vehicle?

    @State private var plate: String = ""
    @State private var modelName: String = ""
    @State private var vin: String = ""
    @State private var registerDate: Date = Date()
    @State private var mileageText: String = ""
    @State private var renewalMonth: Int = 12
    @State private var renewalDay: Int = 12
    @State private var note: String = ""

    @State private var purchaseDate: Date = Date()
    @State private var monthsText: String = ""
    @State private var kmText: String = ""
    @State private var maintenanceNote: String = ""

    @State private var category: InspectionCategory = .car
    @State private var hasInspection = false
    @State private var inspectionDate: Date = Date()

    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("车牌号（如 京A12345）", text: $plate)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("车型（如 5 座客车 / 摩托车）", text: $modelName)
                    TextField("车架号 VIN", text: $vin)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    DatePicker("注册登记日期", selection: $registerDate, displayedComponents: .date)
                    Picker("车辆类型", selection: $category) {
                        ForEach(InspectionCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    HStack {
                        Text("当前里程")
                        Spacer()
                        TextField("0", text: $mileageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                        Text("km").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Picker("月", selection: $renewalMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month) 月").tag(month)
                        }
                    }
                    Picker("日", selection: $renewalDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day) 日").tag(day)
                        }
                    }
                } header: {
                    Text("统一续保日")
                } footer: {
                    Text("建议设为 12 月 12 日：交强险不断保，商业险仅需几天空窗，两车可同日续保。")
                }

                Section {
                    DatePicker("购车日期", selection: $purchaseDate, displayedComponents: .date)
                    HStack {
                        Text("时间周期")
                        Spacer()
                        TextField("6", text: $monthsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 70)
                        Text("个月").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("里程周期")
                        Spacer()
                        TextField("5000", text: $kmText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Text("km").foregroundStyle(.secondary)
                    }
                    TextField("周期说明（如 每半年或 5000 公里保养一次）", text: $maintenanceNote, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("保养周期")
                } footer: {
                    Text("时间周期或里程周期填 0 表示不按该项计算。两项都填时，「先到为准」触发保养提醒。")
                }

                Section {
                    Toggle("录入检验有效期", isOn: $hasInspection)
                    if hasInspection {
                        DatePicker("检验有效期止", selection: $inspectionDate, displayedComponents: .date)
                    }
                } header: {
                    Text("年检")
                } footer: {
                    Text("按行驶证副页或「交管12123」里的检验有效期填写。9 座以下小客车与摩托车 10 年内每 2 年一检，超过 10 年每年一检。")
                }

                Section("备注") {
                    TextField("备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(vehicle == nil ? "添加车辆" : "编辑车辆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(plate.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                guard let vehicle else { return }
                plate = vehicle.plate
                modelName = vehicle.modelName
                vin = vehicle.vin
                registerDate = vehicle.registerDate
                mileageText = vehicle.currentMileage > 0 ? "\(vehicle.currentMileage)" : ""
                renewalMonth = vehicle.renewalMonth
                renewalDay = vehicle.renewalDay
                note = vehicle.note
                purchaseDate = vehicle.purchaseDate ?? vehicle.registerDate
                monthsText = vehicle.maintenanceIntervalMonths > 0 ? "\(vehicle.maintenanceIntervalMonths)" : ""
                kmText = vehicle.maintenanceIntervalKm > 0 ? "\(vehicle.maintenanceIntervalKm)" : ""
                maintenanceNote = vehicle.maintenanceNote
                category = vehicle.inspectionCategory
                hasInspection = vehicle.inspectionValidUntil != nil
                inspectionDate = vehicle.inspectionValidUntil ?? Date()
            }
        }
    }

    private func save() {
        let mileage = Int(mileageText) ?? 0
        let months = Int(monthsText.trimmingCharacters(in: .whitespaces)) ?? 0
        let kms = Int(kmText.trimmingCharacters(in: .whitespaces)) ?? 0
        if let vehicle {
            vehicle.plate = plate.trimmingCharacters(in: .whitespaces)
            vehicle.modelName = modelName
            vehicle.vin = vin
            vehicle.registerDate = registerDate
            vehicle.currentMileage = mileage
            vehicle.renewalMonth = renewalMonth
            vehicle.renewalDay = renewalDay
            vehicle.note = note
            vehicle.purchaseDate = purchaseDate
            vehicle.maintenanceIntervalMonths = months
            vehicle.maintenanceIntervalKm = kms
            vehicle.maintenanceNote = maintenanceNote
            vehicle.inspectionCategory = category
            vehicle.inspectionValidUntil = hasInspection ? inspectionDate : nil
        } else {
            let newVehicle = Vehicle(
                plate: plate.trimmingCharacters(in: .whitespaces),
                modelName: modelName,
                vin: vin,
                registerDate: registerDate,
                currentMileage: mileage,
                renewalMonth: renewalMonth,
                renewalDay: renewalDay,
                note: note
            )
            newVehicle.purchaseDate = purchaseDate
            newVehicle.maintenanceIntervalMonths = months
            newVehicle.maintenanceIntervalKm = kms
            newVehicle.maintenanceNote = maintenanceNote
            newVehicle.inspectionCategory = category
            newVehicle.inspectionValidUntil = hasInspection ? inspectionDate : nil
            context.insert(newVehicle)
        }
        try? context.save()
        let policies = (try? context.fetch(FetchDescriptor<Policy>())) ?? []
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        NotificationManager.shared.reschedule(policies: policies, vehicles: vehicles)
        dismiss()
    }
}
