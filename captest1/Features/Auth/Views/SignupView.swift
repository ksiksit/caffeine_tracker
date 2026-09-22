//
//  SignupView.swift
//  captest1
//

import SwiftUI

struct SignupView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var nickname: String = ""
    @State private var agreedToTerms: Bool = false
    @State private var agreedToPrivacy: Bool = false

    @FocusState private var focused: Field?

    enum Field { case email, password, nickname }

    private var isEmailValid: Bool {
        email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                    options: [.regularExpression, .caseInsensitive]) != nil
    }

    private var isPasswordValid: Bool { password.count >= 8 && password.count <= 72 }
    private var isNicknameValid: Bool { nickname.count >= 2 && nickname.count <= 20 }

    private var canSubmit: Bool {
        isEmailValid && isPasswordValid && isNicknameValid &&
            agreedToTerms && agreedToPrivacy && !auth.isProcessing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let error = auth.lastError, error.fieldMessages.isEmpty {
                    errorBanner(error)
                }

                fields

                consentSection

                submitButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: email) { auth.clearError() }
        .onChange(of: password) { auth.clearError() }
        .onChange(of: nickname) { auth.clearError() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("새 계정 만들기")
                .font(.title2)
                .fontWeight(.bold)
            Text("이메일, 비밀번호, 닉네임을 입력해주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "이메일", placeholder: "you@example.com", text: $email,
                  isValid: email.isEmpty || isEmailValid,
                  invalidMessage: "이메일 형식이 올바르지 않아요",
                  fieldKey: "email") {
                $0.keyboardType(.emailAddress)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                  .focused($focused, equals: .email)
                  .submitLabel(.next)
                  .onSubmit { focused = .password }
            }

            secureField(title: "비밀번호", placeholder: "8자 이상", text: $password,
                        isValid: password.isEmpty || isPasswordValid,
                        invalidMessage: "비밀번호는 8~72자여야 해요",
                        fieldKey: "password")

            field(title: "닉네임", placeholder: "2~20자", text: $nickname,
                  isValid: nickname.isEmpty || isNicknameValid,
                  invalidMessage: "닉네임은 2~20자여야 해요",
                  fieldKey: "nickname") {
                $0.focused($focused, equals: .nickname)
                  .submitLabel(.done)
                  .onSubmit { focused = nil }
            }
        }
    }

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            consentRow(text: "[필수] 서비스 이용약관 동의", isOn: $agreedToTerms)
            consentRow(text: "[필수] 개인정보 처리방침 동의", isOn: $agreedToPrivacy)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func consentRow(text: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Toggle(isOn: isOn) {
                Text(text)
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
            .tint(Theme.Colors.accent)

            Button("보기") {
                // 약관 화면은 후속 작업
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var submitButton: some View {
        Button {
            focused = nil
            Task {
                await auth.signup(email: email, password: password, nickname: nickname)
                // 성공 시 RootView가 .authenticated로 전환되며 자동 dismiss됨
            }
        } label: {
            ZStack {
                if auth.isProcessing {
                    ProgressView().tint(Theme.Colors.onAccent)
                } else {
                    Text("가입하기").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSubmit ? Theme.Colors.accent : Color.gray.opacity(0.4))
            .foregroundStyle(Theme.Colors.onAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
    }

    @ViewBuilder
    private func field<Modifier: View>(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isValid: Bool,
        invalidMessage: String,
        fieldKey: String,
        @ViewBuilder modifier: (TextField<Text>) -> Modifier
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            modifier(TextField(placeholder, text: text))
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isValid {
                Text(invalidMessage).font(.caption2).foregroundStyle(Theme.Colors.signalStop)
            }
            if let msg = auth.lastError?.fieldMessages[fieldKey] {
                Text(msg).font(.caption2).foregroundStyle(Theme.Colors.signalStop)
            }
        }
    }

    private func secureField(
        title: String, placeholder: String, text: Binding<String>,
        isValid: Bool, invalidMessage: String, fieldKey: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            SecureField(placeholder, text: text)
                .focused($focused, equals: .password)
                .submitLabel(.next)
                .onSubmit { focused = .nickname }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isValid {
                Text(invalidMessage).font(.caption2).foregroundStyle(Theme.Colors.signalStop)
            }
            if let msg = auth.lastError?.fieldMessages[fieldKey] {
                Text(msg).font(.caption2).foregroundStyle(Theme.Colors.signalStop)
            }
        }
    }

    private func errorBanner(_ error: AuthErrorMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Theme.Colors.signalStop)
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title).font(.subheadline).fontWeight(.semibold)
                Text(error.body).font(.caption)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.signalStop.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
