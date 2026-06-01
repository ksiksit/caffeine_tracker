# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 빌드 및 테스트 명령어

```bash
# 빌드
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 단위 테스트
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# UI 테스트
xcodebuild -scheme captest1UITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# 특정 테스트만 실행
xcodebuild -scheme captest1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:captest1Tests/<클래스명>/<메서드명> test
```

## 프로젝트 개요

질 좋은 수면을 위한 카페인 관리 앱. SwiftUI + HealthKit + Charts 기반의 **thin-client**.

> **풀스택 프로젝트**: 이 iOS 앱 + Spring 백엔드([`../server`](../server)). 도메인 연산(약동학·수면 병합·베이지안 학습)은
> **서버가 수행**하고, 앱은 사용자 입력을 전송하고 서버 계산 결과를 표시한다. **앱 실행 시 서버가 함께 떠 있어야 함**
> (`BASE_URL` 기본 `http://localhost:8080`).

- **카페인 관리**: 음료 프리셋/직접 입력으로 기록 → 서버 저장, 서버가 계산한 잔류량 차트·마감시각 표시
- **수면**: HealthKit 원시 수면 샘플을 읽어 **서버로 업로드**, 병합·SOL·요약은 서버가 계산해 표시
- **학습**: 서버가 카페인 잔량+수면 SOL로 베이지안 반감기 학습, 대시보드는 서버 통계 렌더
- **설정**: 반감기·건강상태·취침·기준용량을 서버에 저장(로컬 미러), 서버 연산의 입력값

## 아키텍처

```
captest1/
├── App/          # 앱 진입점, 환경 주입(Store·APIClient·Auth)
├── Views/        # SwiftUI 뷰 (TabView 4탭: 홈·수면 분석·학습·설정) + Auth/
│   └── Sleep/    # 수면 분석 서브뷰
├── ViewModels/   # AddCaffeineViewModel (즉시 미리보기 등)
├── Models/       # 서버 DTO, 프리셋, 수면 표시 모델, 건강 상태, (SwiftData 모델은 보존·미사용)
├── Services/     # APIClient, CaffeineStore/LearningStore(@Observable), SettingsManager,
│                 #   AuthManager/TokenStore/Keychain, HealthKitManager/SleepFetchService(읽기)
├── Utilities/    # 상수, 카페인 헬퍼(즉시 미리보기용)
└── Resources/    # entitlements, 에셋, 로컬라이제이션
```

**데이터 흐름**: 사용자 입력 → `APIClient` → 서버 연산 → `Store(@Observable)` → View
**수면**: HealthKit 원시 샘플 → 서버 업로드 → 서버 병합·요약 → View
**설정**: 서버 권위 + `SettingsManager` 로컬 미러(변경 시 디바운스 PUT)

## 핵심 도메인 지식 (연산은 서버에서 수행)

- **약동학 계산**: `amount = dose * exp(-ke * t)`, ke = ln(2)/halfLife — 서버 `calc.Pharmacokinetics`.
  단, **카페인 추가 화면 즉시 미리보기 1곳만** 로컬 `CaffeineKineticsCalculator`/`CaffeineHelpers.caffeineCutoffTime` 사용.
- **건강 상태 보정**: `effectiveHalfLife = base × condition.multiplier` — 흡연(×0.5), 경구피임약(×2.0), 임신(×2.5). 서버 resolve.
- **수면 병합**: 단계 우선순위(deep→REM→core→unspecified→awake→inBed) — 서버 `calc.SleepMerger`. 앱은 읽기·업로드만.

## 주의사항

- 사용자와의 대화는 **한국어**로 진행
- 모든 UI 텍스트와 에러 메시지는 **한국어**로 작성
- DrinkPreset의 카페인 양은 실제 데이터 기반이므로 임의 변경 금지
- CaffeineCondition의 multiplier 값(0.5, 1.0, 2.0, 2.5)은 약리학 근거 기반이므로 임의 변경 금지(서버 `calc`와 동일)
- HealthKit **읽기만** 기기에서 가능(Apple 정책) — 병합·SOL·학습은 서버. 수면 로직 변경은 서버 레포에서.
- 도메인 연산을 바꿀 땐 서버 `calc`가 source of truth — 클라 로컬 미러(즉시 미리보기)와 상수를 어긋나지 않게 유지.
