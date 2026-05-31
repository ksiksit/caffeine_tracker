//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(AuthManager.self) private var auth
    @State private var bedtimeDate = Date()
    @State private var showLogoutConfirm = false

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
                            // 학습은 단계 3에서 서버(sleep·learning 도메인)로 이관 예정 — 현재 비활성.
                        }
                    } label: {
                        Label("HealthKit 연동", systemImage: "heart.fill")
                    }
                }
            }

            Section("알림") {
                Label("카페인 알림 설정", systemImage: "bell.fill")
            }

            Section("계정") {
                if case .authenticated(let me) = auth.state {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Color("EspressoBrown"))
                        Text(me.email)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("정보") {
                Label("앱 버전 1.0", systemImage: "info.circle")
            }
        }
        .navigationTitle("설정")
        .confirmationDialog(
            "정말 로그아웃하시겠어요?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("로그아웃", role: .destructive) {
                Task {
                    await auth.logout()
                    settings.resetLearnedData()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기기의 학습된 카페인 반감기 데이터도 함께 초기화됩니다.")
        }
        .task {
            await healthKit.refreshAccessState()
        }
        .onAppear {
            var components = DateComponents()
            components.hour = settings.bedtimeHour
            components.minute = settings.bedtimeMinute
            bedtimeDate = Calendar.current.date(from: components) ?? Date()
        }
        // 편집 변경 → 서버로 디바운스 동기화(server-authoritative)
        .onChange(of: settings.halfLife) { settings.scheduleSync() }
        .onChange(of: settings.conditionRawValue) { settings.scheduleSync() }
        .onChange(of: settings.isLearningEnabled) { settings.scheduleSync() }
        .onChange(of: settings.referenceDoseMg) { settings.scheduleSync() }
        .onChange(of: settings.bedtimeHour) { settings.scheduleSync() }
        .onChange(of: settings.bedtimeMinute) { settings.scheduleSync() }
    }
}

#Preview {
    let s = SettingsManager()
    let keychain = KeychainHelper(service: "preview.captest1.auth")
    let store = TokenStore(keychain: keychain)
    let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, tokenStore: store)
    return NavigationStack {
        SettingsView()
    }
    .environment(s)
    .environment(HealthKitManager(settings: s))
    .environment(AuthManager(api: client, tokenStore: store))
}
