# PRD: Karabiner Korean Shortcuts

## 문제 정의

macOS에서 한글 IME가 활성화된 상태로 키보드 단축키를 사용하면, IME가 키 이벤트를 가로채서 단축키가 동작하지 않는다.

### 영향받는 단축키 유형

| 유형 | 예시 | 증상 |
|------|------|------|
| **Ctrl+키** | Ctrl+W(단어 삭제), Ctrl+A(줄 처음), Ctrl+R(히스토리 검색) | IME가 조합 중 Ctrl 이벤트를 소비 |

### 영향받는 환경

- 자체 키 입력 처리를 사용하는 TUI 앱 (Claude Code, OpenCode 등)
- macOS Ventura 13+ / Sonoma 14+ / Sequoia 15+

> 일반 터미널(Terminal.app, iTerm2, tmux 등)에서는 한글 모드에서도 Ctrl+키가 정상 동작합니다.
> 이 규칙은 주로 React Ink 등 자체 입력 처리를 사용하는 TUI 도구의 workaround입니다.

### 근본 원인

```
물리 키 → IOKit HID → IME(한글) → 앱
                        ↑
                   여기서 키를 가로챔
```

macOS 이벤트 체인에서 IME가 앱보다 먼저 키 이벤트를 받기 때문에, 앱 레벨이나 터미널 레벨에서는 해결 불가능하다. IOKit 레벨에서 키를 가로채야 하며, 이를 제공하는 것이 Karabiner-Elements의 가상 키보드 드라이버다.

---

## 솔루션

Karabiner-Elements complex modification 규칙셋 + 원클릭 설치 스크립트를 오픈소스로 제공한다.

### 핵심 동작

한글 입력 소스가 활성화된 상태에서:

1. **Ctrl+키 입력 시**: 입력 소스를 영문으로 전환 → Ctrl+키 전송 → 입력 소스를 한글로 복원

### 설계 원칙

- **비침투적**: 일반 한글 타이핑에 영향 없음. modifier가 눌렸을 때만 개입
- **입력기 다양성**: Apple 2벌식, 3벌식, 구름 입력기 모두 지원
- **원클릭 설치/제거**: 셸 스크립트 한 줄로 설치 및 제거

---

## 사용자 스토리

### US-1: 한글 상태에서 Ctrl+키 단축키 사용

> 개발자로서, 한글 입력 중에도 Ctrl+W, Ctrl+A 등 터미널 단축키를 한/영 전환 없이 사용하고 싶다.

**수용 조건:**
- 한글 입력 상태에서 Ctrl+A~Z 모두 정상 동작
- 단축키 실행 후 입력 소스가 한글로 유지됨
- 조합 중(예: ㅎㅏ)이던 글자는 조합 취소 후 단축키 실행
- 모든 터미널 앱에서 동일하게 동작

### US-2: 원클릭 설치

> 사용자로서, 터미널에서 명령어 한 줄로 설치하고 바로 사용하고 싶다.

**수용 조건:**
- `bash <(curl ...)` 한 줄로 설치 완료
- 기존 Karabiner 설정이 있으면 규칙만 추가 (기존 설정 덮어쓰지 않음)
- Karabiner가 미설치 상태면 안내 메시지 출력
- 설치 후 즉시 동작 (Karabiner 자동 리로드)

### US-3: 깔끔한 제거

> 사용자로서, 이 규칙이 마음에 안 들면 흔적 없이 제거하고 싶다.

**수용 조건:**
- `uninstall.sh`로 규칙 파일 삭제 + karabiner.json에서 규칙 제거
- 다른 Karabiner 규칙에 영향 없음
- 제거 후 원래 동작으로 즉시 복원

---

## 규칙 구조

### Rule 1: Ctrl+키 한글 우회 (핵심, 기본 활성화)

대상 키: Ctrl + A~Z 전체 (26개)

```
조건: input_source == Korean (language: "ko")
동작: 영문 전환 → Ctrl+키 전송 → 한글 복원
```

**지원 입력기:**
- `com.apple.inputmethod.Korean.2SetKorean` (Apple 2벌식)
- `com.apple.inputmethod.Korean.3SetKorean` (Apple 3벌식)
- `com.apple.inputmethod.Korean.390Sebulshik` (Apple 390 3벌식)
- `org.youknowone.inputmethod.Gureum.*` (구름 입력기)

### Rule 2: Meta(Cmd)+키 한글 우회 (선택적)

대상 키: Cmd + 일반적 단축키들

```
조건: input_source == Korean
동작: 영문 전환 → Cmd+키 전송 → 한글 복원
```

> macOS에서 Cmd+키는 대부분 IME를 우회하지만, 일부 앱/환경에서 문제가 보고됨.
> 필요한 사용자만 활성화.

---

## 기술 스펙

### 입력 소스 전환 방식

Karabiner의 `select_input_source`는 한국어 IME에서 macOS 버그로 실패할 수 있다. 따라서 두 가지 전략을 사용한다:

1. **우선**: `select_input_source`로 직접 전환 시도
2. **폴백**: 키보드 단축키 (Caps Lock 또는 Ctrl+Space) 전송으로 전환

> 설치 스크립트에서 사용자의 한영 전환 키를 감지하거나 질문하여 적절한 전략 선택.

### 파일 구조

```
karabiner-korean-shortcuts/
├── README.md                          # 유저 문서
├── LICENSE                            # MIT
├── install.sh                         # 설치 스크립트
├── uninstall.sh                       # 제거 스크립트
├── rules/
│   ├── ctrl-keys.json                 # Rule 1: Ctrl+키 우회
│   └── meta-keys.json                 # Rule 2: Cmd+키 우회
├── CONTRIBUTING.md                    # 기여 가이드
└── docs/
    └── verification.md                # 검증 체크리스트
```

### install.sh 동작

```
1. Karabiner-Elements 설치 여부 확인
   └ 미설치 → brew 설치 안내 출력 후 종료
2. 기존 karabiner.json 백업
   └ ~/.config/karabiner/karabiner.json.backup.{timestamp}
3. 규칙 파일 다운로드 → assets/complex_modifications/에 배치
4. karabiner.json에 Rule 1(Ctrl+키) 활성화
5. Rule 2(Cmd+키)는 --with-meta 옵션으로 활성화
6. 완료 메시지 + 권한 설정 안내 (최초 설치 시)
```

### uninstall.sh 동작

```
1. karabiner.json에서 우리 규칙만 제거 (description으로 식별)
2. assets/complex_modifications/에서 규칙 파일 삭제
3. 백업 파일 정리 여부 질문
4. 완료 메시지
```

---

## 제약 사항

| 항목 | 설명 |
|------|------|
| **Karabiner 의존성** | Karabiner-Elements 필수. 다른 방법으로는 근본 해결 불가 |
| **macOS 전용** | Karabiner는 macOS만 지원 |
| **권한 승인 필수** | Input Monitoring 권한을 수동으로 승인해야 함 (OS 제한) |
| **select_input_source 버그** | macOS 버전에 따라 한국어 IME 직접 전환이 실패할 수 있음 |

---

## 비목표 (Non-Goals)

- ₩ → ` 변환 (이미 기존 규칙으로 잘 해결됨)
- 한/영 전환 키 매핑 변경 (기존 규칙으로 해결됨)
- Windows/Linux 지원
- Karabiner-Elements 자동 설치 (brew 명령 안내만 제공)
- GUI 설정 도구 제작

---

## 성공 지표

- [ ] Rule 1(Ctrl+키): 한글 상태에서 Ctrl+A~Z 26개 전부 정상 동작
- [ ] Rule 1: 단축키 실행 후 입력 소스가 한글로 복원됨
- [ ] Rule 1: 조합 중이던 한글이 깨지지 않음 (조합 취소 후 단축키 실행)
- [ ] install.sh: 기존 Karabiner 설정 보존
- [ ] uninstall.sh: 깔끔한 제거 + 다른 규칙 무영향
- [ ] Apple 2벌식, 3벌식, 구름 입력기에서 모두 동작
