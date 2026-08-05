#!/bin/sh
# 오늘 작업할 빈 캔버스를 kra/에 만들고 Krita로 연다.
# 규격: A4 300dpi, 2480x3508, RGB 8bit — Krita가 기본 제공하는 A4 템플릿을 복사한다.
#       (흰 배경 레이어 + 빈 그림 레이어 2장 구성. 새 문서 대화상자를 거칠 필요가 없다)
# 이름: MMDD_sNN.kra — 앞은 만든 날짜, 뒤 sNN은 **갤러리에서 받게 될 번호**.
#       png/의 마지막 번호(와 아직 안 내보낸 kra의 번호) 다음 값을 미리 붙여둔다.
#       그래서 0806_s08.kra로 그린 그림은 내보내면 08_s08.png가 되어 번호가 일치한다.
#       번호를 되돌리면 내보낸 PNG가 이전 작품의 수정본으로 오인된다.
#
# 사용법: ./newdoc.sh      오늘 캔버스가 이미 있으면 그걸 열기만 한다(매일 자동 실행용)
#         ./newdoc.sh -n   같은 날에도 캔버스를 하나 더 만든다
cd "$(dirname "$0")"

TPL="/Applications/krita.app/Contents/Resources/krita/templates/design/.source/DesignpresentationA4portrait_2480x3508_300dpiRGB_8bit_.kra"
[ -f "$TPL" ] || { echo "템플릿을 못 찾음: $TPL"; exit 1; }

today=$(date +%m%d)

# 자동 실행이 하루에 여러 번 돌아도 캔버스가 늘어나지 않게, 오늘 것이 있으면 그것만 연다
if [ "$1" != "-n" ]; then
  existing=$(ls kra 2>/dev/null | grep "^${today}_s[0-9][0-9]\.kra$" | sort | tail -1)
  if [ -n "$existing" ]; then
    open -a krita "kra/$existing"
    echo "오늘 캔버스 이미 있음: kra/$existing (새로 만들려면 ./newdoc.sh -n)"
    exit 0
  fi
fi

# 다음 번호 = 갤러리 마지막 번호와 아직 안 내보낸 kra 번호 중 큰 값 + 1
# (앞의 0은 떼야 08·09가 8진수로 오해받지 않는다)
lastpng=$(ls png 2>/dev/null | sed -n 's/^\([0-9][0-9]\)_.*\.png$/\1/p' | sort -n | tail -1 | sed 's/^0//')
lastkra=$(ls kra 2>/dev/null | sed -n 's/.*_s\([0-9][0-9]\)\.kra$/\1/p'  | sort -n | tail -1 | sed 's/^0//')
last=$(( ${lastpng:-0} > ${lastkra:-0} ? ${lastpng:-0} : ${lastkra:-0} ))
out="kra/${today}_s$(printf '%02d' $(( last + 1 ))).kra"

cp "$TPL" "$out"
open -a krita "$out"
echo "새 작업 파일: $out (2480x3508, 300dpi)"
