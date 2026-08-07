#!/bin/sh
# 파일명에서 갤러리 번호를 읽는 규칙 한 곳. newdoc.sh와 optimize.sh가 **같은** 규칙을
# 써야 한다 — 예전에는 둘이 각자 정규식을 들고 있다가 어긋났고, newdoc.sh 쪽이
# `NN.png`만 매칭해서 `MMDD_NN.png`인 png/를 통째로 못 읽었다. 그래서 png/에 12번까지
# 있는데도 오늘 캔버스에 10번을 다시 발급했다(이미 쓴 번호 = 갤러리에서 덮어씀).
#
# 읽는 형태:  0806_08.png -> 08   |   08.png -> 08   |   0806_s08.png -> 08 (옛 이름)
# 못 읽으면 빈 값.
#
# 사용:  . ./numof.sh          함수만 정의
#        numof 0806_08.png     -> 08        (확장자 기본값 png)
#        numof 0806_08.kra kra -> 08
#        sh numof.sh --test    자기검사

numof() {
  # 개행을 붙여 넘긴다 — 없으면 sed도 개행 없이 뱉어 여러 번 호출한 결과가 붙어버린다
  # (08 + 08 = "0808"로 읽혀 번호가 809까지 튀었다)
  printf '%s\n' "$1" | sed -n "s/^\([0-9][0-9]*_\)\{0,1\}s\{0,1\}\([0-9][0-9]\)\.${2:-png}\$/\2/p"
}

# 디렉터리에서 가장 큰 번호를 읽는다 (없으면 0). 앞의 0은 떼야 08·09가 8진수로 안 읽힌다.
maxnum() {   # maxnum <디렉터리> <확장자>
  last=$(for f in "$1"/*."$2"; do numof "$(basename "$f")" "$2"; done | sort -n | tail -1)
  echo $(( $(echo "${last:-0}" | sed 's/^0//') + 0 ))
}

[ "$1" = "--test" ] || return 0 2>/dev/null || exit 0

fail=0
check() {   # check <입력> <확장자> <기대값>
  got=$(numof "$1" "$2")
  if [ "$got" = "$3" ]; then
    echo "  ok   $1 ($2) -> '${got}'"
  else
    echo "  FAIL $1 ($2) -> '${got}', 기대 '$3'"; fail=1
  fi
}

echo "numof 자기검사"
check 0806_08.png  png 08     # 지금 쓰는 이름 — 이게 깨져서 번호가 충돌했다
check 0807_12.png  png 12
check 08.png       png 08     # 옛 웹용 이름
check 0806_s08.png png 08     # 옛 sNN 이름
check 0808_13.kra  kra 13
check homepage.kra kra ""     # 번호 없는 파일
check 0806_08.png~ png ""     # 편집기 백업
check 0806_08.kra  png ""     # 확장자 불일치
check 0806_8.png   png ""     # 한 자리는 번호로 안 침

# 여러 번 호출한 결과가 붙지 않는지 (예전 실전 버그)
joined=$(printf '%s' "$(numof 0806_08.png)$(numof 0807_09.png)")
lines=$( { numof 0806_08.png; numof 0807_09.png; } | wc -l | tr -d ' ')
if [ "$lines" = "2" ]; then echo "  ok   연속 호출이 2줄로 분리됨"
else echo "  FAIL 연속 호출이 '$joined' 로 붙음"; fail=1; fi

[ "$fail" = 0 ] && echo "전부 통과" || echo "실패 있음"
exit $fail
