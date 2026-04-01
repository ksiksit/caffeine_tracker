//
//  SleepDataProcessor.swift
//  captest1
//

import Foundation

protocol SleepSampleProtocol {
    var startDate: Date { get }
    var endDate: Date { get }
    var sleepValue: Int { get }
}

struct SleepDataProcessor {

    /// 수면 단계 우선순위 (높을수록 더 세분화된 정보)
    static func stagePriority(for value: Int) -> Int {
        let stage = SleepStage(from: value)
        switch stage {
        case .asleepDeep: return 5
        case .asleepREM: return 4
        case .asleepCore: return 3
        case .asleepUnspecified: return 2
        case .awake: return 1
        case .inBed: return 0
        }
    }

    /// Apple Watch와 iPhone 양쪽에서 기록된 수면 샘플을 타임라인 기반으로 병합.
    /// 겹치는 구간에서는 가장 세분화된(우선순위 높은) 단계를 선택하고,
    /// 겹치지 않는 구간은 그대로 보존한다.
    static func mergeSamples<T: SleepSampleProtocol>(_ samples: [T]) -> [(start: Date, end: Date, sleepValue: Int)] {
        guard !samples.isEmpty else { return [] }

        // 1. 모든 시간 경계점(boundary) 수집
        var boundaries: Set<Date> = []
        for sample in samples {
            boundaries.insert(sample.startDate)
            boundaries.insert(sample.endDate)
        }
        let sortedBoundaries = boundaries.sorted()

        // 2. 각 구간별로 가장 높은 우선순위 단계 선택
        var intervals: [(start: Date, end: Date, sleepValue: Int)] = []
        for i in 0..<(sortedBoundaries.count - 1) {
            let start = sortedBoundaries[i]
            let end = sortedBoundaries[i + 1]

            // 이 구간을 완전히 포함하는 모든 샘플 찾기
            let overlapping = samples.filter { $0.startDate <= start && $0.endDate >= end }
            guard let best = overlapping.max(by: { stagePriority(for: $0.sleepValue) < stagePriority(for: $1.sleepValue) })
            else { continue }

            intervals.append((start, end, best.sleepValue))
        }

        // 3. 연속된 같은 단계 구간 병합
        var merged: [(start: Date, end: Date, sleepValue: Int)] = []
        for interval in intervals {
            if let last = merged.last, last.sleepValue == interval.sleepValue, last.end == interval.start {
                merged[merged.count - 1] = (last.start, interval.end, last.sleepValue)
            } else {
                merged.append(interval)
            }
        }

        return merged
    }
}
