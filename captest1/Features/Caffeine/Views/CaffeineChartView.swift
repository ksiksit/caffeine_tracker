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
    /// 서버가 계산한 취침 시각 예상 잔량(today.predictedAtBedtime). 위험 영역 판정에 포함한다
    var predictedAtBedtime: Double? = nil

    private let ink = Theme.Colors.ink

    /// 선·영역 공통 보간. 서버 점은 섭취마다 "1초 전 점 + 섭취 점"으로 수직 상승을 표현하고,
    /// 섭취가 틱 정각이면 같은 x에 점이 두 개 생긴다. monotone은 그 두 점 사이에서 영역이 옆으로 삐져나오므로 linear를 쓴다
    /// (15분 간격 감소 구간은 직선으로 이어도 곡선과 구분되지 않는다). 선과 영역은 반드시 같은 보간을 쓴다.
    static let interpolation: InterpolationMethod = .linear

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
            bedtimeDangerEdge
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
                y: .value("mg", point.concentrationMg),
                // 기본값(standard)은 같은 x의 값을 쌓아, 틱 정각 섭취 지점에서 선 위로 가는 기둥이 솟는다
                stacking: .unstacked
            )
            .foregroundStyle(ink.opacity(0.07))
            .interpolationMethod(Self.interpolation)

            LineMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg),
                series: .value("구간", "실측")
            )
            .foregroundStyle(ink)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(Self.interpolation)
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
            .interpolationMethod(Self.interpolation)
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

    /// 취침 이후 위험 영역의 위쪽 끝. 취침 이후 최대 잔류량이 안전선 이상일 때만 값을 주고, 아니면 nil(영역을 그리지 않음).
    /// - 하루 전체 최대값으로 판정하면 낮에 많이 마시고 취침 땐 안전한 날에도 붉게 칠해진다.
    /// - 경계는 신호등과 같다: 서버는 취침 잔량이 안전선 "이상"이면 초과로 본다(headroom <= 0).
    /// - 차트 샘플은 15분 간격이라 취침이 23:10처럼 사이에 있으면 취침 순간 값이 없다. 서버가 계산한 취침 시 잔량을 함께 본다.
    static func dangerZoneTop(
        dataPoints: [CaffeineKineticsCalculator.DataPoint],
        bedtime: Date,
        threshold: Double,
        predictedAtBedtime: Double? = nil
    ) -> Double? {
        let afterBedtime = dataPoints.filter { $0.time >= bedtime }.map(\.concentrationMg)
        guard let maxAfterBedtime = (afterBedtime + [predictedAtBedtime].compactMap { $0 }).max(),
              maxAfterBedtime >= threshold else { return nil }
        return maxAfterBedtime
    }

    /// 위험 영역의 가로 범위(취침 ~ 차트 끝)와 위쪽 끝. 그리지 않으면 nil.
    private var dangerZone: (start: Date, end: Date, top: Double)? {
        guard let bedtime,
              let chartEnd = dataPoints.last?.time,
              bedtime < chartEnd,
              let top = Self.dangerZoneTop(
                dataPoints: dataPoints, bedtime: bedtime,
                threshold: AppConstants.Caffeine.bedtimeSafeThresholdMg, predictedAtBedtime: predictedAtBedtime)
        else { return nil }
        return (bedtime, chartEnd, top)
    }

    @ChartContentBuilder
    private var bedtimeDangerZone: some ChartContent {
        if let zone = dangerZone {
            RectangleMark(
                xStart: .value("취침", zone.start),
                xEnd: .value("끝", zone.end),
                yStart: .value("임계", AppConstants.Caffeine.bedtimeSafeThresholdMg),
                yEnd: .value("최대", zone.top)
            )
            .foregroundStyle(Theme.Colors.signalStop.opacity(0.08))
        }
    }

    /// 위험 영역의 아래 경계(안전선 위 취침 이후 구간)를 신호색으로 긋는다.
    /// 취침 잔량이 정확히 안전선(50 mg)이면 서버는 초과로 보지만 영역 높이가 0이라 면만으로는 보이지 않는다.
    @ChartContentBuilder
    private var bedtimeDangerEdge: some ChartContent {
        if let zone = dangerZone {
            RuleMark(
                xStart: .value("취침", zone.start),
                xEnd: .value("끝", zone.end),
                y: .value("안전선", AppConstants.Caffeine.bedtimeSafeThresholdMg)
            )
            .foregroundStyle(Theme.Colors.signalStop.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }
}
