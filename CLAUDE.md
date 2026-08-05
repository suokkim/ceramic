# 동글사각 | CIRCLE SQUARE

세라믹 도자기 컨셉 디자인 갤러리 (GitHub Pages, `docs/`가 사이트 루트).
공개 주소: https://suokkim.github.io/ceramic/

**세부 정책은 [POLICY.md](POLICY.md) 참조.** 이미지 규격·순서·디자인 컨셉을 바꾸면 POLICY.md도 함께 갱신할 것.

## 핵심 규칙
- 이미지는 **PNG만**. 원본은 `png/`(로컬 전용, git에 안 올라감), 웹용만 `docs/images/`에 공개.
- 파일명 `NN.png` — 번호가 곧 이름이자 순서. 갤러리는 **역순(최신 먼저)** 표시.
- 웹용은 **긴 변 1600px**, 원본이 바뀐 것만 다시 생성.

## 오늘 작업 시작
```
./newdoc.sh    # kra/MMDD_NN.kra (A4 300dpi 2480x3508) 생성 후 Krita로 열기
```
매일 아침 8시에 자동 실행됨.

## 이미지 올리기
Krita에서 `png/`로 내보내면 끝. 감시 에이전트가 `optimize.sh` → 커밋 → 푸시까지 자동 처리.
번호가 같으면 수정본으로 간주해 덮어쓴다. 손으로 하려면 `./optimize.sh` 후 커밋·푸시.
