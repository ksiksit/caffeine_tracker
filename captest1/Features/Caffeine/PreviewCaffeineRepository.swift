//
//  PreviewCaffeineRepository.swift
//  captest1
//
//  #Preview용 카페인 페이크: 오늘 기록 2건과 서버 계산 결과를 흉내 낸다.
//

#if DEBUG
import Foundation

nonisolated struct PreviewCaffeineRepository: CaffeineRepository {
    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse {
        let records = [
            CaffeineRecordDTO(id: 1, amount: 150, drinkName: "아메리카노", timestamp: now.addingTimeInterval(-3 * 3600)),
            CaffeineRecordDTO(id: 2, amount: 75, drinkName: "에스프레소", timestamp: now.addingTimeInterval(-1 * 3600)),
        ]
        let chart = stride(from: -4, through: 20, by: 1).map { h in
            ChartPointDTO(
                time: now.addingTimeInterval(Double(h) * 3600),
                concentrationMg: max(0, 180 - Double(h + 4) * 9)
            )
        }
        return CaffeineTodayResponse(
            now: now,
            bedtime: now.addingTimeInterval(6 * 3600),
            records: records,
            todayTotal: 225,
            overDailyLimit: false,
            chart: chart,
            currentResidual: 140,
            predictedAtBedtime: 62,
            cutoff: CutoffDTO(status: "CUTOFF", cutoff: now.addingTimeInterval(2 * 3600), existingAtBedtime: nil),
            effectiveHalfLifeHours: 5,
            referenceDoseMg: 75
        )
    }

    func create(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        CaffeineRecordDTO(id: Int64(Date().timeIntervalSince1970), amount: req.amount, drinkName: req.drinkName, timestamp: req.timestamp)
    }

    func update(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO {
        CaffeineRecordDTO(id: id, amount: req.amount, drinkName: req.drinkName, timestamp: req.timestamp)
    }

    func delete(id: Int64) async throws {}
}
#endif
