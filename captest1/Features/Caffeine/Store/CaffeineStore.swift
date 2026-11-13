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
    /// 보여 주는 today가 최신 조회로 확인되지 않은 값인가(기기 캐시에서 꺼냈거나 마지막 조회가 실패함).
    /// 이때 화면은 `today.now`("N분 전") 기준이라고 알린다.
    private(set) var isStale = false

    private let repository: any CaffeineRepository
    @ObservationIgnored private let cache: CaffeineTodayCache?
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var accountId: Int64?

    /// - Parameter cache: nil이면 기기에 저장하지 않는다(테스트·미리보기).
    init(repository: any CaffeineRepository, cache: CaffeineTodayCache? = nil, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.cache = cache
        self.clock = now
    }

    // MARK: - 서버 동기화

    /// 로그인한 계정을 알린다. 아직 서버 값이 없으면 이 계정의 마지막 응답(같은 날)을 꺼내 "N분 전 기준"으로 보여 준다.
    func activate(accountId: Int64) {
        if let previous = self.accountId, previous != accountId {
            today = nil
            isStale = false
        }
        self.accountId = accountId
        if let today, !isStale {
            // 계정을 알기 전에 조회가 먼저 끝났으면 지금 저장한다.
            cache?.save(today, accountId: accountId)
            return
        }
        if today == nil, let cached = cache?.load(accountId: accountId),
           CaffeineTodayCache.isUsable(cached, at: clock()) {
            today = cached
            isStale = true
        }
    }

    /// 로그아웃 시 이전 계정의 값을 지운다(기기 캐시 포함).
    func reset() {
        today = nil
        isLoading = false
        errorMessage = nil
        isStale = false
        accountId = nil
        cache?.clear()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await repository.today()
            today = fresh
            isStale = false
            errorMessage = nil
            if let accountId { cache?.save(fresh, accountId: accountId) }
        } catch is CancellationError {
            // 무시
        } catch {
            errorMessage = "현황을 불러오지 못했어요. 서버 연결을 확인해주세요."
            // 이전 값은 "N분 전 기준"으로 남기되, 하루 경계를 넘었으면 어제 기록·마감이라 버린다.
            if let today, !CaffeineTodayCache.isUsable(today, at: clock()) {
                self.today = nil
            }
            isStale = self.today != nil
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

    /// 서버 신호등 상태. 서버 값이 없거나 알 수 없는 형식이면 nil — 판단 근거 없이 "지금 OK"로 보이지 않게 한다.
    var cutoffResult: CaffeineCutoffResult? {
        guard let c = today?.cutoff else { return nil }
        switch c.status {
        case "SAFE_ANYTIME":
            return .safeAnytime
        case "CUTOFF":
            return c.cutoff.map { .cutoff($0) }
        case "ALREADY_EXCEEDED":
            return .alreadyExceeded(c.existingAtBedtime ?? 0)
        default:
            return nil
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
    var carryoverRecords: [CaffeineRecordDTO] { today?.carryoverRecords ?? [] }
    /// 서버 잔량 계산과 같은 투약 목록(최근 24시간). 미리보기가 서버 마감과 어긋나지 않게 이 값을 쓴다.
    var residualDoses: [CaffeineKineticsCalculator.Dose] {
        (carryoverRecords + todayRecords).map {
            CaffeineKineticsCalculator.Dose(timestamp: $0.timestamp, amountMg: Double($0.amount))
        }
    }
    var todayTotal: Int { today?.todayTotal ?? 0 }
    var currentResidual: Double { today?.currentResidual ?? 0 }
    var predictedAtBedtime: Double { today?.predictedAtBedtime ?? 0 }
    var currentTime: Date { today?.now ?? Date() }
}
