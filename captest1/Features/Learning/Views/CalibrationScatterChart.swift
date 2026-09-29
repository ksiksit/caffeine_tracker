//
//  CalibrationScatterChart.swift
//  captest1
//
//  Calibration plot — x: 모델이 예측한 SOL, y: HealthKit 측정 SOL.
//  y=x 대각선과 ±10분 노이즈 밴드 가이드라인을 함께 표시한다.
//  점이 대각선에 모일수록 likelihood 가정이 데이터로 지지됨.
//

import SwiftUI
import Charts

/// Calibration 차트 입력 점 (예측 SOL vs 측정 SOL). 서버 대시보드 DTO에서 매핑한다.
struct CalibrationPoint: Identifiable {
    let id = UUID()
    let predicted: Double
    let observed: Double
}

struct CalibrationScatterChart: View {
    let points: [CalibrationPoint]
    let domain: ClosedRange<Double>
    /// 회색 노이즈 밴드 폭 (분). 기본 ±10 = σ_obs.
    var noiseBandMinutes: Double = 10

    var body: some View {
        Chart {
            // 1) ±10분 노이즈 밴드 — 두 점 AreaMark
            AreaMark(
                x: .value("x", domain.lowerBound),
                yStart: .value("lo", domain.lowerBound - noiseBandMinutes),
                yEnd:   .value("hi", domain.lowerBound + noiseBandMinutes),
                series: .value("series", "band")
            )
            .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.10))
            AreaMark(
                x: .value("x", domain.upperBound),
                yStart: .value("lo", domain.upperBound - noiseBandMinutes),
                yEnd:   .value("hi", domain.upperBound + noiseBandMinutes),
                series: .value("series", "band")
            )
            .foregroundStyle(Theme.Colors.inkSecondary.opacity(0.10))

            // 2) y=x 대각선 가이드라인 — 두 점 LineMark
            LineMark(
                x: .value("x", domain.lowerBound),
                y: .value("y", domain.lowerBound),
                series: .value("series", "ideal")
            )
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Theme.Colors.inkSecondary)
            LineMark(
                x: .value("x", domain.upperBound),
                y: .value("y", domain.upperBound),
                series: .value("series", "ideal")
            )
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Theme.Colors.inkSecondary)

            // 3) 데이터 점
            ForEach(points) { p in
                PointMark(
                    x: .value("예측 SOL", p.predicted),
                    y: .value("측정 SOL", p.observed)
                )
                .foregroundStyle(Theme.Colors.accent)
                .symbolSize(80)
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: domain)
        .chartXAxisLabel("예측 SOL (분)", position: .bottom, alignment: .center)
        .chartYAxisLabel("측정 SOL (분)", position: .leading, alignment: .center)
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CalibrationPreviewWrapper: View {
    let points: [CalibrationPoint]
    var body: some View {
        CalibrationScatterChart(points: points, domain: 10...55)
            .padding()
    }
}

#Preview("정상 — 대각선 근처") {
    CalibrationPreviewWrapper(points: [
        .init(predicted: 18, observed: 22),
        .init(predicted: 25, observed: 23),
        .init(predicted: 32, observed: 35),
        .init(predicted: 40, observed: 38),
        .init(predicted: 28, observed: 30),
        .init(predicted: 22, observed: 19),
        .init(predicted: 45, observed: 50)
    ])
}

#Preview("적은 데이터") {
    CalibrationPreviewWrapper(points: [
        .init(predicted: 20, observed: 25),
        .init(predicted: 30, observed: 28)
    ])
}
