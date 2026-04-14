//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @State private var bedtimeDate = Date()

    var body: some View {
        @Bindable var settings = settings
        List {
            Section("카페인 대사") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("카페인 반감기", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(String(format: "%.1f시간", settings.halfLife))
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $settings.halfLife,
                        in: AppConstants.Pharmacokinetics.minHalfLifeHours...AppConstants.Pharmacokinetics.maxHalfLifeHours,
                        step: 0.5
                    )
                    .tint(Color("EspressoBrown"))

                    Text("일반 성인 평균 5시간")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("건강 상태", systemImage: "heart.text.square")
                        Spacer()
                        Picker("건강 상태", selection: $settings.conditionRawValue) {
                            ForEach(CaffeineCondition.allCases) { c in
                                Text(c.label).tag(c.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if settings.condition != .none {
                        Text(settings.condition.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("적용된 반감기")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f시간", settings.effectiveHalfLifeHours))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("EspressoBrown"))
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
                        settings.bedtimeHour = components.hour ?? 23
                        settings.bedtimeMinute = components.minute ?? 0
                    }

                    Text("취침 시간을 설정하면 카페인 차트에 표시됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $settings.referenceDoseMg, in: 20...300, step: 5) {
                        HStack {
                            Label("기준 섭취량", systemImage: "cup.and.saucer")
                            Spacer()
                            Text("\(settings.referenceDoseMg) mg")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("홈 화면의 카페인 마감 시간 계산에 사용됩니다. (아메리카노 1잔 ≈ 75 mg)")
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
            components.hour = settings.bedtimeHour
            components.minute = settings.bedtimeMinute
            bedtimeDate = Calendar.current.date(from: components) ?? Date()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SettingsManager())
}
