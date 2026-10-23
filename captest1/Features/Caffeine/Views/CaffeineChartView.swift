//
//  CaffeineChartView.swift
//  captest1
//
//  하루 체내 카페인 타임라인. 지금까지는 실선, 이후 예측은 점선.
//  세로선: 지금 / 마감(있을 때, 신호색) / 취침. 값은 서버 계산 결과(dataPoints)를 그대로 그린다.
//

import SwiftUI
import Charts

struct CaffeineChartView: View {
    let dataPoints: [CaffeineKineticsCalculator.DataPoint]
    let doses: [CaffeineKineticsCalculator.Dose]
    let currentTime: Date
    /// 서버가 정한 다음 취침 시각(today 응답). 이미 지난 오늘 취침은 서버가 내일로 넘겨 준다
    var bedtime: Date? = nil
    /// 다음 한 잔 마감 시각. 지났거나 없으면 nil
    var cutoffTime: Date? = nil
    var cutoffColor: Color = Theme.Colors.signalOK

    private let ink = Theme.Colors.ink

    /// 지금까지의 점(실측 구간)
    private var pastPoints: [CaffeineKineticsCalculator.DataPoint] {
        dataPoints.filter { $0.time <= currentTime }
    }

    /// 지금 이후의 점(예측 구간). 실선과 이어지도록 마지막 실측 점을 앞에 붙인다.
    private var futurePoints: [CaffeineKineticsCalculator.DataPoint] {
        let future = dataPoints.filter { $0.time > currentTime }
        if let last = pastPoints.last { return [last] + future }
        return future
    }

    var body: some View {
        Chart {
            bedtimeDangerZone
            safetyRule
            pastSeries
            futureSeries
            doseMarkers
            currentTimeRule
            cutoffRule
            bedtimeRule
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(koreanTimeLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.Colors.hairline)
                AxisValueLabel {
                    if let mg = value.as(Double.self) {
                        Text("\(Int(mg))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(height: 200)
        .accessibilityLabel("오늘 체내 카페인 타임라인")
    }

    @ChartContentBuilder
    private var pastSeries: some ChartContent {
        ForEach(pastPoints) { point in
            AreaMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg)
            )
            .foregroundStyle(ink.opacity(0.07))
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg),
                series: .value("구간", "실측")
            )
            .foregroundStyle(ink)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)
        }
    }

    @ChartContentBuilder
    private var futureSeries: some ChartContent {
        ForEach(futurePoints) { point in
            LineMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg),
                series: .value("구간", "예측")
            )
            .foregroundStyle(ink.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            .interpolationMethod(.monotone)
        }
    }

    @ChartContentBuilder
    private var doseMarkers: some ChartContent {
        ForEach(doses, id: \.timestamp) { dose in
            PointMark(
                x: .value("시간", dose.timestamp),
                y: .value("mg", 0.0)
            )
            .foregroundStyle(Theme.Colors.inkSecondary)
            .symbolSize(20)
        }
    }

    @ChartContentBuilder
    private var currentTimeRule: some ChartContent {
        if let point = pastPoints.last {
            PointMark(
                x: .value("현재", currentTime),
                y: .value("mg", point.concentrationMg)
            )
            .foregroundStyle(ink)
            .symbolSize(50)
            .annotation(position: .top, spacing: 4) {
                Text("지금")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink)
            }
        }
    }

    @ChartContentBuilder
    private var cutoffRule: some ChartContent {
        if let cutoffTime {
            RuleMark(x: .value("마감", cutoffTime))
                .foregroundStyle(cutoffColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    Text("마감")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(cutoffColor)
                }
        }
    }

    @ChartContentBuilder
    private var bedtimeRule: some ChartContent {
        if let bedtime {
            RuleMark(x: .value("취침", bedtime))
                .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    Text("취침")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
        }
    }

    @ChartContentBuilder
    private var safetyRule: some ChartContent {
        RuleMark(y: .value("안전선", AppConstants.Caffeine.bedtimeSafeThresholdMg))
            .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            .annotation(position: .top, alignment: .trailing, spacing: 2) {
                Text("안전 \(Int(AppConstants.Caffeine.bedtimeSafeThresholdMg)) mg")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
    }

    @ChartContentBuilder
    private var bedtimeDangerZone: some ChartContent {
        if let bedtime,
           let chartEnd = dataPoints.last?.time,
           bedtime < chartEnd {
            let threshold = AppConstants.Caffeine.bedtimeSafeThresholdMg
            let maxConcentration = dataPoints.map(\.concentrationMg).max() ?? threshold
            if maxConcentration > threshold {
                RectangleMark(
                    xStart: .value("취침", bedtime),
                    xEnd: .value("끝", chartEnd),
                    yStart: .value("임계", threshold),
                    yEnd: .value("최대", maxConcentration)
                )
                .foregroundStyle(Theme.Colors.signalStop.opacity(0.08))
            }
        }
    }
}
