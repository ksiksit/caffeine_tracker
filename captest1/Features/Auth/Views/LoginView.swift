//
//  LoginView.swift
//  captest1
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth

    @State private var email: String = ""
    @State private var password: String = ""

    @FocusState private var focused: Field?

    enum Field { case email, password }

    private var isEmailValid: Bool {
        email.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                    options: [.regularExpression, .caseInsensitive]) != nil
    }

    private var isPasswordValid: Bool {
        password.count >= 8 && password.count <= 72
    }

    private var canSubmit: Bool {
        isEmailValid && isPasswordValid && !auth.isProcessing
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let error = auth.lastError, error.fieldMessages.isEmpty {
                        errorBanner(error)
                    }

                    fields

                    submitButton

                    NavigationLink {
                        SignupView()
                    } label: {
                        HStack(spacing: 4) {
                            Text("계정이 없으신가요?")
                                .foregroundStyle(.secondary)
                            Text("회원가입")
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.Colors.canvas)
            .navigationBarHidden(true)
            .onChange(of: email) { auth.clearError() }
            .onChange(of: password) { auth.clearError() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("로그인")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("이메일과 비밀번호로 로그인해주세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("이메일")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                    .padding(12)
                    .background(Theme.Colors.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if !email.isEmpty && !isEmailValid {
                    Text("이메일 형식이 올바르지 않아요")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.signalStop)
                }
                if let msg = auth.lastError?.fieldMessages["email"] {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.signalStop)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("비밀번호")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("8자 이상", text: $password)
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        if canSubmit { Task { await auth.login(email: email, password: password) } }
                    }
                    .padding(12)
                    .background(Theme.Colors.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if !password.isEmpty && !isPasswordValid {
                    Text("비밀번호는 8~72자여야 해요")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.signalStop)
                }
                if let msg = auth.lastError?.fieldMessages["password"] {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.signalStop)
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            focused = nil
            Task { await auth.login(email: email, password: password) }
        } label: {
            ZStack {
                if auth.isProcessing {
                    ProgressView()
                        .tint(Theme.Colors.onAccent)
                } else {
                    Text("로그인")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSubmit ? Theme.Colors.accent : Theme.Colors.surfaceMuted)
            .foregroundStyle(canSubmit ? Theme.Colors.onAccent : Theme.Colors.inkSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit)
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
