//
//  CafeNearbyRows.swift
//  captest1
//
//  설정 화면 "카페 근처 알림" 토글 아래에 붙는 줄들: 동 선택 · 위치 권한 · 감시 중인 구역 수.
//  설정 기능이 알림 기능을 직접 참조하지 않도록 App 조립층(ContentView)이 SettingsView의 슬롯에 끼워 넣는다.
//

import SwiftUI
import UIKit

struct CafeNearbyRows: View {
    @Environment(CafeNearbyStore.self) private var cafeNearby
    @Environment(LocationPermissionManager.self) private var location
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            NavigationLink {
                DongPickerView()
            } label: {
                HStack {
                    Label("알림 받을 동", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text(selectedText)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .lineLimit(1)
                }
            }

            locationRow

            Label("감시 중인 카페 구역 \(cafeNearby.monitoredZoneCount)개", systemImage: "cup.and.saucer")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.inkSecondary)
        }
        .task {
            location.refresh()
            await cafeNearby.loadDongsIfNeeded()
            await cafeNearby.refreshMonitoredCount()
        }
    }

    private var selectedText: String {
        let names = cafeNearby.selectedDongs.map(\.name)
        if !names.isEmpty { return names.joined(separator: " · ") }
        // 카탈로그를 읽기 전에도 선택 개수는 보여준다.
        return cafeNearby.selectedDongCodes.isEmpty ? "선택 안 함" : "\(cafeNearby.selectedDongCodes.count)곳"
    }

    @ViewBuilder
    private var locationRow: some View {
        if location.isReadyForGeofence {
            Label("위치 '항상 허용' 켜짐", systemImage: "location.fill")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    if !location.requestNextStep(), let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label(locationButtonTitle, systemImage: "location")
                }
                Text("앱을 열지 않아도 카페 구역에 들어서면 알려면 위치를 '항상 허용'과 '정확한 위치'로 두어야 해요. 위치는 기기 밖으로 보내지 않아요.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
        }
    }

    private var locationButtonTitle: String {
        switch location.permission {
        case .notDetermined: "위치 권한 허용하기"
        case .whenInUse where !location.hasAskedAlways: "위치를 '항상 허용'으로 바꾸기"
        default: "설정 앱에서 위치 '항상 허용' 켜기"
        }
    }
}

#Preview {
    NavigationStack {
        List {
            Section("알림") {
                CafeNearbyRows()
            }
        }
    }
    .environment(CafeNearbyStore(catalog: PreviewCafeZoneCatalog(), monitor: PreviewGeofenceMonitor(),
                                 scheduler: PreviewLocalNotificationScheduler(),
                                 localStore: CafeNearbyLocalStore(defaults: UserDefaults(suiteName: "preview.cafeNearby")!)))
    .environment(LocationPermissionManager())
}
