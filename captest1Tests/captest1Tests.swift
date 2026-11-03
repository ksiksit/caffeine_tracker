//
//  captest1Tests.swift
//  captest1Tests
//
//  Created by 김종범 on 3/24/26.
//

// 테스트 구성:
// - APIClientEnvelopeTests.swift      서버 응답 봉투 처리 (URLProtocol 스텁, Support/)
// - CaffeineStoreTests.swift          today 매핑·쓰기 흐름 (Fakes/FakeCaffeineRepository)
// - LearningStoreTests.swift          학습 실행·대시보드 (Fakes/FakeLearningRepository)
// - SettingsManagerTests.swift        서버 권위 값 적용·디바운스 PUT (Fakes/FakeSettingsRepository)
// - SleepStoreTests.swift             업로드 조건·서버 요약 매핑 (Fakes/FakeSleepRepository)
// - ModelTests.swift                  HealthKit 권한 상태, SleepStage·SleepSummary 표시 모델, DrinkPreset, 추가 화면 섭취 시각·저장 버튼 문구
// - CaffeineCutoffTests.swift         즉시 미리보기·차트 보조 함수
// - CaffeineKineticsCalculatorTests.swift  즉시 미리보기용 약동학 로컬 미러
//
// 약동학·수면 병합·베이지안 학습 등 서버로 이관된 로직의 검증은
// 서버 레포(calc/* 골든 테스트)로 이전됨.
