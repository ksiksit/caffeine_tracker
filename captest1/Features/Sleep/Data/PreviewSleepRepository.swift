//
//  PreviewSleepRepository.swift
//  captest1
//
//  #Preview용 수면 페이크: HealthKit 샘플 없이 서버 요약 하나를 흉내 낸다.
//

#if DEBUG
import Foundation
import HealthKit

nonisolated struct PreviewSleepSampleSource: SleepSampleSource {
    func fetchRawSamples(for date: Date) async throws -> [RawSleepSample] { [] }
}

nonisolated struct PreviewSleepRepository: SleepRepository {
    func uploadSamples(_ req: UploadSleepSamplesRequest) async throws -> UploadSleepSamplesResponse {
        UploadSleepSamplesResponse(received: req.samples.count, inserted: 0)
    }

    func summary(date: String, timeZone: TimeZone) async throws -> SleepSummaryResponse {
        SleepSummaryResponse(
            date: date,
            hasData: true,
            bedtimeStart: Date().addingTimeInterval(-9 * 3600),
            records: [],
            totalSleepSeconds: 6.5 * 3600,
            timeInBedSeconds: 7.25 * 3600,
            sleepEfficiency: 0.9,
            sleepOnsetLatencySeconds: 18 * 60,
            stageBreakdown: [
                SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.awake.rawValue, durationSeconds: 0.75 * 3600),
                SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.asleepCore.rawValue, durationSeconds: 3.4 * 3600),
                SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.asleepDeep.rawValue, durationSeconds: 1.2 * 3600),
                SleepStageItem(hkValue: HKCategoryValueSleepAnalysis.asleepREM.rawValue, durationSeconds: 1.9 * 3600),
            ]
        )
    }
}
#endif
