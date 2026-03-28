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

# ── UI 헬퍼 ─────────────────────────────────────────────────────

header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  Korean Shortcuts 검증 테스트 (v$VERSION)          ${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${YELLOW}한글 입력 상태를 유지하세요${NC}                     ${BOLD}║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}다른 터미널 창에서 테스트 → 결과 입력${NC}             ${BOLD}║${NC}"
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
    echo -e "  │"
    echo -e "  │  ${DIM}다른 터미널 창에서 테스트한 뒤 결과를 입력하세요${NC}"
    echo -e "  └──────────────────────────────────────────────"
    echo ""

    while true; do
        echo -ne "  결과? ${GREEN}1${NC}=pass / ${RED}2${NC}=fail / ${YELLOW}3${NC}=skip: "
        read -r -n 1 answer </dev/tty
        echo ""

        case "$answer" in
            1)
                PASS_COUNT=$((PASS_COUNT + 1))
                echo -e "  ${GREEN}✓${NC} $test_name — ${GREEN}PASS${NC}"
                RESULT_LINES+=("| $test_name | PASS | |")
                break
                ;;
            2)
                FAIL_COUNT=$((FAIL_COUNT + 1))
                echo -ne "  ${RED}✗${NC} 증상을 입력하세요: "
                read -r symptom </dev/tty
                echo -e "  ${RED}✗${NC} $test_name — ${RED}FAIL${NC}"
                RESULT_LINES+=("| $test_name | **FAIL** | $symptom |")
                FAIL_DETAILS+=("- **$test_name**: $symptom")
                break
                ;;
            3)
                SKIP_COUNT=$((SKIP_COUNT + 1))
                echo -e "  ${YELLOW}─${NC} $test_name — ${YELLOW}SKIP${NC}"
                RESULT_LINES+=("| $test_name | SKIP | |")
                break
                ;;
            *)
                echo -e "  ${DIM}1, 2, 3 중 하나를 눌러주세요${NC}"
                ;;
        esac
    done
    echo ""
}


# -- Phase 정의 ---------------------------------------------------

run_phase_1() {
    local total=12
    phase_header "Phase 1" "Ctrl+키 단축키"

    run_test "Ctrl+C 인터럽트" \
        "sleep 100 입력 후 Enter" \
        "Ctrl+C 누르기" \
        "프로세스가 종료되고 새 프롬프트가 나타남" 1 $total

    run_test "Ctrl+W 단어 삭제" \
        "echo hello world test 입력 (Enter 누르지 않기)" \
        "Ctrl+W 누르기" \
        "마지막 단어 'test'가 삭제됨" 2 $total

    run_test "Ctrl+A 줄 맨 앞으로 이동" \
        "echo hello world 입력 (Enter 누르지 않기)" \
        "Ctrl+A 누르기" \
        "커서가 줄 맨 앞으로 이동함" 3 $total

    run_test "Ctrl+E 줄 맨 뒤로 이동" \
        "Ctrl+A로 커서를 맨 앞으로 이동한 상태" \
        "Ctrl+E 누르기" \
        "커서가 줄 맨 뒤로 이동함" 4 $total

    run_test "Ctrl+U 줄 전체 삭제" \
        "아무 텍스트나 입력 (Enter 누르지 않기)" \
        "Ctrl+U 누르기" \
        "입력한 줄 전체가 삭제됨" 5 $total

    run_test "Ctrl+K 커서 뒤 삭제" \
        "echo hello world 입력 후 Ctrl+A로 맨 앞 이동" \
        "Ctrl+K 누르기" \
        "커서 뒤의 텍스트가 모두 삭제됨" 6 $total

    run_test "Ctrl+L 화면 클리어" \
        "" \
        "Ctrl+L 누르기" \
        "터미널 화면이 클리어됨" 7 $total

    run_test "Ctrl+R 히스토리 검색" \
        "" \
        "Ctrl+R 누르기 (Ctrl+C로 종료)" \
        "역방향 검색 프롬프트 또는 fzf UI가 나타남" 8 $total

    run_test "Ctrl+D EOF 전송" \
        "cat 입력 후 Enter (입력 대기 상태)" \
        "Ctrl+D 누르기" \
        "cat이 종료됨 (EOF 수신)" 9 $total

    run_test "Ctrl+Z 프로세스 일시정지" \
        "sleep 100 입력 후 Enter" \
        "Ctrl+Z 누르기" \
        "suspended 또는 Stopped 메시지가 나타남" 10 $total

    run_test "Ctrl+[ ESC 키" \
        "" \
        "Ctrl+[ 누르기" \
        "ESC와 동일하게 동작함" 11 $total

    run_test "Ctrl+Shift+키 조합" \
        "" \
        "Ctrl+Shift+아무 알파벳 누르기" \
        "Shift 수정자가 유지됨" 12 $total
}

run_phase_2() {
    local total=5
    phase_header "Phase 2" "tmux 단축키"

    run_test "Ctrl+B (tmux 프리픽스)" \
        "tmux 세션 안에서" \
        "Ctrl+B 누르기" \
        "tmux가 다음 키 입력을 대기함" 1 $total

    run_test "Ctrl+B → c 새 창 생성" \
        "tmux 프리픽스 입력 후" \
        "c 누르기" \
        "새 tmux 창이 생성됨" 2 $total

    run_test "Ctrl+B → n 다음 창 이동" \
        "tmux 창이 2개 이상인 상태" \
        "Ctrl+B 후 n 누르기" \
        "다음 창으로 전환됨" 3 $total

    run_test "Ctrl+B → d 세션 분리" \
        "tmux 세션 안에서" \
        "Ctrl+B 후 d 누르기" \
        "tmux에서 분리됨" 4 $total

    run_test "Ctrl+B → [ 복사 모드" \
        "tmux 세션 안에서" \
        "Ctrl+B 후 [ 누르기" \
        "복사 모드 진입" 5 $total
}

run_phase_3() {
    local total=6
    phase_header "Phase 3" "한글 입력 정상성"

    run_test "기본 한글 조합" \
        "" \
        "한글을 정상적으로 입력" \
        "자모가 올바르게 조합됨 (ㄱ+ㅏ → 가)" 1 $total

    run_test "조합 중 Ctrl+키 입력" \
        "한글 한 글자를 조합 중인 상태 (초성+중성까지)" \
        "조합 중에 Ctrl+C 누르기" \
        "조합이 취소되고 Ctrl+C가 실행됨" 2 $total

    run_test "Ctrl+키 후 한글 유지" \
        "" \
        "Ctrl+L 누른 후 한글 입력" \
        "여전히 한글 모드 유지 (영문으로 바뀌지 않음)" 3 $total

    run_test "Ctrl+키 연속 입력" \
        "" \
        "Ctrl+A → Ctrl+E → Ctrl+K 빠르게 연속 입력 후 한글 입력" \
        "한글 모드가 여전히 유지됨" 4 $total

    run_test "빠른 한글 타이핑" \
        "" \
        "긴 한글 문장을 빠르게 입력" \
        "빠진 글자나 깨진 조합 없음" 5 $total

    run_test "한영 전환 후 Ctrl+키" \
        "" \
        "한→영 전환 → 영문 입력 → 영→한 전환 → Ctrl+W" \
        "언어 전환 후에도 Ctrl+W가 정상 동작함" 6 $total
}

run_phase_4() {
    local total=5
    phase_header "Phase 4" "부작용 확인"

    run_test "브라우저에서 Cmd+C/V" \
        "Safari/Chrome에서 텍스트 선택" \
        "한글 모드에서 Cmd+C 후 Cmd+V" \
        "복사/붙여넣기가 정상 동작함 (--with-meta 설치 시)" 1 $total

    run_test "Spotlight (Cmd+Space)" \
        "" \
        "한글 모드에서 Cmd+Space 누르기" \
        "Spotlight이 정상적으로 열림" 2 $total

    run_test "한/영 전환 키" \
        "" \
        "한/영 전환 키 누르기" \
        "입력 소스가 정상적으로 전환됨" 3 $total

    run_test "Option+키 (특수 문자)" \
        "터미널에서" \
        "한글 모드에서 Option+아무 키 누르기" \
        "Karabiner 규칙의 간섭 없음" 4 $total

    run_test "기존 Karabiner 규칙 공존" \
        "다른 Karabiner 규칙이 있는 경우" \
        "기존 규칙을 테스트" \
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
            --all)    run_phases=(1 2 3 4) ;;
            --help|-h)
                echo "사용법: test-runner.sh [옵션]"
                echo ""
                echo "옵션:"
                echo "  --all          전체 Phase 실행"
                echo "  --phase N      특정 Phase만 실행 (1~4)"
                echo "  1 2 3          Phase 번호 나열"
                echo ""
                echo "Phase:"
                echo "  1  Ctrl+키 단축키"
                echo "  2  tmux 단축키"
                echo "  3  한글 입력 정상성"
                echo "  4  부작용 확인"
                exit 0
                ;;
        esac
    done

    # 기본: 전체 실행
    if [ ${#run_phases[@]} -eq 0 ]; then
        run_phases=(1 2 3 4)
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
