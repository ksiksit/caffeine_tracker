//
//  AddCaffeineViewModel.swift
//  captest1
//

import Foundation
import SwiftData

@MainActor @Observable
final class AddCaffeineViewModel {
    // MARK: - 입력 상태
    var selectedPreset: DrinkPreset?
    var customAmount: String = ""
    var customName: String = ""
    var isCustomMode: Bool = false
    var showingSaveError: Bool = false

    // MARK: - 유효성 검증
    var parsedAmount: Int? {
        guard let value = Int(customAmount), value > 0,
              value <= AppConstants.Caffeine.maxCustomAmountMg else { return nil }
        return value
    }

    var canSave: Bool {
        if isCustomMode { return parsedAmount != nil }
        return selectedPreset != nil
    }

    var validationMessage: String? {
        guard isCustomMode, !customAmount.isEmpty else { return nil }
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

    /// - Returns: 저장 성공 시 true
    func save(into modelContext: ModelContext) -> Bool {
        let record: CaffeineRecord
        if let preset = selectedPreset, !isCustomMode {
            record = CaffeineRecord(amount: preset.caffeineAmount, drinkName: preset.name)
        } else {
            guard let amount = parsedAmount else { return false }
            let name = customName.isEmpty ? "직접 입력" : customName
            record = CaffeineRecord(amount: amount, drinkName: name)
        }

        modelContext.insert(record)

        do {
            try modelContext.save()
            return true
        } catch {
            showingSaveError = true
            return false
        }
    }
}
