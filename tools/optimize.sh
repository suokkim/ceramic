#!/bin/sh
# png/ 원본 → docs/images/ 웹용(긴 변 1600px) 변환 + 목록(images.json) 갱신
#
# 이름 규칙: kra도 png도 MMDD_NN — 앞은 날짜, 뒤는 갤러리 번호 (예: 0806_08.png).
# **png/ 파일 이름은 절대 바꾸지 않는다.** Krita는 늘 문서 이름 그대로 내보내므로,
# 여기서 번호로 바꿔버리면 다음 내보내기가 제 이름으로 다시 떨어져 같은 작품이
# 새 번호를 받는다(실제로 겪었다). 이름은 그대로 두고 번호만 읽어 docs/에 복사한다.
# 공개되는 웹용만 번호로 통일한다 — 갤러리 순서가 파일명 정렬이라 날짜가 끼면 꼬인다.
cd "$(dirname "$0")/.."   # 저장소 루트 기준으로 동작 (tools/ 안에 있으므로 한 단계 위)
mkdir -p docs/images/th docs/images/sq

# 파일명에서 번호 읽기 — 규칙은 numof.sh 하나에만 둔다(newdoc.sh와 공유).
# 여기서 따로 정규식을 쓰면 두 스크립트가 어긋나 번호가 충돌한다. 검사: sh tools/numof.sh --test
. ./tools/numof.sh

# 번호를 못 읽는 파일에만 오늘 날짜로 번호를 붙인다 (Krita 밖에서 넣은 파일용).
# *_sil.png(수제 실루엣)와 *_v2.png(같은 작품의 버전, 아래 참조)는 새 작품이
# 아니므로 건드리지 않는다 — 여기 예외를 안 걸면 numof가 못 읽어 새 번호를 받아버린다.
next=$(for f in png/*.png; do numof "$(basename "$f")"; done | sort -n | tail -1 | sed 's/^0//')
next=$(( ${next:-0} + 1 ))
for f in png/*.png; do
  base=$(basename "$f")
  case "$base" in *_sil.png|*_v[0-9]*.png) continue;; esac
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

# 예외: 원작(무접미사)이 없는 번호는 **가장 낮은 버전을 원작으로 승격**한다 —
# 버전만 올라온 작품이 고아로 숨지 않게. 승격판은 대표판 파이프라인(썸네일·실루엣)을
# 그대로 타고, 아래 버전 루프에서는 제외해 같은 그림이 두 번 나오지 않는다.
# 진짜 원작이 나중에 들어오면 맵에서 밀려나 자동으로 버전 슬롯으로 돌아간다.
promo=$(for f in $(ls png/*_v[0-9]*.png 2>/dev/null); do
          # 명령 치환 안의 case는 패턴에 여는 괄호가 필수 — 없으면 )가 $( )를 닫아버린다
          case "$f" in (*_sil.png) continue;; esac
          nv=$(verof "$(basename "$f")"); [ -n "$nv" ] && echo "$nv $f"
        done | sort -k1,1 -k2,2n |
        while read -r n k f; do
          echo "$map" | grep -q "^$n " || echo "$n $f"
        done | awk '!seen[$1]++')
[ -n "$promo" ] && map=$(printf '%s\n%s' "$map" "$promo" | sort)

# 웹용 이미지 생성 — 원본이 바뀐 것만.
# sips 출력은 같은 입력이라도 실행할 때마다 바이트가 달라진다(내부 타임스탬프). 매번
# 전부 다시 만들면 바뀐 게 없어도 git에 2MB짜리 변경이 계속 쌓이므로 원본 해시로 거른다.
# node 경로: launchd(자동업로드 앱) 환경에는 /opt/homebrew/bin이 PATH에 없다.
NODE=$(command -v node || echo /opt/homebrew/bin/node)
: > docs/.imghash.new
echo "$map" | while read -r n f; do
  [ -z "$n" ] && continue
  out="docs/images/$n.png"
  th="docs/images/th/$n.jpg"
  sq="docs/images/sq/$n.jpg"
  h=$(md5 -q "$f")
  old=$(grep "^$n.png " docs/.imghash 2>/dev/null | cut -d' ' -f2)
  if [ "$h" != "$old" ] || [ ! -f "$out" ] || [ ! -f "$th" ] || [ ! -f "$sq" ]; then
    cp "$f" "$out"
    sips -Z 1600 "$out" >/dev/null
    # 대문 그리드용 썸네일. 칸 폭이 250px 남짓이라 600px면 레티나에서도 충분하다.
    # **JPEG인 이유**: 모아보기가 기본이 되면서 그리드 전체가 한 화면에 들어와
    # loading=lazy가 무력해졌고, 15장 1.06MB를 첫 로딩에 전부 받았다. 같은 크기
    # JPEG q82면 0.40MB — 화질 손실은 배경 오차 0, 오브제 ±1로 눈에 안 보인다.
    # 공개 원본(docs/images/)과 png/는 PNG 그대로. 썸네일만 JPEG다.
    # 축소와 변환을 한 번에 — 나눠서 하면 JPEG로 인코딩한 걸 다시 인코딩하게 된다
    sips -Z 600 -s format jpeg -s formatOptions 82 "$out" --out "$th" >/dev/null

    # 폰 모아보기 전용 정사각 240px. 모아보기는 CSS로 정사각 크롭해 보여주는데
    # 폰에서 칸이 113px(레티나 226px)이라 th의 424x600은 5배 과잉이다.
    # 크롭과 축소는 반드시 두 번에 나눠 부를 것 — 한 번에 주면 sips가 -Z를 먼저
    # 적용해서 169x169 같은 엉뚱한 크기가 나온다.
    W=$(sips -g pixelWidth "$out" | tail -1 | awk '{print $2}')
    sips -c "$W" "$W" "$out" --out "$sq.crop.png" >/dev/null
    sips -Z 240 -s format jpeg -s formatOptions 82 "$sq.crop.png" --out "$sq" >/dev/null
    rm -f "$sq.crop.png"
    # 흰 배경 톤을 썸네일에 미리 굽는다(예전 CSS dimWhite 필터의 파일판) — 자세한
    # 커브는 tone.mjs 참고. 웹용 원본($out)은 뷰어 전용이라 톤을 얹지 않는다.
    "$NODE" tools/tone.mjs "$th" "$sq"
  fi
  echo "$n.png $h" >> docs/.imghash.new
done

# 같은 작품의 버전(png/MMDD_NN_v2.png → docs/images/NN-2.png).
# 뷰어에서 좌우 스와이프로만 보이므로 1600px PNG 하나만 만든다 — 그리드엔 원작
# (대표판)만 나오니 썸네일(th/sq)도, 실루엣(si)도 원작 것을 그대로 쓴다.
for f in $(ls -tr png/*_v[0-9]*.png 2>/dev/null); do
  case "$f" in *_sil.png) continue;; esac
  case "$promo" in *" $f"*) continue;; esac   # 원작으로 승격된 버전은 버전 슬롯에서 제외
  nv=$(verof "$(basename "$f")"); [ -z "$nv" ] && continue
  n=${nv% *}; k=${nv#* }
  out="docs/images/$n-$k.png"
  h=$(md5 -q "$f")
  old=$(grep "^$n-$k.png " docs/.imghash 2>/dev/null | cut -d' ' -f2)
  if [ "$h" != "$old" ] || [ ! -f "$out" ]; then
    cp "$f" "$out"
    sips -Z 1600 "$out" >/dev/null
  fi
  echo "$n-$k.png $h" >> docs/.imghash.new
done
mv docs/.imghash.new docs/.imghash

# 모아보기 실루엣(si/) — 웹용 PNG에서 오프라인 생성 (node silhouette.mjs).
# 처음엔 브라우저가 240px JPEG 썸네일로 매번 계산했는데 노이즈·저해상도 때문에
# 규칙이 계속 늘었다. 1600px 원본에서 한 번만 만들면 안정적이고, 결과가 파일이라
# 눈으로 검수하거나 문제 작품만 개별 수정할 수 있다. 원본이 바뀐 것만 다시(-nt).
mkdir -p docs/images/si

# 수제 실루엣 오버라이드: Krita에서 실루엣을 별도 레이어에 그렸다면
# 그 레이어를 png/MMDD_NN_sil.png 로 저장한다(레이어 > 가져오기/내보내기 > 레이어 저장).
# 있으면 자동 계산 대신 그 그림을 그대로 벡터화(--manual: 휴리스틱 전부 생략).
# 같은 번호가 둘이면 작품과 같은 규칙으로 최신 파일이 이긴다.
# 수제를 그만두려면 _sil 파일과 si/NN.svg를 지우고 이 스크립트를 다시 돌리면 된다.
silmap=$(for f in $(ls -tr png/*_sil.png 2>/dev/null); do
           n=$(numof "$(basename "$f" | sed 's/_sil\.png$/.png/')")
           [ -n "$n" ] && echo "$n $f"
         done | awk '{m[$1]=$2} END {for (k in m) print k, m[k]}')

for w in docs/images/*.png; do
  n=$(basename "$w" .png)
  case "$n" in *-*) continue;; esac   # 버전(NN-2)은 실루엣 없음 — 원작 것을 공유
  si="docs/images/si/$n.svg"
  src="$w"; mode=""
  manual=$(echo "$silmap" | awk -v n="$n" '$1==n {print $2}')
  if [ -n "$manual" ]; then src="$manual"; mode="--manual"; fi
  if [ ! -f "$si" ] || [ "$src" -nt "$si" ]; then
    "$NODE" tools/silhouette.mjs $mode "$src" "$si" || echo "실루엣 실패: $n"
  fi
done

# 원본에서 사라진 웹 이미지 정리 (삭제 반영) — 썸네일·실루엣도 같이
for w in docs/images/*.png; do
  b=$(basename "$w")
  grep -q "^$b " docs/.imghash ||
    rm -f "$w" "docs/images/th/${b%.png}.jpg" "docs/images/sq/${b%.png}.jpg" \
          "docs/images/si/${b%.png}.svg"
done
# 옛 PNG 썸네일 잔여물 정리 (JPEG 전환 전에 만들어진 것)
rm -f docs/images/th/*.png

# 최근 작업(큰 번호)이 먼저 보이도록 역순 정렬. ?v=는 원본+실루엣 해시라 실행할
# 때마다 흔들리지 않고, 그림이나 실루엣을 실제로 고쳤을 때만 바뀌어 캐시를
# 무효화한다. 실루엣을 합치는 이유: 작품은 그대로 두고 수제 실루엣만 다시 그리면
# URL이 안 바뀌어 기기들이 옛 실루엣을 계속 보여줬다(0810_22에서 실제로 겪었다).
# 형식: 작품당 배열 [원작, v2, v3, …] — 첫 요소가 대표판(그리드에 보이는 판).
python3 -c '
import json, hashlib, os, re
groups = {}
for line in open("docs/.imghash"):
    name, h = line.split()
    base, ver = re.match(r"(\d+)(?:-(\d+))?\.png$", name).groups()
    if ver is None:
        si = "docs/images/si/" + base + ".svg"
        if os.path.exists(si):
            h = hashlib.md5((h + hashlib.md5(open(si, "rb").read()).hexdigest()).encode()).hexdigest()
    groups.setdefault(base, []).append((int(ver or 0), name + "?v=" + h[:8]))
out = []
for base in sorted(groups, reverse=True):
    vs = sorted(groups[base])
    if vs[0][0] == 0:              # 원작 없는 고아 버전은 목록에서 뺀다
        out.append([v for _, v in vs])
print(json.dumps(out, ensure_ascii=False))
' > docs/images.json

# 링크 공유 미리보기 이미지를 최신 작품(가장 큰 번호)으로 갱신.
# ls docs/images가 아니라 .imghash를 읽는다 — 디렉터리(th)가 끼면 그게 tail -1로 잡힌다.
newest=$(cut -d' ' -f1 docs/.imghash | sort | tail -1)
sed -i '' "s|\(og:image\" content=\"https://suokkim.github.io/ceramic/images/\)[^\"]*|\1$newest|" docs/index.html

echo "완료: $(ls docs/images/*.png | wc -l | tr -d ' ')개 이미지, 공유 이미지: $newest"
