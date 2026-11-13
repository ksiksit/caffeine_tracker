//
//  HomeView.swift
//  captest1
//
//  Created on 3/28/26.
//
//  미니멀 방향 홈: 마감 문장 → 타임라인 → 지표 줄 → 오늘 기록, 기록 버튼은 하단 고정.
//

import SwiftUI
import Charts

struct HomeView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(CaffeineStore.self) private var store

    @State private var showingAddSheet = false
    @State private var editingRecord: CaffeineRecordDTO?
    @State private var pendingDelete: CaffeineRecordDTO?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    var body: some View {
        // 서버 결과가 없으면 cutoffResult가 nil — 판단 근거 없이 "괜찮아요"로 안내하지 않는다.
        let hero = store.cutoffResult.map {
            CutoffHeroCard(cutoffResult: $0, now: store.currentTime, referenceDoseMg: settings.referenceDoseMg)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                if let hero {
                    hero
                } else {
                    CutoffUnavailableHero(
                        failed: store.errorMessage != nil,
                        isRetrying: store.isLoading
                    ) {
                        Task { await store.refresh() }
                    }
                }

                if store.isStale, let asOf = store.today?.now {
                    staleNotice(asOf: asOf)
                }

                if !store.todayRecords.isEmpty {
                    chart(hero: hero)
                } else if store.today != nil {
                    timelinePlaceholder
                }

                metricStrip

                // today가 없을 때는 hero가, 조회 실패로 이전 값을 보여 줄 때는 staleNotice가 이미 알린다. 여기선 저장 실패 등만.
                if store.today != nil, !store.isStale, let message = store.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.signalWarn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                todayRecordsSection

                if !store.carryoverRecords.isEmpty {
                    carryoverRecordsSection
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { addButton }
        .navigationTitle("홈")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .sheet(isPresented: $showingAddSheet) {
            AddCaffeineView()
        }
        .sheet(item: $editingRecord) { record in
            AddCaffeineView(editing: record)
        }
        .task {
            await store.refresh()
        }
        .alert("기록을 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let record = pendingDelete {
                    Task { await store.delete(id: record.id) }
                }
                pendingDelete = nil
            }
            Button("취소", role: .cancel) { pendingDelete = nil }
        }
    }

    // MARK: - 차트

    private func chart(hero: CutoffHeroCard?) -> some View {
        CaffeineChartView(
            dataPoints: store.chartDataPoints,
            doses: store.chartDoses,
            currentTime: store.currentTime,
            bedtime: store.bedtime,
            cutoffTime: hero?.upcomingCutoff(at: store.currentTime),
            cutoffColor: hero?.style.color ?? Theme.Colors.signalOK,
            predictedAtBedtime: store.today?.predictedAtBedtime
        )
    }

    // MARK: - 연결 끊김 안내

    /// 마지막으로 받은 값을 보여 주는 중임을 알린다. "N분 전"은 분마다 다시 센다.
    private func staleNotice(asOf: Date) -> some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(Self.staleText(asOf: asOf, now: context.date), systemImage: "wifi.exclamationmark")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.Colors.signalWarn)
                Spacer(minLength: 8)
                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Text("다시 시도")
                    }
                }
                .font(.footnote.weight(.semibold))
                .disabled(store.isLoading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("caffeineStaleNotice")
    }

    /// "서버 연결 안 됨 · 12분 전 기준". `asOf`는 today.now — 앱이 보낸 기기 시각이라 기기 시계로 뺀다.
    static func staleText(asOf: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(asOf) / 60))
        let ago: String
        if minutes < 1 {
            ago = String(localized: "방금 전")
        } else if minutes < 60 {
            ago = String(localized: "\(minutes)분 전")
        } else {
            ago = String(localized: "\(minutes / 60)시간 전")
        }
        return String(localized: "서버 연결 안 됨 · \(ago) 기준")
    }

    // MARK: - 지표 줄

    private var metricStrip: some View {
        let limit = AppConstants.Caffeine.dailyRecommendedLimitMg
        // 서버 값이 없을 때 0 mg를 보여주면 "체내에 없음"으로 읽힌다 — 값 자리를 비운다.
        guard store.today != nil else {
            return MetricStrip([
                .init(label: "지금 체내", value: "–"),
                .init(label: "취침 시 예상", value: "–"),
                .init(label: "오늘 섭취", value: "–"),
            ])
        }
        return MetricStrip([
            .init(label: "지금 체내", value: "\(Int(store.currentResidual.rounded()))", unit: "mg"),
            .init(label: "취침 시 예상", value: "\(Int(store.predictedAtBedtime.rounded()))", unit: "mg"),
            .init(
                label: "오늘 섭취",
                value: "\(store.todayTotal)",
                unit: "/ \(limit) mg",
                valueColor: store.todayTotal > limit ? Theme.Colors.signalStop : Theme.Colors.ink
            ),
        ])
    }

    // MARK: - 기록 버튼(하단 고정)

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Label("카페인 기록", systemImage: "plus")
        }
        .buttonStyle(.primary)
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.Colors.canvas)
    }

    // MARK: - 오늘 기록

    /// 오늘 경계 이전이지만 지금 잔량에 들어 있는 기록. 합계에는 포함되지 않아도 여기서 고칠 수 있어야 한다.
    private var carryoverRecordsSection: some View {
        HealthCard("지난 24시간 기록", showsDivider: false) {
            VStack(spacing: 0) {
                ForEach(Array(store.carryoverRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        HairlineDivider()
                    }
                    recordRow(record)
                }
            }
        }
    }

    private var todayRecordsSection: some View {
        HealthCard("오늘 기록", showsDivider: false) {
            if store.today == nil {
                Text(store.errorMessage != nil ? "기록을 불러오지 못했어요." : "불러오는 중…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            } else if store.todayRecords.isEmpty {
                Text("아직 오늘 마신 기록이 없어요. 마시면 바로 기록해 두세요.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.todayRecords.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            HairlineDivider()
                        }
                        recordRow(record)
                    }
                }
            }
        }
    }

    // MARK: - 빈 타임라인

    /// 기록이 없는 날, 차트 자리를 비워 두지 않고 무엇이 생길지 알려 준다.
    private var timelinePlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.title2)
                .foregroundStyle(Theme.Colors.inkSecondary)
            Text("첫 잔을 기록하면\n오늘의 카페인 타임라인이 여기 그려져요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text("지금 몸속 카페인이 언제 빠지는지, 취침 때 얼마나 남는지 보여 줘요.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 180)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                .strokeBorder(Theme.Colors.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 기록 행

    /// 행을 탭하면 수정 화면(삭제 포함)이 열린다. 길게 누르기 메뉴는 빠른 경로로 남겨 둔다.
    private func recordRow(_ record: CaffeineRecordDTO) -> some View {
        Button {
            editingRecord = record
        } label: {
            recordRowLabel(record)
        }
        .buttonStyle(.plain)
        .accessibilityHint("탭해서 수정하거나 삭제")
        .contextMenu {
            Button {
                editingRecord = record
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDelete = record
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func recordRowLabel(_ record: CaffeineRecordDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.drinkName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Colors.ink)
                Text(Self.timeFormatter.string(from: record.timestamp))
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }

            Spacer()

            Text("\(record.amount) mg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .padding(.vertical, Theme.Spacing.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
