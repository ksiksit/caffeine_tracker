//
//  CaffeineChartView.swift
//  captest1
//

import SwiftUI
import Charts

struct CaffeineChartView: View {
    let dataPoints: [CaffeineKineticsCalculator.DataPoint]
    let doses: [CaffeineKineticsCalculator.Dose]
    let currentTime: Date
    var bedtimeHour: Int = 23
    var bedtimeMinute: Int = 0

    private let espressoBrown = Theme.Colors.accent

    var body: some View {
        Chart {
            bedtimeDangerZone
            safetyRule
            caffeineLineSeries
            doseMarkers
            currentTimeRule
            bedtimeRule
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.separator))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(koreanTimeLabel(for: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.separator))
                AxisValueLabel {
                    if let mg = value.as(Double.self) {
                        Text("\(Int(mg))mg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(height: 240)
    }

    @ChartContentBuilder
    private var caffeineLineSeries: some ChartContent {
        ForEach(dataPoints) { point in
            LineMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg)
            )
            .foregroundStyle(espressoBrown)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("시간", point.time),
                y: .value("mg", point.concentrationMg)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [espressoBrown.opacity(0.2), espressoBrown.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var doseMarkers: some ChartContent {
        ForEach(doses, id: \.timestamp) { dose in
            PointMark(
                x: .value("시간", dose.timestamp),
                y: .value("mg", CaffeineKineticsCalculator.nearestConcentration(at: dose.timestamp, in: dataPoints))
            )
            .foregroundStyle(espressoBrown)
            .symbolSize(60)
            .symbol {
                Circle()
                    .fill(espressoBrown)
                    .frame(width: 8, height: 8)
            }
            .annotation(position: .top, spacing: 4) {
                Text("\(Int(dose.amountMg))mg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ChartContentBuilder
    private var currentTimeRule: some ChartContent {
        RuleMark(x: .value("현재", currentTime))
            .foregroundStyle(.orange.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1))
            .annotation(position: .top, alignment: .leading, spacing: 4) {
                Text("지금")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
    }

    @ChartContentBuilder
    private var bedtimeRule: some ChartContent {
        if let bedtime = resolvedBedtimeDate(hour: bedtimeHour, minute: bedtimeMinute) {
            RuleMark(x: .value("취침", bedtime))
                .foregroundStyle(.indigo.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, alignment: .leading, spacing: 4) {
                    Text("취침")
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
        }
    }

    @ChartContentBuilder
    private var safetyRule: some ChartContent {
        RuleMark(y: .value("안전선", AppConstants.Caffeine.bedtimeSafeThresholdMg))
            .foregroundStyle(.secondary.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .annotation(position: .top, alignment: .trailing, spacing: 2) {
                Text("안전 50mg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    @ChartContentBuilder
    private var bedtimeDangerZone: some ChartContent {
        if let bedtime = resolvedBedtimeDate(hour: bedtimeHour, minute: bedtimeMinute),
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
                .foregroundStyle(Color.red.opacity(0.10))
            }
        }
    }
}
