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
    @Query(sort: \CaffeineRecord.timestamp, order: .reverse)
    private var allRecords: [CaffeineRecord]

    @AppStorage("caffeineHalfLife") private var halfLife: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    @AppStorage("caffeineCondition") private var conditionRawValue: Int = CaffeineCondition.none.rawValue
    @AppStorage("bedtimeHour") private var bedtimeHour: Int = 23
    @AppStorage("bedtimeMinute") private var bedtimeMinute: Int = 0
    @State private var viewModel = HomeViewModel()

    private var effectiveHL: Double {
        let condition = CaffeineCondition(rawValue: conditionRawValue) ?? .none
        return effectiveHalfLife(base: halfLife, condition: condition)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("EspressoBrown"))

                Text("오늘의 카페인")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(viewModel.todayTotal) mg")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text(viewModel.todayRecords.isEmpty ? "카페인 섭취를 기록하세요" : "일일 권장량: \(AppConstants.Caffeine.dailyRecommendedLimitMg) mg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.showingAddSheet = true
                } label: {
                    Label("카페인 추가", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("EspressoBrown"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if !viewModel.todayRecords.isEmpty {
                    CaffeineChartView(
                        dataPoints: viewModel.chartDataPoints,
                        doses: viewModel.chartDoses,
                        currentTime: viewModel.currentTime,
                        bedtimeHour: bedtimeHour,
                        bedtimeMinute: bedtimeMinute
                    )
                }

                if !viewModel.todayRecords.isEmpty {
                    todayRecordsSection
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("홈")
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddCaffeineView()
        }
        .task(id: allRecords.count) {
            viewModel.halfLife = effectiveHL
            viewModel.updateRecords(allRecords)
            await viewModel.updateChartData()
        }
        .onChange(of: halfLife) {
            viewModel.halfLife = effectiveHL
            Task { await viewModel.updateChartData() }
        }
        .onChange(of: conditionRawValue) {
            viewModel.halfLife = effectiveHL
            Task { await viewModel.updateChartData() }
        }
    }

    private var todayRecordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 기록")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(viewModel.todayRecords) { record in
                HStack {
                    Text(record.drinkName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(record.amount) mg")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(record.timestamp, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: CaffeineRecord.self, inMemory: true)
}
