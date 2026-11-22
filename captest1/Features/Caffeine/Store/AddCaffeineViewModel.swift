//
//  AddCaffeineViewModel.swift
//  captest1
//

import Foundation

@MainActor @Observable
final class AddCaffeineViewModel {
    // MARK: - 입력 상태
    var selectedPreset: DrinkPreset?
    var customAmount: String = ""
    var customName: String = ""
    var isCustomMode: Bool = false
    var showingSaveError: Bool = false

    // MARK: - 섭취 시각 / 편집 모드
    var editingRecord: CaffeineRecordDTO?
    var selectedDate: Date = .now
    /// 사용자가 섭취 시각을 직접 바꿨는가. 신규 추가에서 안 바꿨으면 저장 순간의 "지금"을 쓴다(시트를 오래 열어 둔 경우 대비).
    var isTimeEdited: Bool = false

    /// 기록에 쓸 섭취 시각. 편집이거나 직접 고른 경우 선택값, 아니면 지금.
    func intakeTime(now: Date = Date()) -> Date {
        editingRecord != nil || isTimeEdited ? selectedDate : now
    }

    // MARK: - 유효성 검증
    var parsedAmount: Int? {
        guard let value = Int(customAmount), value > 0,
              value <= AppConstants.Caffeine.maxCustomAmountMg else { return nil }
        return value
    }

    /// 공백만 입력한 이름은 비어 있는 것으로 본다(서버 @NotBlank).
    private var trimmedCustomName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 서버 @Size 는 UTF-16 길이로 잰다.
    private var isCustomNameTooLong: Bool {
        trimmedCustomName.utf16.count > AppConstants.Caffeine.maxDrinkNameLength
    }

    var canSave: Bool {
        if isCustomMode { return parsedAmount != nil && !isCustomNameTooLong }
        return selectedPreset != nil
    }

    /// 하단 저장 버튼 문구. 무엇이 기록될지 버튼에 바로 보여주고, 못 누르는 이유도 버튼이 말한다.
    var saveButtonTitle: String {
        if editingRecord != nil { return "저장" }
        if isCustomMode {
            guard let amount = parsedAmount else { return "카페인 양을 입력하세요" }
            return "\(trimmedCustomName.isEmpty ? "직접 입력" : trimmedCustomName) \(amount) mg 추가"
        }
        guard let preset = selectedPreset else { return "음료를 선택하세요" }
        return "\(preset.name) \(preset.caffeineAmount) mg 추가"
    }

    // MARK: - 마감시각 미리보기

    /// 지금 입력한 양(직접 입력이면 입력값, 아니면 고른 프리셋). 없으면 nil.
    private var pendingAmount: Int? {
        if isCustomMode { return parsedAmount }
        return selectedPreset?.caffeineAmount
    }

    /// 미리보기에 쓸 양. 수정 모드에서 양·시각을 아직 안 바꿨으면 바뀔 것이 없으므로 nil.
    private func previewAmount() -> Int? {
        guard let amount = pendingAmount else { return nil }
        if let editing = editingRecord, amount == editing.amount, selectedDate == editing.timestamp {
            return nil
        }
        return amount
    }

    /// "이대로 저장하면 마감시각이 어떻게 바뀌는지" 계산.
    /// 신규 추가는 기존 기록에 새 기록을 더하고, 수정은 고치는 기록을 빼고 고친 값을 넣는다.
    /// - Parameter records: 서버 잔량 계산에 들어간 기록(최근 24시간). 수정 중인 기록도 들어 있다.
    func previewCutoff(
        records: [CaffeineRecordDTO],
        halfLifeHours: Double,
        bedtime: Date,
        referenceDoseMg: Double
    ) -> (current: CaffeineCutoffResult, projected: CaffeineCutoffResult)? {
        guard let amount = previewAmount() else { return nil }

        func doses(_ list: [CaffeineRecordDTO]) -> [CaffeineKineticsCalculator.Dose] {
            list.map { CaffeineKineticsCalculator.Dose(timestamp: $0.timestamp, amountMg: Double($0.amount)) }
        }

        let current = caffeineCutoffTime(
            currentDoses: doses(records),
            bedtime: bedtime,
            referenceDoseMg: referenceDoseMg,
            halfLifeHours: halfLifeHours
        )

        let others = records.filter { $0.id != editingRecord?.id }
        let pendingDose = CaffeineKineticsCalculator.Dose(
            timestamp: intakeTime(), amountMg: Double(amount)
        )
        let projected = caffeineCutoffTime(
            currentDoses: doses(others) + [pendingDose],
            bedtime: bedtime,
            referenceDoseMg: referenceDoseMg,
            halfLifeHours: halfLifeHours
        )

        return (current, projected)
    }

    /// 이대로 저장하면 오늘 총량이 하루 권장량을 넘는가. 넘으면 그 총량(mg), 아니면 nil.
    /// 서버가 준 오늘 합계에 더하고 빼기만 한다. 섭취 시각이 오늘(새벽 5시 경계) 밖이면 오늘 합계에 들어가지 않으므로 경고하지 않는다.
    /// - Parameters:
    ///   - todayRecords: 서버가 오늘 합계에 넣은 기록.
    ///   - todayTotal: 서버가 계산한 오늘 합계.
    ///   - today: 서버 today의 기준 시각(`now`). 이 시각이 속한 날이 "오늘"이다.
    func previewDailyTotalOverLimit(
        todayRecords: [CaffeineRecordDTO],
        todayTotal: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Int? {
        guard let amount = previewAmount() else { return nil }
        let isToday = CaffeineTodayCache.dayStart(of: intakeTime(), calendar: calendar)
            == CaffeineTodayCache.dayStart(of: today, calendar: calendar)
        guard isToday else { return nil }

        var total = todayTotal + amount
        if let editing = editingRecord, let original = todayRecords.first(where: { $0.id == editing.id }) {
            total -= original.amount
        }
        return total > AppConstants.Caffeine.dailyRecommendedLimitMg ? total : nil
    }

    var validationMessage: String? {
        guard isCustomMode else { return nil }
        if isCustomNameTooLong {
            return "음료 이름은 \(AppConstants.Caffeine.maxDrinkNameLength)자 이하로 입력해 주세요"
        }
        guard !customAmount.isEmpty else { return nil }
        if Int(customAmount) == nil {
            return "숫자만 입력해 주세요"
        }
        if let value = Int(customAmount), value <= 0 {
            return "1 이상의 값을 입력해 주세요"
        }
        if let value = Int(customAmount), value > AppConstants.Caffeine.maxCustomAmountMg {
            return "\(AppConstants.Caffeine.maxCustomAmountMg) mg 이하로 입력해 주세요"
        }
        return nil
    }

    // MARK: - 액션
    func selectPreset(_ preset: DrinkPreset) {
        selectedPreset = preset
        isCustomMode = false
    }

    func activateCustomMode() {
        isCustomMode = true
        selectedPreset = nil
    }

    func filterCustomAmount(_ newValue: String) {
        let filtered = newValue.filter(\.isNumber)
        if filtered != newValue { customAmount = filtered }
    }

    func loadForEdit(_ record: CaffeineRecordDTO) {
        editingRecord = record
        customName = record.drinkName
        customAmount = String(record.amount)
        selectedDate = record.timestamp
        if let preset = DrinkPreset.all.first(where: {
            $0.name == record.drinkName && $0.caffeineAmount == record.amount
        }) {
            selectedPreset = preset
            isCustomMode = false
        } else {
            selectedPreset = nil
            isCustomMode = true
        }
    }

    /// 입력값을 (양, 음료명, 시각)으로 해소. 시각은 `intakeTime` 규칙을 따른다.
    /// - Returns: 유효하지 않으면 nil.
    func resolve() -> (amount: Int, drinkName: String, timestamp: Date)? {
        let amount: Int
        let drinkName: String
        if let preset = selectedPreset, !isCustomMode {
            amount = preset.caffeineAmount
            drinkName = preset.name
        } else {
            guard let parsed = parsedAmount else { return nil }
            amount = parsed
            drinkName = trimmedCustomName.isEmpty ? "직접 입력" : trimmedCustomName
        }
        return (amount, drinkName, intakeTime())
    }
}
