//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("caffeineHalfLife") private var halfLife: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours

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

                    Text("일반 성인 평균 5시간. 흡연자는 더 짧고, 임산부는 더 길 수 있습니다.")
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
