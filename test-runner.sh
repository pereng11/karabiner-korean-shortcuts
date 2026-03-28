#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════
# Korean Shortcuts — 가이드형 수동 테스트 러너
# ══════════════════════════════════════════════════════════════════

VERSION="0.1.0"
RESULTS_DIR="./test-results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RESULT_FILE="$RESULTS_DIR/$TIMESTAMP.md"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# 카운터
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_COUNT=0

# 결과 저장 배열
declare -a RESULT_LINES=()
declare -a FAIL_DETAILS=()

# ── 환경 수집 ────────────────────────────────────────────────────

collect_env() {
    MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    MACOS_NAME=$(sw_vers -productName 2>/dev/null || echo "macOS")

    KARABINER_VERSION="not installed"
    if [ -d "/Applications/Karabiner-Elements.app" ]; then
        KARABINER_VERSION=$(defaults read /Applications/Karabiner-Elements.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
    fi

    KARABINER_RUNNING="no"
    if pgrep -q "karabiner" 2>/dev/null; then
        KARABINER_RUNNING="yes"
    fi

    INPUT_SOURCE=$(defaults read ~/Library/Preferences/com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null \
        | grep -o '"KeyboardLayout Name" = [^;]*' | head -1 | sed 's/"KeyboardLayout Name" = //' || echo "unknown")

    INPUT_SOURCE_ID="unknown"
    if command -v /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli &>/dev/null; then
        INPUT_SOURCE_ID=$(/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name 2>/dev/null || echo "unknown")
    fi

    TERMINAL_APP="${TERM_PROGRAM:-unknown}"
    TERMINAL_VERSION="${TERM_PROGRAM_VERSION:-unknown}"
    SHELL_NAME=$(basename "$SHELL")

    RULES_COUNT=0
    if [ -f ~/.config/karabiner/karabiner.json ] && command -v jq &>/dev/null; then
        RULES_COUNT=$(jq '[.profiles[0].complex_modifications.rules[] | select(.description | startswith("[Korean Shortcuts]"))] | length' ~/.config/karabiner/karabiner.json 2>/dev/null || echo 0)
    fi
}

# ── UI 헬퍼 ──────────────────────────────────��───────────────────

header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  Korean Shortcuts 검증 테스트 (v$VERSION)          ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${YELLOW}한글 입력 상태를 유지하세요${NC}                     ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

phase_header() {
    local phase="$1"
    local title="$2"
    echo ""
    echo -e "${BOLD}${CYAN}── $phase: $title ──${NC}"
    echo ""
    RESULT_LINES+=("")
    RESULT_LINES+=("## $phase: $title")
    RESULT_LINES+=("")
    RESULT_LINES+=("| 테스트 | 결과 | 비고 |")
    RESULT_LINES+=("|--------|------|------|")
}

# ── 테스트 실행 ──────────────────────────────────────────────────

run_test() {
    local test_name="$1"
    local preparation="$2"
    local action="$3"
    local expected="$4"
    local phase_num="$5"
    local phase_total="$6"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    echo -e "  ${DIM}($phase_num/$phase_total)${NC} ${BOLD}$test_name${NC}"
    echo ""
    if [ -n "$preparation" ]; then
        echo -e "  ${BLUE}준비:${NC} $preparation"
    fi
    echo -e "  ${BLUE}동작:${NC} $action"
    echo -e "  ${BLUE}기대:${NC} $expected"
    echo ""

    while true; do
        echo -ne "  결과? [${GREEN}p${NC}]ass / [${RED}f${NC}]ail / [${YELLOW}s${NC}]kip: "
        read -r -n 1 answer
        echo ""

        case "$answer" in
            p|P)
                PASS_COUNT=$((PASS_COUNT + 1))
                echo -e "  ${GREEN}✓${NC} $test_name — ${GREEN}PASS${NC}"
                RESULT_LINES+=("| $test_name | PASS | |")
                break
                ;;
            f|F)
                FAIL_COUNT=$((FAIL_COUNT + 1))
                echo -ne "  ${RED}✗${NC} 증상을 입력하세요: "
                read -r symptom
                echo -e "  ${RED}✗${NC} $test_name — ${RED}FAIL${NC}"
                RESULT_LINES+=("| $test_name | **FAIL** | $symptom |")
                FAIL_DETAILS+=("- **$test_name**: $symptom")
                break
                ;;
            s|S)
                SKIP_COUNT=$((SKIP_COUNT + 1))
                echo -e "  ${YELLOW}─${NC} $test_name — ${YELLOW}SKIP${NC}"
                RESULT_LINES+=("| $test_name | SKIP | |")
                break
                ;;
            *)
                echo -e "  ${DIM}p, f, s 중 하나를 눌러주세요${NC}"
                ;;
        esac
    done
    echo ""
}

# ── 테스트 ���이스 정의 ───────────────────────────────────────────

run_phase_1() {
    local total=12
    phase_header "Phase 1" "Ctrl+키 단축키"

    run_test "Ctrl+C 인터럽트" \
        "터미널에서 sleep 100 실행" \
        "한글 상태에서 Ctrl+C" \
        "프로세스가 중단되고 새 프롬프트가 뜸" 1 $total

    run_test "Ctrl+W 단어 삭제" \
        "echo hello world test 타이핑 (엔터 X)" \
        "한글 상태에서 Ctrl+W" \
        "마지막 단어 'test'가 삭제됨" 2 $total

    run_test "Ctrl+A 줄 맨 앞 이동" \
        "echo hello world 타이핑 (엔터 X)" \
        "한글 상태에서 Ctrl+A" \
        "커서가 줄 맨 앞(echo 앞)으로 이동" 3 $total

    run_test "Ctrl+E 줄 맨 뒤 이동" \
        "Ctrl+A로 맨 앞 이동한 상태에서" \
        "한글 상태에서 Ctrl+E" \
        "커서가 줄 맨 뒤로 이동" 4 $total

    run_test "Ctrl+U 줄 전체 삭제" \
        "echo hello world 타이핑 (엔터 X)" \
        "한글 상태에서 Ctrl+U" \
        "줄 전체가 삭제됨" 5 $total

    run_test "Ctrl+K 커서 뒤 삭제" \
        "echo hello world 타이핑 후 Ctrl+A로 맨 앞 이동" \
        "한글 상태에서 Ctrl+K" \
        "커서 뒤의 모든 텍스트가 삭제됨" 6 $total

    run_test "Ctrl+L 화면 클리어" \
        "" \
        "한글 상태에서 Ctrl+L" \
        "터미널 화면이 클리어됨" 7 $total

    run_test "Ctrl+R 히스토리 검색" \
        "" \
        "한글 상태에서 Ctrl+R" \
        "역방향 검색 프롬프트 또는 fzf 검색 UI가 뜸" 8 $total

    run_test "Ctrl+D EOF 전송" \
        "cat 명령어 실행 (입력 대기 상태)" \
        "한글 상태에서 Ctrl+D" \
        "cat이 종료됨 (EOF 수신)" 9 $total

    run_test "Ctrl+Z 프로세스 일시중지" \
        "sleep 100 실행" \
        "한글 상태에서 Ctrl+Z" \
        "[1]+ Stopped 메시지 출력" 10 $total

    run_test "Ctrl+[ ESC 동작" \
        "" \
        "한글 상태에서 Ctrl+[" \
        "ESC와 동일하게 동작 (앱에 따라 다름)" 11 $total

    run_test "Ctrl+Shift+키 조합" \
        "" \
        "한글 상태에서 Ctrl+Shift+T (앱에 따라)" \
        "Shift가 포함된 Ctrl 조합도 정상 동작" 12 $total
}

run_phase_2() {
    local total=10
    phase_header "Phase 2" "단독 키 — 기본 알파벳"

    echo -e "  ${YELLOW}이 Phase는 --with-standalone 설치 필요${NC}"
    echo -e "  ${DIM}터미널 앱에서만 동작합니다.${NC}"
    echo ""

    run_test "y → yes (확인)" \
        "Claude Code 또는 TUI 앱에서 확인 다이얼로그 띄우기" \
        "한글 상태에서 y (ㅛ 위치) 누르기" \
        "Yes가 선택됨 (ㅛ가 입력되지 않음)" 1 $total

    run_test "n → no (거부)" \
        "Claude Code 또는 TUI 앱에서 확인 다이얼로그 띄우기" \
        "한글 상태에서 n (ㅜ 위치) 누르기" \
        "No가 선��됨" 2 $total

    run_test "q → quit (닫기)" \
        "Claude Code에서 Ctrl+O로 Transcript 열기" \
        "한글 상태에서 q (ㅂ 위치) 누르기" \
        "Transcript가 닫힘" 3 $total

    run_test "j → 아래 이동" \
        "vim, less, ��는 TUI 앱에서 리스트 화면" \
        "한글 상태에서 j (ㅓ 위치) 누르기" \
        "아래로 이동" 4 $total

    run_test "k → 위 이동" \
        "vim, less, 또는 TUI 앱에서 리스트 화면" \
        "한글 상태에서 k (ㅏ 위치) 누르기" \
        "위로 이동" 5 $total

    run_test "i → insert" \
        "vim에서 normal mode" \
        "한글 상태에서 i (ㅑ 위치) 누르기" \
        "insert mode 진입" 6 $total

    run_test "h → 왼쪽 이동" \
        "vim에서 normal mode" \
        "한글 상태에서 h (ㅗ 위치) 누르기" \
        "커서가 왼쪽으로 이동" 7 $total

    run_test "l → 오른쪽 이동" \
        "vim에서 normal mode" \
        "한글 상태에서 l (ㅣ 위치) 누르기" \
        "커서가 오른쪽으로 이동" 8 $total

    run_test "/ → 검색" \
        "vim, less, 또는 man 페이지" \
        "한글 상태에서 / 누르기" \
        "검색 프롬프트가 뜸" 9 $total

    run_test ". → 명령 반복" \
        "vim에서 dd로 줄 삭제 후" \
        "한글 상태에서 . 누르기" \
        "마지막 명령이 반복됨 (줄 삭제)" 10 $total
}

run_phase_3() {
    local total=6
    phase_header "Phase 3" "단독 키 — Shift 조합"

    run_test "G (Shift+g) → 파일 끝" \
        "vim에서 파일 열기" \
        "한글 상태에서 Shift+G" \
        "파일 맨 끝으로 이동" 1 $total

    run_test "gg → 파일 처음" \
        "vim에서 파일 끝에 있는 상태" \
        "한글 상태에서 g를 두 번" \
        "파일 맨 처음으로 이동" 2 $total

    run_test "A (Shift+a) → 줄 끝 삽입" \
        "vim에서 normal mode" \
        "한글 상태에서 Shift+A" \
        "줄 끝에서 insert mode 진입" 3 $total

    run_test "O (Shift+o) → 위에 줄 삽입" \
        "vim에서 normal mode" \
        "한글 상태에서 Shift+O" \
        "현재 줄 위에 새 줄이 열리고 insert mode" 4 $total

    run_test "dd → 줄 삭제" \
        "vim에서 normal mode" \
        "한글 상태에서 d를 두 번" \
        "현재 줄이 삭제됨" 5 $total

    run_test ":wq → 저장 종료" \
        "vim에서 normal mode" \
        "한글 상태에서 :wq Enter" \
        "파일이 저장���고 vim 종료" 6 $total
}

run_phase_4() {
    local total=5
    phase_header "Phase 4" "tmux 단축키"

    run_test "Ctrl+B (tmux prefix)" \
        "tmux 세션 안에서" \
        "한글 상태에서 Ctrl+B" \
        "tmux가 prefix 입력 대기 상태가 됨" 1 $total

    run_test "Ctrl+B, c → 새 창" \
        "tmux prefix 입력 후" \
        "한글 상태에서 c (ㅊ 위치)" \
        "새 tmux 창이 생성됨" 2 $total

    run_test "Ctrl+B, n → 다음 창" \
        "tmux 창이 2개 이상인 상태" \
        "한글 상태에서 Ctrl+B 후 n" \
        "다음 창으로 전환" 3 $total

    run_test "Ctrl+B, d → detach" \
        "tmux 세션 안에서" \
        "한글 상태에서 Ctrl+B 후 d" \
        "tmux에서 detach됨" 4 $total

    run_test "Ctrl+B, [ → 복사 모드" \
        "tmux 세션 안에서" \
        "한글 상태에서 Ctrl+B 후 [" \
        "tmux 복사 모드 진입" 5 $total
}

run_phase_5() {
    local total=6
    phase_header "Phase 5" "한글 입력 정상성"

    run_test "기본 한글 조합" \
        "" \
        "한글 상태에서 '한글테스트' 타이핑" \
        "ㅎ+ㅏ+ㄴ=한, ㄱ+ㅡ+ㄹ=글 정상 조합" 1 $total

    run_test "조합 중 Ctrl+키" \
        "'테스' 까지 타이핑 (ㅌㅔㅅ 조합 중)" \
        "조합 도중 Ctrl+C" \
        "조합이 끊기고 Ctrl+C가 실행됨" 2 $total

    run_test "Ctrl+키 후 한글 유지" \
        "" \
        "Ctrl+L (클리어) 후 바로 한글 타이핑" \
        "한글 모드가 유지됨 (영문으로 바뀌지 않음)" 3 $total

    run_test "Ctrl+키 연타 후 한글 유지" \
        "" \
        "Ctrl+A → Ctrl+E → Ctrl+K 빠르게 연타 후 한글 타이핑" \
        "한글 모드가 여전히 유지됨" 4 $total

    run_test "빠른 타이핑 중 키 누락" \
        "" \
        "빠르게 '한글입력테스트문장입니다' 타이핑" \
        "누락이나 깨짐 없이 정상 입력" 5 $total

    run_test "영문 전환 후 복귀" \
        "" \
        "한/영 전환 → 영문 타이핑 → 한/영 전환 → Ctrl+W" \
        "한영 전환 후에도 규칙이 정상 동작" 6 $total
}

run_phase_6() {
    local total=5
    phase_header "Phase 6" "다른 앱 영향"

    run_test "Safari/Chrome: Cmd+C/V" \
        "브라우저에서 텍스트 선택" \
        "한글 상태에서 Cmd+C 후 Cmd+V" \
        "복사/붙여넣기 정상 (--with-meta 설치 시)" 1 $total

    run_test "Spotlight (Cmd+Space)" \
        "" \
        "한글 상태에서 Cmd+Space" \
        "Spotlight 검색이 뜸" 2 $total

    run_test "한/영 전환키" \
        "" \
        "한/영 전환키 누르기" \
        "입력 소스가 정상 전환됨" 3 $total

    run_test "Option+알파벳 (특수문자)" \
        "터미널에서" \
        "한글 상태에서 Option+키 조합" \
        "Karabiner 규칙 영향 없이 기본 동작" 4 $total

    run_test "다른 Karabiner 규칙 공존" \
        "기존에 설정한 Karabiner 규칙이 있다면" \
        "기존 규칙 동작 확인" \
        "Korean Shortcuts가 기존 규칙을 방해하지 않음" 5 $total
}

# ── 리포트 생성 ──────────────────────────────────────────────────

generate_report() {
    mkdir -p "$RESULTS_DIR"

    {
        echo "# Korean Shortcuts 검증 리포트"
        echo ""
        echo "- 날짜: $(date '+%Y-%m-%d %H:%M')"
        echo "- 버전: $VERSION"
        echo ""
        echo "## 환경"
        echo ""
        echo "| 항목 | 값 |"
        echo "|------|-----|"
        echo "| macOS | $MACOS_NAME $MACOS_VERSION |"
        echo "| Karabiner | $KARABINER_VERSION |"
        echo "| Karabiner 실행 | $KARABINER_RUNNING |"
        echo "| 등록된 규칙 | ${RULES_COUNT}개 |"
        echo "| 터미널 | $TERMINAL_APP $TERMINAL_VERSION |"
        echo "| 셸 | $SHELL_NAME |"

        for line in "${RESULT_LINES[@]}"; do
            echo "$line"
        done

        echo ""
        echo "## 요약"
        echo ""
        echo "| | 수 |"
        echo "|---|---|"
        echo "| PASS | $PASS_COUNT |"
        echo "| FAIL | $FAIL_COUNT |"
        echo "| SKIP | $SKIP_COUNT |"
        echo "| 합계 | $TOTAL_COUNT |"

        if [ ${#FAIL_DETAILS[@]} -gt 0 ]; then
            echo ""
            echo "## 실패 항목"
            echo ""
            for detail in "${FAIL_DETAILS[@]}"; do
                echo "$detail"
            done
        fi

        # 이전 리포트와 비교
        local prev_report
        prev_report=$(ls -t "$RESULTS_DIR"/*.md 2>/dev/null | sed -n '2p')
        if [ -n "$prev_report" ] && [ -f "$prev_report" ]; then
            local prev_pass prev_fail
            prev_pass=$(grep -c "| PASS |" "$prev_report" 2>/dev/null || echo 0)
            prev_fail=$(grep -c "| \*\*FAIL\*\* |" "$prev_report" 2>/dev/null || echo 0)

            echo ""
            echo "## 이전 리포트 비교"
            echo ""
            echo "- 이전: $(basename "$prev_report")"
            echo "- PASS: $prev_pass → $PASS_COUNT"
            echo "- FAIL: $prev_fail → $FAIL_COUNT"

            if [ "$FAIL_COUNT" -gt "$prev_fail" ]; then
                echo "- **REGRESSION 감지**: 실패 항목이 증가했습니다"
            fi
        fi

        # GitHub Issue 템플릿
        if [ ${#FAIL_DETAILS[@]} -gt 0 ]; then
            echo ""
            echo "## GitHub Issue 템플릿"
            echo ""
            echo '```markdown'
            echo "### 환경"
            echo "- macOS: $MACOS_NAME $MACOS_VERSION"
            echo "- Karabiner: $KARABINER_VERSION"
            echo "- 터미널: $TERMINAL_APP $TERMINAL_VERSION"
            echo ""
            echo "### 실패 항목"
            for detail in "${FAIL_DETAILS[@]}"; do
                echo "$detail"
            done
            echo '```'
        fi

    } > "$RESULT_FILE"
}

# ── 메인 ─────────────────────────────────────────────────────────

main() {
    local run_phases=()

    # 옵션 파싱
    for arg in "$@"; do
        case "$arg" in
            --phase)  ;; # 다음 인자에서 처리
            1|2|3|4|5|6) run_phases+=("$arg") ;;
            --all)    run_phases=(1 2 3 4 5 6) ;;
            --help|-h)
                echo "사용법: test-runner.sh [옵션]"
                echo ""
                echo "옵션:"
                echo "  --all          전체 Phase 실행"
                echo "  --phase N      특정 Phase만 실행 (1~6)"
                echo "  1 2 3          Phase 번호 나열"
                echo ""
                echo "Phase:"
                echo "  1  Ctrl+키 단축키"
                echo "  2  단독 키 — 기본 알파벳"
                echo "  3  단독 키 — Shift 조합"
                echo "  4  tmux 단축키"
                echo "  5  한글 입력 정상성"
                echo "  6  다른 앱 영향"
                exit 0
                ;;
        esac
    done

    # 기본: 전체 실행
    if [ ${#run_phases[@]} -eq 0 ]; then
        run_phases=(1 2 3 4 5 6)
    fi

    collect_env
    header

    echo -e "  ${DIM}환경 정보:${NC}"
    echo -e "  macOS $MACOS_VERSION | Karabiner $KARABINER_VERSION | $TERMINAL_APP"
    echo -e "  규칙 ${RULES_COUNT}개 등록됨"

    if [ "$KARABINER_RUNNING" = "no" ]; then
        echo ""
        echo -e "  ${RED}Karabiner가 실행 중이 아닙니다. 먼저 실행하세요.${NC}"
        exit 1
    fi

    echo ""
    echo -e "  ${YELLOW}테스트 시작 전 한글 입력 상태인지 확인하세요.${NC}"
    echo -ne "  준비되면 Enter: "
    read -r

    for phase in "${run_phases[@]}"; do
        case "$phase" in
            1) run_phase_1 ;;
            2) run_phase_2 ;;
            3) run_phase_3 ;;
            4) run_phase_4 ;;
            5) run_phase_5 ;;
            6) run_phase_6 ;;
        esac
    done

    # 리포트 생성
    generate_report

    # 최종 결과 출력
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  검증 결과                                       ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
    echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
    echo -e "  ${YELLOW}SKIP${NC}: $SKIP_COUNT"
    echo -e "  합계: $TOTAL_COUNT"
    echo ""
    echo -e "  리포트: ${BLUE}$RESULT_FILE${NC}"

    if [ ${#FAIL_DETAILS[@]} -gt 0 ]; then
        echo ""
        echo -e "  ${RED}실패 항목:${NC}"
        for detail in "${FAIL_DETAILS[@]}"; do
            echo -e "    $detail"
        done
    fi
    echo ""
}

main "$@"
