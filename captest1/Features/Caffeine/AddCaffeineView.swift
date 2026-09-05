//
//  AddCaffeineView.swift
//  captest1
//

import SwiftUI

struct AddCaffeineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsManager.self) private var settings
    @Environment(CaffeineStore.self) private var store

    let editingRecord: CaffeineRecordDTO?

    @State private var viewModel = AddCaffeineViewModel()
    @State private var loaded = false
    @State private var isSaving = false
    @FocusState private var focusedField: CustomField?

    init(editing record: CaffeineRecordDTO? = nil) {
        self.editingRecord = record
    }

    private var isEditMode: Bool { editingRecord != nil }

    private enum CustomField {
        case name, amount
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    presetSection
                    customSection
                    if isEditMode {
                        timeSection
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                if let preview = cutoffPreview {
                    CutoffPreviewBanner(
                        current: preview.current,
                        projected: preview.projected,
                        predictedAtBedtime: preview.predictedAtBedtime
                    )
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPreset?.name)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.customAmount)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isCustomMode)
                }
            }
            .navigationTitle(isEditMode ? "기록 수정" : "카페인 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "저장" : "추가") {
                        save()
                    }
                    .disabled(!viewModel.canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .task {
                if !loaded, let record = editingRecord {
                    viewModel.loadForEdit(record)
                }
                loaded = true
            }
            .alert("저장 실패", isPresented: $viewModel.showingSaveError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("카페인 기록을 저장하는데 실패했습니다. 다시 시도해 주세요.")
            }
            .onChange(of: viewModel.customAmount) { _, newValue in
                viewModel.filterCustomAmount(newValue)
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue != nil {
                    viewModel.activateCustomMode()
                }
            }
        }
    }

    private var cutoffPreview: (current: CaffeineCutoffResult, projected: CaffeineCutoffResult, predictedAtBedtime: Double)? {
        // 즉시 미리보기만 로컬 공식 유지(키 입력 왕복 방지). 오늘 doses와 취침시각은 서버 today 결과에서.
        // today가 아직 없으면(첫 로드 전) doses도 비어 있어 미리보기 의미가 없으므로 배너를 띄우지 않는다.
        guard !isEditMode, let bedtime = store.bedtime else { return nil }
        let todayDoses = store.chartDoses
        guard let pair = viewModel.previewCutoff(
            todayDoses: todayDoses,
            halfLifeHours: settings.effectiveHalfLifeHours,
            bedtime: bedtime,
            referenceDoseMg: Double(settings.referenceDoseMg)
        ) else { return nil }

        let projectedResidual: Double = {
            switch pair.projected {
            case .alreadyExceeded(let mg): return mg
            default: return 0
            }
        }()
        return (pair.current, pair.projected, projectedResidual)
    }

    private func save() {
        guard let resolved = viewModel.resolve() else {
            viewModel.showingSaveError = true
            return
        }
        isSaving = true
        Task {
            let ok: Bool
            if let editing = viewModel.editingRecord {
                ok = await store.update(
                    id: editing.id, amount: resolved.amount,
                    drinkName: resolved.drinkName, timestamp: resolved.timestamp)
            } else {
                ok = await store.add(
                    amount: resolved.amount, drinkName: resolved.drinkName, timestamp: resolved.timestamp)
            }
            isSaving = false
            if ok {
                dismiss()
            } else {
                viewModel.showingSaveError = true
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("음료 선택")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(DrinkPreset.all) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: DrinkPreset) -> some View {
        let isSelected = viewModel.selectedPreset?.name == preset.name && !viewModel.isCustomMode
        return Button {
            viewModel.selectPreset(preset)
            focusedField = nil
        } label: {
            VStack(spacing: 8) {
                CategoryIconBadge(
                    symbol: preset.icon,
                    tint: Color("EspressoBrown"),
                    size: 36
                )
                Text(preset.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(preset.caffeineAmount) mg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color("EspressoBrown") : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("섭취 시각")

            HealthCard {
                DatePicker(
                    "섭취 시각",
                    selection: $viewModel.selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("직접 입력")

            HealthCard {
                VStack(spacing: 12) {
                    TextField("음료 이름 (선택)", text: $viewModel.customName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                        .focused($focusedField, equals: .name)

                    HStack {
                        TextField("카페인 (mg)", text: $viewModel.customAmount)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                            )
                            .focused($focusedField, equals: .amount)

                        Text("mg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let message = viewModel.validationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        viewModel.isCustomMode ? Color("EspressoBrown") : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

#Preview {
    AddCaffeineView()
        .environment(SettingsManager())
        .environment(CaffeineStore(repository: PreviewCaffeineRepository()))
}
