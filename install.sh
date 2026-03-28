#!/bin/bash
set -euo pipefail

# Korean Shortcuts for Karabiner-Elements
# 한글 상태에서 키보드 단축키가 정상 동작하도록 하는 Karabiner 규칙 설치 스크립트

REPO_URL="https://raw.githubusercontent.com/ellispark/karabiner-korean-shortcuts/main"
KARABINER_CONFIG="$HOME/.config/karabiner"
KARABINER_ASSETS="$KARABINER_CONFIG/assets/complex_modifications"
RULE_PREFIX="korean-shortcuts"
IDENTIFIER="[Korean Shortcuts]"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# ── Karabiner 설치 확인 ──────────────────────────────────────────

if [ ! -d "$KARABINER_CONFIG" ]; then
    error "Karabiner-Elements가 설치되어 있지 않습니다.

  설치 방법:
    brew install --cask karabiner-elements

  설치 후 이 스크립트를 다시 실행하세요."
fi

if [ ! -f "$KARABINER_CONFIG/karabiner.json" ]; then
    error "karabiner.json을 찾을 수 없습니다. Karabiner-Elements를 한 번 실행해주세요."
fi

# ── jq 확인 ──────────────────────────────────────────────────────

if ! command -v jq &> /dev/null; then
    warn "jq가 설치되어 있지 않습니다. 설치 중..."
    if command -v brew &> /dev/null; then
        brew install jq
    else
        error "jq를 설치할 수 없습니다. 먼저 Homebrew를 설치하세요: https://brew.sh"
    fi
fi

# ── 옵션 파싱 ────────────────────────────────────────────────────

INSTALL_META=false
LOCAL_MODE=false

for arg in "$@"; do
    case "$arg" in
        --with-meta)       INSTALL_META=true ;;
        --all)             INSTALL_META=true ;;
        --local)           LOCAL_MODE=true ;;
        --help|-h)
            echo "사용법: install.sh [옵션]"
            echo ""
            echo "옵션:"
            echo "  --with-meta        Cmd+키 규칙 활성화"
            echo "  --all              모든 규칙 활성화"
            echo "  --local            로컬 파일 사용 (개발용)"
            echo "  --help, -h         이 도움말 표시"
            exit 0
            ;;
        *)
            warn "알 수 없는 옵션: $arg"
            ;;
    esac
done

# ── 기존 설정 백업 ───────────────────────────────────────────────

BACKUP_PATH="$KARABINER_CONFIG/karabiner.json.backup.$(date +%Y%m%d%H%M%S)"
cp "$KARABINER_CONFIG/karabiner.json" "$BACKUP_PATH"
ok "기존 설정 백업: $BACKUP_PATH"

# ── 규칙 파일 복사 ───────────────────────────────────────────────

mkdir -p "$KARABINER_ASSETS"

copy_rule() {
    local filename="$1"
    if [ "$LOCAL_MODE" = true ]; then
        local script_dir
        script_dir="$(cd "$(dirname "$0")" && pwd)"
        cp "$script_dir/rules/$filename" "$KARABINER_ASSETS/${RULE_PREFIX}-${filename}"
    else
        curl -fsSL "$REPO_URL/rules/$filename" \
            -o "$KARABINER_ASSETS/${RULE_PREFIX}-${filename}"
    fi
}

copy_rule "ctrl-keys.json"
ok "Ctrl+키 규칙 파일 설치"

if [ "$INSTALL_META" = true ]; then
    copy_rule "meta-keys.json"
    ok "Cmd+키 규칙 파일 설치"
fi

# ── karabiner.json에 규칙 활성화 ─────────────────────────────────

activate_rule() {
    local file="$1"
    local json_file="$KARABINER_ASSETS/$file"

    if [ ! -f "$json_file" ]; then
        return
    fi

    # 규칙 파일에서 rules 배열 추출하고 enabled: true 추가
    local rules
    rules=$(jq '[.rules[] | . + {"enabled": true}]' "$json_file")

    # 기존에 같은 description의 규칙이 있으면 제거 후 추가
    local descriptions
    descriptions=$(echo "$rules" | jq -r '.[].description')

    local config="$KARABINER_CONFIG/karabiner.json"
    local tmp="/tmp/karabiner-korean-tmp-$$.json"

    # complex_modifications 구조가 없으면 생성
    jq '
        .profiles[0].complex_modifications //= {} |
        .profiles[0].complex_modifications.rules //= []
    ' "$config" > "$tmp" && mv "$tmp" "$config"

    # 이 파일의 규칙 description 목록 추출
    local desc_filter
    desc_filter=$(echo "$rules" | jq '[.[].description]')

    # 동일 description 규칙만 제거 후 새 규칙 추가
    jq --argjson descs "$desc_filter" --argjson rules "$rules" '
        .profiles[0].complex_modifications.rules |=
            ([.[] | select(.description as $d | $descs | index($d) | not)] + $rules)
    ' "$config" > "$tmp" && mv "$tmp" "$config"

    rm -f "$tmp"
}

activate_rule "${RULE_PREFIX}-ctrl-keys.json"

if [ "$INSTALL_META" = true ]; then
    activate_rule "${RULE_PREFIX}-meta-keys.json"
fi

ok "karabiner.json에 규칙 활성화 완료"

# ── 완료 ─────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}설치 완료!${NC} Karabiner가 자동으로 규칙을 로드합니다."
echo ""
echo "설치된 규칙:"
echo "  ✓ Ctrl+키 한글 우회 (Ctrl+A~Z, Ctrl+[, Ctrl+/ 등)"
if [ "$INSTALL_META" = true ]; then
    echo "  ✓ Cmd+키 한글 우회"
fi
echo ""

# 최초 설치 시 권한 안내
if ! pgrep -q "karabiner"; then
    warn "Karabiner가 실행 중이 아닙니다."
    echo "  1. Karabiner-Elements 앱을 실행하세요"
    echo "  2. 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링에서 허용하세요"
fi
