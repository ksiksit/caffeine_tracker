//
//  LearningDashboardView.swift
//  captest1
//
//  베이지안 학습 결과 대시보드. 5개 카드 — Hero / Trend / Calibration /
//  Distribution / List. N에 따라 표시 카드 수 분기.
//

import SwiftUI
import SwiftData
import Charts

struct LearningDashboardView: View {
    @Environment(SettingsManager.self) private var settings
    @Query(sort: \HalfLifeObservation.date, order: .forward)
    private var observations: [HalfLifeObservation]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch observations.count {
                case 0:
                    EmptyLearningStateCard(reason: settings.lastLearningSkipReason)
                case 1..<3:
                    HeroEstimateCard(observations: observations, settings: settings)
                    EarlyStageHintCard(count: observations.count)
                    ObservationListCard(observations: observations)
                default:
                    HeroEstimateCard(observations: observations, settings: settings)
                    LearningTrendCard(observations: observations)
                    CalibrationCard(observations: observations)
                    InputDistributionCard(observations: observations)
                    ObservationListCard(observations: observations)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("내 학습 데이터")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - ① Hero

fileprivate struct HeroEstimateCard: View {
    let observations: [HalfLifeObservation]
    let settings: SettingsManager

    var body: some View {
        let latest = observations.last!
        let halfWidth = 1.96 * sqrt(latest.posteriorVariance)
        let confidence = LearningStats.confidenceScore(
            posteriorVariance: latest.posteriorVariance
        )

        HealthCard("현재 추정 반감기", symbol: "scope", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", latest.posteriorMean))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("EspressoBrown"))
                        .monospacedDigit()
                    Text("h")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(String(format: "95%% 신뢰구간  %.2f h ~ %.2f h",
                            latest.posteriorMean - halfWidth,
                            latest.posteriorMean + halfWidth))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider()

                ConfidenceBar(score: confidence)

                HStack {
                    Label("\(observations.count)회 관측",
                          systemImage: "chart.bar.doc.horizontal")
                    Spacer()
                    if let date = settings.lastLearnedDate {
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

fileprivate struct LearningTrendCard: View {
    let observations: [HalfLifeObservation]

    var body: some View {
        HealthCard("학습 추세", symbol: "chart.line.uptrend.xyaxis",
                   tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("사후 평균과 95% 신뢰구간이 모집단 prior(5.0h)에서 어떻게 멀어졌는지 확인하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(observations) { obs in
                        AreaMark(
                            x: .value("날짜", obs.date),
                            yStart: .value("하한",
                                obs.posteriorMean - 1.96 * sqrt(obs.posteriorVariance)),
                            yEnd: .value("상한",
                                obs.posteriorMean + 1.96 * sqrt(obs.posteriorVariance))
                        )
                        .foregroundStyle(Color("EspressoBrown").opacity(0.15))

                        LineMark(
                            x: .value("날짜", obs.date),
                            y: .value("반감기", obs.posteriorMean)
                        )
                        .foregroundStyle(Color("EspressoBrown"))
                        .interpolationMethod(.monotone)
                        .symbol(.circle)
                    }

                    RuleMark(y: .value("Prior",
                        AppConstants.Pharmacokinetics.defaultHalfLifeHours))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .topTrailing, alignment: .trailing) {
                            Text("모집단 5.0h")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 2.5...7.5)
                .chartYAxis {
                    AxisMarks(values: [3, 4, 5, 6, 7]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text("\(Int(v))h") }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }
}

// MARK: - ③ Calibration (캡스톤 핵심)

fileprivate struct CalibrationCard: View {
    let observations: [HalfLifeObservation]

    var body: some View {
        let points = observations.map {
            LearningStats.Point(
                predicted: LearningStats.predictedSOL(
                    residualMg: $0.predictedResidualAtBedtime),
                observed: $0.observedSOLMinutes,
                date: $0.date
            )
        }
        let r2 = LearningStats.rSquared(points: points)
        let rmse = LearningStats.rmse(points: points)
        let domain = LearningStats.calibrationDomain(points: points)

        HealthCard("모델 정확도", symbol: "target", tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("점이 대각선에 가까울수록 모델 예측이 정확합니다. 회색 띠 = ±10분 노이즈 범위.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                CalibrationScatterChart(points: points, domain: domain)

                HStack(spacing: 24) {
                    metricBlock(label: "R²",
                                value: r2.map { String(format: "%.3f", $0) } ?? "—",
                                unit: nil)
                    metricBlock(label: "RMSE",
                                value: String(format: "%.1f", rmse),
                                unit: "분")
                    Spacer()
                }
            }
        }
    }

    private func metricBlock(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color("EspressoBrown"))
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - ④ Input Distribution

fileprivate struct InputDistributionCard: View {
    let observations: [HalfLifeObservation]

    var body: some View {
        let residualBins = LearningStats.histogram(
            values: observations.map(\.predictedResidualAtBedtime),
            binCount: 6
        )
        let solBins = LearningStats.histogram(
            values: observations.map(\.observedSOLMinutes),
            binCount: 6
        )

        HealthCard("입력 데이터 분포", symbol: "chart.bar.fill",
                   tint: Color("EspressoBrown")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("학습에 사용된 카페인 잔량과 SOL의 분포입니다. 한쪽으로 치우쳐 있다면 더 다양한 조건의 데이터가 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    histogramColumn(title: "취침 시 카페인 잔량",
                                    unit: "mg", bins: residualBins)
                    Divider().frame(maxHeight: 180)
                    histogramColumn(title: "측정된 SOL",
                                    unit: "분", bins: solBins)
                }
            }
        }
    }

    private func histogramColumn(
        title: String, unit: String,
        bins: [LearningStats.HistogramBin]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            Chart(bins) { bin in
                BarMark(
                    x: .value("범위", bin.label),
                    y: .value("개수", bin.count)
                )
                .foregroundStyle(Color("EspressoBrown").opacity(0.7))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(orientation: .vertical)
                        .font(.system(size: 8))
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .frame(height: 140)
            Text("\(unit) 기준")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ⑤ Observation list

fileprivate struct ObservationListCard: View {
    let observations: [HalfLifeObservation]

    var body: some View {
        HealthCard("전체 기록", symbol: "list.bullet.rectangle",
                   tint: Color("EspressoBrown")) {
            VStack(spacing: 0) {
                ForEach(Array(observations.reversed().enumerated()),
                        id: \.element.id) { index, obs in
                    if index > 0 { Divider() }
                    row(obs)
                }
            }
        }
    }

    private func row(_ obs: HalfLifeObservation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(obs.date, format: .dateTime.month().day())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f h → %.2f h",
                            obs.priorMean, obs.posteriorMean))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(String(format: "잔량 %.0f mg", obs.predictedResidualAtBedtime),
                      systemImage: "cup.and.saucer")
                Label(String(format: "SOL %.0f분", obs.observedSOLMinutes),
                      systemImage: "moon.zzz")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty / Early state

fileprivate struct EmptyLearningStateCard: View {
    let reason: LearningSkipReason?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("아직 학습된 데이터가 없어요")
                .font(.headline)
            Text("HealthKit 수면 기록과 카페인 섭취 기록이 쌓이면\n매일 자동으로 반감기가 갱신됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let reason {
                Text("학습되지 않은 이유: \(reason.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

fileprivate struct EarlyStageHintCard: View {
    let count: Int
    var body: some View {
        HealthCard(symbol: "info.circle", tint: .indigo) {
            Text("관측 \(count)회 누적. 모델 정확도와 입력 분포 차트는 3회 관측부터 표시됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("≥3 관측") {
    DashboardPreviewWrapper(observationCount: 8)
}

#Preview("2 관측 (early)") {
    DashboardPreviewWrapper(observationCount: 2)
}

#Preview("0 관측 (empty)") {
    DashboardPreviewWrapper(observationCount: 0)
}

private struct DashboardPreviewWrapper: View {
    let observationCount: Int

    var body: some View {
        let container = try! ModelContainer(
            for: HalfLifeObservation.self, CaffeineRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        for i in 0..<observationCount {
            let date = Calendar.current.date(
                byAdding: .day, value: -i, to: now
            )!
            let priorMean = 5.0 + Double(observationCount - i) * 0.05
            let postMean = priorMean + 0.1 * (Double.random(in: -1...1))
            let postVar = max(0.0025, 2.25 * pow(0.92, Double(observationCount - i)))
            if let obs = try? HalfLifeObservation(
                date: date,
                predictedResidualAtBedtime: Double.random(in: 30...180),
                observedSOLMinutes: Double.random(in: 12...45),
                priorMean: priorMean, priorVariance: 1.5,
                posteriorMean: postMean, posteriorVariance: postVar,
                conditionMultiplier: 1.0
            ) {
                context.insert(obs)
            }
        }
        try? context.save()
        return NavigationStack { LearningDashboardView() }
            .modelContainer(container)
            .environment(SettingsManager())
    }
}
