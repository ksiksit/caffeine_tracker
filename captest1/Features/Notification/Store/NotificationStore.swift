//
//  NotificationStore.swift
//  captest1
//
//  서버 알림 계획을 받아 로컬 알림 예약을 통째로 교체한다(api.md 알림 절: "기존 예약을 전부 취소하고 이 목록대로 다시 예약").
//  재조회 시점(기록 변경·설정 변경·포그라운드 진입)은 App 조립층이 관찰해 `scheduleRefresh()`를 부른다 —
//  Feature 간 직접 참조를 만들지 않기 위해서다(CLAUDE.md 의존 규칙 2).
//

import Foundation

@MainActor
@Observable
final class NotificationStore {
    private(set) var permission: LocalNotificationPermission = .notDetermined
    /// 마지막으로 예약에 성공한 목록(설정 화면 표시용).
    private(set) var scheduled: [LocalNotification] = []
    private(set) var lastSyncedAt: Date?
    /// 마지막으로 받은 카페 근처 금지 구간. 판정은 카페 근처 알림 스토어가 하므로 여기서는 전달만 한다.
    private(set) var cafeNearbyWindows: [CafeNearbyWindowDTO] = []
    /// 계획 조회에 성공할 때마다 1씩 오른다. 금지 구간이 이전과 같아도(빈 목록 포함) 조립층이 저장하도록 신호로 쓴다.
    private(set) var planRevision = 0
    var errorMessage: String?

    private let repository: any NotificationRepository
    private let scheduler: any LocalNotificationScheduling
    private var refreshTask: Task<Void, Never>?

    /// 트리거가 한꺼번에 몰릴 때(앱 시작 직후 설정 로드 + 오늘 현황 + 포그라운드) 한 번만 조회하도록 모으는 시간.
    static let debounce: Duration = .milliseconds(500)

    init(repository: any NotificationRepository, scheduler: any LocalNotificationScheduling) {
        self.repository = repository
        self.scheduler = scheduler
    }

    func refreshPermission() async {
        permission = await scheduler.permission()
    }

    /// 아직 묻지 않았을 때만 시스템 권한 창을 띄운다.
    func requestPermissionIfNeeded() async {
        await refreshPermission()
        guard permission == .notDetermined else { return }
        _ = await scheduler.requestPermission()
        await refreshPermission()
    }

    /// 서버 계획을 받아 예약을 교체한다.
    /// 권한이 없으면 조회하지 않는다. 조회에 실패하면 기존 예약을 그대로 둔다 — 조금 낡은 계획이 빈 계획보다 낫다.
    func refresh() async {
        await refreshPermission()
        guard permission == .authorized else { return }
        do {
            let plan = try await repository.plan()
            let items = plan.items.map(Self.localNotification(from:))
            await scheduler.replaceAll(with: items)
            scheduled = items
            lastSyncedAt = plan.now
            cafeNearbyWindows = plan.cafeNearbyWindows
            planRevision += 1
            errorMessage = nil
        } catch is CancellationError {
            // 무시
        } catch {
            errorMessage = "알림 일정을 갱신하지 못했어요. 이전 일정대로 울려요."
        }
    }

    /// 짧은 시간 안의 여러 요청을 한 번의 조회로 합친다.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard let self, !Task.isCancelled else { return }
            await self.refresh()
        }
    }

    /// 로그아웃 시 이 계정 기준으로 예약한 알림을 지운다.
    func clear() async {
        refreshTask?.cancel()
        refreshTask = nil
        await scheduler.removeAll()
        scheduled = []
        lastSyncedAt = nil
        cafeNearbyWindows = []
    }

    /// 종류당 한 건이므로 종류 + 시각으로 식별자를 만든다.
    static func localNotification(from item: NotificationItemDTO) -> LocalNotification {
        LocalNotification(
            id: "\(item.type).\(Int(item.fireAt.timeIntervalSince1970))",
            fireAt: item.fireAt, title: item.title, body: item.body)
    }
}
