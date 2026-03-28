# Korean Shortcuts for Karabiner-Elements

macOS에서 한글 입력 상태로도 키보드 단축키가 정상 동작하도록 하는 [Karabiner-Elements](https://karabiner-elements.pqrs.org/) 규칙셋입니다.

## 문제

한글 IME가 활성화된 상태에서 `Ctrl+W`(단어 삭제), `Ctrl+A`(줄 처음) 같은 터미널 단축키가 동작하지 않습니다. 매번 한/영 전환을 해야 합니다.

**Before**: 한/영 전환 → Ctrl+W → 한/영 전환 (3번 키 입력)

**After**: Ctrl+W (1번 키 입력)

## 사전 요구사항

[Karabiner-Elements](https://karabiner-elements.pqrs.org/)가 필요합니다:

```bash
brew install --cask karabiner-elements
```

설치 후 최초 1회:
1. Karabiner-Elements 앱 실행
2. **시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링**에서 Karabiner 허용

## 설치

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pereng11/karabiner-korean-shortcuts/main/install.sh)
```

끝. Karabiner가 자동으로 규칙을 로드합니다.

### 옵션

```bash
# 기본: Ctrl+키 규칙만 설치
bash install.sh

# Cmd+키 규칙도 추가
bash install.sh --with-meta

# 전부 설치
bash install.sh --all
```

## 포함된 규칙

### 1. Ctrl+키 한글 우회 (기본)

한글 상태에서 Ctrl+A~Z 및 Ctrl+[, Ctrl+/, Ctrl+- 등이 정상 동작합니다.

| 단축키 | 동작 |
|--------|------|
| `Ctrl+W` | 단어 삭제 |
| `Ctrl+A` | 줄 맨 앞 |
| `Ctrl+E` | 줄 맨 뒤 |
| `Ctrl+C` | 인터럽트 |
| `Ctrl+R` | 히스토리 검색 |
| `Ctrl+L` | 화면 클리어 |
| `Ctrl+U` | 줄 전체 삭제 |
| `Ctrl+K` | 커서 뒤 삭제 |
| ... | Ctrl+A~Z 전체 30개 |

### 2. Cmd+키 한글 우회 (선택)

`--with-meta` 옵션으로 설치. macOS에서 Cmd+키는 대부분 한글 상태에서도 동작하지만, 일부 앱에서 문제가 발생할 경우 사용합니다.

## 제거

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pereng11/karabiner-korean-shortcuts/main/uninstall.sh)
```

또는 로컬에서:

```bash
bash uninstall.sh
```

## 작동 원리

Karabiner-Elements는 macOS 커널 레벨에서 키 이벤트를 가로챕니다:

```
키보드 → IOKit → Karabiner(여기서 변환) → IME → 앱
```

한글 입력 소스가 활성화된 상태에서 Ctrl+키가 눌리면:

1. 입력 소스를 영문으로 전환
2. Ctrl+키 이벤트 전송
3. 입력 소스를 한글로 복원

이 과정이 순간적으로 이루어져 사용자는 인지하지 못합니다.

## 지원 환경

- macOS Ventura 13+, Sonoma 14+, Sequoia 15+
- Apple 2벌식, 3벌식, 390 3벌식 한글 입력기
- 구름(Gureum) 입력기

## 트러블슈팅

### 규칙이 동작하지 않아요

1. Karabiner-Elements가 실행 중인지 확인
2. **시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링**에서 Karabiner 허용 확인
3. Karabiner-Elements 앱 > Complex Modifications 탭에서 규칙이 활성화되어 있는지 확인

### Ctrl+키 후 한글이 아닌 영문으로 입력돼요

입력 소스 복원이 실패한 경우입니다. Karabiner-EventViewer를 열어 현재 입력 소스 ID를 확인하고, [이슈](https://github.com/pereng11/karabiner-korean-shortcuts/issues)에 보고해주세요.


## 라이선스

MIT License. [LICENSE](./LICENSE) 참조.
