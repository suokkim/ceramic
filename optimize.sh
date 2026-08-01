#!/bin/sh
# png/ 원본 → docs/images/ 웹용(긴 변 1600px) 변환 + 목록(images.json) 갱신
# 파일명 규칙: NN_이름.png (NN = 2자리 표시 순서). 넘버링 없으면 맨 뒤 번호 자동 부여.
cd "$(dirname "$0")"
mkdir -p docs/images

# 넘버링 없는 파일에 다음 번호 자동 부여
next=$(ls png | grep -E '^[0-9]{2}_' | sort | tail -1 | cut -c1-2 | sed 's/^0//')
next=$(( ${next:-0} + 1 ))
for f in png/*.png; do
  base=$(basename "$f")
  case "$base" in
    [0-9][0-9]_*) ;;
    *) mv "$f" "png/$(printf '%02d' "$next")_$base"
       echo "넘버링 추가: $base → $(printf '%02d' "$next")_$base"
       next=$((next+1)) ;;
  esac
done

# 웹용 이미지 전체 재생성 (삭제/이름변경 반영)
rm -f docs/images/*.png
for f in png/*.png; do
  out="docs/images/$(basename "$f")"
  cp "$f" "$out"
  sips -Z 1600 "$out" >/dev/null
done
python3 -c 'import json,glob,os;print(json.dumps(sorted(os.path.basename(p) for p in glob.glob("docs/images/*.png")),ensure_ascii=False))' > docs/images.json
echo "완료: $(ls docs/images | wc -l | tr -d ' ')개 이미지"
