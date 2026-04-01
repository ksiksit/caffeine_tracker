//
//  CaffeineKineticsCalculator.swift
//  captest1
//

import Foundation

struct CaffeineKineticsCalculator {

    struct Dose {
        let timestamp: Date
        let amountMg: Double
    }

    struct DataPoint: Identifiable, Equatable {
        let index: Int
        let time: Date
        let concentrationMg: Double

        var id: Int { index }
    }

    static func remainingAmount(
        dose: Double,
        hoursSinceDose: Double,
        halfLifeHours: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    ) -> Double {
        guard hoursSinceDose >= 0, dose > 0, halfLifeHours > 0 else { return 0 }
        let ke = log(2) / halfLifeHours
        return dose * exp(-ke * hoursSinceDose)
    }

    static func totalRemaining(
        at time: Date,
        doses: [Dose],
        halfLifeHours: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    ) -> Double {
        doses.reduce(0) { total, dose in
            let hours = time.timeIntervalSince(dose.timestamp) / 3600
            return total + remainingAmount(dose: dose.amountMg, hoursSinceDose: hours, halfLifeHours: halfLifeHours)
        }
    }

    static func generateTimeSeries(
        doses: [Dose],
        from startTime: Date,
        to endTime: Date,
        intervalMinutes: Int = AppConstants.Pharmacokinetics.chartIntervalMinutes,
        halfLifeHours: Double = AppConstants.Pharmacokinetics.defaultHalfLifeHours
    ) -> [DataPoint] {
        guard intervalMinutes > 0 else { return [] }

        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        var points: [DataPoint] = []
        var current = startTime

        // Collect dose timestamps that fall within the range for sharp transitions
        let doseTimesInRange = doses
            .map(\.timestamp)
            .filter { $0 > startTime && $0 <= endTime }
            .sorted()

        while current <= endTime {
            // Insert points just before and at each dose timestamp for sharp transitions
            for doseTime in doseTimesInRange {
                let justBefore = doseTime.addingTimeInterval(-1)
                if current < justBefore && justBefore < current.addingTimeInterval(intervalSeconds) {
                    let concBefore = totalRemaining(at: justBefore, doses: doses, halfLifeHours: halfLifeHours)
                    points.append(DataPoint(index: 0, time: justBefore, concentrationMg: concBefore))

                    let concAt = totalRemaining(at: doseTime, doses: doses, halfLifeHours: halfLifeHours)
                    points.append(DataPoint(index: 0, time: doseTime, concentrationMg: concAt))
                }
            }

            let conc = totalRemaining(at: current, doses: doses, halfLifeHours: halfLifeHours)
            points.append(DataPoint(index: 0, time: current, concentrationMg: conc))
            current = current.addingTimeInterval(intervalSeconds)
        }

        let sorted = points.sorted { $0.time < $1.time }
        return sorted.enumerated().map {
            DataPoint(index: $0.offset, time: $0.element.time, concentrationMg: $0.element.concentrationMg)
        }
    }
}
