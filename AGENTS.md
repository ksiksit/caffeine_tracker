# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## 빌드 및 테스트 명령어

```bash
# 빌드
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 단위 테스트 (기본 검증)
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1Tests test

# UI 테스트 (UI 변경 또는 요청 시)
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1UITests test

# 전체 테스트 (단위 + UI 테스트가 함께 실행될 수 있으므로 기본 검증으로 사용하지 않음)
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# 특정 단위 테스트만 실행
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1Tests/<클래스명>/<메서드명> test
```

## 테스트 실행 및 실패 해석 지침

- 기본 검증 순서는 **빌드 → 단위 테스트**이다.
- UI 테스트는 UI 변경이 있거나 사용자가 요청한 경우에만 별도로 실행한다.
- `xcodebuild -scheme captest1 ... test`는 UI 테스트까지 함께 실행될 수 있으므로 기본 검증 명령으로 사용하지 않는다.
- 실패 보고 시 **컴파일 실패**, **단위 테스트 실패**, **UI 테스트 실패**, **CoreSimulator/테스트 러너 실행 실패**를 구분한다.
- `CoreSimulatorService connection became invalid`, `Simulator device failed to launch ... xctrunner`, `ipc/mig server died`, 샌드박스/권한 오류는 앱 로직 실패로 단정하지 않는다.
- 긴 SwiftUI 화면의 UI 테스트는 요소가 처음부터 보인다고 가정하지 말고, 필요 시 스크롤 후 확인한다.

## 프로젝트 개요

질 좋은 수면을 위한 카페인 관리 앱. SwiftUI + HealthKit + Charts 기반의 **thin-client**.

> **풀스택 프로젝트**: 이 iOS 앱 + Spring 백엔드(`../server`). 도메인 연산(약동학·수면 병합·베이지안 학습)은
> **서버가 수행**하고, 앱은 입력 전송 + 서버 계산 결과 표시. **앱 실행 시 서버 필요**(`BASE_URL` 기본 `http://localhost:8080`, gitignore된 `captest1/Resources/Secrets.plist`가 있으면 우선 — 배포 서버 주소는 커밋 금지).

- **카페인 관리**: 기록 → 서버 저장, 서버가 계산한 잔류량 차트·마감시각 표시
- **수면**: HealthKit 원시 샘플을 읽어 **서버 업로드**, 병합·SOL·요약은 서버 계산
- **학습**: 서버가 베이지안 반감기 학습, 대시보드는 서버 통계 렌더
- **설정**: 서버 저장(로컬 미러), 서버 연산 입력값

## 아키텍처

```text
captest1/
├── App/              # 조립(컴포지션 루트): captest1App·AppDelegate(위치 이벤트 재실행 대비)·RootView·ContentView·AppEnvironment
├── Features/         # ↔ 서버 domain/<도메인>. 각 Feature 안은 Views/Store/Data/Model 4종으로 분류(Model은 있는 곳만)
│   ├── Auth/
│   │   ├── Views/    # LoginView·SignupView
│   │   ├── Store/    # AuthManager(세션 상태)·AuthState
│   │   └── Data/     # AuthRepository(포트)·APIClient+Auth(어댑터)·AuthDTO·PreviewAuthRepository
│   ├── Caffeine/
│   │   ├── Views/    # HomeView·AddCaffeineView·CaffeineChartView·CutoffHeroCard·CutoffPreviewBanner
│   │   ├── Store/    # CaffeineStore·AddCaffeineViewModel(폼 전용)
│   │   ├── Data/     # CaffeineRepository·APIClient+Caffeine·CaffeineDTO·PreviewCaffeineRepository
│   │   └── Model/    # CaffeineKineticsCalculator·CaffeineCutoff(즉시 미리보기용 로컬 미러)·DrinkPreset
│   ├── Sleep/
│   │   ├── Views/    # SleepAnalysisView·LastNightCard·StageBreakdownView·RecentNightsView
│   │   ├── Store/    # SleepStore(업로드·요약)
│   │   ├── Data/     # SleepRepository·APIClient+Sleep·SleepDTO·PreviewSleepRepository
│   │   └── Model/    # SleepModels(서버값 표시 모델)
│   ├── Insight/      # 카페인·수면 리포트(서버 domain/insight). 지금은 수면 탭 슬롯만(전용 화면은 계획서 §4)
│   │   ├── Views/    # LastNightCaffeineRow(지난밤 취침 잔량·그날 섭취)·NightlyCaffeineCard(7밤 막대·표) — 수면 탭 슬롯에 ContentView가 끼워 넣음
│   │   ├── Store/    # InsightStore(최근 7밤 리포트, 수면 업로드 후·기록 변경 후 재조회)
│   │   └── Data/     # InsightRepository·APIClient+Insight·InsightDTO·PreviewInsightRepository
│   ├── Learning/
│   │   ├── Views/    # LearningDashboardView·CalibrationScatterChart·ConfidenceBar
│   │   ├── Store/    # LearningStore
│   │   └── Data/     # LearningRepository·APIClient+Learning·LearningDTO
│   ├── Notification/
│   │   ├── Views/    # NotificationPermissionRow·CafeNearbyRows(설정 화면 슬롯에 ContentView가 끼워 넣음)·DongPickerView
│   │   ├── Store/    # NotificationStore(서버 알림 계획 → 로컬 예약 교체)·CafeNearbyStore(동 선택 → 지오펜스, 진입 판정 → 즉시 알림)
│   │   ├── Data/     # NotificationRepository·APIClient+Notification·NotificationDTO·PreviewNotificationRepository·CafeZoneCatalog(번들 CafeZones.json)·CafeNearbyLocalStore
│   │   └── Model/    # CafeNearbyGate(금지 구간 안인가·전체 60분 재알림 간격 — 순수 판정)
│   └── Settings/
│       ├── Views/    # SettingsView(알림 권한 줄·카페 근처 상세 줄은 슬롯으로 받음)
│       ├── Store/    # SettingsManager(서버 권위 + 로컬 미러, 알림 종류별 on/off·카페 근처 포함)
│       └── Data/     # SettingsRepository·APIClient+Settings·SettingsDTO
├── Core/             # ↔ 서버 global/. Features를 참조하지 않는다
│   ├── Networking/   # APIClient(전송·JWT·401 refresh·봉투 해제), APIEnvelope·APIError, ServerDateCoding, TokenStore, AuthSession
│   ├── HealthKit/    # HealthKitManager(가용성·권한만), SleepFetchService(읽기), SleepSampleSource 포트
│   ├── Notifications/ # LocalNotificationScheduler(로컬 알림 예약·즉시 알림·권한), LocalNotification 값, LocalNotificationScheduling 포트, LocalNotificationPresenter(앞에 있을 때 배너)
│   ├── Location/     # GeofenceMonitor(CLMonitor 원형 구역 감시, GeofenceMonitoring 포트)·LocationPermissionManager(권한 상태만)
│   ├── Security/     # KeychainHelper
│   ├── DesignSystem/ # HealthCard·CategoryIconBadge·HealthMetric·SectionHeader
│   └── Model/        # CaffeineCondition, AppConstants
└── Resources/        # entitlements, 에셋, 로컬라이제이션
```

**구조 이름**: Clean Architecture의 의존 규칙을 적용한 Feature-first MVVM(Repository 포트까지만 채택).
`XStore`(@Observable) = ViewModel 역할, `XRepository` = 포트, `extension APIClient: XRepository` = 어댑터, UseCase·Entity는 생략(연산은 서버).

**의존 규칙**
1. `Core`는 `Features`를 참조하지 않는다. (`grep -rnE "SettingsManager|CaffeineStore|LearningStore|SleepStore|AuthManager|NotificationStore|CafeNearbyStore" captest1/Core` 결과 없음)
2. Feature 간 참조는 `SettingsManager` 읽기만 허용. 그 외 공유가 필요하면 `Core/Model`로 올린다.
3. View는 Repository·Catalog를 직접 호출하지 않는다. 항상 Store를 거친다. (`grep -rn "Repository\|Catalog" captest1/Features/*/Views | grep -v Preview` 결과 없음. `#Preview`의 페이크 주입만 예외)
4. `APIClient` 본체에는 엔드포인트를 두지 않는다. 각 Feature의 `APIClient+X.swift` 확장이 `XRepository`를 채택하고, 조립은 `captest1App.init` 한 곳에서 한다. 예외: `CafeNearbyStore`는 위치 이벤트로 백그라운드 재실행될 때 화면 없이 동작해야 해서 `AppDelegate`가 만들고 앱이 environment로 넘긴다.
5. DTO는 Feature 폴더에, 날짜 코딩·에러·봉투는 `Core/Networking`에.
6. Feature 안은 `Views/ Store/ Data/ Model/` 4종으로만 분류한다(`find captest1/Features -mindepth 2 -maxdepth 2 -name "*.swift"` 결과 없음). 의존 방향은 `Views → Store → Data·Model`. Views는 Model·DTO를 읽기만 하고, Data는 같은 Feature의 다른 폴더를 모른다. 배치 기준은 `docs/ios-architecture-plan.md` 단계 9의 표.

**데이터 흐름**: 사용자 입력 → `Store` → `XRepository`(= `APIClient` 확장) → 서버 연산 → `Store(@Observable)` → View
**수면**: HealthKit 원시 샘플(`SleepSampleSource`) → `SleepStore`가 서버 업로드 → 서버 병합·요약 → `SleepSummary`(서버값 그대로) → View
**설정**: 서버 권위 + `SettingsManager` 로컬 미러(변경 시 디바운스 PUT)
**알림**: 서버 `/api/notifications/plan`(무엇을·언제·어떤 문구로) → `NotificationStore`가 기존 예약을 전부 지우고 교체 → `Core/Notifications`가 로컬 알림 예약.
재조회 신호(today 갱신·설정 서버 반영·포그라운드 진입)는 기능끼리 부르지 않고 `ContentView`가 관찰해 잇는다. 조회 실패 시 기존 예약 유지
**카페 근처 알림**: 번들 `CafeZones.json`(tools/cafe-zones로 생성) 중 고른 동(최대 2개)의 구역 상위 17개를 지오펜스 등록 → 계획의 `cafeNearbyWindows`를 기기에 저장 →
진입 순간 `CafeNearbyGate`가 네트워크 없이 판정해 서버 문구로 즉시 알림. 동·위치는 서버로 보내지 않는다. 앱이 꺼져 있어도 `AppDelegate`가 감시를 재개한다

## 핵심 도메인 지식 (연산은 서버에서 수행)

- **약동학 계산**: `amount = dose * exp(-ke * t)` — 서버 `calc.Pharmacokinetics`. 카페인 추가 즉시 미리보기 1곳만 로컬.
- **건강 상태 보정**: `effectiveHalfLife = base × condition.multiplier` — 흡연(×0.5), 경구피임약(×2.0), 임신(×2.5). 서버 resolve.
- **수면 병합**: 단계 우선순위(deep→REM→core→unspecified→awake→inBed) — 서버 `calc.SleepMerger`. 앱은 읽기·업로드만.

## 주의사항

- 사용자와의 대화는 **한국어**로 진행
- 모든 UI 텍스트와 에러 메시지는 **한국어**로 작성
- DrinkPreset의 카페인 양은 실제 데이터 기반이므로 임의 변경 금지
- CaffeineCondition의 multiplier 값(0.5, 1.0, 2.0, 2.5)은 약리학 근거 기반이므로 임의 변경 금지(서버 `calc`와 동일)
- HealthKit **읽기만** 기기 가능(Apple 정책) — 병합·SOL·학습은 서버. 도메인 연산 변경은 서버 `calc`가 source of truth.
