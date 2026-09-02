#!/bin/sh
# png/에 PNG가 떨어지면 자동으로 최적화 → 커밋 → 푸시.
# LaunchAgent(com.ceramic.autopush)가 png/ 폴더 변화를 감지해 이 스크립트를 부른다.
cd "$(dirname "$0")"

# --- 헛트리거 차단 ---
# launchd의 WatchPaths는 파일 내용이 안 바뀌어도 폴더 메타데이터 이벤트만으로 발동한다
# (실제로 png/가 12시간 동안 그대로인데 20번 넘게 실행됐다). 그때마다 전체 재계산을
# 돌리면 앱이 뜨고 지는 게 눈에 보이고 docs/도 매번 다시 쓰인다. png/의 실제 상태
# (파일명·크기·수정시각)를 지문으로 떠서 지난번과 같으면 즉시 끝낸다.
# 지문은 /tmp에 둔다 — git에 안 들어가고, 날아가도 다음 한 번만 헛도는 게 전부다.
STAMP=/tmp/ceramic-pngstamp
now=$(stat -f "%N %z %m" png/*.png 2>/dev/null | md5)
[ -f "$STAMP" ] && [ "$now" = "$(cat "$STAMP")" ] && exit 0

# 동시 실행 방지 — 이벤트가 몰아치면 여러 개가 겹쳐 돌아 git이 서로를 밟는다.
# mkdir은 원자적이라 락으로 안전하다. 죽은 락(10분 이상)은 스스로 걷어낸다.
LOCK=/tmp/ceramic-autopush.lock
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ] || exit 0
  rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCK"' EXIT INT TERM

# 내보내기가 끝나기 전에 달려들면 반쪽짜리 PNG를 읽는다. 크기가 멈출 때까지 기다린다.
prev=""; i=0
while [ $i -lt 20 ]; do
  now=$(ls -l png/*.png 2>/dev/null | awk '{s+=$5} END {print s}')
  [ "$now" = "$prev" ] && [ -n "$now" ] && break
  prev="$now"; sleep 2; i=$((i+1))
done

./tools/optimize.sh || exit 1

git add -A
# 바뀐 게 없으면 커밋하지 않는다 — 이 스크립트가 png/를 손대며 자신을 다시 부를 수 있어서,
# 여기서 멈춰야 무한 반복이 되지 않는다.
git diff --cached --quiet || git commit -q -m "Sync works $(date +%Y-%m-%d)"
# 푸시는 따로 판단한다. 지난번에 오프라인이라 실패했다면 밀린 커밋이 남아 있고,
# "이번엔 바뀐 게 없다"고 그냥 끝내버리면 영영 안 올라간다.
[ -n "$(git log origin/main..HEAD --oneline 2>/dev/null)" ] &&
  git push -q && echo "푸시 완료: $(date)"

# 처리 끝난 상태를 지문으로 남긴다 — 대기 루프 뒤(내보내기 완료 후) 값이라야
# 다음 실행이 "이미 처리됨"을 정확히 판정한다.
stat -f "%N %z %m" png/*.png 2>/dev/null | md5 > "$STAMP"
exit 0
