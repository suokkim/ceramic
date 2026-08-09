#!/bin/sh
# 오늘 작업할 빈 캔버스를 kra/에 만들고 Krita로 연다.
# 규격: A4 300dpi, 2480x3508, RGB 8bit — 저장소의 template.kra를 복사한다.
#       구성: 흰 배경 + 빈 그림 레이어 + 숨긴 "sil" 레이어(수제 실루엣용, POLICY 4절).
#       Krita 기본 A4 템플릿에 sil 레이어를 심은 것 — 원본은
#       /Applications/krita.app/.../DesignpresentationA4portrait_2480x3508_300dpiRGB_8bit_.kra
# 이름: MMDD_NN.kra — 앞은 만든 날짜, 뒤 NN은 **갤러리에서 받게 될 번호**.
#       png/의 마지막 번호(와 아직 안 내보낸 kra의 번호) 다음 값을 미리 붙여둔다.
#       그래서 0806_08.kra로 그린 그림은 내보내면 그대로 08.png가 된다.
#       번호를 되돌리면 내보낸 PNG가 이전 작품을 덮어쓴다.
#
# 사용법: ./newdoc.sh      오늘 캔버스가 이미 있으면 그걸 열기만 한다(매일 자동 실행용)
#         ./newdoc.sh -n   같은 날에도 캔버스를 하나 더 만든다
cd "$(dirname "$0")"

TPL="template.kra"
[ -f "$TPL" ] || { echo "템플릿을 못 찾음: $TPL"; exit 1; }

today=$(date +%m%d)

# 자동 실행이 하루에 여러 번 돌아도 캔버스가 늘어나지 않게, 오늘 것이 있으면 그것만 연다
if [ "$1" != "-n" ]; then
  existing=$(ls kra 2>/dev/null | grep "^${today}_[0-9][0-9]\.kra$" | sort | tail -1)
  if [ -n "$existing" ]; then
    open -a krita "kra/$existing"
    echo "오늘 캔버스 이미 있음: kra/$existing (새로 만들려면 ./newdoc.sh -n)"
    exit 0
  fi
fi

# 다음 번호 = 내보낸 png의 마지막 번호와 아직 안 내보낸 kra 번호 중 큰 값 + 1.
# png/를 반드시 봐야 한다 — 하루에 여러 장을 내보내면 kra 하나에 png가 여러 개라
# kra만 보면 이미 쓴 번호를 다시 발급한다(실제로 0807_12까지 있는데 0808_10을 만들었다).
# 번호 읽는 규칙은 optimize.sh와 공유한다. 여기서 따로 정규식을 쓰지 말 것.
. ./numof.sh
lastpng=$(maxnum png png)
lastkra=$(maxnum kra kra)
last=$(( lastpng > lastkra ? lastpng : lastkra ))
out="kra/${today}_$(printf '%02d' $(( last + 1 ))).kra"

# 템플릿의 자리표시자 그룹 이름(0000_00)을 실제 번호로 바꿔서 복사한다.
# .kra는 zip이라 maindoc.xml만 고쳐 다시 싼다 — 그룹 이름이 곧 갤러리 번호라서
# (krita-export-sil.py가 그룹 이름으로 내보낼 파일명을 정한다) 여기서 미리 심는다.
name=$(basename "$out" .kra)
python3 - "$TPL" "$out" "$name" << 'EOF'
import sys, zipfile
tpl, out, name = sys.argv[1:4]
src = zipfile.ZipFile(tpl)
with zipfile.ZipFile(out, 'w') as dst:
    for item in src.infolist():
        data = src.read(item.filename)
        if item.filename == 'maindoc.xml':
            data = data.replace(b'0000_00', name.encode())
        # mimetype은 무압축 첫 항목이어야 한다는 kra(ODF식) 관례 유지
        ctype = zipfile.ZIP_STORED if item.filename == 'mimetype' else zipfile.ZIP_DEFLATED
        dst.writestr(item, data, compress_type=ctype)
EOF
open -a krita "$out"
echo "새 작업 파일: $out (2480x3508, 300dpi, 그룹 $name)"
