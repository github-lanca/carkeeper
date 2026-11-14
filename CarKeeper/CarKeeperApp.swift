import SwiftUI
import SwiftData

@main
struct CarKeeperApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Vehicle.self, Policy.self, MaintenanceRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            SeedData.seedIfNeeded(context: container.mainContext)
            SeedData.seedMaintenanceIfNeeded(context: container.mainContext)
            SeedData.seedInspectionIfNeeded(context: container.mainContext)
        } catch {
            fatalError("无法初始化本地数据存储：\(error)")
        }
        if !UserDefaults.standard.bool(forKey: "skipNotifPrompt") {
            NotificationManager.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
