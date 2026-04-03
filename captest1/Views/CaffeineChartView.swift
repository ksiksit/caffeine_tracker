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

    private let espressoBrown = Color("EspressoBrown")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(espressoBrown)
                Text("체내 카페인 예측")
                    .font(.headline)
            }

            chartContent
                .frame(height: 240)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }

    private var chartContent: some View {
        Chart {
            caffeineLineSeries
            doseMarkers
            currentTimeRule
            bedtimeRule
        }
        .chartXAxis {
            // Minor gridlines every 3 hours (no labels)
            AxisMarks(values: .stride(by: .hour, count: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
            // Major marks every 6 hours with Korean labels
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(koreanTimeLabel(for: date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
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
                    colors: [espressoBrown.opacity(0.3), espressoBrown.opacity(0.02)],
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
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                    )
                    .shadow(color: espressoBrown.opacity(0.3), radius: 2, y: 1)
            }
            .annotation(position: .top, spacing: 6) {
                Text("\(Int(dose.amountMg))mg")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(espressoBrown)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    @ChartContentBuilder
    private var currentTimeRule: some ChartContent {
        RuleMark(x: .value("현재", currentTime))
            .foregroundStyle(.orange.opacity(0.7))
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            .annotation(position: .top, alignment: .leading, spacing: 4) {
                Text("지금")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange, in: Capsule())
            }
    }

    @ChartContentBuilder
    private var bedtimeRule: some ChartContent {
        if let bedtime = resolvedBedtimeDate(hour: bedtimeHour, minute: bedtimeMinute) {
            RuleMark(x: .value("취침", bedtime))
                .foregroundStyle(.indigo.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 4) {
                    Text("취침")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.indigo, in: Capsule())
                }
        }
    }

}
