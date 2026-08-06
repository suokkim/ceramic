#!/bin/sh
# png/ 원본 → docs/images/ 웹용(긴 변 1600px) 변환 + 목록(images.json) 갱신
#
# 이름 규칙: kra도 png도 MMDD_NN — 앞은 날짜, 뒤는 갤러리 번호 (예: 0806_08.png).
# **png/ 파일 이름은 절대 바꾸지 않는다.** Krita는 늘 문서 이름 그대로 내보내므로,
# 여기서 번호로 바꿔버리면 다음 내보내기가 제 이름으로 다시 떨어져 같은 작품이
# 새 번호를 받는다(실제로 겪었다). 이름은 그대로 두고 번호만 읽어 docs/에 복사한다.
# 공개되는 웹용만 번호로 통일한다 — 갤러리 순서가 파일명 정렬이라 날짜가 끼면 꼬인다.
cd "$(dirname "$0")"
mkdir -p docs/images/th

# 파일명에서 번호 읽기. 0806_08.png → 08, 08.png → 08, 0806_s08.png → 08(옛 이름).
# 못 읽으면 빈 값.
numof() {
  # 개행을 붙여 넘긴다 — 없으면 sed도 개행 없이 뱉어 여러 번 호출한 결과가 붙어버린다
  # (08 + 08 = "0808"로 읽혀 번호가 809까지 튀었다)
  printf '%s\n' "$1" | sed -n 's/^\([0-9][0-9]*_\)\{0,1\}s\{0,1\}\([0-9][0-9]\)\.png$/\2/p'
}

# 번호를 못 읽는 파일에만 오늘 날짜로 번호를 붙인다 (Krita 밖에서 넣은 파일용).
next=$(for f in png/*.png; do numof "$(basename "$f")"; done | sort -n | tail -1 | sed 's/^0//')
next=$(( ${next:-0} + 1 ))
for f in png/*.png; do
  base=$(basename "$f")
  [ -n "$(numof "$base")" ] && continue
  new="$(date +%m%d)_$(printf '%02d' "$next").png"
  mv -f "$f" "png/$new"
  echo "넘버링 추가: $base → $new"
  next=$((next+1))
done

# 번호 → 원본 파일. 같은 번호가 둘이면 최신 파일이 이긴다(ls -tr = 오래된 것부터).
map=$(for f in $(ls -tr png/*.png 2>/dev/null); do
        n=$(numof "$(basename "$f")"); [ -n "$n" ] && echo "$n $f"
      done | awk '{m[$1]=$2} END {for (k in m) print k, m[k]}' | sort)

# 웹용 이미지 생성 — 원본이 바뀐 것만.
# sips 출력은 같은 입력이라도 실행할 때마다 바이트가 달라진다(내부 타임스탬프). 매번
# 전부 다시 만들면 바뀐 게 없어도 git에 2MB짜리 변경이 계속 쌓이므로 원본 해시로 거른다.
: > docs/.imghash.new
echo "$map" | while read -r n f; do
  [ -z "$n" ] && continue
  out="docs/images/$n.png"
  th="docs/images/th/$n.png"
  h=$(md5 -q "$f")
  old=$(grep "^$n.png " docs/.imghash 2>/dev/null | cut -d' ' -f2)
  if [ "$h" != "$old" ] || [ ! -f "$out" ] || [ ! -f "$th" ]; then
    cp "$f" "$out"
    sips -Z 1600 "$out" >/dev/null
    # 대문 그리드용 썸네일. 칸 폭이 250px 남짓이라 600px면 레티나에서도 충분하고,
    # 원본을 그대로 받을 때보다 3~5배 가볍다 (첫 로딩 2.2MB → 0.7MB).
    cp "$out" "$th"
    sips -Z 600 "$th" >/dev/null
  fi
  echo "$n.png $h" >> docs/.imghash.new
done
mv docs/.imghash.new docs/.imghash

# 원본에서 사라진 웹 이미지 정리 (삭제 반영) — 썸네일도 같이
for w in docs/images/*.png; do
  b=$(basename "$w")
  grep -q "^$b " docs/.imghash || rm -f "$w" "docs/images/th/$b"
done

# 최근 작업(큰 번호)이 먼저 보이도록 역순 정렬. ?v=는 **원본** 해시라 실행할 때마다
# 흔들리지 않고, 그림을 실제로 고쳤을 때만 바뀌어 캐시를 무효화한다.
python3 -c '
import json
entries = []
for line in open("docs/.imghash"):
    name, h = line.split()
    entries.append(name + "?v=" + h[:8])
entries.sort(reverse=True)
print(json.dumps(entries, ensure_ascii=False))
' > docs/images.json

# 링크 공유 미리보기 이미지를 최신 작품(가장 큰 번호)으로 갱신.
# ls docs/images가 아니라 .imghash를 읽는다 — 디렉터리(th)가 끼면 그게 tail -1로 잡힌다.
newest=$(cut -d' ' -f1 docs/.imghash | sort | tail -1)
sed -i '' "s|\(og:image\" content=\"https://suokkim.github.io/ceramic/images/\)[^\"]*|\1$newest|" docs/index.html

echo "완료: $(ls docs/images/*.png | wc -l | tr -d ' ')개 이미지, 공유 이미지: $newest"
