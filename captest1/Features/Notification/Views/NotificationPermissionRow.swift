//
//  NotificationPermissionRow.swift
//  captest1
//
//  설정 화면 "알림" 섹션 맨 위의 권한 상태 줄. 설정 기능이 알림 기능을 직접 참조하지 않도록
//  App 조립층(ContentView)이 SettingsView의 슬롯에 끼워 넣는다.
//

import SwiftUI
import UIKit

struct NotificationPermissionRow: View {
    @Environment(NotificationStore.self) private var notifications
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            switch notifications.permission {
            case .authorized:
                VStack(alignment: .leading, spacing: 4) {
                    Label("알림 켜짐", systemImage: "bell.fill")
                    Text(nextText)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    if let error = notifications.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                }
            case .notDetermined:
                Button {
                    Task {
                        await notifications.requestPermissionIfNeeded()
                        notifications.scheduleRefresh()
                    }
                } label: {
                    Label("알림 허용하기", systemImage: "bell.badge")
                }
            case .denied:
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("설정 앱에서 알림 켜기", systemImage: "bell.slash")
                    }
                    Text("알림이 꺼져 있어서 아래 항목이 울리지 않아요.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
        }
        .task { await notifications.refreshPermission() }
    }

    private var nextText: String {
        guard let next = notifications.scheduled.first else { return "오늘 남은 알림이 없어요" }
        return "다음 알림 \(next.fireAt.formatted(date: .omitted, time: .shortened)) · \(next.title)"
    }
}

#Preview {
    List {
        Section("알림") {
            NotificationPermissionRow()
        }
    }
    .environment(NotificationStore(repository: PreviewNotificationRepository(),
                                   scheduler: PreviewLocalNotificationScheduler()))
}
