# 검증 체크리스트

개발 및 유지보수를 위한 테스트 플로우.

## Phase 1: 기본 환경

```
[ ] macOS 버전 확인 (Ventura 13+ / Sonoma 14+ / Sequoia 15+)
[ ] Karabiner-Elements 설치 및 드라이버 승인
    └ System Settings > Privacy & Security > Input Monitoring 허용
[ ] Karabiner-EventViewer로 한글 입력소스 ID 확인
    └ 예상값: com.apple.inputmethod.Korean.2SetKorean
[ ] 규칙 파일 위치 확인
    └ ~/.config/karabiner/assets/complex_modifications/korean-shortcuts-*.json
[ ] karabiner.json에서 규칙 활성화 상태 확인
    └ profiles[0].complex_modifications.rules 내 [Korean Shortcuts] 존재
```

## Phase 2: Ctrl+키 (터미널별)

한글 입력 모드 상태에서 테스트. 각 터미널마다 반복.

### Terminal.app

```
[ ] Ctrl+C → 프로세스 중단 (sleep 100 실행 후)
[ ] Ctrl+W → 단어 삭제 (긴 명령어 입력 후)
[ ] Ctrl+A → 줄 맨 앞으로 이동
[ ] Ctrl+E → 줄 맨 뒤로 이동
[ ] Ctrl+L → 화면 클리어
[ ] Ctrl+R → 히스토리 검색
[ ] Ctrl+U → 줄 전체 삭제
[ ] Ctrl+K → 커서 뒤 삭제
[ ] Ctrl+[ → ESC 동작
[ ] Ctrl+/ → undo (지원하는 쉘에서)
```

### iTerm2

```
[ ] 위와 동일한 10개 테스트
[ ] 기존 iTerm2 커스텀 키매핑과 충돌 여부
```

### Alacritty / Kitty / WezTerm / Warp

```
[ ] 사용하는 터미널에서 동일 테스트
```

### tmux

```
[ ] Ctrl+B → tmux prefix 동작
[ ] Ctrl+B, c → 새 창 생성
[ ] Ctrl+B, n → 다음 창
[ ] Ctrl+B, [ → 복사 모드
[ ] Ctrl+B, d → detach
```

## Phase 3: 단독 키 (Claude Code / vim / tmux)

`--with-standalone` 설치 후, 한글 입력 모드 상태에서:

### Claude Code

```
[ ] Confirmation 다이얼로그에서 y → Yes
[ ] Confirmation 다이얼로그에서 n → No
[ ] Transcript (Ctrl+O)에서 q → 닫힘
[ ] Message Selector에서 j → 아래
[ ] Message Selector에서 k → 위로
[ ] Settings에서 / → 검색
```

### vim/neovim

```
[ ] j → 아래 이동
[ ] k → 위 이동
[ ] h → 왼쪽 이동
[ ] l → 오른쪽 이동
[ ] i → insert mode
[ ] v → visual mode
[ ] d → delete
[ ] y → yank
[ ] p → paste
[ ] / → search
[ ] G (Shift+g) → 파일 끝
[ ] gg → 파일 처음
[ ] dd → 줄 삭제
[ ] :wq → 저장 종료 (: 가 정상 동작하는지)
```

### tmux copy mode

```
[ ] j/k → 이동
[ ] / → 검색
[ ] q → copy mode 종료
```

## Phase 4: 부작용

```
[한글 입력 정상성]
[ ] 일반 텍스트 입력 시 한글 조합 정상 (예: ㅎ+ㅏ+ㄴ = 한)
[ ] 조합 중 Ctrl+키 → 조합 취소 + 단축키 실행
[ ] Ctrl+키 후 다시 타이핑 → 한글 모드 유지

[다른 앱 영향]
[ ] Safari/Chrome: Cmd+C/V/X 정상
[ ] VS Code: Ctrl+Shift+P, Cmd+S 등 정상
[ ] Spotlight (Cmd+Space) 정상
[ ] 한/영 전환키 정상 동작

[Edge Case]
[ ] Shift+알파벳 (대문자) → 영향 없음
[ ] Option+알파벳 (특수문자) → 영향 없음
[ ] 빠른 연타 시 키 누락 없음
[ ] Ctrl+Shift+키 (예: Ctrl+Shift+T) → 정상 동작
```

## Phase 5: 입력기 호환성

```
[ ] Apple 기본 한글 2벌식
[ ] Apple 기본 한글 3벌식
[ ] Apple 기본 한글 390 3벌식
[ ] 구름(Gureum) 입력기
```

## Phase 6: 설치/제거 스크립트

```
[install.sh]
[ ] Karabiner 미설치 → 에러 메시지 + 설치 안내
[ ] 기본 설치 → Ctrl+키 규칙만 활성화
[ ] --with-standalone → 단독 키 규칙 추가 활성화
[ ] --with-meta → Cmd+키 규칙 추가 활성화
[ ] --all → 전체 활성화
[ ] 기존 Karabiner 설정 보존 (다른 규칙 영향 없음)
[ ] 재설치 시 중복 규칙 생기지 않음
[ ] karabiner.json 백업 생성됨

[uninstall.sh]
[ ] Korean Shortcuts 규칙만 제거
[ ] 다른 Karabiner 규칙 무영향
[ ] 규칙 파일 삭제
[ ] 백업 정리 옵션
```

## Phase 7: 장기 안정성

```
[ ] 8시간+ 연속 사용 후 키 입력 지연 없음
[ ] 재부팅 후 자동 시작 및 규칙 유지
[ ] macOS 업데이트 후 동작 확인
[ ] Karabiner 비활성화 시 원래 동작 즉시 복원
```
