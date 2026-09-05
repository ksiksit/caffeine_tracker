# iOS 앱 아키텍처 재편 계획서

> 작성: 2026-09-04 · 개정: 2026-09-05 (재분석 반영, §8) · 대상: `captest1` (iOS thin-client) · 서버: `../server`
> 채택 구조: **Clean Architecture 기반 MVVM의 축소 변형** — Repository 프로토콜(포트)과 Data 계층은 살리고,
> UseCase 계층과 Entity↔DTO 매핑은 생략. 화면 패턴은 Apple 방식(`@Observable` Store + Environment)을 유지한다.

---

## 0. 왜 바꾸는가

| 현재 문제 | 재편 후 |
|---|---|
| 서버가 2026-09-03에 모든 응답을 `{success,data,error,message}` 봉투로 감쌌는데 앱은 바디를 DTO로 바로 디코딩 → **최신 서버에 붙이면 로그인부터 실패** | `Core/Networking`이 봉투를 한 곳에서 벗김 |
| 앱은 레이어형(Views/Models/Services), 서버는 도메인형(`domain/caffeine` …) → 같은 기능이 두 레포에서 다른 축으로 잘림 | `Features/<도메인>` 폴더가 서버 `domain/<도메인>`과 1:1 |
| 프로토콜 0개, 스토어 5개가 `APIClient` 구체 actor에 직접 의존 → 스토어 단위 테스트 0개 | `<도메인>Repository` 프로토콜로 페이크 주입 가능 |
| `APIClient` 한 파일이 5개 도메인 엔드포인트를 전부 보유 | 본체는 전송·인증·봉투만, 엔드포인트는 Feature별 `APIClient+X.swift` 확장 |
| `HealthKitManager`가 권한·읽기·업로드·요약·표시모델 변환 5가지 책임 | 권한/읽기는 `Core/HealthKit`, 업로드·요약은 `Features/Sleep/SleepStore` |
| 서버가 계산해 보낸 수면 요약(총수면·침대시간·효율·단계별 합계)을 버리고 `SleepSummary`가 records로 **다시 계산** → "연산은 서버" 원칙 위반, 서버 병합 로직이 바뀌면 두 값이 갈라짐 | `SleepSummary`를 서버 필드를 그대로 담는 표시 모델로 축소, 재계산 코드·테스트 삭제 (단계 5) |
| 같은 계산이 여러 벌: `yyyy-MM-dd` 포매터 3곳, 취침시각 계산 2곳(미리보기용은 서버 `today.bedtime`과 의미 동일) | 날짜 코딩은 `Core/Networking/ServerDateCoding` 한 곳, 미리보기 취침시각은 서버 값 사용 (단계 3) |
| SwiftData 모델·헬퍼·`.claude/PROJECT_ANALYSIS.md` 등 서버 이관 잔재 | 삭제 |

## 1. 원칙 (의존 규칙)

1. **Core는 Features를 참조하지 않는다.** (`HealthKitManager`가 `SettingsManager`를 보는 현재 구조는 끊는다)
2. **Feature 간 참조는 `Settings` 스토어 읽기만 허용.** 그 외 공유가 필요하면 `Core/Model`로 올린다.
3. **View는 Repository를 직접 호출하지 않는다.** 항상 Store(=ViewModel 역할)를 거친다.
4. **`APIClient` 본체에는 엔드포인트 메서드를 두지 않는다.** 각 Feature의 `APIClient+X.swift` 확장에서 `XRepository`를 채택한다.
5. **DTO는 Feature 폴더에, 날짜 코딩·에러·봉투는 `Core/Networking`에.**
6. **이동 커밋과 수정 커밋을 분리한다.** git이 rename을 잡아 리뷰가 가능해진다.

용어 대응 (발표·문서용):

| Clean + MVVM 원형 | 이 프로젝트 |
|---|---|
| View | SwiftUI View |
| ViewModel | 서버 상태는 `XStore`, 폼 전용은 `XViewModel` (`AddCaffeineViewModel`) |
| UseCase | 생략 (연산은 서버 `calc`) |
| Repository 프로토콜 | `XRepository` (포트) |
| Repository 구현 / DataSource | `extension APIClient: XRepository` (어댑터) |
| Entity | 생략, 서버 DTO를 표시 모델로 사용 |

## 2. 목표 트리

```text
captest1/
├── App/                          # 조립(컴포지션 루트)
│   ├── captest1App.swift
│   ├── AppEnvironment.swift      # ← Services/
│   ├── RootView.swift            # ← Views/Auth/
│   └── ContentView.swift         # ← Views/
├── Features/                     # ↔ 서버 domain/
│   ├── Auth/
│   │   ├── LoginView.swift, SignupView.swift
│   │   ├── AuthManager.swift     # 세션 상태 Store
│   │   ├── AuthState.swift
│   │   ├── AuthDTO.swift         # 요청/응답 + AuthErrorMessage (APIError는 Core로)
│   │   ├── AuthRepository.swift  # 신규: protocol
│   │   └── APIClient+Auth.swift  # 신규: 확장(어댑터)
│   ├── Caffeine/
│   │   ├── HomeView.swift, AddCaffeineView.swift, AddCaffeineViewModel.swift
│   │   ├── CaffeineChartView.swift, CutoffHeroCard.swift, CutoffPreviewBanner.swift
│   │   ├── CaffeineStore.swift
│   │   ├── CaffeineDTO.swift     # ← ServerDomainDTO.swift(카페인 부분)
│   │   ├── CaffeineCutoff.swift  # ← CaffeineHelpers.swift(마감시각·CutoffResult·koreanTimeLabel·resolvedBedtimeDate)
│   │   ├── CaffeineKineticsCalculator.swift   # 즉시 미리보기용 로컬 계산(유지)
│   │   ├── DrinkPreset.swift
│   │   ├── CaffeineRepository.swift           # 신규
│   │   └── APIClient+Caffeine.swift           # 신규
│   ├── Sleep/
│   │   ├── SleepAnalysisView.swift, LastNightCard.swift, StageBreakdownView.swift, RecentNightsView.swift
│   │   ├── SleepStore.swift      # 신규: HealthKitManager에서 업로드·요약 조회 분리, 서버 DTO → 표시 모델 1:1 매핑
│   │   ├── SleepModels.swift     # ← SleepData.swift (SleepStage + SleepSummary 표시 모델. 재계산 없음, SleepRecord 삭제)
│   │   ├── SleepDTO.swift        # ← ServerSleepDTO.swift
│   │   ├── SleepRepository.swift # 신규
│   │   └── APIClient+Sleep.swift # 신규
│   ├── Learning/
│   │   ├── LearningDashboardView.swift, CalibrationScatterChart.swift, ConfidenceBar.swift
│   │   ├── LearningStore.swift
│   │   ├── LearningDTO.swift     # ← ServerLearningDTO.swift
│   │   ├── LearningRepository.swift           # 신규
│   │   └── APIClient+Learning.swift           # 신규
│   └── Settings/
│       ├── SettingsView.swift
│       ├── SettingsManager.swift # Store 역할(이름 유지)
│       ├── SettingsDTO.swift     # ← ServerDomainDTO.swift(설정 부분)
│       ├── SettingsRepository.swift           # 신규
│       └── APIClient+Settings.swift           # 신규
├── Core/                         # ↔ 서버 global/
│   ├── Networking/
│   │   ├── APIClient.swift       # 전송·JWT·refresh 재시도·봉투 디코딩만
│   │   ├── APIEnvelope.swift     # 신규: 봉투 DTO
│   │   ├── APIError.swift        # ← AuthDTO.swift(APIError·ServerFieldError 부분)
│   │   ├── ServerDateCoding.swift# ← ServerDomainDTO.swift(날짜 코딩 부분) + localDate(yyyy-MM-dd) 포매터 1곳으로 단일화
│   │   └── TokenStore.swift
│   ├── HealthKit/
│   │   ├── HealthKitManager.swift# 가용성·권한 상태·권한 요청만
│   │   ├── SleepFetchService.swift
│   │   └── SleepSampleSource.swift            # 신규: protocol (읽기 포트)
│   ├── Security/
│   │   └── KeychainHelper.swift
│   ├── DesignSystem/
│   │   └── HealthCard.swift      # HealthCard·CategoryIconBadge·HealthMetric·SectionHeader
│   └── Model/
│       ├── CaffeineCondition.swift            # + `effectiveHalfLife(base:)` 메서드
│       └── AppConstants.swift    # ← Utilities/Constants.swift
└── Resources/                    # 변경 없음
```

삭제: `Models/CaffeineRecord.swift`, `Models/HalfLifeObservation.swift`(SwiftData), `Utilities/CaffeineHelpers.swift`의 레거시 함수
(`filterTodayRecords`·`calculateTotalCaffeine`·`isOverDailyLimit`·`toDoses`), `.claude/PROJECT_ANALYSIS.md`,
`SleepData.swift`의 `SleepRecord`와 records 기반 재계산 프로퍼티 5개(단계 5), `AddCaffeineView.nextBedtimeForPreview`와 `yyyy-MM-dd` 포매터 사본 2곳(단계 3),
테스트 `SleepDataSOLTests.swift` 전체·`SleepSummaryTests`의 재계산 테스트 3개(단계 5).

## 3. 단계별 작업

각 단계는 **독립 커밋**. 검증 명령은 §4.

### 단계 0 — 작업 중 변경(WIP) 정리 · 0.5h

현재 미커밋 9파일(홈 히어로 디스크, 접이식 카드, 학습 상세 접기, BASE_URL EC2, UI 테스트, 문자열 카탈로그).

- [x] `captest1UITests.swift`: 존재하지 않는 `"자세히"` 탭 제거. 디스크에 `.accessibilityIdentifier("caffeineSignalDisc")`를 달고 존재만 확인. `"0 mg"` 단언 삭제(디스크가 접근성 자식을 무시하므로 노출 안 됨).
- [ ] `Config/Info.plist`: BASE_URL·ATS 변경은 **별도 커밋**으로 분리(단계 8에서 빌드 구성별로 다시 정리).  ← **미커밋**: 커밋이 자동 모드 권한 분류기에 차단됨(ATS 보안 설정). 사용자가 직접 커밋할 것
- [x] 나머지 UI 변경 커밋: `feat: 홈 히어로 신호등 디스크 + 접이식 카드`.

**Done**: `git status` 깨끗. 빌드 통과.

### 단계 1 — 응답 봉투 대응 (가장 시급) · 2h

서버 계약(`../server` README "공통 응답 구조", `docs/api.md`, `docs/openapi.yaml`): 키 4개 항상 존재.
바디 없던 성공(로그아웃·삭제)은 **200 + `data: null`**(구 204 대체). `error.fieldErrors`는 검증 실패에만 있고 없으면 키 자체가 생략된다(옵셔널로 받으면 됨).
```json
{ "success": true,  "data": { ... }, "error": null, "message": null }
{ "success": false, "data": null, "error": { "code": "INVALID_CREDENTIALS" }, "message": "이메일 또는 비밀번호가 올바르지 않습니다." }
{ "success": false, "data": null, "error": { "code": "VALIDATION_FAILED", "fieldErrors": [ { "field": "email", "message": "..." } ] }, "message": "입력값이 올바르지 않습니다." }
```
페이로드 DTO는 서버 record와 **필드 단위로 일치** 확인 완료(2026-09-04). 바뀌는 건 봉투뿐.

- [x] `Core/Networking/APIEnvelope.swift` 신규:
  ```swift
  nonisolated struct APIEnvelope<T: Decodable>: Decodable, Sendable where T: Sendable {
      let success: Bool
      let data: T?
      let error: APIErrorBody?
      let message: String?
  }
  nonisolated struct APIErrorBody: Decodable, Sendable {
      let code: String
      let fieldErrors: [ServerFieldError]?
  }
  ```
- [x] `APIClient.decode`: `APIEnvelope<T>`로 디코딩 → `success && data != nil`이면 `data` 반환, 아니면 `error.code`+`message`로 `APIError` 생성. 바디 없는 성공(로그아웃·삭제)은 `APIEnvelope<EmptyPayload>`로 받고 `data`를 무시.
- [x] `APIClient.parseError`: 최상위 `code` 대신 `error.code`, 문장은 최상위 `message`. 기존 `ServerErrorResponse` 삭제.
- [x] `APIError` 확장: 서버 `ErrorCode` 전 항목 매핑 (2026-09-05 서버 `ErrorCode.java` 13개와 대조 완료, 아래 목록이 전부). 프레임워크가 상태를 정하는 `HTTP_{status}` 코드는 `.unknown`으로.
  - 기존: `EMAIL_ALREADY_EXISTS`, `INVALID_CREDENTIALS`, `INVALID_REFRESH_TOKEN`, `VALIDATION_FAILED`, `MALFORMED_JSON`, `INTERNAL_ERROR`
  - 추가: `UNAUTHORIZED`·`FORBIDDEN` → `.unauthorized`, `NOT_FOUND`·`CAFFEINE_RECORD_NOT_FOUND` → `.notFound`, `INVALID_PARAMETER` → `.invalidParameter`, `METHOD_NOT_ALLOWED`·`UNSUPPORTED_MEDIA_TYPE` → `.unknown`
  - `toUserMessage()`는 서버 `message`(한국어)가 있으면 우선 사용.
- [x] 401 → refresh 재시도 로직은 **HTTP 상태 기준이므로 변경 없음**.
- [x] 단위 테스트 `Core/Networking/APIClientEnvelopeTests.swift`: `URLProtocol` 스텁으로 위 JSON 3종 + 401→refresh→재시도 1회 시나리오.

**Done**: 로컬 서버(`../server` HEAD, `./gradlew bootRun`)에 회원가입→로그인→홈 로드→기록 추가→로그아웃 통과. 잘못된 비밀번호 시 "이메일 또는 비밀번호가 올바르지 않습니다." 표시.

> EC2에 봉투 도입 이전 이미지가 떠 있으면 앱이 반대로 깨진다. 먼저 재배포할 것. 절차는 서버 `CLAUDE.md` "배포" 절
> (EC2에 인터넷이 없어 PC에서 `docker save` → `scp` → EC2에서 `docker load` → `docker compose -f docker-compose.prod.yml up -d` → `curl localhost:8080/actuator/health`).
> 서버 문서가 가리키는 `docs/운영-가이드.md`는 2026-09-05 현재 존재하지 않는다. 인증 없이 `GET /api/settings`를 쳐서 `{"success":false,"error":{"code":"UNAUTHORIZED"}…}`가 오면 봉투 버전이다.

### 단계 2 — 폴더 재편 (이동만, 코드 수정 0) · 0.5h

`captest1/`은 Xcode 동기화 루트 그룹이라 `git mv`만으로 반영된다. **Xcode를 닫고** 진행.

| 현재 | 이동 |
|---|---|
| `Services/AppEnvironment.swift` | `App/` |
| `Views/Auth/RootView.swift`, `Views/ContentView.swift` | `App/` |
| `Views/Auth/{LoginView,SignupView}.swift`, `Services/AuthManager.swift`, `Models/{AuthState,AuthDTO}.swift` | `Features/Auth/` |
| `Views/{HomeView,AddCaffeineView,CaffeineChartView}.swift`, `ViewModels/AddCaffeineViewModel.swift`, `Views/Components/{CutoffHeroCard,CutoffPreviewBanner}.swift`, `Services/{CaffeineStore,CaffeineKineticsCalculator}.swift`, `Models/DrinkPreset.swift`, `Utilities/CaffeineHelpers.swift` | `Features/Caffeine/` |
| `Views/SleepAnalysisView.swift`, `Views/Sleep/*.swift`, `Models/{SleepData,ServerSleepDTO}.swift` | `Features/Sleep/` |
| `Views/LearningDashboardView.swift`, `Views/Components/{CalibrationScatterChart,ConfidenceBar}.swift`, `Services/LearningStore.swift`, `Models/ServerLearningDTO.swift` | `Features/Learning/` |
| `Views/SettingsView.swift`, `Services/SettingsManager.swift`, `Models/ServerDomainDTO.swift` | `Features/Settings/` (DTO는 단계 3에서 분할) |
| `Services/{APIClient,TokenStore}.swift` | `Core/Networking/` |
| `Services/{HealthKitManager,SleepFetchService}.swift` | `Core/HealthKit/` |
| `Services/KeychainHelper.swift` | `Core/Security/` |
| `Views/Components/HealthCard.swift` | `Core/DesignSystem/` |
| `Models/CaffeineCondition.swift`, `Utilities/Constants.swift` | `Core/Model/` |
| `Models/{CaffeineRecord,HalfLifeObservation}.swift` | 그대로 두고 단계 6에서 삭제 |

**Done**: 빌드·단위 테스트 통과(코드 변경 없음). 커밋 `refactor: Feature-first 폴더 재편 (이동만)`.

### 단계 3 — 파일 분할 · 중복 제거 · 1.5h

- [x] `ServerDomainDTO.swift` → `Core/Networking/ServerDateCoding.swift` + `Features/Caffeine/CaffeineDTO.swift` + `Features/Settings/SettingsDTO.swift`
- [x] `AuthDTO.swift` → `APIError`·`ServerFieldError`는 `Core/Networking/APIError.swift`, 나머지는 그대로
- [x] `CaffeineHelpers.swift` → `Features/Caffeine/CaffeineCutoff.swift`로 개명. `effectiveHalfLife(base:condition:)`는 `CaffeineCondition.effectiveHalfLife(base:)` 메서드로 `Core/Model`에 이동(설정·카페인 양쪽이 쓰므로). 레거시 함수 4개는 단계 6까지 유지.
- [x] `SleepData.swift` → `SleepModels.swift`, `Constants.swift` → `AppConstants.swift`
- [x] **날짜 포매터 단일화**: `ServerDateCoding`에 `static let localDate: DateFormatter`(yyyy-MM-dd, gregorian, en_US_POSIX, `.current`) 추가.
  `SettingsManager.serverDateFormatter`, `HealthKitManager.localDateString`, `ObservationItem.formatter` 세 사본을 이걸로 교체.
- [x] **미리보기 취침시각을 서버 값으로**: `AddCaffeineView.nextBedtimeForPreview` 삭제. `CaffeineStore`에 `var bedtime: Date? { today?.bedtime }` 추가하고
  `cutoffPreview`는 `guard !isEditMode, let bedtime = store.bedtime else { return nil }`. 서버 `bedtime`은 `LocalCalendar.nextBedtime`(오늘 hh:mm, 지났으면 내일)이라
  삭제하는 함수와 의미가 같다. `today`가 아직 없으면 배너를 안 띄운다(그때는 doses도 비어 있어 미리보기 의미가 없음).
  차트의 `resolvedBedtimeDate`(차트 기준일 취침시각)는 의미가 달라 **그대로 둔다**(단계 8 참고).

**Done**: 빌드·단위 테스트 통과. `grep -rn 'dateFormat = "yyyy-MM-dd"' captest1` 결과 1곳. 커밋 `refactor: DTO·헬퍼 파일을 Feature 단위로 분할, 포매터·미리보기 취침시각 중복 제거`.

### 단계 4 — Repository 포트 도입 · 3h (핵심)

각 Feature에 프로토콜 1개 + `APIClient` 확장 1개. 스토어는 프로토콜 타입만 소유.

```swift
// Features/Caffeine/CaffeineRepository.swift
protocol CaffeineRepository: Sendable {
    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse
    func create(_ req: CreateCaffeineRecordRequest) async throws -> CaffeineRecordDTO
    func update(id: Int64, _ req: UpdateCaffeineRecordRequest) async throws -> CaffeineRecordDTO
    func delete(id: Int64) async throws
}

// Features/Caffeine/APIClient+Caffeine.swift
extension APIClient: CaffeineRepository {
    func today(now: Date, timeZone: TimeZone) async throws -> CaffeineTodayResponse {
        try await get("/api/caffeine/today", query: ["now": isoOffset(now), "tz": timeZone.identifier])
    }
    // create/update/delete …
}

// Features/Caffeine/CaffeineStore.swift
@MainActor @Observable final class CaffeineStore {
    private let repository: any CaffeineRepository
    init(repository: any CaffeineRepository) { … }
}
```

- [x] `APIClient` 본체에 제네릭 헬퍼만 남김: `get/post/put/delete(path:query:body:)` + `postNoContent` 등 `internal`. 기존 엔드포인트 메서드는 Feature 확장으로 이동.
  - `AuthRepository`: `login`, `signup`, `refresh`, `logout`, `me`
  - `CaffeineRepository`: 위
  - `SleepRepository`: `uploadSamples`, `summary(date:timeZone:)`
  - `LearningRepository`: `run(timeZone:)`, `dashboard()`
  - `SettingsRepository`: `get()`, `update(_:)`
- [x] 스토어 5개 생성자를 프로토콜 주입으로 변경: `CaffeineStore`, `LearningStore`, `AuthManager`, `SettingsManager.attach(repository:)`, (수면은 단계 5)
- [x] `captest1App.swift` 조립부: `APIClient` 인스턴스 하나를 각 프로토콜 타입으로 주입.
- [x] `#Preview`: 각 Feature에 `Preview<X>Repository` 페이크를 두어 네트워크 없이 미리보기.

**Done**: 빌드 통과. `grep -rn "APIClient" captest1/Features` 결과가 `APIClient+X.swift` 파일뿐. 커밋 `refactor: Repository 포트 도입, APIClient를 Core 전송층 + Feature 확장으로 분리`.

### 단계 5 — HealthKit 분리 · 수면 요약 서버값 사용 · 2.5h

- [x] `Core/HealthKit/SleepSampleSource.swift`: `protocol SleepSampleSource { func fetchRawSamples(for date: Date) async throws -> [RawSleepSample] }`, `SleepFetchService`가 채택.
- [x] `Core/HealthKit/HealthKitManager.swift`: `isAvailable`·`accessState`·`refreshAccessState`·`requestAuthorization`만. `hasRequestedHealthKitAuthorization` 플래그를 `SettingsManager`에서 **이 클래스로 이동**(UserDefaults 키 `hasRequestedHealthKitAuthorization` 유지 → 기존 사용자 상태 보존). 이로써 Core→Features 의존이 사라진다.
- [x] `Features/Sleep/SleepStore.swift` 신규: `lastNightSummary`·`recentSummaries`·`isLoading`·`errorMessage`·`loadData()`·`loadDataIfNeeded()`. 의존: `any SleepSampleSource` + `any SleepRepository`. 8일치 로드는 `withThrowingTaskGroup`으로 병렬화(현재 순차 최대 16회 왕복).
- [x] **`SleepSummary`를 서버값 표시 모델로 축소** (`Features/Sleep/SleepModels.swift`). 서버 `SleepSummaryResponse`와 1:1:
  ```swift
  struct SleepSummary: Identifiable {
      let id = UUID()
      let date: Date
      let bedtimeStart: Date?
      let totalSleepDuration: TimeInterval   // ← totalSleepSeconds
      let timeInBed: TimeInterval            // ← timeInBedSeconds (서버도 최초 시작~최후 끝 스팬, 현재 클라 정의와 동일)
      let sleepEfficiency: Double            // ← sleepEfficiency
      let sleepOnsetLatency: TimeInterval?   // ← sleepOnsetLatencySeconds
      let stageBreakdown: [(stage: SleepStage, duration: TimeInterval)]  // ← stageBreakdown (서버도 SleepStage 선언 순서)
      static func formatDuration(_ interval: TimeInterval) -> String   // 유지 (표시 포맷일 뿐 연산 아님)
  }
  ```
  매핑은 `SleepStore`가 담당(`hasData == false`면 nil, `hkValue`→`SleepStage(from:)`). `SleepRecord`와 records 기반 계산 프로퍼티 5개
  (`totalSleepDuration`·`timeInBed`·`sleepEfficiency`·`sleepOnsetLatency`·`stageBreakdown`)는 삭제.
  뷰 3개(`LastNightCard`·`StageBreakdownView`·`RecentNightsView`)가 쓰는 멤버는 `date`·`totalSleepDuration`·`timeInBed`·`sleepEfficiency`·`stageBreakdown`뿐이라 **뷰 변경 없음**
  (`records`·`sleepOnsetLatency`는 뷰에서 미사용, 2026-09-05 확인).
- [x] 테스트 정리: `SleepDataSOLTests.swift` 삭제(SOL은 서버 `BedtimeExtractor`·`SleepSummaryCalc`가 계산하고 서버 테스트가 담당),
  `ModelTests.SleepSummaryTests`에서 `totalSleepDuration`·`sleepEfficiency`·`stageBreakdown` 3개 삭제. `formatDuration` 2개는 유지.
  `SleepStage.isAsleep`은 재계산 프로퍼티 외에 쓰는 곳이 없으므로(2026-09-05 확인) 함께 삭제하고 `SleepStageTests.isAsleep_correctForAllCases`도 지운다.
- [x] 뷰 교체: `SleepAnalysisView`·`SettingsView`·`ContentView`는 권한은 `HealthKitManager`, 데이터는 `SleepStore`에서 읽음. `captest1App`에 `SleepStore` 주입 추가.

**Done**: 실기기에서 권한 요청→수면 탭 로드 통과(시뮬레이터는 빈 상태 화면). 재편 전후 수면 탭 숫자(총수면·침대에서·효율·단계별)가 같은지 스크린샷 비교.
`grep -nE "reduce|filter" captest1/Features/Sleep/SleepModels.swift` 결과 없음. 커밋 `refactor: HealthKit 권한(Core)과 수면 스토어(Feature) 분리, 수면 요약은 서버값 표시`.

### 단계 6 — 레거시 삭제 · 문서 갱신 · 1h

- [x] 삭제: `CaffeineRecord.swift`, `HalfLifeObservation.swift`, `captest1App.sharedModelContainer`와 `import SwiftData`, `CaffeineCutoff.swift`의 레거시 함수 4개, `.claude/PROJECT_ANALYSIS.md`
- [x] 테스트 정리: `HalfLifeObservationTests.swift` 삭제, `CaffeineHelpersTests.swift`에서 `filterTodayRecords`·`calculateTotalCaffeine`·`isOverDailyLimit` 테스트 삭제(`koreanTimeLabel`·`resolvedBedtimeDate`는 유지)
- [x] `README.md`·`CLAUDE.md`·`AGENTS.md`의 "프로젝트 구조" 트리를 §2로 교체, §1 의존 규칙 추가. `docs/server-migration-plan.md`의 Flyway 언급에 "서버는 2026-09-03 Flyway 제거" 주석.

**Done**: `grep -rn "SwiftData" captest1` 결과 없음. 커밋 `chore: 서버 이관 잔재 삭제 + 구조 문서 갱신`.

### 단계 7 — 테스트 · 3h

포트가 생겼으니 스토어 로직을 페이크로 검증한다.

- [x] `captest1Tests/Fakes/`: `FakeCaffeineRepository`, `FakeLearningRepository`, `FakeSettingsRepository`, `FakeSleepRepository`, `FakeSleepSampleSource`(고정 응답 + 호출 기록)
- [x] `CaffeineStoreTests`: `cutoffResult` 매핑 3분기(`SAFE_ANYTIME`/`CUTOFF`/`ALREADY_EXCEEDED`), `add` 실패 시 `errorMessage` 설정과 `false` 반환, 성공 시 `refresh` 재호출
- [x] `LearningStoreTests`: `updatedCount == 0`이면 `skipMessage` 노출, run 실패 시 dashboard만이라도 조회
- [x] `SettingsManagerTests`: `applyServer` 후 `halfLife` didSet의 prior 리셋이 서버 `learned*`로 덮이는지, `scheduleSync` 디바운스 1회 PUT
- [x] `SleepStoreTests`: 원시 샘플 없으면 업로드 생략, `hasData == false`면 nil, `SleepSummaryResponse` → `SleepSummary` 매핑(초→`TimeInterval`, hkValue→`SleepStage`, 단계 순서 보존, `sleepOnsetLatencySeconds` nil 전파)
- [ ] (선택) UI 테스트용 `-uiTesting` 런치 인자: 조립부에서 페이크 Repository + 인증 상태 `authenticated`로 시작 → 서버 없이 탭 이동 테스트 통과  ← 미실시(선택)

**Done**: `-only-testing:captest1Tests` 전부 통과. 커밋 `test: 스토어 단위 테스트 추가 (페이크 Repository)`.

### 단계 8 — 선택 · 1~2h

- [ ] BASE_URL을 빌드 구성별로: Debug `http://localhost:8080`, Release EC2. `NSAllowsArbitraryLoads`는 Debug 전용 plist 또는 xcconfig로 한정. 서버 HTTPS 전환 시 제거.
- [ ] `SettingsManager.halfLife` didSet의 prior 리셋을 명시적 메서드(`resetPriorForManualHalfLife()`)로 바꿔 `applyServer` 순서 의존 제거.
- [ ] 차트의 취침 룰·위험 구간(`CaffeineChartView`)도 서버 `today.bedtime`으로 통일할지 결정. 통일하면 `resolvedBedtimeDate`와 테스트 3개를 지울 수 있지만,
  지금 시각이 취침시각을 지난 경우 서버 값은 다음날이라 차트 범위(기준일 05시 + 24h) 밖으로 나가 취침선·위험 구간이 사라진다. 실기기에서 밤 시간대 화면을 확인하고 결정.

## 4. 검증 명령

```bash
# 빌드
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 단위 테스트 (기본 검증)
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:captest1Tests test

# 의존 규칙 점검 (Core가 Features를 참조하면 안 됨)
grep -rnE "SettingsManager|CaffeineStore|LearningStore|SleepStore|AuthManager" captest1/Core && echo "규칙 위반" || echo "OK"

# 엔드포인트가 본체에 남아 있지 않은지
grep -n '"/api/' captest1/Core/Networking/APIClient.swift && echo "본체에 엔드포인트 잔존" || echo "OK"

# 수면 요약을 클라가 재계산하지 않는지 (records 기반 reduce/filter가 없어야 함)
grep -nE "reduce|filter" captest1/Features/Sleep/SleepModels.swift && echo "재계산 잔존" || echo "OK"

# yyyy-MM-dd 포매터가 Core/Networking 한 곳뿐인지
grep -rn 'dateFormat = "yyyy-MM-dd"' captest1 | grep -v "Core/Networking/ServerDateCoding.swift" && echo "포매터 사본 잔존" || echo "OK"
```

## 5. 일정 · 커밋 순서

| 단계 | 내용 | 예상 | 커밋 |
|---|---|---:|---|
| 0 | WIP 정리 | 0.5h | `feat: 홈 히어로 신호등 디스크 + 접이식 카드` / `chore: BASE_URL EC2` |
| 1 | 봉투 대응 | 2h | `fix: 서버 ApiResponse 봉투 대응 + ErrorCode 매핑` |
| 2 | 폴더 이동 | 0.5h | `refactor: Feature-first 폴더 재편 (이동만)` |
| 3 | 파일 분할·중복 제거 | 1.5h | `refactor: DTO·헬퍼 파일을 Feature 단위로 분할, 포매터·미리보기 취침시각 중복 제거` |
| 4 | Repository 포트 | 3h | `refactor: Repository 포트 도입, APIClient 분리` |
| 5 | HealthKit 분리 + 수면 요약 서버값 | 2.5h | `refactor: HealthKit 권한(Core)과 수면 스토어(Feature) 분리, 수면 요약은 서버값 표시` |
| 6 | 레거시 삭제·문서 | 1h | `chore: 서버 이관 잔재 삭제 + 구조 문서 갱신` |
| 7 | 테스트 | 3h | `test: 스토어 단위 테스트 추가` |
| 8 | 선택 | 1~2h | `chore: BASE_URL 빌드 구성 분리` |

핵심(1~4)은 하루, 전체는 이틀. 단계 1은 단독으로도 배포 가치가 있으므로 먼저 끝내고 main에 올린다.

## 6. 리스크

- **파일 이동 중 Xcode 열림**: 동기화 그룹이 즉시 반영되지만 편집 중 충돌 가능. 닫고 `git mv` 후 재오픈.
- **EC2 서버 버전**: 봉투 이전 이미지가 떠 있으면 단계 1 이후 앱이 EC2에서 깨진다. 재배포 선행.
- **`SettingsManager` didSet 부작용**: `halfLife` 변경이 학습값을 리셋한다. 단계 5에서 플래그를 옮길 때 didSet 순서를 건드리지 말 것(단계 8에서 정리).
- **UI 테스트 로그인 게이트**: 페이크 주입(단계 7 선택) 전까지 UI 테스트는 저장된 세션 + 서버가 필요.
- **취침시각 의미 두 가지**: 서버 `today.bedtime`(=`LocalCalendar.nextBedtime`, 지금 이후 첫 취침)은 미리보기의 `nextBedtimeForPreview`와 같지만, 차트의 `resolvedBedtimeDate`(차트 기준일 취침)와는 다르다. 단계 3에서는 미리보기만 서버 값으로 바꾸고 차트는 건드리지 않는다.
- **수면 숫자 동일성**: 서버 `SleepSummaryCalc`의 `timeInBedSeconds`는 최초 시작~최후 끝 스팬(IN_BED 합이 아님), `stageBreakdown`은 `SleepStage` 선언 순서로, 둘 다 현재 클라 정의와 같다. 그래도 단계 5 Done에서 실기기 스크린샷으로 확인.

## 7. 범위 밖

SPM 멀티모듈·Tuist, TCA·RIBs 도입, UseCase 계층, 오프라인 동기화, SwiftData 재사용. 팀·기능이 커지면 `Features/<X>`를 그대로 패키지로 승격한다.

## 8. 2026-09-05 개정 내역 (재분석 반영)

코드를 다시 훑어 계획을 검증했다. **채택 구조는 그대로**(다른 아키텍처로 바꿀 이유 없음), 아래를 보완했다.

| 구분 | 내용 | 반영 위치 |
|---|---|---|
| 신규 발견 | 서버가 보낸 수면 요약값(총수면·침대시간·효율·단계별 합계)을 앱이 버리고 `SleepSummary`가 records로 재계산. thin-client 원칙 위반, 서버 병합 로직 변경 시 두 값이 갈라짐 | §0, §2, 단계 5, §4, §6 |
| 신규 발견 | `yyyy-MM-dd` 포매터 3벌, 취침시각 계산 2벌(미리보기용은 서버 `today.bedtime`과 의미 동일) | 단계 3, 단계 8 |
| 검증 완료 | 단계 1의 봉투 구조·`ErrorCode` 13개 매핑이 서버 HEAD(`global/web/ApiResponse.java`·`global/error/ErrorCode.java`)와 일치. 앱 쪽 봉투 대응은 미착수 | 단계 1 |
| 검증 완료 | 수면 뷰 3개가 쓰는 `SleepSummary` 멤버는 `date`·`totalSleepDuration`·`timeInBed`·`sleepEfficiency`·`stageBreakdown`뿐. `records`·`sleepOnsetLatency`는 뷰에서 미사용 → 표시 모델 축소 시 뷰 변경 없음 | 단계 5 |
| 검증 완료 | 서버 `timeInBedSeconds`·`stageBreakdown` 정의가 현재 클라 계산과 동일 → 숫자 변화 없이 교체 가능 | §6 |
| 우선순위 | 봉투 대응(단계 1)은 구조 개선이 아니라 통신이 깨지는 버그. 폴더 이동보다 먼저, 단독 커밋으로 main에 | §3 순서 유지 |

현재 구조 진단 요약(발표·문서용):

- 파일 43개·약 4,900줄, 프로토콜 0개, 스토어 5개 전부 `APIClient` 구체 타입 의존, 스토어 단위 테스트 0개, 삭제 예정 코드를 검증하는 테스트 18개, 서버와 중복 계산을 검증하는 테스트 15개.
- 잘 된 것: 조립부가 `captest1App.init` 한 곳, 뷰는 `APIClient`를 직접 호출하지 않음(#Preview 2곳 제외), actor/MainActor/Sendable 일관, 스토어 5개가 서버 `domain/` 5개와 1:1.
- 검토한 대안과 결론: 풀 Clean(UseCase가 전부 한 줄 위임이 됨)·TCA(서버 응답 캐시 위주 상태에 보일러플레이트만 증가)·SPM 멀티모듈(이 규모에선 이득 없음) 모두 비권고. "아키텍처 교체"가 아니라 "폴더 축 교체 + Repository 포트 한 겹".
- 발표용 한 줄: "Clean Architecture의 의존 규칙을 적용한 Feature-first MVVM, Repository 포트까지만 채택".

## 9. 진행 기록 (2026-09-05, 브랜치 `feat/client-server-phase1`)

| 단계 | 커밋 | 비고 |
|---|---|---|
| 0 | `f46e442` feat(히어로 디스크), `e5ab057` docs(계획서) | `Config/Info.plist`(BASE_URL EC2·ATS)는 커밋이 권한 분류기에 차단되어 **미커밋으로 남김** |
| 1 | `db2470e` fix(봉투 대응) | 스텁 테스트 8개. 로컬 서버(HEAD)에 인증 없는 GET·잘못된 로그인·검증 실패·없는 경로 4건을 쳐서 봉투 형태가 스텁과 같음을 확인(계정 생성은 안 함). 실제 계정으로 로그인→기록 추가→로그아웃 E2E는 **사용자 확인 필요** |
| 2 | `4c20f41` refactor(폴더 이동) | 40개 rename, 코드 변경 0. Xcode를 연 채로 진행했으나 동기화 폴더라 문제 없음 |
| 3 | `3a8985b` refactor(분할·중복 제거) | 포매터 1곳, 미리보기 취침시각은 서버 `today.bedtime` |
| 4 | `85ad7f6` refactor(Repository 포트) | `AuthSession` 포트를 추가로 도입(AuthManager의 토큰 세션 제어가 APIClient 구체 타입에 남지 않도록). `toUserMessage()`는 알려진 코드엔 앱 문구 유지, 매핑 안 된 코드만 서버 message 사용(AuthManager가 케이스 패턴매칭을 하므로 enum에 message를 싣지 않음). 프리뷰 페이크는 프리뷰가 있는 Auth·Caffeine·Sleep에만 |
| 5 | `4544832` refactor(HealthKit 분리·수면 서버값) | 실기기 스크린샷 비교는 **사용자 확인 필요**(시뮬레이터는 HealthKit 없음) |
| 6 | `6847f16` chore(레거시 삭제·문서) | README·CLAUDE.md·AGENTS.md 트리·의존 규칙 교체 |
| 7 | `12ac5f0` test(스토어 테스트) | 단위 테스트 67개 통과. `SettingsManager(defaults:)` 주입, `CaffeineCutoffResult: Equatable` |
| 8 | 미착수 | BASE_URL 빌드 구성 분리, didSet 리셋 명시화, 차트 취침시각 통일 여부는 사용자 결정 |

남은 사용자 확인: (1) `Config/Info.plist` 커밋 여부, (2) 로컬 서버에서 앱 로그인→홈→기록 추가→로그아웃, (3) 실기기 수면 탭 숫자 비교, (4) EC2 서버가 봉투 버전인지 확인 후 재배포.
