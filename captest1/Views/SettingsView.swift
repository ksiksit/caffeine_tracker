//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsManager.self) private var settings
    @Environment(HealthKitManager.self) private var healthKit
    @Query private var allCaffeineRecords: [CaffeineRecord]
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

                    if settings.isLearningEnabled {
                        Text("슬라이더를 조작하면 자동 학습이 초기화됩니다.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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

            Section("개인화 학습") {
                Toggle(isOn: $settings.isLearningEnabled) {
                    Label("자동 학습", systemImage: "brain.head.profile")
                }
                .tint(Color("EspressoBrown"))

                if settings.isLearningEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("현재 추정 반감기")
                            Spacer()
                            Text(String(format: "%.2f h", settings.learnedHalfLifeMean))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("EspressoBrown"))
                        }
                        Text(String(format: "95%% CI: ± %.2f h",
                                    settings.halfLifeCredibleIntervalHalfWidth))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let last = settings.lastLearnedDate {
                            Text("마지막 학습: \(last, format: .dateTime.month().day())")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("아직 학습된 데이터가 없어요. 수면 기록이 쌓이면 자동으로 갱신됩니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                if healthKit.accessState == .requestCompleted {
                    Label("HealthKit 접근 요청 완료", systemImage: "heart.fill")
                        .foregroundStyle(.primary)
                } else if healthKit.accessState == .unavailable {
                    Label("건강 데이터 사용 불가", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.primary)
                } else {
                    Button {
                        Task {
                            await healthKit.requestAuthorization()
                            await healthKit.loadData()
                            // 권한 부여 직후 학습 1회 트리거
                            let learner = BayesianHalfLifeLearner(
                                settings: settings, context: modelContext
                            )
                            let summaries = healthKit.recentSummaries.isEmpty
                                ? healthKit.lastNightSummary.map { [$0] } ?? []
                                : healthKit.recentSummaries
                            let result = learner.updateMissingObservations(
                                summaries: summaries,
                                allCaffeineRecords: allCaffeineRecords
                            )
                            settings.lastLearningSkipReason = result.displayReason
                        }
                    } label: {
                        Label("HealthKit 연동", systemImage: "heart.fill")
                    }
                }
            }

            Section("알림") {
                Label("카페인 알림 설정", systemImage: "bell.fill")
            }

            Section("정보") {
                Label("앱 버전 1.0", systemImage: "info.circle")
            }
        }
        .navigationTitle("설정")
        .task {
            await healthKit.refreshAccessState()
        }
        .onAppear {
            var components = DateComponents()
            components.hour = settings.bedtimeHour
            components.minute = settings.bedtimeMinute
            bedtimeDate = Calendar.current.date(from: components) ?? Date()
        }
    }
}

#Preview {
    let s = SettingsManager()
    return NavigationStack {
        SettingsView()
    }
    .environment(s)
    .environment(HealthKitManager(settings: s))
    .modelContainer(for: [CaffeineRecord.self, HalfLifeObservation.self], inMemory: true)
}
