//
//  HomeView.swift
//  captest1
//
//  Created on 3/28/26.
//

import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsManager.self) private var settings
    @Query(sort: \CaffeineRecord.timestamp, order: .reverse)
    private var allRecords: [CaffeineRecord]

    @State private var viewModel = HomeViewModel()
    @State private var editingRecord: CaffeineRecord?
    @State private var pendingDelete: CaffeineRecord?

    private var recordsSignature: Int {
        var hasher = Hasher()
        for record in allRecords {
            hasher.combine(record.persistentModelID)
            hasher.combine(record.amount)
            hasher.combine(record.timestamp)
        }
        return hasher.finalize()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CutoffHeroCard(
                    cutoffResult: viewModel.cutoffResult,
                    now: viewModel.currentTime,
                    currentResidual: viewModel.currentResidual,
                    predictedAtBedtime: viewModel.predictedAtBedtime,
                    referenceDoseMg: settings.referenceDoseMg,
                    todayTotalMg: viewModel.todayTotal
                )

                addButton

                if !viewModel.todayRecords.isEmpty {
                    HealthCard(
                        "시간대별 카페인",
                        symbol: "chart.line.uptrend.xyaxis",
                        tint: Color("EspressoBrown")
                    ) {
                        CaffeineChartView(
                            dataPoints: viewModel.chartDataPoints,
                            doses: viewModel.chartDoses,
                            currentTime: viewModel.currentTime,
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
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddCaffeineView()
        }
        .task(id: recordsSignature) {
            viewModel.halfLife = settings.effectiveHalfLifeHours
            viewModel.bedtimeHour = settings.bedtimeHour
            viewModel.bedtimeMinute = settings.bedtimeMinute
            viewModel.referenceDoseMg = Double(settings.referenceDoseMg)
            viewModel.updateRecords(allRecords)
            await viewModel.updateChartData()
        }
        .sheet(item: $editingRecord) { record in
            AddCaffeineView(editing: record)
        }
        .alert("기록을 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let record = pendingDelete {
                    modelContext.delete(record)
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("취소", role: .cancel) { pendingDelete = nil }
        }
        .onChange(of: settings.halfLife) {
            viewModel.halfLife = settings.effectiveHalfLifeHours
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.learnedHalfLifeMean) {
            viewModel.halfLife = settings.effectiveHalfLifeHours
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.isLearningEnabled) {
            viewModel.halfLife = settings.effectiveHalfLifeHours
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.conditionRawValue) {
            viewModel.halfLife = settings.effectiveHalfLifeHours
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.bedtimeHour) {
            viewModel.bedtimeHour = settings.bedtimeHour
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.bedtimeMinute) {
            viewModel.bedtimeMinute = settings.bedtimeMinute
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: settings.referenceDoseMg) {
            viewModel.referenceDoseMg = Double(settings.referenceDoseMg)
            Task { await viewModel.updateChartData() }
        }
    }

    // MARK: - 추가 버튼

    private var addButton: some View {
        Button {
            viewModel.showingAddSheet = true
        } label: {
            Label("카페인 추가", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color("EspressoBrown"))
    }

    // MARK: - 오늘의 기록 카드

    private var todayRecordsCard: some View {
        HealthCard("오늘의 기록", symbol: "list.bullet", tint: Color("EspressoBrown")) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.todayRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider().padding(.leading, 44)
                    }
                    recordRow(record)
                }
            }
        }
    }

    private func recordRow(_ record: CaffeineRecord) -> some View {
        HStack(spacing: 12) {
            CategoryIconBadge(symbol: "cup.and.saucer.fill", tint: Color("EspressoBrown"), size: 32)

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

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: CaffeineRecord.self, inMemory: true)
    .environment(SettingsManager())
}
