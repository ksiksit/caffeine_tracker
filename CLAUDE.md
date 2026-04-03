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
```

## 프로젝트 개요

카페인 섭취 추적 및 수면 분석 iOS 앱. SwiftUI + SwiftData + HealthKit 기반.

- **카페인 추적**: 음료 프리셋/직접 입력으로 카페인 기록, 약동학(반감기 기반 지수 감쇠) 모델로 체내 잔류량 차트 표시
- **수면 분석**: HealthKit에서 수면 데이터(6단계) 조회, iPhone/Apple Watch 중복 샘플 병합 처리
- **설정**: 카페인 반감기 조정(3~7시간), HealthKit 연동 토글

## 아키텍처

```
captest1/
├── App/          # 앱 진입점, ModelContainer·HealthKitManager 주입
├── Views/        # SwiftUI 뷰 (TabView 3탭: 홈, 수면 분석, 설정)
├── ViewModels/   # @Observable @MainActor 뷰모델
├── Models/       # CaffeineRecord(@Model), DrinkPreset, SleepData
├── Services/     # CaffeineKineticsCalculator, HealthKitManager, SleepDataProcessor
├── Utilities/    # AppConstants(enum 상수), CaffeineHelpers
└── Resources/    # entitlements (HealthKit 권한)
```

**네비게이션**: TabView + NavigationStack (3탭)  
**데이터 흐름**: @Query(SwiftData) → ViewModel(@Observable) → View  
**설정 저장**: @AppStorage (반감기 등 경량 설정)

## 핵심 코드 패턴

- **뷰모델**: `@Observable @MainActor` 패턴 사용
- **뷰 구성**: private computed property로 서브뷰 분리
- **HealthKit**: async/await 기반, HealthKitManager를 @Environment로 주입
- **약동학 계산**: `amount = dose * exp(-ke * t)`, ke = ln(2)/halfLife, 15분 간격 시계열
- **수면 데이터 병합**: SleepDataProcessor가 단계 우선순위 기반으로 중복 샘플 병합
- **상수 관리**: `AppConstants` enum에 중앙 집중 (일일 권장량 400mg, 차트 간격 등)

## 주의사항

- 사용자와의 대화는 **한국어**로 진행
- 모든 UI 텍스트와 에러 메시지는 **한국어**로 작성
- DrinkPreset의 카페인 양은 실제 데이터 기반이므로 임의 변경 금지
- SleepDataProcessor의 병합 로직은 Apple Watch/iPhone 동시 착용 시나리오를 처리하므로 수정 시 관련 테스트 반드시 확인
