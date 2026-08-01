#!/bin/sh
# png/ 원본 → docs/images/ 웹용(긴 변 1600px) 변환 + 목록(images.json) 갱신
cd "$(dirname "$0")"
mkdir -p docs/images
for f in png/*.png; do
  out="docs/images/$(basename "$f")"
  cp "$f" "$out"
  sips -Z 1600 "$out" >/dev/null
done
python3 -c 'import json,glob,os;print(json.dumps(sorted(os.path.basename(p) for p in glob.glob("docs/images/*.png")),ensure_ascii=False))' > docs/images.json
echo "완료: $(ls docs/images | wc -l | tr -d ' ')개 이미지"
