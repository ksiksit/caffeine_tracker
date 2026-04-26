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

카페인 섭취 추적 및 수면 분석 iOS 앱. SwiftUI + SwiftData + HealthKit + Charts 기반.

- **카페인 추적**: 음료 프리셋/직접 입력으로 카페인 기록, 약동학 모델로 체내 잔류량 차트 표시
- **수면 분석**: HealthKit에서 수면 데이터(6단계) 조회, iPhone/Apple Watch 다중 기기 샘플 병합
- **설정**: 카페인 반감기 조정(3~7시간), 건강 상태별 반감기 보정(흡연/경구피임약/임신), 취침 시간 설정, HealthKit 연동

## 아키텍처

```
captest1/
├── App/          # 앱 진입점, ModelContainer·HealthKitManager 주입
├── Views/        # SwiftUI 뷰 (TabView 3탭: 홈, 수면 분석, 설정)
│   └── Sleep/    # 수면 분석 서브뷰 (어젯밤 카드, 단계 분석, 최근 기록)
├── ViewModels/   # 뷰모델
├── Models/       # SwiftData 모델, 프리셋, 수면 데이터, 건강 상태
├── Services/     # 약동학 계산, HealthKit 연동, 수면 데이터 처리
├── Utilities/    # 상수, 헬퍼 함수
└── Resources/    # entitlements, 에셋, 로컬라이제이션
```

**데이터 흐름**: @Query(SwiftData) → ViewModel(@Observable) → View
**설정 저장**: @AppStorage (반감기, 건강 상태, 취침 시간 등)

## 핵심 도메인 지식

- **약동학 계산**: `amount = dose * exp(-ke * t)`, ke = ln(2)/halfLife, 15분 간격 시계열
- **건강 상태 보정**: `effectiveHalfLife = base × condition.multiplier` — 흡연(×0.5), 경구피임약(×2.0), 임신(×2.5)
- **수면 데이터 병합**: 단계 우선순위(deep→REM→core→unspecified→awake→inBed) 기반으로 다중 기기 중복 샘플 병합

## 주의사항

- 사용자와의 대화는 **한국어**로 진행
- 모든 UI 텍스트와 에러 메시지는 **한국어**로 작성
- DrinkPreset의 카페인 양은 실제 데이터 기반이므로 임의 변경 금지
- CaffeineCondition의 multiplier 값(0.5, 1.0, 2.0, 2.5)은 약리학 근거 기반이므로 임의 변경 금지
- SleepDataProcessor의 병합 로직 수정 시 관련 테스트 반드시 확인
