//
//  RootView.swift
//  captest1
//

import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        switch auth.state {
        case .checking:
            VStack(spacing: 12) {
                ProgressView()
                Text("로그인 정보 확인 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        case .unauthenticated:
            LoginView()
        case .authenticated:
            ContentView()
        }
    }
}
