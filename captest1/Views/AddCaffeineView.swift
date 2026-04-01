//
//  AddCaffeineView.swift
//  captest1
//

import SwiftUI
import SwiftData

struct AddCaffeineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AddCaffeineViewModel()
    @FocusState private var focusedField: CustomField?

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
                VStack(spacing: 20) {
                    presetSection
                    customSection
                }
                .padding()
            }
            .navigationTitle("카페인 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        if viewModel.save(into: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .fontWeight(.semibold)
                }
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

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("음료 선택")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(DrinkPreset.all) { preset in
                    Button {
                        viewModel.selectPreset(preset)
                        focusedField = nil
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.title2)
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(preset.caffeineAmount) mg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.selectedPreset?.name == preset.name && !viewModel.isCustomMode
                                        ? Color.brown : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("직접 입력")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("음료 이름 (선택)", text: $viewModel.customName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)

                HStack {
                    TextField("카페인 (mg)", text: $viewModel.customAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .amount)

                    Text("mg")
                        .foregroundStyle(.secondary)
                }

                if let message = viewModel.validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isCustomMode ? Color.brown : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
    AddCaffeineView()
        .modelContainer(for: CaffeineRecord.self, inMemory: true)
}
