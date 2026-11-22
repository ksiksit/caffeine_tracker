//
//  CutoffPreviewTests.swift
//  captest1Tests
//
//  카페인 추가·수정 화면의 미리보기(마감 시각 변화, 하루 권장량 초과 경고) 검증.
//

import Foundation
import Testing
@testable import captest1

// 반감기 5시간·기준 75mg·취침 10시간 뒤. 2시간 전 100mg 한 잔이면 취침 시 약 19mg이라 마감은 약 3.6시간 뒤다.
@MainActor
struct CutoffPreviewEditTests {
    private let now = Date()
    private var bedtime: Date { now.addingTimeInterval(10 * 3600) }
    private var record: CaffeineRecordDTO {
        .fixture(id: 1, amount: 100, drinkName: "테스트 음료", timestamp: now.addingTimeInterval(-2 * 3600))
    }

    private func preview(_ vm: AddCaffeineViewModel, records: [CaffeineRecordDTO])
        -> (current: CaffeineCutoffResult, projected: CaffeineCutoffResult)? {
        vm.previewCutoff(records: records, halfLifeHours: 5, bedtime: bedtime, referenceDoseMg: 75)
    }

    private func cutoff(_ doses: [CaffeineKineticsCalculator.Dose]) -> CaffeineCutoffResult {
        caffeineCutoffTime(currentDoses: doses, bedtime: bedtime, referenceDoseMg: 75, halfLifeHours: 5)
    }

    @Test func edit_unchanged_showsNoPreview() {
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(record)
        #expect(preview(vm, records: [record]) == nil)
    }

    @Test func edit_nameOnlyChange_showsNoPreview() {
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(record)
        vm.customName = "다른 이름"
        #expect(preview(vm, records: [record]) == nil)
    }

    @Test func edit_amountChange_replacesOwnRecordInsteadOfAdding() throws {
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(record)
        vm.customAmount = "10"

        let result = try #require(preview(vm, records: [record]))
        // 현재 = 고치기 전 기록 그대로, 예상 = 자기 기록을 빼고 고친 값만.
        #expect(result.current == cutoff([.init(timestamp: record.timestamp, amountMg: 100)]))
        #expect(result.projected == cutoff([.init(timestamp: record.timestamp, amountMg: 10)]))
        guard case .cutoff(let before) = result.current, case .cutoff(let after) = result.projected else {
            Issue.record("둘 다 마감 시각이 나와야 한다: \(result)")
            return
        }
        #expect(after > before)
    }

    @Test func edit_largerAmount_exceedsAtBedtime() throws {
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(record)
        vm.customAmount = "300"

        let result = try #require(preview(vm, records: [record]))
        // 300mg 한 잔만이면 취침 시 약 57mg. 원래 100mg을 더한 400mg(약 76mg)이 아니다.
        guard case .alreadyExceeded(let mg) = result.projected else {
            Issue.record("취침 시 초과가 나와야 한다: \(result.projected)")
            return
        }
        #expect(abs(mg - 300 * pow(2, -12.0 / 5)) < 0.001)
    }

    @Test func edit_timeChange_keepsOtherRecords() throws {
        let other = CaffeineRecordDTO.fixture(id: 2, amount: 50, timestamp: now.addingTimeInterval(-5 * 3600))
        let vm = AddCaffeineViewModel()
        vm.loadForEdit(record)
        let moved = now.addingTimeInterval(-1 * 3600)
        vm.selectedDate = moved

        let result = try #require(preview(vm, records: [other, record]))
        #expect(result.projected == cutoff([
            .init(timestamp: other.timestamp, amountMg: 50),
            .init(timestamp: moved, amountMg: 100),
        ]))
    }

    @Test func add_appendsToExistingRecords() throws {
        let vm = AddCaffeineViewModel()
        vm.activateCustomMode()
        vm.customAmount = "80"
        vm.selectedDate = now
        vm.isTimeEdited = true

        let result = try #require(preview(vm, records: [record]))
        #expect(result.current == cutoff([.init(timestamp: record.timestamp, amountMg: 100)]))
        #expect(result.projected == cutoff([
            .init(timestamp: record.timestamp, amountMg: 100),
            .init(timestamp: now, amountMg: 80),
        ]))
    }

    @Test func add_withoutAmount_showsNoPreview() {
        let vm = AddCaffeineViewModel()
        #expect(preview(vm, records: [record]) == nil)
    }
}

@MainActor
struct DailyTotalPreviewTests {
    private let calendar = Calendar.current
    /// 오늘 14시(서버 today의 기준 시각 역할).
    private var today: Date { calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())! }
    private func at(hour: Int) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today)! }

    private func addingVM(amount: Int, at time: Date) -> AddCaffeineViewModel {
        let vm = AddCaffeineViewModel()
        vm.activateCustomMode()
        vm.customAmount = String(amount)
        vm.selectedDate = time
        vm.isTimeEdited = true
        return vm
    }

    private func overLimit(_ vm: AddCaffeineViewModel, records: [CaffeineRecordDTO]) -> Int? {
        vm.previewDailyTotalOverLimit(
            todayRecords: records, todayTotal: records.reduce(0) { $0 + $1.amount },
            today: today, calendar: calendar)
    }

    @Test func add_overLimit_returnsProjectedTotal() {
        let records = [CaffeineRecordDTO.fixture(id: 1, amount: 300, timestamp: at(hour: 9))]
        #expect(overLimit(addingVM(amount: 150, at: at(hour: 13)), records: records) == 450)
    }

    @Test func add_exactlyAtLimit_noWarning() {
        let records = [CaffeineRecordDTO.fixture(id: 1, amount: 300, timestamp: at(hour: 9))]
        #expect(overLimit(addingVM(amount: 100, at: at(hour: 13)), records: records) == nil)
    }

    @Test func add_beforeDayBoundary_isNotCountedToday() {
        // 새벽 3시는 서버 기준 어제(5시 경계)라 오늘 합계에 들어가지 않는다.
        let records = [CaffeineRecordDTO.fixture(id: 1, amount: 300, timestamp: at(hour: 9))]
        #expect(overLimit(addingVM(amount: 150, at: at(hour: 3)), records: records) == nil)
    }

    @Test func add_withoutAmount_noWarning() {
        let records = [CaffeineRecordDTO.fixture(id: 1, amount: 500, timestamp: at(hour: 9))]
        #expect(overLimit(AddCaffeineViewModel(), records: records) == nil)
    }

    @Test func edit_subtractsOwnAmount() {
        let editing = CaffeineRecordDTO.fixture(id: 1, amount: 200, drinkName: "테스트 음료", timestamp: at(hour: 9))
        let records = [editing, .fixture(id: 2, amount: 150, timestamp: at(hour: 11))]

        let vm = AddCaffeineViewModel()
        vm.loadForEdit(editing)
        #expect(overLimit(vm, records: records) == nil)   // 안 바꿨으면 경고 없음

        vm.customAmount = "250"
        #expect(overLimit(vm, records: records) == nil)   // 150 + 250 = 400, 초과 아님

        vm.customAmount = "300"
        #expect(overLimit(vm, records: records) == 450)   // 200을 빼고 300을 더한다(650이 아님)
    }

    @Test func edit_recordOutsideToday_movedIntoToday_addsAmount() {
        // 어제(5시 이전) 기록은 오늘 합계에 없었으므로 뺄 것이 없다.
        let editing = CaffeineRecordDTO.fixture(id: 9, amount: 200, drinkName: "테스트 음료", timestamp: at(hour: 3))
        let records = [CaffeineRecordDTO.fixture(id: 2, amount: 250, timestamp: at(hour: 11))]

        let vm = AddCaffeineViewModel()
        vm.loadForEdit(editing)
        vm.selectedDate = at(hour: 10)
        #expect(overLimit(vm, records: records) == 450)
    }
}

@MainActor
struct CutoffPreviewBannerLineTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func later(_ hours: Double) -> Date { now.addingTimeInterval(hours * 3600) }

    private func line(_ current: CaffeineCutoffResult, _ projected: CaffeineCutoffResult, editing: Bool)
        -> CutoffPreviewBanner.Line? {
        CutoffPreviewBanner.cutoffLine(current: current, projected: projected, isEditing: editing, now: now)
    }

    @Test func exceeded_wordingFollowsMode() {
        let adding = line(.cutoff(later(2)), .alreadyExceeded(56.8), editing: false)
        #expect(adding?.isWarning == true)
        #expect(adding?.message == "추가하면 취침 시 57 mg — 수면에 영향")

        let editing = line(.cutoff(later(2)), .alreadyExceeded(56.8), editing: true)
        #expect(editing?.message == "수정하면 취침 시 57 mg — 수면에 영향")
    }

    @Test func cutoffMoved_showsBothTimes_andIgnoresSmallChange() {
        let moved = line(.cutoff(later(3)), .cutoff(later(1)), editing: true)
        #expect(moved?.isWarning == false)
        #expect(moved?.message.contains("→") == true)

        #expect(line(.cutoff(later(3)), .cutoff(later(3).addingTimeInterval(120)), editing: true) == nil)
    }

    @Test func pastCutoff_isWarning() {
        let result = line(.cutoff(later(1)), .cutoff(later(-1)), editing: true)
        #expect(result?.isWarning == true)
        #expect(result?.message == "수정하면 마감이 이미 지난 시각이 됩니다")
    }

    @Test func edit_relaxingCases_areInfo() {
        let freed = line(.cutoff(later(2)), .safeAnytime, editing: true)
        #expect(freed?.isWarning == false)
        #expect(freed?.message.hasSuffix("→ 마감 자유") == true)

        let fromExceeded = line(.alreadyExceeded(80), .safeAnytime, editing: true)
        #expect(fromExceeded?.message == "수정하면 마감 자유")

        let toCutoff = line(.alreadyExceeded(80), .cutoff(later(2)), editing: true)
        #expect(toCutoff?.isWarning == false)
        #expect(toCutoff?.message.hasPrefix("수정하면 ") == true)
        #expect(toCutoff?.message.hasSuffix("까지 OK") == true)
    }

    @Test func safeToSafe_showsNothing() {
        #expect(line(.safeAnytime, .safeAnytime, editing: false) == nil)
    }

    @Test func dailyTotalLine_wording() {
        #expect(CutoffPreviewBanner.dailyTotalLine(overLimitTotalMg: nil, isEditing: false) == nil)
        let adding = CutoffPreviewBanner.dailyTotalLine(overLimitTotalMg: 450, isEditing: false)
        #expect(adding?.isWarning == true)
        #expect(adding?.message == "추가하면 오늘 총 450 mg — 하루 권장 400 mg 초과")
        let editing = CutoffPreviewBanner.dailyTotalLine(overLimitTotalMg: 420, isEditing: true)
        #expect(editing?.message == "수정하면 오늘 총 420 mg — 하루 권장 400 mg 초과")
    }
}
