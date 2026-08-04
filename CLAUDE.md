# 동글사각 | CIRCLE SQUARE

세라믹 도자기 컨셉 디자인 갤러리 (GitHub Pages, `docs/`가 사이트 루트).
공개 주소: https://suokkim.github.io/ceramic/

**세부 정책은 [POLICY.md](POLICY.md) 참조.** 이미지 규격·순서·디자인 컨셉을 바꾸면 POLICY.md도 함께 갱신할 것.

## 핵심 규칙
- 이미지는 **PNG만**, `png/` 폴더에 원본 보관. 원본은 절대 수정 금지.
- 파일명 `NN_이름.png` — 번호가 순서, 갤러리는 **역순(최신 먼저)** 표시.
- 웹용은 **긴 변 1600px**, `docs/images/`에 자동 생성.

## 오늘 작업 시작
```
./newdoc.sh    # kra/MMDD_sNN.kra (A4 300dpi 2480x3508) 생성 후 Krita로 열기
```

## 이미지 올리기
```
1. PNG를 png/에 넣기 (넘버링 없으면 자동 부여)
2. ./optimize.sh
3. git add -A && git commit -m "add image" && git push
```
