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
  stripped=$(printf '%s' "$base" | sed 's/^[0-9][0-9]*_//')
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

# 웹용 이미지 전체 재생성 (삭제/이름변경 반영)
rm -f docs/images/*.png
for f in png/*.png; do
  out="docs/images/$(basename "$f")"
  cp "$f" "$out"
  sips -Z 1600 "$out" >/dev/null
done
# 최근 작업(큰 번호)이 먼저 보이도록 역순 정렬, 파일 해시를 ?v=로 붙여 수정 시 캐시 자동 무효화
python3 -c '
import json, glob, os, hashlib
entries = []
for p in sorted(glob.glob("docs/images/*.png"), reverse=True):
    h = hashlib.md5(open(p, "rb").read()).hexdigest()[:8]
    entries.append(os.path.basename(p) + "?v=" + h)
print(json.dumps(entries, ensure_ascii=False))
' > docs/images.json

# 링크 공유 미리보기 이미지를 최신 작품(가장 큰 번호)으로 갱신
newest=$(ls docs/images | sort | tail -1)
sed -i '' "s|\(og:image\" content=\"https://suokkim.github.io/ceramic/images/\)[^\"]*|\1$newest|" docs/index.html

echo "완료: $(ls docs/images | wc -l | tr -d ' ')개 이미지, 공유 이미지: $newest"
