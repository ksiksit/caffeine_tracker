# 질 좋은 수면을 위한 카페인 관리 앱 (captest1)

`captest1`은 질 좋은 수면을 위한 카페인 관리를 돕는 iOS 앱입니다. 사용자가 마신 음료의 카페인 양을 기록하면, **서버**가 약동학 모델로 현재 체내 잔류량과 취침 시 예상 잔류량을 계산해 카페인 섭취가 수면에 미치는 영향을 보여주고, HealthKit 수면 데이터가 쌓이면 수면 잠복기(SOL)를 바탕으로 개인화된 카페인 반감기를 자동 학습해 예측 정확도를 높입니다.

> **풀스택 프로젝트 (thin-client)** — 이 iOS 앱은 [`../server`](../server)(Java · Spring Boot · MySQL)와 함께 동작합니다.
> 도메인 연산(약동학·수면 병합·베이지안 학습)과 데이터 저장은 **서버**가 담당하고, 앱은 사용자 입력을 전송하고 서버가 계산한 결과를 표시합니다.
> **앱을 실행하려면 서버가 함께 떠 있어야 합니다** (`BASE_URL` 기본값 `http://localhost:8080`).
>
> ```text
>   iOS 앱(captest1)                       서버(server)
>   기록 입력 · 화면 표시  ── REST(JWT) ──▶   약동학 · 수면 병합 · 베이지안 학습 ──▶ MySQL
>   HealthKit 읽기        ── 원시 샘플 업로드 ─▶   수면 병합 · SOL · 학습
> ```

## 프로젝트 소개

카페인은 섭취량뿐 아니라 섭취 시각, 개인별 대사 속도, 건강 상태에 따라 수면에 미치는 영향이 달라집니다. 이 프로젝트는 단순 섭취량 기록을 넘어, 사용자의 취침 시간과 실제 수면 데이터를 연결해 “질 좋은 수면을 위해 오늘 언제까지 카페인을 마셔도 괜찮은지”를 더 구체적으로 판단할 수 있도록 돕는 것을 목표로 합니다.

앱은 SwiftUI 기반의 4개 탭으로 구성됩니다.

| 탭 | 역할 |
| --- | --- |
| 홈 | 카페인 마감 시각을 hero로 강조, 잔류량 차트(50mg 안전선·취침 위험 영역 시각화), 취침 시 예상 잔류량, 오늘의 기록 |
| 수면 분석 | HealthKit 수면 기록 조회, 지난밤 수면 요약, 단계별 수면 분석, 최근 기록 표시 |
| 내 학습 데이터 | 베이지안 반감기 학습 결과, 신뢰도, 추세, 모델 정확도 시각화 |
| 설정 | 반감기, 건강 상태 보정, 취침 시간, 기준 섭취량, HealthKit 연동 관리 |

## 주요 기능

- 음료 프리셋과 직접 입력을 통한 카페인 기록 추가, 수정, 삭제
- 카페인 추가 시 마감 시각 변화 즉시 미리보기 (예: `오후 5:30 → 오후 4:15`)
- 오늘 섭취한 카페인의 총량과 현재 잔류량 계산
- 취침 시 예상 카페인 잔류량과 추가 섭취 가능 여부 안내
- 15분 간격의 카페인 잔류량 시계열 차트 제공 (50mg 안전선과 취침 후 위험 영역 시각화)
- HealthKit 수면 데이터 권한 요청 및 수면 기록 조회
- Apple Watch와 iPhone에서 중복 기록된 수면 샘플 병합
- 수면 단계별 시간, 총 수면 시간, 수면 효율, 수면 잠복기 분석
- HealthKit 수면 잠복기와 카페인 잔류량을 활용한 베이지안 반감기 자동 학습
- 건강 상태별 카페인 반감기 보정 지원

## 스크린샷

실제 스크린샷 파일은 별도 작업으로 추가할 예정입니다. 현재 README에는 깨진 이미지 링크가 생기지 않도록 예정 경로만 정리합니다.

| 화면 | 예정 경로 | 설명 |
| --- | --- | --- |
| 홈 | `docs/screenshots/home.png` | 마감 시각 hero, 잔류량 차트(안전선·위험 영역), 취침 시 예상량, 오늘의 기록 |
| 수면 분석 | `docs/screenshots/sleep-analysis.png` | 지난밤 수면 요약, 단계별 수면 분석, 최근 기록 |
| 내 학습 데이터 | `docs/screenshots/learning-dashboard.png` | 개인화 반감기 추정, 신뢰도, 모델 정확도 |
| 설정 | `docs/screenshots/settings.png` | 반감기, 건강 상태, 취침 시간, HealthKit 설정 |

## 기술 스택

| 영역 | 기술 |
| --- | --- |
| UI | SwiftUI |
| 상태 관리 | Observation (`@Observable`) Store, SwiftUI Environment |
| 네트워킹 | 서버 REST API (`APIClient`, JWT 인증, ISO-8601 날짜 계약) |
| 건강 데이터 | HealthKit (읽기만 — 원시 샘플을 서버로 업로드) |
| 차트 | Swift Charts |
| 설정 | 서버 저장 + `SettingsManager` 로컬 미러 |
| 로컬 저장소 | SwiftData 모델은 보존하되 미사용(온라인 전용) |
| 테스트 | Swift Testing + XCTest (도메인 연산 검증은 서버 골든 테스트로 이전) |

기본 데이터 흐름은 다음과 같습니다.

```text
사용자 입력 -> APIClient -> 서버 연산 -> Store(@Observable) -> SwiftUI View
HealthKit 원시 샘플 -> 서버 업로드 -> 서버 병합/요약·학습 -> View
```

## 핵심 계산/학습 모델

> 아래 연산은 모두 **서버(`../server`의 `calc` 패키지)에서 수행**됩니다. 앱은 결과를 표시합니다.
> 단 **카페인 추가 화면의 즉시 마감시각 미리보기 1곳만** 키 입력 왕복을 피하려고 로컬 공식(`CaffeineKineticsCalculator`)을 유지합니다.

### 카페인 약동학 모델

카페인 잔류량은 지수 감소 모델로 계산합니다.

```text
amount = dose * exp(-ke * t)
ke = ln(2) / halfLife
```

- `dose`: 섭취한 카페인 양(mg)
- `t`: 섭취 후 지난 시간(hour)
- `halfLife`: 카페인 반감기(hour)
- 기본 반감기는 5시간이며, 설정에서 3시간에서 7시간 범위로 조정할 수 있습니다.

### 건강 상태별 반감기 보정

서버는 설정된 기본 반감기에 건강 상태별 multiplier를 적용해 실제 계산에 사용할 반감기를 구합니다.

```text
effectiveHalfLife = baseHalfLife * conditionMultiplier
```

| 건강 상태 | Multiplier | 의미 |
| --- | ---: | --- |
| 해당 없음 | 1.0 | 기본 반감기 사용 |
| 흡연자 | 0.5 | 카페인 대사가 빨라지는 조건 |
| 경구 피임약 복용 | 2.0 | 카페인 대사가 느려지는 조건 |
| 임신 중 | 2.5 | 카페인 대사가 크게 느려지는 조건 |

### 수면 데이터 병합

HealthKit에는 iPhone과 Apple Watch가 같은 시간대에 수면 데이터를 동시에 기록할 수 있습니다. 앱은 원시 샘플을 서버에 업로드하고, 서버(`calc.SleepMerger`)가 모든 샘플의 시간 경계점을 기준으로 타임라인을 나누고, 겹치는 구간에서는 더 세분화된 수면 단계를 우선합니다.

우선순위는 다음 순서로 적용됩니다.

```text
deep -> REM -> core -> unspecified -> awake -> inBed
```

### 베이지안 반감기 자동 학습

이 프로젝트의 기술적 차별점은 카페인 기록과 HealthKit 수면 잠복기(SOL)를 연결해 개인화된 카페인 반감기를 학습한다는 점입니다. 학습은 **서버**가 수행하고(`calc.BayesianHalfLifeUpdater`), 앱의 "내 학습 데이터" 탭은 서버가 계산한 통계를 표시합니다.

- 취침 시 예상 카페인 잔류량과 실제 수면 잠복기를 관측값으로 사용합니다.
- 학습은 base half-life를 대상으로 수행하고, 건강 상태 multiplier는 별도로 적용합니다.
- 최근 미학습 날짜를 오래된 순으로 배치 학습하며, 직전 날의 결과를 다음 날의 prior로 쓰는 순차 갱신입니다.
- 수면 시간이 너무 짧거나, 취침 시각을 찾을 수 없거나, 카페인 잔류량이 너무 적은 경우에는 학습을 건너뜁니다.
- 학습 결과는 사후 평균, 사후 분산, 95% 신뢰구간, 모델 정확도 차트로 확인할 수 있습니다.

## 프로젝트 구조

```text
captest1/
├── App/          # 앱 진입점, 환경 주입(Store·APIClient·Auth)
├── Views/        # SwiftUI 화면과 공용 컴포넌트, Auth/(로그인·회원가입)
├── ViewModels/   # AddCaffeineViewModel (즉시 미리보기 등)
├── Models/       # 서버 DTO, 음료 프리셋, 수면 표시 모델, 건강 상태 (SwiftData 모델은 보존·미사용)
├── Services/     # APIClient, CaffeineStore/LearningStore, SettingsManager,
│                 #   AuthManager/TokenStore/Keychain, HealthKitManager/SleepFetchService(읽기),
│                 #   CaffeineKineticsCalculator(즉시 미리보기용)
├── Utilities/    # 상수, 카페인 헬퍼
└── Resources/    # entitlements, 에셋, 로컬라이제이션

captest1Tests/    # 단위 테스트 (도메인 연산 검증은 서버 골든 테스트로 이전)
captest1UITests/  # 기본 탭 이동과 런치 성능 UI 테스트
```

## 실행 방법

> **먼저 서버를 실행**해야 합니다. [`../server`](../server)의 README를 따라 백엔드를 `http://localhost:8080`에 띄우세요
> (앱의 `BASE_URL` 기본값). 회원가입/로그인 후 기능을 사용할 수 있습니다.

1. 서버(`../server`)를 로컬에서 실행합니다.
2. Xcode에서 `captest1.xcodeproj`를 엽니다.
3. Scheme을 `captest1`로 선택하고, 실행 대상은 `iPhone 17 Pro` 시뮬레이터를 기준으로 합니다.
4. Run 버튼을 눌러 앱을 실행하고, 회원가입/로그인합니다.

HealthKit 수면 분석은 기기 환경, HealthKit 권한, 실제 수면 데이터 유무에 따라 결과가 달라질 수 있습니다. 시뮬레이터에서는 앱 화면과 기본 흐름을 확인할 수 있지만, 실제 수면 데이터 연동 검증은 HealthKit 데이터가 있는 기기에서 확인하는 것이 좋습니다.

## 빌드 및 테스트

### 빌드

```bash
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### 단위 테스트

기본 검증은 빌드 후 단위 테스트를 실행하는 흐름을 권장합니다.

```bash
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1Tests test
```

### UI 테스트

UI를 변경했거나 UI 흐름 검증이 필요할 때 별도로 실행합니다.

```bash
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1UITests test
```

### 전체 테스트

전체 테스트는 단위 테스트와 UI 테스트가 함께 실행될 수 있으므로 기본 검증 명령으로는 사용하지 않습니다.

```bash
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

테스트 실패를 해석할 때는 컴파일 실패, 단위 테스트 실패, UI 테스트 실패, CoreSimulator 또는 테스트 러너 실행 실패를 구분해야 합니다. `CoreSimulatorService connection became invalid`, `Simulator device failed to launch`, `xctrunner`, `ipc/mig server died` 같은 오류는 앱 로직 실패로 단정하지 않습니다.

## 참고 사항

- 모든 UI 텍스트와 사용자-facing 메시지는 한국어를 기준으로 작성되어 있습니다.
- DrinkPreset의 카페인 양과 건강 상태별 multiplier는 도메인 근거를 바탕으로 한 값이므로 임의 변경하지 않습니다(서버 `calc`와 동일 값 유지).
- 수면 병합·약동학·베이지안 학습 로직은 **서버(`../server`의 `calc` 패키지)**가 source of truth이며, 변경 시 서버의 골든 테스트를 함께 확인해야 합니다.
- 이 앱은 개인의 카페인 섭취와 수면 패턴을 이해하기 위한 참고용 도구이며, 의학적 진단이나 치료를 대체하지 않습니다.
