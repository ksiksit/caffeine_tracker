# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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
