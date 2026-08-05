#!/bin/sh
# png/에 PNG가 떨어지면 자동으로 최적화 → 커밋 → 푸시.
# LaunchAgent(com.ceramic.autopush)가 png/ 폴더 변화를 감지해 이 스크립트를 부른다.
cd "$(dirname "$0")"

# 내보내기가 끝나기 전에 달려들면 반쪽짜리 PNG를 읽는다. 크기가 멈출 때까지 기다린다.
prev=""; i=0
while [ $i -lt 20 ]; do
  now=$(ls -l png/*.png 2>/dev/null | awk '{s+=$5} END {print s}')
  [ "$now" = "$prev" ] && [ -n "$now" ] && break
  prev="$now"; sleep 2; i=$((i+1))
done

./optimize.sh || exit 1

git add -A
# 바뀐 게 없으면 조용히 끝낸다 — 이 스크립트가 png/를 손대며 자신을 다시 부를 수 있어서,
# 여기서 멈춰야 무한 반복이 되지 않는다.
git diff --cached --quiet && exit 0
git commit -q -m "Add work $(date +%Y-%m-%d)" && git push -q && echo "푸시 완료: $(date)"
