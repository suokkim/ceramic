# 동글사각 | CIRCLE SQUARE

세라믹 도자기 컨셉 디자인 갤러리 (GitHub Pages, `docs/`가 사이트 루트).
공개 주소: https://suokkim.github.io/ceramic/

**전체 작업 흐름은 [WORKFLOW.md](WORKFLOW.md), 세부 정책은 [POLICY.md](POLICY.md) 참조.**
이미지 규격·순서·디자인 컨셉·프로세스를 바꾸면 두 문서도 함께 갱신할 것.

## 핵심 규칙
- 작품은 **PNG**. 원본은 `png/`(로컬 전용, git에 안 올라감), 웹용만 `docs/images/`에 공개.
- 파일명은 kra·png 모두 `MMDD_NN` (예: `0806_08`). 웹용만 `NN.png`로 통일.
- `png/` 이름은 절대 바꾸지 않는다 — Krita가 문서 이름 그대로 내보내므로 어긋난다.
- 웹용은 **긴 변 1600px**, 원본이 바뀐 것만 다시 생성.
- 썸네일만 **JPEG**(용량). 작품 파일은 PNG 그대로.
  `docs/images/th/NN.jpg`(600px, 기본) + `docs/images/sq/NN.jpg`(240px 정사각, 폰 모아보기용)
  + `docs/images/si/NN.svg`(벡터 실루엣, 모아보기 겹층 — `tools/silhouette.mjs`가 생성).
- 실루엣을 손으로 그리려면 Krita에서 실루엣 레이어를 `png/MMDD_NN_sil.png`로 저장
  (레이어 > 가져오기/내보내기 > 레이어 저장). 있으면 자동 계산 대신 그대로 벡터화된다.

## 오늘 작업 시작
```
./newdoc.sh    # kra/MMDD_NN.kra (A4 300dpi 2480x3508) 생성 후 Krita로 열기
```
매일 아침 8시에 자동 실행됨.

## 이미지 올리기
Krita에서 `png/`로 내보내면 끝. 감시 에이전트가 `tools/optimize.sh` → 커밋 → 푸시까지 자동 처리.
수정본은 그냥 다시 내보내면 같은 파일을 덮어쓴다. 손으로 하려면 `./tools/optimize.sh` 후 커밋·푸시.
