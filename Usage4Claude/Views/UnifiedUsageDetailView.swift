//
//  UnifiedUsageDetailView.swift
//  Usage4Claude
//
//  Created by Claude Code on 2026-05-06.
//  Copyright © 2026 f-is-h. All rights reserved.
//

import SwiftUI

/// 통합 사용량 popover (v3.1)
/// 활성 계정의 큰 카드를 맨 위에 두고, 보조 계정들의 미니 카드를 그 아래로 나열한다.
/// 보조 카드를 클릭하면 활성 계정으로 전환되어 카드 순서가 재배치된다.
struct UnifiedUsageDetailView: View {
    let activeCard: UsageDetailView
    @Binding var extraClaudeUsage: [UUID: UsageData]
    @Binding var extraCodexUsage: [UUID: CodexUsageData]
    @ObservedObject private var settings = UserSettings.shared
    @StateObject private var localization = LocalizationManager.shared

    private var width: CGFloat {
        settings.isMultiProviderActive ? 580 : 290
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                activeCard

                let claudeSecondaries = settings.secondaryClaudeAccounts
                let codexSecondaries = settings.secondaryCodexAccounts

                if !claudeSecondaries.isEmpty {
                    sectionDivider
                    sectionHeader(L.Unified.claudeSection)
                    ForEach(claudeSecondaries) { account in
                        SecondaryAccountMiniCard(
                            label: account.displayName,
                            data: extraClaudeUsage[account.id],
                            isClaude: true,
                            extraUsageMode: settings.resolvedExtraUsageDisplayMode(for: account.id)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }

                if !codexSecondaries.isEmpty {
                    sectionDivider
                    sectionHeader(L.Unified.codexSection)
                    ForEach(codexSecondaries) { account in
                        SecondaryAccountMiniCard(
                            label: account.displayName,
                            codexData: extraCodexUsage[account.id],
                            isClaude: false,
                            extraUsageMode: settings.resolvedExtraUsageDisplayMode(for: account.id)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }

                Spacer(minLength: 8)
            }
        }
        .frame(width: width)
        .id(localization.updateTrigger)
    }

    @ViewBuilder
    private var sectionDivider: some View {
        Divider().padding(.horizontal, 12).padding(.top, 4)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

/// 보조 organization 미니 카드 — 한 줄짜리 컴팩트 표시
/// 같은 사용자의 다른 organization (요금제) 사용량을 동시에 노출하기 위한 카드.
/// 별도 계정이 아니라 같은 sessionKey 안의 다른 워크스페이스이므로 "전환" 액션이 의미 없다.
private struct SecondaryAccountMiniCard: View {
    let label: String
    var data: UsageData? = nil
    var codexData: CodexUsageData? = nil
    let isClaude: Bool
    let extraUsageMode: ExtraUsageDisplayMode

    var body: some View {
        HStack(spacing: 12) {
            // 좌측 색상 인디케이터 (provider 구분)
            RoundedRectangle(cornerRadius: 2)
                .fill(isClaude ? Color.orange : Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0))
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                metricsLine
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private var metricsLine: some View {
        if isClaude {
            if let data = data {
                claudeMetrics(data)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            if let codex = codexData {
                codexMetrics(codex)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func claudeMetrics(_ data: UsageData) -> some View {
        HStack(spacing: 8) {
            if let fh = data.fiveHour {
                MetricChip(label: "5h", value: "\(Int(fh.percentage))%", color: .green)
            }
            if let sd = data.sevenDay {
                MetricChip(label: "7d", value: "\(Int(sd.percentage))%", color: .purple)
            }
            if let opus = data.opus {
                MetricChip(label: "Opus", value: "\(Int(opus.percentage))%", color: .orange)
            }
            if let sonnet = data.sonnet {
                MetricChip(label: "Sonnet", value: "\(Int(sonnet.percentage))%", color: .blue)
            }
            if let extra = data.extraUsage, extra.enabled {
                extraUsageChip(percentage: extra.percentage,
                               used: extra.used,
                               currency: extra.currencySymbol,
                               color: .pink)
            }
        }
    }

    @ViewBuilder
    private func codexMetrics(_ data: CodexUsageData) -> some View {
        HStack(spacing: 8) {
            if let primary = data.primary {
                MetricChip(label: "5h", value: "\(Int(primary.percentage))%",
                           color: Color(red: 45/255.0, green: 212/255.0, blue: 191/255.0))
            }
            if let secondary = data.secondary {
                MetricChip(label: "7d", value: "\(Int(secondary.percentage))%",
                           color: Color(red: 96/255.0, green: 165/255.0, blue: 250/255.0))
            }
            if let extra = data.extraUsage, extra.enabled {
                extraUsageChip(percentage: extra.percentage,
                               used: nil,
                               currency: "$",
                               color: Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0))
            }
        }
    }

    /// extraUsageMode에 맞춰 라벨/값 형태를 분기 — `$ 10%` 처럼 통화기호와 % 가 같이 노출되는 일이 없도록.
    @ViewBuilder
    private func extraUsageChip(percentage: Double?, used: Double?, currency: String, color: Color) -> some View {
        switch extraUsageMode {
        case .amount:
            if let used {
                // 금액 모드: 라벨 없이 통화 + 사용 금액 (소수점 1자리)
                MetricChip(label: "", value: "\(currency)\(formatAmount(used))", color: color)
            } else if let percentage {
                // used 정보 없으면 % 로 fallback (Codex 같은 경우)
                MetricChip(label: "", value: "\(Int(percentage))%", color: color)
            }
        case .percent:
            if let percentage {
                // 백분율 모드: $ 라벨 없이 % 만
                MetricChip(label: "Extra", value: "\(Int(percentage))%", color: color)
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 100 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

private struct MetricChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
