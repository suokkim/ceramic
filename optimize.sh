#!/bin/sh
# png/ 원본 → docs/images/ 웹용(긴 변 1600px) 변환 + 목록(images.json) 갱신
# 파일명 규칙: NN_이름.png (NN = 2자리 표시 순서). 넘버링 없으면 맨 뒤 번호 자동 부여.
cd "$(dirname "$0")"
mkdir -p docs/images

# 파일명은 NN.png 하나뿐. Krita가 붙이는 0806_ 같은 날짜 접두어는 떼어낸다.
#   0806_08.png → 08.png   (kra에서 미리 정해둔 번호를 그대로 쓴다. 이미 08.png가
#                           있으면 수정본이므로 덮어쓴다 — 이게 재수출 절차 전부다)
#   이름만 있는 파일  → 맨 뒤 번호를 새로 부여
# 1단계: 번호를 이미 갖고 있는 파일부터 처리한다. 순서가 중요하다 —
#        나중에 부여할 번호가 이미 쓰인 번호를 덮어쓰지 않게 하려면 이쪽이 먼저다.
for f in png/*.png; do
  base=$(basename "$f")
  case "$base" in [0-9][0-9].png) continue ;; esac
  # 날짜 접두어를 떼고, 예전 규칙의 s도 떼어본다 — Krita에 열려 있던 문서는 옛 이름
  # (0806_s08.kra)으로 저장되므로 내보내기도 s가 붙어 나온다. 이걸 못 읽으면 같은
  # 작품이 새 번호를 받아 갤러리에 두 번 올라간다(실제로 겪음).
  stripped=$(printf '%s' "$base" | sed 's/^[0-9][0-9]*_//; s/^s//')
  case "$stripped" in [0-9][0-9].png)
    mv -f "$f" "png/$stripped"; echo "이름 정리: $base → $stripped" ;;
  esac
done
# 2단계: 번호가 없는 파일에 맨 뒤 번호를 부여
next=$(ls png | grep -E '^[0-9]{2}\.png$' | sort | tail -1 | cut -c1-2 | sed 's/^0//')
next=$(( ${next:-0} + 1 ))
for f in png/*.png; do
  base=$(basename "$f")
  case "$base" in [0-9][0-9].png) continue ;; esac
  new="$(printf '%02d' "$next").png"
  mv -f "$f" "png/$new"
  echo "넘버링 추가: $base → $new"
  next=$((next+1))
done

# 웹용 이미지 생성 — 원본이 바뀐 것만.
# sips 출력은 같은 입력이라도 실행할 때마다 바이트가 달라진다(내부 타임스탬프). 매번
# 전부 다시 만들면 바뀐 게 없어도 git에 2MB짜리 변경이 계속 쌓이므로 원본 해시로 거른다.
: > docs/.imghash.new
for f in png/*.png; do
  base=$(basename "$f"); h=$(md5 -q "$f")
  old=$(grep "^$base " docs/.imghash 2>/dev/null | cut -d' ' -f2)
  if [ "$h" != "$old" ] || [ ! -f "docs/images/$base" ]; then
    cp "$f" "docs/images/$base"
    sips -Z 1600 "docs/images/$base" >/dev/null
  fi
  echo "$base $h" >> docs/.imghash.new
done
mv docs/.imghash.new docs/.imghash
# 원본에서 사라진 웹 이미지 정리 (삭제·이름변경 반영)
for w in docs/images/*.png; do
  [ -f "png/$(basename "$w")" ] || rm -f "$w"
done
# 최근 작업(큰 번호)이 먼저 보이도록 역순 정렬. ?v=는 **원본** 해시라 실행할 때마다
# 흔들리지 않고, 그림을 실제로 고쳤을 때만 바뀌어 캐시를 무효화한다.
python3 -c '
import json, glob, os, hashlib
entries = []
for p in sorted(glob.glob("docs/images/*.png"), reverse=True):
    name = os.path.basename(p)
    h = hashlib.md5(open("png/" + name, "rb").read()).hexdigest()[:8]
    entries.append(name + "?v=" + h)
print(json.dumps(entries, ensure_ascii=False))
' > docs/images.json

# 링크 공유 미리보기 이미지를 최신 작품(가장 큰 번호)으로 갱신
newest=$(ls docs/images | sort | tail -1)
sed -i '' "s|\(og:image\" content=\"https://suokkim.github.io/ceramic/images/\)[^\"]*|\1$newest|" docs/index.html

echo "완료: $(ls docs/images | wc -l | tr -d ' ')개 이미지, 공유 이미지: $newest"
