# -*- coding: utf-8 -*-
# 작품 + 실루엣 동시 내보내기 — Krita Ten Scripts용 (단축키 하나로 실행)
#
# 두 가지 모드를 자동으로 고른다:
#
# [다작품 모드] 하루 한 파일에 작품 여러 개 — **최상위 레이어(그룹) 이름이 번호**다.
#   0809_18      → png/0809_18.png      (이 레이어 + 공용 레이어(배경)만 켜고 내보냄)
#   0809_18_sil  → png/0809_18_sil.png  (실루엣, 레이어만 따로 저장)
#   0809_19 …    → 각각 반복
#   번호 없는 최상위 레이어(배경 등)는 공용 — 모든 작품에 같이 깔린다.
#   **그룹 안의 "sil" 레이어는 그룹 번호를 자동으로 따른다** — 그룹을 복제해 다음
#   작품을 만들 때 그룹 이름만 바꾸면 된다(안쪽 sil은 이름 그대로).
#   작품 내보낼 땐 모든 실루엣 레이어가 자동으로 꺼진다.
#
# [단일 모드] 번호 레이어가 하나도 없으면 — 문서 파일명이 곧 작품 번호.
#   전체(sil 제외)   → png/<문서명>.png
#   "sil" 레이어     → png/<문서명>_sil.png
#
# 빈(칠한 게 없는) 실루엣 레이어는 없는 것으로 친다 — 자동 계산 실루엣을 보존.
# 내보낸 뒤는 감시 에이전트가 벡터화·업로드까지 자동 처리한다.
#
# 설치(한 번): 설정 > Krita 구성 > Python 플러그인 관리자 > "Ten Scripts" 켜고 재시작
#   → 도구 > 스크립트 > Ten Scripts 설정에서 이 파일을 슬롯에 지정 (단축키 Ctrl+Shift+숫자).

import os
import re
from krita import Krita, InfoObject
from PyQt5.QtWidgets import QMessageBox

# 번호 레이어 이름: MMDD_NN 또는 NN (+ _sil). optimize.sh의 numof와 같은 관용.
NUM = re.compile(r"^(\d{4}_)?\d{2}$")


def _say(text):
    QMessageBox.information(None, u"내보내기", text)


def _walk(node):
    for c in node.childNodes():
        yield c
        for g in _walk(c):
            yield g


def _is_sil_name(name):
    return name == "sil" or (name.endswith("_sil") and NUM.match(name[:-4]))


def _has_paint(node):
    return not node.bounds().isEmpty()


def _save_layer(doc, node, path):
    # doc.bounds()를 줘야 칠한 부분만이 아니라 캔버스 전체 크기로 나온다(정렬 유지)
    node.save(path, doc.resolution(), doc.resolution(), InfoObject(), doc.bounds())


doc = Krita.instance().activeDocument()
if doc is None:
    _say(u"열린 문서가 없다.")
elif not doc.fileName():
    _say(u"먼저 문서를 저장할 것 — 파일명에서 내보낼 이름을 읽는다.")
else:
    docname = os.path.splitext(os.path.basename(doc.fileName()))[0]
    png_dir = os.path.join(os.path.dirname(os.path.dirname(doc.fileName())), "png")
    if not os.path.isdir(png_dir):
        _say(u"png/ 폴더를 못 찾았다: " + png_dir)
    else:
        top = doc.rootNode().childNodes()
        works = [n for n in top if NUM.match(n.name().strip())]
        sils = [n for n in _walk(doc.rootNode()) if _is_sil_name(n.name().strip())]
        # 그룹 안의 sil은 그룹 번호와 짝: [(파일이름, 노드)]
        inner_sils = []
        for w in works:
            for s in _walk(w):
                if _is_sil_name(s.name().strip()):
                    inner_sils.append((w.name().strip() + "_sil", s))

        doc.setBatchmode(True)  # 내보내기 대화상자 억제
        try:
            msg = []
            # Krita 노드 객체는 해시 불가 — dict 키로 못 쓰고 (node, visible) 쌍 목록으로
            orig = [(n, n.visible()) for n in works + sils]
            try:
                if works:
                    # --- 다작품 모드: 번호 레이어마다 한 장씩 ---
                    for w in works:
                        name = w.name().strip()
                        for n in works:
                            n.setVisible(n is w)
                        for n in sils:
                            n.setVisible(False)
                        # 가시성 변경 후 합성이 끝나기 전에 내보내면 Krita가 죽는다 —
                        # refreshProjection만으론 부족하고 반드시 waitForDone까지.
                        doc.refreshProjection()
                        doc.waitForDone()
                        path = os.path.join(png_dir, name + ".png")
                        renew = os.path.exists(path)  # 이미 있던 번호 = 기존 작품 갱신
                        doc.exportImage(path, InfoObject())
                        msg.append(u"작품 → " + name + ".png" + (u" (갱신)" if renew else u" (신규)"))
                    # 그룹 안 sil은 그룹 번호로, 최상위 번호_sil은 제 이름으로
                    inner_nodes = [s for _, s in inner_sils]
                    exports = inner_sils + [
                        (s.name().strip(), s) for s in sils
                        if s.name().strip() != "sil" and not any(s is n for n in inner_nodes)
                    ]
                    for sname, s in exports:
                        if not _has_paint(s):
                            continue  # 빈 실루엣(템플릿 기본)은 조용히 무시
                        _save_layer(doc, s, os.path.join(png_dir, sname + ".png"))
                        msg.append(u"실루엣 → " + sname + ".png")
                else:
                    # --- 단일 모드: 문서명이 작품 번호 ---
                    sil = next((s for s in sils if _has_paint(s)), None)
                    if sil is not None:
                        _save_layer(doc, sil, os.path.join(png_dir, docname + "_sil.png"))
                        msg.append(u"실루엣 → " + docname + "_sil.png")
                    for s in sils:
                        s.setVisible(False)
                    doc.refreshProjection()
                    doc.waitForDone()
                    doc.exportImage(os.path.join(png_dir, docname + ".png"), InfoObject())
                    msg.append(u"작품 → " + docname + ".png")
                    if sil is None:
                        msg.append(u"(그린 실루엣 없음 — 자동 계산)")
            finally:
                for n, v in orig:
                    n.setVisible(v)
                doc.refreshProjection()
                doc.waitForDone()
            _say(u"\n".join(msg))
        finally:
            doc.setBatchmode(False)
