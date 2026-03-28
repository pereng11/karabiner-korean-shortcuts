#!/bin/bash
set -euo pipefail

KARABINER_CONFIG="$HOME/.config/karabiner"
KARABINER_ASSETS="$KARABINER_CONFIG/assets/complex_modifications"
RULE_PREFIX="korean-shortcuts"
IDENTIFIER="[Korean Shortcuts]"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ok()    { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

if [ ! -f "$KARABINER_CONFIG/karabiner.json" ]; then
    error "karabiner.json을 찾을 수 없습니다."
fi

if ! command -v jq &> /dev/null; then
    error "jq가 필요합니다: brew install jq"
fi

# ── karabiner.json에서 규칙 제거 ─────────────────────────────────

jq --arg id "$IDENTIFIER" '
    .profiles[0].complex_modifications.rules |=
        [.[] | select(.description | startswith($id) | not)]
' "$KARABINER_CONFIG/karabiner.json" > /tmp/karabiner-uninstall-tmp.json \
    && mv /tmp/karabiner-uninstall-tmp.json "$KARABINER_CONFIG/karabiner.json"

ok "karabiner.json에서 Korean Shortcuts 규칙 제거"

# ── 규칙 파일 삭제 ───────────────────────────────────────────────

removed=0
for f in "$KARABINER_ASSETS"/${RULE_PREFIX}-*.json; do
    if [ -f "$f" ]; then
        rm "$f"
        removed=$((removed + 1))
    fi
done

if [ "$removed" -gt 0 ]; then
    ok "규칙 파일 ${removed}개 삭제"
else
    ok "삭제할 규칙 파일 없음"
fi

# ── 백업 파일 정리 ───────────────────────────────────────────────

backups=("$KARABINER_CONFIG"/karabiner.json.backup.*)
if [ -e "${backups[0]}" ]; then
    echo ""
    echo "백업 파일이 남아 있습니다:"
    for b in "${backups[@]}"; do
        echo "  $(basename "$b")"
    done
    read -rp "백업 파일도 삭제할까요? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -f "$KARABINER_CONFIG"/karabiner.json.backup.*
        ok "백업 파일 삭제"
    fi
fi

echo ""
echo -e "${GREEN}제거 완료!${NC} Karabiner가 자동으로 설정을 다시 로드합니다."
