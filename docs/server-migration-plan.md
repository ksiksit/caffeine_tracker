# 서버 기반 전환 계획서

> ## ✅ 전환 완료 (2026-06-01)
>
> 서버 이관이 완료되었습니다. **실제 채택 방식은 thin-client(서버 권위)** 입니다 —
> 앱은 입력을 전송하고 **서버가 약동학·수면 병합·베이지안 학습을 연산·저장**하며, 앱은 결과를 표시합니다.
> 아래 본문에 적힌 *local-first 양방향 동기화*는 **초기 구상이며 미채택**(오프라인 동기화는 고도화 과제로 보류)입니다.
>
> **실제 구현 요약:**
> - 서버: `settings`·`caffeine`·`sleep`·`learning` 도메인 + `calc/` 순수 연산(iOS Swift 포팅, 골든 테스트). Flyway `V1`~`V6`.
>   ※ 서버는 2026-09-03에 Flyway를 제거하고 `docs/db-schema.sql` 수동 적용으로 전환했다. 아래 Flyway 언급은 당시 기록이다.
> - 클라: `APIClient` + `CaffeineStore`/`LearningStore`(@Observable) + `SettingsManager` 서버 미러. HealthKit 읽기만 기기.
> - 타임존 계약(요청 `tz`), JSON 날짜 ISO-8601+오프셋, learning 순차 prior 체이닝.
> - 온라인 전용(기존 로컬 데이터는 버리고 새로 시작, 학습 mean/variance만 1회 시드 가능).
> - 상세 단계별 계획·검증은 작업 플랜 참조. 아래 §1~§6은 **초기 구상 기록(historical)**.

> 카페인 관리 앱(SwiftUI + SwiftData + HealthKit)을 **Spring Boot 백엔드 + 로컬 우선 동기화** 구조로 전환하는 로드맵.
> 앱 레포: `captest1` · 서버 레포: `../server` (Java 21 / Spring Boot 3.5 / **MySQL 8**)
> 최종 갱신: 2026-05-31 (구상) · 완료: 2026-06-01 (thin-client로 실현)

---

## 1. 현재 상태 (2026-05-31 기준)

### ✅ 완료 — 인증 (양쪽 다)
**클라이언트** (`captest1`): APIClient(actor, 401→refresh 자동 재시도) · AuthManager(bootstrap/login/signup/logout) · TokenStore+Keychain · AuthDTO(에러 계약) · Auth 화면들.

**서버** (`server`): signup/login/refresh(로테이션)/logout/me 전부 구현. 에러 계약(`EMAIL_ALREADY_EXISTS` 등 6종 + `fieldErrors`)이 클라이언트와 일치. refresh 토큰은 DB에 SHA-256 해시로 저장. JWT는 oauth2-resource-server, access 1h / refresh 14d. Flyway V1(users)·V2(refresh_tokens). Dockerfile·CI·prod 프로파일 완비.

### ⚠️ 즉시 수정 필요 — `/api/me` 타입 불일치 (로그인 차단 버그)
- **서버** `UserController.MeResponse.userId`: `String` (`jwt.getSubject()`) → JSON `"userId":"1"` (따옴표)
- **클라이언트** `MeResponse.userId`: `Int64` → 따옴표 문자열을 Int64로 디코딩하면 **실패** → `APIError.decoding`
- `getMe()`는 `login()`과 `bootstrap()` 둘 다에서 호출됨 → **현재 로그인하면 토큰은 받지만 getMe 단계에서 실패**해 인증 상태로 못 넘어감.
- **권장 수정(서버쪽)**: `MeResponse.userId`를 `Long`으로, `new MeResponse(Long.parseLong(jwt.getSubject()), ...)`. `SignupResponse.userId`가 이미 `Long`이라 일관성도 맞음.

### ❌ 미구현 — 도메인 데이터 (전환의 본체)
`CaffeineRecord`·`HalfLifeObservation`은 SwiftData 로컬 전용, 설정은 `@AppStorage`. 서버엔 카페인/관측/설정 도메인 자체가 없음.

---

## 2. 목표 아키텍처

```
 iOS (SwiftUI)                              Spring Boot 3.5 / MySQL 8
 View ─ ViewModel ─ Repository              Controller → Service → Repository
                      │                                    │
              SwiftData(캐시) ◀─ SyncService(actor) ──REST──▶  (도메인별 테이블)
```
- **로컬 우선**: SwiftData가 UI 1차 소스, SyncService가 백그라운드 양방향 동기화. 오프라인 동작.
- **충돌 해결**: `updatedAt` 기준 Last-Write-Wins (캡스톤 범위 단순화).
- **멱등 키**: 클라이언트 생성 `client_uuid`로 push 중복/재시도 안전.

---

## 3. 남은 작업 — 서버 (기존 도메인 컨벤션 그대로)

> 서버 `CLAUDE.md`의 "새 도메인 추가 순서" 준수: 패키지(Controller/Service/Repository/Entity/dto/exception) → SecurityConfig 등록 → Flyway `V{n}` → 테스트(H2, `*IT`).
> 모든 엔드포인트 인증 필요, `@AuthenticationPrincipal Jwt`의 subject로 user 스코프 격리.

### 도메인 1: `caffeine` — 카페인 기록  *(먼저, 수직 슬라이스 대상)*
- Entity(`BaseTimeEntity` 상속): `user_id`, `client_uuid`(unique), `amount`, `drink_name`, `timestamp`, `deleted`
- Flyway `V3__create_caffeine_records.sql`
- 엔드포인트:
  - `GET /api/caffeine-records?since=<iso8601>` — delta pull
  - `POST /api/caffeine-records` — client_uuid 멱등 업서트
  - `PUT /api/caffeine-records/{clientUuid}`
  - `DELETE /api/caffeine-records/{clientUuid}` — 소프트 삭제

### 도메인 2: `observation` — 반감기 학습 관측치
- Entity: `user_id`, `client_uuid`, `date`, `predicted_residual`, `observed_sol_minutes`, `prior_mean/variance`, `posterior_mean/variance`, `condition_multiplier`, `deleted`
- Flyway `V4__create_half_life_observations.sql`, 엔드포인트는 도메인 1과 동일 패턴

### 도메인 3: `settings` — 유저 설정/학습 상태
- Entity `user_settings`(`user_id` PK): `half_life`, `condition`, `bedtime_hour/minute`, `reference_dose_mg`, `is_learning_enabled`, `learned_mean`, `learned_variance`, `last_learned_date`
- Flyway `V5__create_user_settings.sql`
- `GET /api/settings` · `PUT /api/settings` (없으면 기본값 생성)

---

## 4. 남은 작업 — 클라이언트 (로컬 우선 동기화)

### 4-1. SwiftData 모델에 동기화 메타데이터 추가 + 마이그레이션
`CaffeineRecord`·`HalfLifeObservation`에:
```swift
var clientUUID: UUID      // 안정 식별자(서버 멱등 키)
var remoteId: Int64?      // 서버 PK, 동기화 전 nil
var updatedAt: Date       // LWW 기준
var isDirty: Bool         // push 필요
var isDeleted: Bool       // 소프트 삭제 tombstone
var userId: Int64?        // 유저 스코프
```
→ SwiftData 스키마 마이그레이션(기존 로컬 데이터 보존, 최초 로그인 시 현재 유저로 귀속).

### 4-2. APIClient에 도메인 메서드 추가 + DTO
인증과 동일 패턴으로 `caffeine-records`/`observations`/`settings` CRUD + `since` delta.

### 4-3. Repository + SyncService(actor)
- Repository: ViewModel이 SwiftData 직접 접근 대신 경유, 쓰기 시 `isDirty=true`·`updatedAt=now`.
- SyncService: **push**(dirty → POST/PUT/DELETE → remoteId 채우고 dirty 해제) / **pull**(`since` → client_uuid 업서트, LWW 병합) / 트리거(포그라운드·변경 디바운스·주기적) / `lastSyncAt` 유저별 보관.

### 4-4. 유저 스코프 & 설정 동기화
`@Query`에 `userId` 필터, 로그아웃 시 로컬 정리(`SettingsManager.resetLearnedData()` 재설계). `learnedMean/Variance`를 `user_settings`와 동기화하면 기기 간 학습 상태 유지(기기 종속 키 `hasRequestedHealthKit`는 제외).

---

## 5. 로드맵 (권장 순서 — 수직 슬라이스 우선)

| 단계 | 내용 | Done 기준 |
|------|------|-----------|
| **A. 계약 수정** | `/api/me` userId 타입 Long 통일 | 앱: 회원가입→로그인→자동로그인→로그아웃 end-to-end 통과 |
| **B. 수직 슬라이스(carffeine)** | 서버 도메인 1 + 클라 4-1~4-3을 **카페인 기록 하나로 끝까지** | 기기 A 기록 → 서버 → 기기 B 동기화. 오프라인 기록 후 복귀 시 push |
| **C. observation** | 동일 패턴 복제 | 학습 관측치 동기화 |
| **D. settings** | user_settings 양방향 | 재로그인 시 학습값/설정 복원 |
| **E. 하드닝** | 오프라인 큐·충돌·에러 UI · dev ATS(localhost http) · prod HTTPS/리버스 프록시 | 비행기모드→복귀 동기화, prod 배포 |

> **전략**: B에서 카페인 기록 하나로 전체 동기화 파이프라인(메타데이터·Repository·SyncService·LWW)을 먼저 검증한 뒤 C/D로 복제. 가장 단순한 엔티티로 아키텍처를 확정하는 게 리스크가 낮다.

---

## 6. 횡단 관심사 / 리스크
- **dev ATS**: 앱에서 `http://localhost:8080` 호출하려면 Info.plist App Transport Security 예외. prod는 HTTPS(서버 미완료 항목: HTTPS/리버스 프록시).
- **기존 로컬 데이터**: `userId/clientUUID` 없는 기존 기록 → 최초 로그인 시 1회 귀속 마이그레이션.
- **테스트**: SyncService 병합/LWW, 서버 도메인 `*IT`(H2). SleepDataProcessor 관련 테스트 유지.
- **보안**: refresh 회전/해시 저장 이미 구현됨. rate limit·비밀번호 정책은 여력 시.
