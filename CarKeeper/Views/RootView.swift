import SwiftUI
import SwiftData

struct RootView: View {
    /// 默认停在首页；可通过启动参数 -startTab 0/1/2/3/4 指定初始标签页（便于逐页检查）
    @State private var selection: Int = UserDefaults.standard.integer(forKey: "startTab")

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("首页", systemImage: "gauge.with.dots.needle.67percent") }
                .tag(0)

            VehicleListView()
                .tabItem { Label("车辆", systemImage: "car.2.fill") }
                .tag(1)

            MaintenanceListView()
                .tabItem { Label("保养", systemImage: "wrench.and.screwdriver.fill") }
                .tag(2)

            InspectionListView()
                .tabItem { Label("年检", systemImage: "checkmark.seal.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Color(red: 0.04, green: 0.38, blue: 0.84))
    }
}
