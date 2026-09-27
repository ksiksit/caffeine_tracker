//
//  DongPickerView.swift
//  captest1
//
//  카페 근처 알림을 받을 동 선택(최대 2개). 두 동의 카페 구역을 합쳐 카페가 많은 순으로 17개를 감시한다.
//

import SwiftUI

struct DongPickerView: View {
    @Environment(CafeNearbyStore.self) private var cafeNearby
    @State private var query = ""

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    if cafeNearby.selectedDongs.isEmpty {
                        Text("동 이름으로 검색해 주세요. 예: 양재2동, 서초구 양재")
                            .foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    ForEach(cafeNearby.selectedDongs) { row($0) }
                } header: {
                    Text("선택한 동 \(cafeNearby.selectedDongCodes.count)/\(CafeNearbyStore.maxDongs)")
                } footer: {
                    Text("집·회사처럼 자주 머무는 동을 골라 주세요. 두 동을 합쳐 카페가 많은 구역 \(CafeNearbyStore.zoneLimit)곳을 살펴요.")
                }
            } else {
                let results = cafeNearby.search(query)
                if results.isEmpty {
                    Text("'\(query)'에 맞는 동이 없어요")
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                ForEach(results) { row($0) }
            }

            if let error = cafeNearby.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("알림 받을 동")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "동 이름 검색")
        .task { await cafeNearby.loadDongsIfNeeded() }
    }

    private func row(_ dong: CafeDong) -> some View {
        let isSelected = cafeNearby.selectedDongCodes.contains(dong.code)
        let isFull = cafeNearby.selectedDongCodes.count >= CafeNearbyStore.maxDongs
        return Button {
            Task { await cafeNearby.toggle(dong) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dong.name)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("\(dong.sido) \(dong.sigungu) · 카페 구역 \(dong.zones.count)곳")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .disabled(!isSelected && isFull)
    }
}

#Preview {
    NavigationStack {
        DongPickerView()
    }
    .environment(CafeNearbyStore(catalog: PreviewCafeZoneCatalog(), monitor: PreviewGeofenceMonitor(),
                                 scheduler: PreviewLocalNotificationScheduler(),
                                 localStore: CafeNearbyLocalStore(defaults: UserDefaults(suiteName: "preview.cafeNearby")!)))
}
