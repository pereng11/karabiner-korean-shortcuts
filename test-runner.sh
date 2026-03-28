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
    echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}각 테스트는 [연습 구간] → [결과 입력] 순서입니다${NC} ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}연습 구간에서 자유롭게 테스트 후 Enter → 결과 입력${NC}${BOLD}║${NC}"
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

    echo -e "  ┌──────────────────────────────────────────────"
    echo -e "  │ ${DIM}($phase_num/$phase_total)${NC} ${BOLD}$test_name${NC}"
    echo -e "  │"
    local step=1
    if [ -n "$preparation" ]; then
        echo -e "  │  ${BLUE}${step}.${NC} $preparation"
        step=$((step + 1))
    fi
    echo -e "  │  ${BLUE}${step}.${NC} $action"
    step=$((step + 1))
    echo -e "  │  ${BLUE}${step}.${NC} 확인: $expected"
    echo -e "  │"
    echo -e "  │  ${DIM}▼ 연습 구간 — 자유롭게 테스트하세요 (Enter → 결과 입력)${NC}"
    echo -e "  └──────────────────────────────────────────────"

    # 연습 구간: 실제 interactive shell을 띄워서 자유롭게 테스트
    # Ctrl+D 또는 exit로 빠져나오면 결과 입력으로 넘어감
    env PS1="  practice> " bash --norc --noprofile -i 2>/dev/null
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


# -- Phase definitions -------------------------------------------------

run_phase_1() {
    local total=12
    phase_header "Phase 1" "Ctrl+key"

    run_test "Ctrl+C interrupt" \
        "sleep 100 Enter" \
        "Ctrl+C" \
        "process killed, new prompt" 1 $total

    run_test "Ctrl+W word delete" \
        "type: echo hello world test (no Enter)" \
        "Ctrl+W" \
        "last word 'test' deleted" 2 $total

    run_test "Ctrl+A line start" \
        "type: echo hello world (no Enter)" \
        "Ctrl+A" \
        "cursor moves to start of line" 3 $total

    run_test "Ctrl+E line end" \
        "cursor at start after Ctrl+A" \
        "Ctrl+E" \
        "cursor moves to end of line" 4 $total

    run_test "Ctrl+U kill line" \
        "type anything (no Enter)" \
        "Ctrl+U" \
        "entire line deleted" 5 $total

    run_test "Ctrl+K kill after cursor" \
        "type: echo hello world, then Ctrl+A" \
        "Ctrl+K" \
        "text after cursor deleted" 6 $total

    run_test "Ctrl+L clear screen" \
        "" \
        "Ctrl+L" \
        "terminal screen cleared" 7 $total

    run_test "Ctrl+R history search" \
        "" \
        "Ctrl+R (Ctrl+C to exit)" \
        "reverse search prompt or fzf UI appears" 8 $total

    run_test "Ctrl+D EOF" \
        "type: cat Enter (waiting for input)" \
        "Ctrl+D" \
        "cat exits (EOF received)" 9 $total

    run_test "Ctrl+Z suspend" \
        "type: sleep 100 Enter" \
        "Ctrl+Z" \
        "[1]+ Stopped message" 10 $total

    run_test "Ctrl+[ ESC" \
        "" \
        "Ctrl+[" \
        "acts as ESC" 11 $total

    run_test "Ctrl+Shift+key combo" \
        "" \
        "Ctrl+Shift+any letter" \
        "shift modifier preserved" 12 $total
}

run_phase_2() {
    local total=10
    phase_header "Phase 2" "Standalone keys (alphabet)"

    echo -e "  ${YELLOW}Requires --with-standalone install${NC}"
    echo -e "  ${DIM}Terminal apps only. Use less/vim in practice zone.${NC}"
    echo ""

    run_test "y -> yes" \
        "" \
        "press y (hangul position) in TUI" \
        "y sent, not hangul char" 1 $total

    run_test "n -> no" \
        "" \
        "press n (hangul position) in TUI" \
        "n sent, not hangul char" 2 $total

    run_test "q -> quit" \
        "open: less README.md" \
        "press q (hangul position)" \
        "less exits" 3 $total

    run_test "j -> down" \
        "open: less README.md or vim" \
        "press j (hangul position)" \
        "scroll/move down" 4 $total

    run_test "k -> up" \
        "in less or vim" \
        "press k (hangul position)" \
        "scroll/move up" 5 $total

    run_test "i -> insert (vim)" \
        "open: vim /tmp/test-kr.txt" \
        "press i (hangul position)" \
        "enter insert mode (-- INSERT --)" 6 $total

    run_test "h -> left (vim)" \
        "vim normal mode (ESC first)" \
        "press h (hangul position)" \
        "cursor moves left" 7 $total

    run_test "l -> right (vim)" \
        "vim normal mode" \
        "press l (hangul position)" \
        "cursor moves right" 8 $total

    run_test "/ -> search" \
        "in less or vim" \
        "press /" \
        "search prompt appears" 9 $total

    run_test ". -> repeat (vim)" \
        "vim: dd to delete line first" \
        "press ." \
        "last command repeated (line deleted)" 10 $total
}

run_phase_3() {
    local total=6
    phase_header "Phase 3" "Standalone keys (Shift combos)"

    echo -e "  ${DIM}Test in vim: vim /tmp/test-kr.txt${NC}"
    echo ""

    run_test "G (Shift+g) -> file end" \
        "open file in vim" \
        "Shift+G" \
        "cursor jumps to last line" 1 $total

    run_test "gg -> file start" \
        "at end of file" \
        "press g twice" \
        "cursor jumps to first line" 2 $total

    run_test "A (Shift+a) -> append EOL" \
        "vim normal mode" \
        "Shift+A" \
        "insert mode at end of line" 3 $total

    run_test "O (Shift+o) -> open above" \
        "ESC to normal mode" \
        "Shift+O" \
        "new line above, insert mode" 4 $total

    run_test "dd -> delete line" \
        "ESC to normal mode" \
        "press d twice" \
        "current line deleted" 5 $total

    run_test ":wq -> save quit" \
        "ESC to normal mode" \
        "type :wq Enter" \
        "file saved, vim exits" 6 $total
}

run_phase_4() {
    local total=5
    phase_header "Phase 4" "tmux shortcuts"

    run_test "Ctrl+B (tmux prefix)" \
        "inside tmux session" \
        "Ctrl+B" \
        "tmux waits for next key" 1 $total

    run_test "Ctrl+B, c -> new window" \
        "after tmux prefix" \
        "press c" \
        "new tmux window created" 2 $total

    run_test "Ctrl+B, n -> next window" \
        "2+ tmux windows" \
        "Ctrl+B then n" \
        "switches to next window" 3 $total

    run_test "Ctrl+B, d -> detach" \
        "inside tmux session" \
        "Ctrl+B then d" \
        "detached from tmux" 4 $total

    run_test "Ctrl+B, [ -> copy mode" \
        "inside tmux session" \
        "Ctrl+B then [" \
        "copy mode entered" 5 $total
}

run_phase_5() {
    local total=6
    phase_header "Phase 5" "Hangul input integrity"

    run_test "Basic hangul composition" \
        "" \
        "type hangul chars normally" \
        "composition works (jamo -> syllable)" 1 $total

    run_test "Ctrl+key during composition" \
        "start typing a hangul syllable (partial)" \
        "press Ctrl+C mid-composition" \
        "composition cancelled, Ctrl+C executed" 2 $total

    run_test "Hangul preserved after Ctrl+key" \
        "" \
        "Ctrl+L then type hangul" \
        "still in hangul mode (not switched to english)" 3 $total

    run_test "Rapid Ctrl+key sequence" \
        "" \
        "Ctrl+A -> Ctrl+E -> Ctrl+K rapidly, then type hangul" \
        "hangul mode still active" 4 $total

    run_test "Fast hangul typing" \
        "" \
        "type a long hangul sentence quickly" \
        "no missing chars or broken composition" 5 $total

    run_test "Toggle then Ctrl+key" \
        "" \
        "switch to EN -> type -> switch to KR -> Ctrl+W" \
        "Ctrl+W works after language toggle" 6 $total
}

run_phase_6() {
    local total=5
    phase_header "Phase 6" "Side effects"

    run_test "Cmd+C/V in browser" \
        "select text in Safari/Chrome" \
        "Cmd+C then Cmd+V in hangul mode" \
        "copy/paste works (if --with-meta installed)" 1 $total

    run_test "Spotlight (Cmd+Space)" \
        "" \
        "Cmd+Space in hangul mode" \
        "Spotlight opens" 2 $total

    run_test "Language toggle key" \
        "" \
        "press your KR/EN toggle key" \
        "input source switches normally" 3 $total

    run_test "Option+key (special chars)" \
        "in terminal" \
        "Option+any key in hangul mode" \
        "no interference from Karabiner rules" 4 $total

    run_test "Other Karabiner rules coexist" \
        "if you have other Karabiner rules" \
        "test your existing rules" \
        "Korean Shortcuts does not break them" 5 $total
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
