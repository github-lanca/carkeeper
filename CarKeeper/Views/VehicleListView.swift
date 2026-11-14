import SwiftUI
import SwiftData
import UIKit

struct VehicleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vehicle.plate) private var vehicles: [Vehicle]
    @State private var showingAdd = false
    @State private var path: [Vehicle] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(vehicles) { vehicle in
                    NavigationLink(value: vehicle) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(red: 0.04, green: 0.38, blue: 0.84).opacity(0.12))
                                Image(systemName: "car.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(red: 0.04, green: 0.38, blue: 0.84))
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(vehicle.plate)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(vehicle.modelName.isEmpty ? "未填写车型" : vehicle.modelName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(vehicle.activePolicies.count) 份在保")
                                    .font(.system(size: 12, weight: .medium))
                                Text("续保 \(vehicle.renewalCountdown) 天")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationDestination(for: Vehicle.self) { vehicle in
                VehicleDetailView(vehicle: vehicle)
            }
            .navigationTitle("车辆")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                VehicleEditView(vehicle: nil)
            }
            .overlay {
                if vehicles.isEmpty {
                    EmptyHint(icon: "car.2", title: "还没有车辆", subtitle: "点右上角 + 添加车辆")
                }
            }
            .onAppear {
                guard path.isEmpty else { return }
                guard let plate = UserDefaults.standard.string(forKey: "startVehicle") else { return }
                if let target = vehicles.first(where: { $0.plate == plate }) {
                    path = [target]
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(vehicles[index])
        }
        try? context.save()
    }
}
