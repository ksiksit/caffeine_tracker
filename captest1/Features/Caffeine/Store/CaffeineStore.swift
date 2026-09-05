//
//  CaffeineStore.swift
//  captest1
//
//  홈 화면의 서버 상태 저장소. 카페인 기록 CRUD는 서버로 전송하고,
//  잔류량/마감시각 계산은 서버(/api/caffeine/today)가 settings를 읽어 수행한 결과를 보관한다.
//

import Foundation

@MainActor
@Observable
final class CaffeineStore {
    private(set) var today: CaffeineTodayResponse?
    private(set) var isLoading = false
    var errorMessage: String?

    private let repository: any CaffeineRepository

    init(repository: any CaffeineRepository) {
        self.repository = repository
    }

    // MARK: - 서버 동기화

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            today = try await repository.today()
            errorMessage = nil
        } catch is CancellationError {
            // 무시
        } catch {
            errorMessage = "현황을 불러오지 못했어요. 연결을 확인해주세요."
        }
    }

    func add(amount: Int, drinkName: String, timestamp: Date) async -> Bool {
        await mutate {
            _ = try await repository.create(
                CreateCaffeineRecordRequest(amount: amount, drinkName: drinkName, timestamp: timestamp))
        }
    }

    func update(id: Int64, amount: Int, drinkName: String, timestamp: Date) async -> Bool {
        await mutate {
            _ = try await repository.update(
                id: id, UpdateCaffeineRecordRequest(amount: amount, drinkName: drinkName, timestamp: timestamp))
        }
    }

    func delete(id: Int64) async -> Bool {
        await mutate {
            try await repository.delete(id: id)
        }
    }

    /// 쓰기 후 today를 다시 계산해 받아온다. 성공 여부 반환.
    private func mutate(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            await refresh()
            return true
        } catch {
            errorMessage = "저장에 실패했어요. 다시 시도해주세요."
            return false
        }
    }

    // MARK: - DTO → 기존 차트/카드 타입 매핑 (카드 뷰 변경 없이 재사용)

    var cutoffResult: CaffeineCutoffResult {
        guard let c = today?.cutoff else { return .safeAnytime }
        switch c.status {
        case "CUTOFF":
            if let at = c.cutoff { return .cutoff(at) }
            return .safeAnytime
        case "ALREADY_EXCEEDED":
            return .alreadyExceeded(c.existingAtBedtime ?? 0)
        default:
            return .safeAnytime
        }
    }

    var chartDataPoints: [CaffeineKineticsCalculator.DataPoint] {
        (today?.chart ?? []).enumerated().map { idx, p in
            CaffeineKineticsCalculator.DataPoint(index: idx, time: p.time, concentrationMg: p.concentrationMg)
        }
    }

    var chartDoses: [CaffeineKineticsCalculator.Dose] {
        (today?.records ?? []).map {
            CaffeineKineticsCalculator.Dose(timestamp: $0.timestamp, amountMg: Double($0.amount))
        }
    }

    /// 서버가 계산한 다음 취침시각(오늘의 설정 취침시각, 지났으면 내일). 미리보기가 로컬 계산 대신 이 값을 쓴다.
    var bedtime: Date? { today?.bedtime }
    var todayRecords: [CaffeineRecordDTO] { today?.records ?? [] }
    var todayTotal: Int { today?.todayTotal ?? 0 }
    var currentResidual: Double { today?.currentResidual ?? 0 }
    var predictedAtBedtime: Double { today?.predictedAtBedtime ?? 0 }
    var currentTime: Date { today?.now ?? Date() }
}
