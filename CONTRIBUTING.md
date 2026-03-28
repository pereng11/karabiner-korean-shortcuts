# Contributing

## 개발 환경

```bash
# 로컬 설치 (GitHub에서 다운로드하지 않고 로컬 파일 사용)
bash install.sh --local --all
```

## 규칙 수정

규칙 파일은 `rules/` 디렉토리에 있습니다:

| 파일 | 내용 |
|------|------|
| `ctrl-keys.json` | Ctrl+키 한글 우회 |
| `meta-keys.json` | Cmd+키 한글 우회 |

수정 후 `install.sh --local`로 재설치하면 Karabiner가 자동 리로드합니다.

## 테스트

`docs/verification.md`의 체크리스트를 따릅니다.

## 통합 파일 생성

`rules/` 수정 후 통합 파일 재생성:

```bash
python3 -c "
import json
ctrl = json.load(open('rules/ctrl-keys.json'))
meta = json.load(open('rules/meta-keys.json'))
combined = {
    'title': 'Korean Shortcuts - 한글 상태 단축키 우회',
    'maintainers': ['pereng11'],
    'rules': ctrl['rules'] + meta['rules']
}
json.dump(combined, open('korean-shortcuts.json', 'w'), indent=2, ensure_ascii=False)
"
```

## 커밋

conventional commits 형식:
```
feat: 새 규칙 추가
fix: 입력소스 복원 버그 수정
docs: README 업데이트
```
