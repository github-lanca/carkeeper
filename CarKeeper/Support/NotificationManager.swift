import Foundation
import UserNotifications

/// 本地到期提醒：保单到期前 30 / 15 / 7 / 1 天的上午 10 点各提醒一次
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let policyPrefix = "policy."
    private let renewalPrefix = "renewal."
    private let maintenancePrefix = "maint."
    private let inspectionPrefix = "inspect."

    private struct PendingItem {
        let id: String
        let title: String
        let body: String
        let fireDate: Date
    }

    private init() {}

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// 重新排期全部提醒。调用前需在主线程把 SwiftData 模型转成普通值，避免跨线程访问模型。
    func reschedule(policies: [Policy], vehicles: [Vehicle]) {
        var items: [PendingItem] = []

        let now = Date()
        let offsets = [30, 15, 7, 1]

        for policy in policies {
            guard policy.endDate > now else { continue }
            let plate = policy.vehicle?.plate ?? "车辆"
            for offset in offsets {
                guard let fire = Calendar.current.date(byAdding: .day, value: -offset, to: policy.endDate) else { continue }
                let fireAt10 = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: fire) ?? fire
                guard fireAt10 > now else { continue }
                items.append(
                    PendingItem(
                        id: "\(policyPrefix)\(policy.uid).\(offset)",
                        title: "\(plate) \(policy.kind.rawValue) \(offset) 天后到期",
                        body: "保障止期 \(policy.endDate.monthDayText)，记得安排续保。",
                        fireDate: fireAt10
                    )
                )
            }
        }

        for vehicle in vehicles {
            let renewal = vehicle.nextRenewalDate
            guard let fire = Calendar.current.date(byAdding: .day, value: -7, to: renewal) else { continue }
            let fireAt10 = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: fire) ?? fire
            guard fireAt10 > now else { continue }
            items.append(
                PendingItem(
                    id: "\(renewalPrefix)\(vehicle.plate)",
                    title: "\(vehicle.plate) 统一续保日还有 7 天",
                    body: "\(vehicle.renewalMonth) 月 \(vehicle.renewalDay) 日是两车统一续保日，尽早联系保险公司出单。",
                    fireDate: fireAt10
                )
            )
        }

        // 保养提醒：下次保养日期（按里程周期算出的没有确定日期，不在本地通知里排）
        for vehicle in vehicles {
            let plan = vehicle.maintenancePlan
            guard let next = plan.nextDate else { continue }
            for offset in [15, 7, 1] {
                guard let fire = Calendar.current.date(byAdding: .day, value: -offset, to: next) else { continue }
                let fireAt10 = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: fire) ?? fire
                guard fireAt10 > now else { continue }
                items.append(
                    PendingItem(
                        id: "\(maintenancePrefix)\(vehicle.plate).\(offset)",
                        title: "\(vehicle.plate) \(offset) 天后该保养了",
                        body: "按周期应在 \(next.shortDateText) 保养，\(plan.nextMileage.map { "或里程到 \($0) km 时" } ?? "")记得预约。",
                        fireDate: fireAt10
                    )
                )
            }
        }

        // 年检提醒：检验有效期止前 90 / 30 / 7 天（可提前 3 个月办理）
        for vehicle in vehicles {
            let plan = vehicle.inspectionPlan
            guard let valid = plan.validUntil, valid.endOfDay > now else { continue }
            let actText = plan.action?.label ?? "年检"
            for offset in [90, 30, 7] {
                guard let fire = Calendar.current.date(byAdding: .day, value: -offset, to: valid) else { continue }
                let fireAt10 = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: fire) ?? fire
                guard fireAt10 > now else { continue }
                items.append(
                    PendingItem(
                        id: "\(inspectionPrefix)\(vehicle.plate).\(offset)",
                        title: "\(vehicle.plate) 年检 \(offset) 天后到期",
                        body: "检验有效期止 \(valid.shortDateText)，本次需\(actText)，可在到期前 3 个月内办理。",
                        fireDate: fireAt10
                    )
                )
            }
        }

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let managed = requests
                .map(\.identifier)
                .filter { self.isManaged($0) }
            self.center.removePendingNotificationRequests(withIdentifiers: managed)

            for item in items {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
                self.center.add(request) { _ in }
            }
        }
    }

    private func isManaged(_ identifier: String) -> Bool {
        identifier.hasPrefix(policyPrefix)
            || identifier.hasPrefix(renewalPrefix)
            || identifier.hasPrefix(maintenancePrefix)
            || identifier.hasPrefix(inspectionPrefix)
    }

    func cancelAll() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let managed = requests
                .map(\.identifier)
                .filter { self.isManaged($0) }
            self.center.removePendingNotificationRequests(withIdentifiers: managed)
        }
    }

    func pendingCount(completion: @escaping (Int) -> Void) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let managed = requests.filter { self.isManaged($0.identifier) }
            completion(managed.count)
        }
    }
}
