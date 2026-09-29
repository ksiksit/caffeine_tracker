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
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.section) {
                    presetSection
                    customSection
                    timeSection
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.vertical, 16)
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
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
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedDate)
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

            LazyVGrid(columns: columns, spacing: 8) {
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
            HStack(spacing: 4) {
                Text(preset.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("\(preset.caffeineAmount) mg")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .fill(Theme.Colors.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Colors.accent : Theme.Colors.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 신규 추가도 시각을 고를 수 있다("2시에 마신 커피"를 추가 후 수정하지 않고 바로 기록). 기본값은 지금.
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("마신 시각")

            HStack {
                DatePicker(
                    "마신 시각",
                    selection: Binding(
                        get: { viewModel.selectedDate },
                        set: {
                            viewModel.selectedDate = $0
                            viewModel.isTimeEdited = true
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)

                Spacer(minLength: 8)

                if !isEditMode && !viewModel.isTimeEdited {
                    Text("지금")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("직접 입력")

            Group {
                VStack(spacing: 12) {
                    TextField("음료 이름 (선택)", text: $viewModel.customName)
                        .textFieldStyle(.plain)
                        .themedField()
                        .focused($focusedField, equals: .name)

                    HStack {
                        TextField("카페인 (mg)", text: $viewModel.customAmount)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .themedField()
                            .focused($focusedField, equals: .amount)

                        Text("mg")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }

                    if let message = viewModel.validationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.signalStop)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(Theme.Spacing.field)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .stroke(
                        viewModel.isCustomMode ? Theme.Colors.accent : Theme.Colors.hairline,
                        lineWidth: viewModel.isCustomMode ? 2 : 1
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
