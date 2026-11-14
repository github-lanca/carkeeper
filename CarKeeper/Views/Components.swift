import SwiftUI
import UIKit

/// 通用白色圆角容器
struct SectionCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// 险种标签
struct KindBadge: View {
    let kind: PolicyKind
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(kind.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(kind.tint)
        .background(kind.tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// 剩余天数徽标
struct DaysBadge: View {
    let policy: Policy
    var body: some View {
        Text(policy.daysRemaining < 0
             ? "已过期 \(abs(policy.daysRemaining)) 天"
             : (policy.daysRemaining == 0 ? "今天到期" : "剩 \(policy.daysRemaining) 天"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(policy.urgency.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(policy.urgency.tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

/// 数量角标（聚合同一辆车的多条待办时使用）
struct CountBadge: View {
    let count: Int
    var tint: Color = Color(red: 0.72, green: 0.16, blue: 0.12)

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .monospacedDigit()
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, count > 9 ? 5 : 0)
            .background(tint)
            .clipShape(Capsule())
    }
}

/// 保障进度条
struct PolicyProgressBar: View {
    let progress: Double
    let tint: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, geo.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}

/// 保单行
struct PolicyRow: View {
    let policy: Policy
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                KindBadge(kind: policy.kind)
                if policy.kind.isMandatory {
                    Text("法定")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.72, green: 0.16, blue: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer(minLength: 6)
                DaysBadge(policy: policy)
            }

            HStack(spacing: 4) {
                Text(policy.startDate.shortDateText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text(policy.endDate.shortDateText)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            PolicyProgressBar(progress: policy.progress, tint: policy.urgency.tint)

            HStack {
                Text(policy.insurer.isEmpty ? "—" : policy.insurer)
                    .lineLimit(1)
                Spacer()
                Text(policy.premium > 0 ? String(format: "¥%.2f", policy.premium) : "—")
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// 保险状态徽标（与保养状态徽标同款，保证首页两个区块风格一致）
struct UrgencyBadge: View {
    let urgency: Urgency

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: urgency.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(urgency.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(urgency.tint)
        .background(urgency.tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// 保养状态徽标
struct MaintenanceBadge: View {
    let status: MaintenanceStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(status.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(status.tint)
        .background(status.tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// 空状态
struct EmptyHint: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
