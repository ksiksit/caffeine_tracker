//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("caffeineHalfLife") private var halfLife: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    @AppStorage("caffeineCondition") private var conditionRawValue: Int = CaffeineCondition.none.rawValue
    @AppStorage("bedtimeHour") private var bedtimeHour: Int = 23
    @AppStorage("bedtimeMinute") private var bedtimeMinute: Int = 0
    @State private var bedtimeDate = Date()

    private var condition: CaffeineCondition {
        CaffeineCondition(rawValue: conditionRawValue) ?? .none
    }

    var body: some View {
        List {
            Section("카페인 대사") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("카페인 반감기", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(String(format: "%.1f시간", halfLife))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $halfLife,
                        in: AppConstants.Pharmacokinetics.minHalfLifeHours...AppConstants.Pharmacokinetics.maxHalfLifeHours,
                        step: 0.5
                    )
                    .tint(.brown)

                    Text("일반 성인 평균 5시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("건강 상태", systemImage: "heart.text.square")
                        Spacer()
                        Picker("건강 상태", selection: $conditionRawValue) {
                            ForEach(CaffeineCondition.allCases) { c in
                                Text(c.label).tag(c.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if condition != .none {
                        Text(condition.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("적용된 반감기")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f시간", effectiveHalfLife(base: halfLife, condition: condition)))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.brown)
                        }
                    }
                }
            }

            Section("수면") {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        selection: $bedtimeDate,
                        displayedComponents: .hourAndMinute
                    ) {
                        Label("취침 시간", systemImage: "moon.fill")
                    }
                    .onChange(of: bedtimeDate) {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
                        bedtimeHour = components.hour ?? 23
                        bedtimeMinute = components.minute ?? 0
                    }

                    Text("취침 시간을 설정하면 카페인 차트에 표시됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("건강 데이터") {
                Label("HealthKit 연동", systemImage: "heart.fill")
            }

            Section("알림") {
                Label("카페인 알림 설정", systemImage: "bell.fill")
            }

            Section("정보") {
                Label("앱 버전 1.0", systemImage: "info.circle")
            }
        }
        .navigationTitle("설정")
        .onAppear {
            var components = DateComponents()
            components.hour = bedtimeHour
            components.minute = bedtimeMinute
            bedtimeDate = Calendar.current.date(from: components) ?? Date()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
