//
//  LearningDashboardView.swift
//  captest1
//
//  베이지안 학습 결과 대시보드. 학습·통계는 서버가 계산하고, 여기선 서버 DTO를 렌더한다.
//  5개 카드 — Hero / Trend / Calibration / Distribution / List. count에 따라 분기.
//

import SwiftUI
import Charts

struct LearningDashboardView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(LearningStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let dashboard = store.dashboard {
                    content(dashboard)
                } else if store.isLoading {
                    ProgressView("학습 데이터를 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    EmptyLearningStateCard(message: store.skipMessage)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("내 학습 데이터")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
    }

    @ViewBuilder
    private func content(_ dashboard: LearningDashboardResponse) -> some View {
        switch dashboard.count {
        case 0:
            EmptyLearningStateCard(message: store.skipMessage)
        case 1..<3:
            if let latest = dashboard.latest {
                HeroEstimateCard(latest: latest, count: dashboard.count, lastLearnedDate: settings.lastLearnedDate)
            }
            EarlyStageHintCard(count: dashboard.count)
            ObservationListCard(observations: dashboard.observations)
        default:
            if let latest = dashboard.latest {
                HeroEstimateCard(latest: latest, count: dashboard.count, lastLearnedDate: settings.lastLearnedDate)
            }
            LearningTrendCard(observations: dashboard.observations)
            CalibrationCard(calibration: dashboard.calibration)
            InputDistributionCard(residual: dashboard.residualHistogram, sol: dashboard.solHistogram)
            ObservationListCard(observations: dashboard.observations)
        }
    }
}

// MARK: - ① Hero

private struct HeroEstimateCard: View {
    let latest: LatestEstimate
    let count: Int
    let lastLearnedDate: Date?

    var body: some View {
        HealthCard("현재 추정 반감기", symbol: "scope", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", latest.posteriorMean))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("EspressoBrown"))
                        .monospacedDigit()
                    Text("h").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                }

                Text(String(format: "95%% 신뢰구간  %.2f h ~ %.2f h", latest.ciLower, latest.ciUpper))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider()

                ConfidenceBar(score: latest.confidence)

                HStack {
                    Label("\(count)회 관측", systemImage: "chart.bar.doc.horizontal")
                    Spacer()
                    if let date = lastLearnedDate {
                        Text("마지막 학습 \(date, format: .dateTime.month().day())")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - ② Trend

private struct LearningTrendCard: View {
    let observations: [ObservationItem]

    var body: some View {
        HealthCard("학습 추세", symbol: "chart.line.uptrend.xyaxis", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("사후 평균과 95% 신뢰구간이 모집단 prior(5.0h)에서 어떻게 멀어졌는지 확인하세요.")
                    .font(.caption).foregroundStyle(.secondary)

                Chart {
                    ForEach(observations) { obs in
                        AreaMark(
                            x: .value("날짜", obs.parsedDate),
                            yStart: .value("하한", obs.posteriorMean - 1.96 * sqrt(obs.posteriorVariance)),
                            yEnd: .value("상한", obs.posteriorMean + 1.96 * sqrt(obs.posteriorVariance))
                        )
                        .foregroundStyle(Color("EspressoBrown").opacity(0.15))

                        LineMark(x: .value("날짜", obs.parsedDate), y: .value("반감기", obs.posteriorMean))
                            .foregroundStyle(Color("EspressoBrown"))
                            .interpolationMethod(.monotone)
                            .symbol(.circle)
                    }
                    RuleMark(y: .value("Prior", AppConstants.Pharmacokinetics.defaultHalfLifeHours))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .topTrailing, alignment: .trailing) {
                            Text("모집단 5.0h").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 2.5...7.5)
                .chartYAxis {
                    AxisMarks(values: [3, 4, 5, 6, 7]) { value in
                        AxisGridLine()
                        AxisValueLabel { if let v = value.as(Double.self) { Text("\(Int(v))h") } }
                    }
                }
                .frame(height: 220)
            }
        }
    }
}

// MARK: - ③ Calibration (캡스톤 핵심)

private struct CalibrationCard: View {
    let calibration: Calibration

    var body: some View {
        let points = calibration.points.map {
            CalibrationPoint(predicted: $0.predicted, observed: $0.observed)
        }
        let domain = calibration.domainLower...max(calibration.domainUpper, calibration.domainLower + 1)

        HealthCard("모델 정확도", symbol: "target", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("점이 대각선에 가까울수록 모델 예측이 정확합니다. 회색 띠 = ±10분 노이즈 범위.")
                    .font(.caption).foregroundStyle(.secondary)

                CalibrationScatterChart(points: points, domain: domain)

                HStack(spacing: 24) {
                    metricBlock(label: "R²",
                                value: calibration.rSquared.map { String(format: "%.3f", $0) } ?? "—",
                                unit: nil)
                    metricBlock(label: "RMSE", value: String(format: "%.1f", calibration.rmse), unit: "분")
                    Spacer()
                }
            }
        }
    }

    private func metricBlock(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(Color("EspressoBrown"))
                if let unit { Text(unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - ④ Input Distribution

private struct InputDistributionCard: View {
    let residual: [HistogramBinItem]
    let sol: [HistogramBinItem]

    var body: some View {
        HealthCard("입력 데이터 분포", symbol: "chart.bar.fill", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("학습에 사용된 카페인 잔량과 SOL의 분포입니다. 한쪽으로 치우쳐 있다면 더 다양한 조건의 데이터가 필요합니다.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    histogramColumn(title: "취침 시 카페인 잔량", unit: "mg", bins: residual)
                    Divider().frame(maxHeight: 180)
                    histogramColumn(title: "측정된 SOL", unit: "분", bins: sol)
                }
            }
        }
    }

    private func histogramColumn(title: String, unit: String, bins: [HistogramBinItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold))
            Chart(bins) { bin in
                BarMark(x: .value("범위", bin.label), y: .value("개수", bin.count))
                    .foregroundStyle(Color("EspressoBrown").opacity(0.7))
                    .cornerRadius(2)
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel(orientation: .vertical).font(.system(size: 8)) } }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .frame(height: 140)
            Text("\(unit) 기준").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ⑤ Observation list

private struct ObservationListCard: View {
    let observations: [ObservationItem]

    var body: some View {
        HealthCard("전체 기록", symbol: "list.bullet.rectangle", tint: Color("EspressoBrown")) {
            VStack(spacing: 0) {
                ForEach(Array(observations.reversed().enumerated()), id: \.element.id) { index, obs in
                    if index > 0 { Divider() }
                    row(obs)
                }
            }
        }
    }

    private func row(_ obs: ObservationItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(obs.parsedDate, format: .dateTime.month().day())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f h → %.2f h", obs.priorMean, obs.posteriorMean))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(String(format: "잔량 %.0f mg", obs.predictedResidualAtBedtime), systemImage: "cup.and.saucer")
                Label(String(format: "SOL %.0f분", obs.observedSolMinutes), systemImage: "moon.zzz")
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty / Early state

private struct EmptyLearningStateCard: View {
    let message: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56)).foregroundStyle(.secondary)
            Text("아직 학습된 데이터가 없어요").font(.headline)
            Text("HealthKit 수면 기록과 카페인 섭취 기록이 쌓이면\n매일 자동으로 반감기가 갱신됩니다.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let message {
                Text("학습되지 않은 이유: \(message)")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

private struct EarlyStageHintCard: View {
    let count: Int
    var body: some View {
        HealthCard(symbol: "info.circle", tint: .indigo) {
            Text("관측 \(count)회 누적. 모델 정확도와 입력 분포 차트는 3회 관측부터 표시됩니다.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
