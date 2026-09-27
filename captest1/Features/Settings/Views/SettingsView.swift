//
//  SettingsView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI

/// `NotificationStatus`: "알림" 섹션 맨 위에 들어갈 권한 상태 줄. 알림 기능의 화면이라 App 조립층이 끼워 넣는다
/// (설정 기능이 다른 기능을 직접 참조하지 않게 — CLAUDE.md 의존 규칙 2).
struct SettingsView<NotificationStatus: View>: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(SleepStore.self) private var sleepStore
    @Environment(AuthManager.self) private var auth
    @State private var bedtimeDate = Date()
    @State private var showLogoutConfirm = false
    private let notificationStatus: NotificationStatus

    init(@ViewBuilder notificationStatus: () -> NotificationStatus) {
        self.notificationStatus = notificationStatus()
    }

    var body: some View {
        @Bindable var settings = settings
        List {
            Section("카페인 대사") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("카페인 반감기", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(String(format: "%.1f시간", settings.halfLife))
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }

                    Slider(
                        value: $settings.halfLife,
                        in: AppConstants.Pharmacokinetics.minHalfLifeHours...AppConstants.Pharmacokinetics.maxHalfLifeHours,
                        step: 0.5
                    )
                    .tint(Theme.Colors.accent)

                    Text("일반 성인 평균 5시간")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)

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
                            .foregroundStyle(Theme.Colors.inkSecondary)

                        HStack {
                            Text("적용된 반감기")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f시간", settings.effectiveHalfLifeHours))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }
            }

            Section("개인화 학습") {
                Toggle(isOn: $settings.isLearningEnabled) {
                    Label("자동 학습", systemImage: "brain.head.profile")
                }
                .tint(Theme.Colors.signalOK)

                if settings.isLearningEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("현재 추정 반감기")
                            Spacer()
                            Text(String(format: "%.2f h", settings.learnedHalfLifeMean))
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        Text(String(format: "95%% CI: ± %.2f h",
                                    settings.halfLifeCredibleIntervalHalfWidth))
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                        if let last = settings.lastLearnedDate {
                            Text("마지막 학습: \(last, format: .dateTime.month().day())")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("아직 학습된 데이터가 없어요. 수면 기록이 쌓이면 자동으로 갱신됩니다.")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.inkSecondary)
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
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Stepper(value: $settings.referenceDoseMg, in: 20...300, step: 5) {
                        HStack {
                            Label("기준 섭취량", systemImage: "cup.and.saucer")
                            Spacer()
                            Text("\(settings.referenceDoseMg) mg")
                                .foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }

                    Text("홈 화면의 카페인 마감 시간 계산에 사용됩니다. (아메리카노 1잔 ≈ 75 mg)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
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
                            if healthKit.canAttemptDataLoad {
                                await sleepStore.loadData()
                            }
                        }
                    } label: {
                        Label("HealthKit 연동", systemImage: "heart.fill")
                    }
                }
            }

            Section {
                notificationStatus

                Toggle(isOn: $settings.notifyCutoff) {
                    Label("섭취 마감 30분 전", systemImage: "hourglass")
                }
                .tint(Theme.Colors.signalOK)

                Toggle(isOn: $settings.notifyBedtimeResidual) {
                    Label("취침 1시간 전 잔량 예고", systemImage: "moon.zzz")
                }
                .tint(Theme.Colors.signalOK)

                Toggle(isOn: $settings.notifyRecordReminder) {
                    Label("기록 리마인더", systemImage: "square.and.pencil")
                }
                .tint(Theme.Colors.signalOK)
            } header: {
                Text("알림")
            } footer: {
                Text("잔량 예고는 취침 때 50mg 이상 남을 것 같을 때만, 기록 리마인더는 평소 첫 잔보다 2시간이 지나도록 기록이 없을 때만 울려요.")
            }

            Section("계정") {
                if case .authenticated(let me) = auth.state {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(Theme.Colors.accent)
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas.ignoresSafeArea())
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
        .onChange(of: settings.notifyCutoff) { settings.scheduleSync() }
        .onChange(of: settings.notifyBedtimeResidual) { settings.scheduleSync() }
        .onChange(of: settings.notifyRecordReminder) { settings.scheduleSync() }
    }
}

extension SettingsView where NotificationStatus == EmptyView {
    /// 권한 상태 줄 없이(프리뷰 등).
    init() {
        self.init { EmptyView() }
    }
}

#Preview {
    let s = SettingsManager()
    let tokenStore = TokenStore(keychain: KeychainHelper(service: "preview.captest1.auth"))
    return NavigationStack {
        SettingsView()
    }
    .environment(s)
    .environment(HealthKitManager())
    .environment(SleepStore(samples: PreviewSleepSampleSource(), repository: PreviewSleepRepository()))
    .environment(AuthManager(repository: PreviewAuthRepository(), session: PreviewAuthSession(), tokenStore: tokenStore))
}
