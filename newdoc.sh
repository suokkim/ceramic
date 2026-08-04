#!/bin/sh
# 오늘 작업할 빈 캔버스를 kra/에 만들고 Krita로 연다.
# 규격: A4 300dpi, 2480x3508, RGB 8bit — Krita가 기본 제공하는 A4 템플릿을 복사한다.
#       (흰 배경 레이어 + 빈 그림 레이어 2장 구성. 새 문서 대화상자를 거칠 필요가 없다)
# 이름: MMDD_sNN.kra — 앞은 만든 날짜, 뒤 sNN은 작품 일련번호(날짜와 무관하게 계속 증가).
#       일련번호를 매일 s01로 되돌리면 내보낸 PNG가 이전 작품의 수정본으로 오인된다.
cd "$(dirname "$0")"

TPL="/Applications/krita.app/Contents/Resources/krita/templates/design/.source/DesignpresentationA4portrait_2480x3508_300dpiRGB_8bit_.kra"
[ -f "$TPL" ] || { echo "템플릿을 못 찾음: $TPL"; exit 1; }

# kra/에서 가장 큰 sNN을 찾아 +1 (앞의 0은 떼야 8·9가 8진수로 오해받지 않는다)
last=$(ls kra 2>/dev/null | sed -n 's/.*_s\([0-9][0-9]\)\.kra$/\1/p' | sort -n | tail -1 | sed 's/^0//')
out="kra/$(date +%m%d)_s$(printf '%02d' $(( ${last:-0} + 1 ))).kra"
[ -e "$out" ] && { echo "이미 있음: $out"; exit 1; }

cp "$TPL" "$out"
open -a krita "$out"
echo "새 작업 파일: $out (2480x3508, 300dpi)"
