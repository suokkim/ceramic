# Ceramic 도자기 컨셉 디자인 갤러리

GitHub Pages로 공개되는 정적 갤러리. `docs/` 폴더가 사이트 루트.

## 폴더 구조
- `kra/` — Krita 원본 작업 파일 (사이트에 안 올라감)
- `png/` — 원본 PNG 보관 (해상도 그대로)
- `docs/` — 공개 사이트 (index.html + 웹 최적화 이미지)

## 업로드 규칙
- **PNG만 업로드** — `png/` 폴더에 원본을 넣는다. JPG/기타 포맷 금지.
- **웹 이미지 크기: 긴 변 1600px** — 갤러리+확대 보기에 충분하고 로딩이 빠름.
  원본은 건드리지 않고 `docs/images/`에 리사이즈 복사본만 생성.
- 파일명은 `NN_이름.png` 형식 (예: `01_cup.png`) — 앞 2자리 숫자가 갤러리 표시 순서.
  넘버링 없이 넣으면 `optimize.sh`가 맨 뒤 번호를 자동으로 붙여줌.
  순서를 바꾸려면 `png/`에서 번호를 직접 수정한 뒤 `./optimize.sh` 재실행.

## 새 이미지 올리는 방법
1. PNG를 `png/`에 넣는다
2. `./optimize.sh` 실행 → 리사이즈 + `docs/images.json` 목록 자동 갱신
3. `git add -A && git commit -m "add image" && git push`

## GitHub Pages 설정 (최초 1회)
저장소 Settings → Pages → Source: `main` 브랜치, `/docs` 폴더 선택.
