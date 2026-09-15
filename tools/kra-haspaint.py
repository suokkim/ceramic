#!/usr/bin/env python3
# 넘겨받은 .kra 중 **실제로 그린 내용이 있는 것**만 골라 경로를 한 줄씩 출력한다.
# newdoc.sh가 번호를 발급할 때 쓴다 — 작업 중인 파일은 아직 png로 안 내보냈어도
# 그 번호를 예약해둬야 하고(며칠 뒤에 내보낼 수 있다), 손도 안 댄 빈 캔버스는
# 번호를 놓아줘야 갤러리 번호에 구멍이 안 생긴다.
#
# 판정: .kra(zip) 안 레이어 타일 데이터의 압축 전 크기 합을 템플릿과 견준다.
#   빈 캔버스 663,335~663,391 바이트(흰 배경 한 장) — 서로 56바이트 차이.
#   그린 파일 4,131,165 바이트 이상(표본 5개 전부).
# 파일 크기가 아니라 타일 데이터를 보는 이유: 파일 크기는 압축률에 흔들리고,
# 한 획만 그은 날은 작을 수 있다. 타일은 64x64x4=16KB 단위로 늘어나 반응이 뚜렷하다.
#
# 사용: python3 tools/kra-haspaint.py kra/0914_59.kra kra/0913_58.kra ...
import os
import sys
import zipfile

# 붓질 한 번이면 타일이 최소 하나(16KB) 생긴다. 그 4배를 문턱으로 둬 빈 캔버스끼리의
# 오차(수십 바이트)와 확실히 가른다.
# ponytail: 고정 문턱. 아주 작은 획 하나만 그은 날이 빈 것으로 판정되면 16384로 낮출 것.
MARGIN = 65536


def tile_bytes(path):
    """레이어 픽셀 데이터의 압축 전 크기 합. 못 읽으면 None."""
    try:
        with zipfile.ZipFile(path) as z:
            return sum(i.file_size for i in z.infolist()
                       if '/layers/' in i.filename
                       and not i.filename.endswith(('/', '.icc', '.defaultpixel')))
    except Exception:
        return None


tpl = tile_bytes(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'template.kra'))
base = 0 if tpl is None else tpl

for path in sys.argv[1:]:
    n = tile_bytes(path)
    # 못 읽는 파일은 '작업 중'으로 본다 — 번호를 뺏어 덮어쓰는 것보다 아끼는 쪽이 안전
    if n is None or n - base > MARGIN:
        print(path)
