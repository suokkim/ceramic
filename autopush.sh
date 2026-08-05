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
# 바뀐 게 없으면 커밋하지 않는다 — 이 스크립트가 png/를 손대며 자신을 다시 부를 수 있어서,
# 여기서 멈춰야 무한 반복이 되지 않는다.
git diff --cached --quiet || git commit -q -m "Sync works $(date +%Y-%m-%d)"
# 푸시는 따로 판단한다. 지난번에 오프라인이라 실패했다면 밀린 커밋이 남아 있고,
# "이번엔 바뀐 게 없다"고 그냥 끝내버리면 영영 안 올라간다.
[ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ] &&
  git push -q && echo "푸시 완료: $(date)"
exit 0
