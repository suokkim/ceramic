# -*- coding: utf-8 -*-
# 작품 + 실루엣 동시 내보내기 — Krita Ten Scripts용 (단축키 하나로 실행)
#
# 규칙: 실루엣은 이름이 "sil"인 레이어에 그린다 (대소문자 무관, 평소 꺼둬도 됨).
#  - sil 레이어      → png/<문서명>_sil.png   (레이어만, 캔버스 크기로)
#  - 나머지 전부     → png/<문서명>.png       (sil은 자동으로 빼고 내보냄)
# sil 레이어가 없으면 작품만 내보낸다. 그 뒤는 감시 에이전트가 벡터화·업로드까지 자동.
#
# 설치(한 번): 설정 > Krita 구성 > Python 플러그인 관리자 > "Ten Scripts" 켜고 재시작
#   → 도구 > 스크립트 > Ten Scripts 설정에서 이 파일을 슬롯에 지정 (단축키 Ctrl+Shift+숫자).

import os
from krita import Krita, InfoObject
from PyQt5.QtWidgets import QMessageBox


def _say(text):
    QMessageBox.information(None, u"내보내기", text)


def _find_sil(node):
    for c in node.childNodes():
        if c.name().strip().lower() == "sil":
            return c
        r = _find_sil(c)
        if r:
            return r
    return None


doc = Krita.instance().activeDocument()
if doc is None:
    _say(u"열린 문서가 없다.")
elif not doc.fileName():
    _say(u"먼저 문서를 저장할 것 — 파일명에서 내보낼 이름을 읽는다.")
else:
    # kra/MMDD_NN.kra → 프로젝트 루트의 png/ (kra/와 나란한 폴더)
    name = os.path.splitext(os.path.basename(doc.fileName()))[0]
    png_dir = os.path.join(os.path.dirname(os.path.dirname(doc.fileName())), "png")
    if not os.path.isdir(png_dir):
        _say(u"png/ 폴더를 못 찾았다: " + png_dir)
    else:
        doc.setBatchmode(True)  # 내보내기 대화상자 억제
        try:
            sil = _find_sil(doc.rootNode())
            msg = []
            if sil is not None:
                sil_path = os.path.join(png_dir, name + "_sil.png")
                # 레이어 저장은 가시성과 무관하다. doc.bounds()를 줘야 레이어의
                # 칠한 부분만이 아니라 캔버스 전체 크기로 나온다(정렬 유지).
                sil.save(sil_path, doc.resolution(), doc.resolution(),
                         InfoObject(), doc.bounds())
                msg.append(u"실루엣 → " + os.path.basename(sil_path))
            # 작품: sil을 잠깐 숨기고 내보낸 뒤 원상복귀
            was_visible = sil.visible() if sil is not None else None
            if sil is not None and was_visible:
                sil.setVisible(False)
                doc.refreshProjection()
            art_path = os.path.join(png_dir, name + ".png")
            doc.exportImage(art_path, InfoObject())
            msg.append(u"작품 → " + os.path.basename(art_path))
            if sil is not None and was_visible:
                sil.setVisible(True)
                doc.refreshProjection()
            if sil is None:
                msg.append(u"(sil 레이어 없음 — 작품만)")
            _say(u"\n".join(msg))
        finally:
            doc.setBatchmode(False)
