//
//  HomeView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI
import Charts

struct HomeView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(CaffeineStore.self) private var store

    @State private var showingAddSheet = false
    @State private var editingRecord: CaffeineRecordDTO?
    @State private var pendingDelete: CaffeineRecordDTO?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CutoffHeroCard(
                    cutoffResult: store.cutoffResult,
                    now: store.currentTime,
                    currentResidual: store.currentResidual,
                    predictedAtBedtime: store.predictedAtBedtime,
                    referenceDoseMg: settings.referenceDoseMg,
                    todayTotalMg: store.todayTotal
                )

                addButton

                if let message = store.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !store.todayRecords.isEmpty {
                    HealthCard(
                        "시간대별 카페인",
                        symbol: "chart.line.uptrend.xyaxis",
                        tint: Theme.Colors.accent,
                        collapsible: true
                    ) {
                        CaffeineChartView(
                            dataPoints: store.chartDataPoints,
                            doses: store.chartDoses,
                            currentTime: store.currentTime,
                            bedtimeHour: settings.bedtimeHour,
                            bedtimeMinute: settings.bedtimeMinute
                        )
                    }

                    todayRecordsCard
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("홈")
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - 추가 버튼

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Label("카페인 추가", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.Colors.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.Colors.accent)
    }

    // MARK: - 오늘의 기록 카드

    private var todayRecordsCard: some View {
        HealthCard("오늘의 기록", symbol: "list.bullet", tint: Theme.Colors.accent) {
            VStack(spacing: 0) {
                ForEach(Array(store.todayRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider().padding(.leading, 44)
                    }
                    recordRow(record)
                }
            }
        }
    }

    private func recordRow(_ record: CaffeineRecordDTO) -> some View {
        HStack(spacing: 12) {
            CategoryIconBadge(symbol: "cup.and.saucer.fill", tint: Theme.Colors.accent, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.drinkName)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(record.timestamp, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(record.amount) mg")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
