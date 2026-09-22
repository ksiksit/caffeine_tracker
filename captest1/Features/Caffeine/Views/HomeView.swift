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
        let hero = CutoffHeroCard(
            cutoffResult: store.cutoffResult,
            now: store.currentTime,
            referenceDoseMg: settings.referenceDoseMg
        )

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                hero

                if !store.todayRecords.isEmpty {
                    CaffeineChartView(
                        dataPoints: store.chartDataPoints,
                        doses: store.chartDoses,
                        currentTime: store.currentTime,
                        bedtimeHour: settings.bedtimeHour,
                        bedtimeMinute: settings.bedtimeMinute,
                        cutoffTime: upcomingCutoff,
                        cutoffColor: hero.style.color
                    )
                }

                metricStrip

                if let message = store.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                todayRecordsSection
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

    /// 아직 지나지 않은 마감 시각(차트 세로선용)
    private var upcomingCutoff: Date? {
        if case .cutoff(let time) = store.cutoffResult, time > store.currentTime {
            return time
        }
        return nil
    }

    // MARK: - 지표 줄

    private var metricStrip: some View {
        let limit = AppConstants.Caffeine.dailyRecommendedLimitMg
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
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.onAccent)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    Theme.Colors.accent,
                    in: RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.Colors.canvas)
    }

    // MARK: - 오늘 기록

    private var todayRecordsSection: some View {
        HealthCard("오늘 기록", showsDivider: false) {
            if store.todayRecords.isEmpty {
                Text("아직 오늘 마신 기록이 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.todayRecords.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            Rectangle()
                                .fill(Theme.Colors.hairline)
                                .frame(height: 1)
                        }
                        recordRow(record)
                    }
                }
            }
        }
    }

    private func recordRow(_ record: CaffeineRecordDTO) -> some View {
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
        }
        .padding(.vertical, Theme.Spacing.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("길게 눌러 수정하거나 삭제")
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
}
