import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]
    @Query private var policies: [Policy]

    @State private var pendingCount: Int?
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("提醒排期")
                        Spacer()
                        Text(pendingCount.map { "\($0) 条" } ?? "读取中…")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("系统通知权限")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }
                    Button {
                        NotificationManager.shared.reschedule(policies: policies, vehicles: vehicles)
                        refresh()
                    } label: {
                        Label("重新排期全部提醒", systemImage: "arrow.clockwise")
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("打开系统通知设置", systemImage: "gearshape")
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    Text("保单：到期前 30 / 15 / 7 / 1 天；保养：到期前 15 / 7 / 1 天；年检：有效期止前 90 / 30 / 7 天。均为上午 10:00 提醒。")
                }

                Section("数据") {
                    HStack {
                        Text("车辆")
                        Spacer()
                        Text("\(vehicles.count) 台").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("保单")
                        Spacer()
                        Text("\(policies.count) 份").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("年度总保费")
                        Spacer()
                        Text(String(format: "¥%.2f", policies.filter { $0.isActive }.reduce(0) { $0 + $1.premium }))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label("清空全部数据", systemImage: "trash")
                    }
                }

                Section {
                    Text("保单初始数据来自 iCloud 云盘 Personal/Car 目录下的电子保单，日期均按保单正文「保险期间」录入。若与保险公司系统记录不一致，以保险公司为准。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("车管家 1.0 (1) · 数据存于本机")
                        .font(.system(size: 11))
                }
            }
            .navigationTitle("设置")
            .onAppear(perform: refresh)
            .confirmationDialog("确定清空全部车辆与保单？", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    for policy in policies { context.delete(policy) }
                    for vehicle in vehicles { context.delete(vehicle) }
                    try? context.save()
                    NotificationManager.shared.cancelAll()
                    refresh()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作不可撤销，建议先确认数据已备份。")
            }
        }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return "已开启"
        case .denied: return "已关闭"
        case .notDetermined: return "未询问"
        @unknown default: return "未知"
        }
    }

    private var statusColor: Color {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: return Color(red: 0.07, green: 0.44, blue: 0.25)
        case .denied: return Color(red: 0.72, green: 0.16, blue: 0.12)
        default: return .secondary
        }
    }

    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { authStatus = settings.authorizationStatus }
        }
        NotificationManager.shared.pendingCount { count in
            DispatchQueue.main.async { pendingCount = count }
        }
    }
}
