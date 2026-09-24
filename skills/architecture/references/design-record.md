# 설계 문서 양식

설계 문서는 저장소의 `README.md`나 `docs/`에 둔다. 절 순서는 아래를 따르고, 해당 없는 절은 "해당 없음"으로 남긴다.

## 목차

1. Introduction: 목적, 범위(디렉터리별 내용), 용어, 개발 환경
2. System Context: 문맥도, 외부 인터페이스 표
3. Architecture: 설계 원칙, 계층, 컴포넌트 모델, 스레드 모델, 메시지 흐름, 상태 관리, 시간 계약
4. Key Design Decisions: 결정마다 이유와 측정값
5. Safety Design: 상태 기계, 전역 스위치, 시작 시 검증, 보호 기능
6. Communication Protocols: 프레이밍 표, 주의할 점
7. Failure Detection and Recovery: 상대별 감지와 복구 표
8. Logging: 형식, 태그, 보존 정책
9. Configuration: 키, 의미, 주의 사항
10. Build: 명령, 의존 라이브러리와 버전
11. Test Strategy: 시험 목록과 판정 기준
12. Source Layout: 디렉터리 트리와 파일별 역할
- Appendix A. 기존 시스템의 설계 문제
- Appendix B. 현장 확인 항목
- Appendix C. 미구현 항목
- Appendix D. 원칙 예외

## 표 양식

### 외부 인터페이스

| Peer | Direction | Address | Protocol | Rate |
| --- | --- | --- | --- | --- |
| Operator screen | we listen | :80 | WebSocket | 3 s per status kind |

### 설계 원칙

| Principle | Statement | Legacy problem it answers |
| --- | --- | --- |
| P1. One loop | Component code runs on a single thread | shared memory touched with no locking |

### 컴포넌트 목록

| Component | Legacy process absorbed | Rate | Responsibility |
| --- | --- | --- | --- |

### 설계 결정의 측정 근거

결정을 바꾸기 전과 후를 같은 조건에서 측정해 표로 남긴다.

| Measure | Before | After |
| --- | --- | --- |
| IO polling gap, worst | 21,486 ms | 233 ms |

### 큐 목록

| Queue | Ceiling | On overflow |
| --- | --- | --- |
| Message bus | 4,096 | Drop oldest, log the running total |

### 시간 계약

측정 최악값은 WCET가 아니다. 측정 조건(빌드, 하드웨어, 부하, 측정 시간)을 함께 적는다.

| Component | Period | Deadline | Handler budget | Observed worst | Conditions |
| --- | --- | --- | --- | --- | --- |

### 상대별 감지와 복구

| Peer | Detection | Recovery |
| --- | --- | --- |
| Perception controllers | no frame for 5 s | drop the session and listen again |

### Appendix A. 기존 시스템의 설계 문제

영역(구조, 스레드와 블로킹, 경계 검사, 값 검사, 설정, 자원 관리, 동작 결함, 재작성 중 발견)별로 나눈다.

| # | Problem | Consequence | Current answer |
| --- | --- | --- | --- |
| A.3.1 | length computed as total − 12 without checking | wrapped to 65000 and read past the buffer | FrameReader checks the remaining length |

재작성 중 시험으로 발견한 문제는 "How it surfaced" 열에 발견 경위를 적는다. 가짜 장치가 실제보다 관대해서 결함이 숨었던 경우는 교훈으로 따로 적는다.

### Appendix B. 현장 확인 항목

| # | Item | How to verify |
| --- | --- | --- |

### Appendix C. 미구현 항목

기존 구현 대비, 명세 대비, 기존에도 없던 항목, 알려진 제약으로 나눈다.

| Item | Status |
| --- | --- |

### Appendix D. 원칙 예외

코드의 `// exception: EX-P2-001 ...` 표식과 이 표의 ID가 일치해야 한다. 해제한 예외는 지우지 말고 Status를 "released"로 바꾼다.

| ID | Principle | Location | Reason | Mitigation | Approved by | Review when | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EX-P2-001 | P2 | `network/VendorLink.cpp` | vendor sdk has no async connect | 2 s timeout, worst time in the timing table | operator, 2026-09-24 | sdk 3.0 release | active |
