#!/usr/bin/env node
// 실루엣 생성: docs/images/NN.png(웹용 원본) → docs/images/si/NN.svg
// (흰 배경 rect + 회색 #666 오브제 패스 — 벡터라 어떤 크기로 줄여도 매끈하다)
//
// 사용: node silhouette.mjs <입력.png> <출력.svg>
//
// 왜 오프라인인가: 처음엔 브라우저가 240px JPEG 썸네일에서 매번 계산했는데, JPEG
// 노이즈와 저해상도 때문에 의도된 슬릿(5px)과 질감 균열(5px)이 같은 크기로 보여
// 휴리스틱이 계속 늘었다. 1600px 무압축 PNG에서 한 번만 계산하면 같은 규칙이 훨씬
// 안정적으로 돌고, 결과가 파일이라 눈으로 검수·개별 수정이 가능하다.
//
// 파이프라인 (각 단계는 한 가지 결함만 담당):
//  1. 어두움 판정  — 픽셀값 ≤215, 또는 블러 평균 ≤205(흰 긁힘 질감 편입)
//  2. 클로징      — 어두운 픽셀을 R 불려 얇은 밝은 틈을 봉합한 뒤 테두리에서 flood fill
//  3. 오프닝      — 실오라기 통로로 이어진 안쪽 얼룩을 배경에서 분리
//  4. 잔점 제거    — 면적 N/2000 미만의 오브제 점(그림자 붓끝)
//  5. 웅덩이 메꾸기 — 상하좌우가 오브제로 막힌(또는 3방향+둘레 2/3 이상 접촉) 배경 무리.
//                   단 가로로 넓고 얇은(폭≥높이×3) 무리는 의도된 슬릿이므로 남긴다
//  6. 그림자 제거  — 오브제 하단 22%의 세로로 얇은 가로 구조 + 고립된 작은 조각
//
// 이미지 IO는 macOS 내장 sips로 BMP를 오간다 — 의존성 없음.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';

// --manual: 손으로 그린 실루엣 레이어(png/MMDD_NN_sil.png)를 그대로 벡터화한다.
// 자동 모드의 휴리스틱(클로징·오프닝·웅덩이·그림자)은 전부 생략 — 그린 대로 믿는다.
// 어두운 칠 = 오브제, 안 칠한 곳(투명 포함) = 배경. 구멍도 그린 대로 뚫린다.
const args = process.argv.slice(2);
const manual = args[0] === '--manual';
const [inPng, outSvg] = manual ? args.slice(1) : args;
if (!inPng || !outSvg) { console.error('usage: node silhouette.mjs [--manual] in.png out.svg'); process.exit(1); }

const tmp = mkdtempSync(join(tmpdir(), 'sil-'));
try {
  const bmpIn = join(tmp, 'in.bmp');
  execFileSync('sips', ['-s', 'format', 'bmp', inPng, '--out', bmpIn], { stdio: 'ignore' });
  const buf = readFileSync(bmpIn);

  // --- BMP 읽기 (24/32bpp 무압축) ---
  const dataOff = buf.readUInt32LE(10);
  const w = buf.readInt32LE(18);
  let h = buf.readInt32LE(22);
  const bpp = buf.readUInt16LE(28) / 8;
  const bottomUp = h > 0; h = Math.abs(h);
  const stride = (w * bpp + 3) & ~3;
  const N = w * h;
  const lum = new Uint8Array(N);
  for (let y = 0; y < h; y++) {
    const row = dataOff + (bottomUp ? h - 1 - y : y) * stride;
    for (let x = 0; x < w; x++) {
      const o = row + x * bpp;
      let v = (buf[o] + buf[o + 1] + buf[o + 2]) / 3; // BGR 평균
      // 투명 배경(레이어 내보내기)은 흰 종이 위에 얹은 것으로 취급
      if (bpp === 4) { const a = buf[o + 3] / 255; v = v * a + 255 * (1 - a); }
      lum[y * w + x] = v;
    }
  }

  // --- 파라미터 (전부 크기 비례 — 브라우저 시절 240px 기준값을 스케일) ---
  const SIL_CUT = 215;                          // 이보다 밝으면 배경 후보
  const B = Math.max(2, Math.round(w / 120));   // 블러 반경
  const R = Math.max(2, Math.round(w / 120));   // 클로징 반경
  const E = Math.max(1, Math.round(w / 240));   // 오프닝 침식 깊이

  // --- 유틸 ---
  const stack = new Int32Array(N);
  const dilate = (mask, steps, allow) => {
    let front = [];
    for (let p = 0; p < N; p++) if (mask[p]) front.push(p);
    for (let s = 0; s < steps; s++) {
      const next = [];
      for (const p of front) {
        const x = p % w;
        const grow = q => { if (!mask[q] && (!allow || allow(q))) { mask[q] = 1; next.push(q); } };
        if (p >= w) grow(p - w);
        if (p < N - w) grow(p + w);
        if (x > 0) grow(p - 1);
        if (x < w - 1) grow(p + 1);
      }
      front = next;
    }
  };
  // 테두리에서 flood fill — pass(p)인 픽셀만 mark에 1로 채운다
  const floodBorder = (mark, pass) => {
    let sp = 0;
    const push = p => { if (!mark[p] && pass(p)) { mark[p] = 1; stack[sp++] = p; } };
    for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); }
    for (let y = 1; y < h - 1; y++) { push(y * w); push(y * w + w - 1); }
    while (sp) {
      const p = stack[--sp], x = p % w;
      if (p >= w) push(p - w);
      if (p < N - w) push(p + w);
      if (x > 0) push(p - 1);
      if (x < w - 1) push(p + 1);
    }
  };

  // --- 1. 어두움 판정 (블러는 running-sum 박스 블러, O(N)) ---
  const SPAN = 2 * B + 1;
  const tmpB = new Float32Array(N), blur = new Float32Array(N);
  for (let y = 0; y < h; y++) {
    let s = 0;
    for (let x = -B; x <= B; x++) s += lum[y * w + Math.min(w - 1, Math.max(0, x))];
    for (let x = 0; x < w; x++) {
      tmpB[y * w + x] = s / SPAN;
      s += lum[y * w + Math.min(w - 1, x + B + 1)] - lum[y * w + Math.max(0, x - B)];
    }
  }
  for (let x = 0; x < w; x++) {
    let s = 0;
    for (let y = -B; y <= B; y++) s += tmpB[Math.min(h - 1, Math.max(0, y)) * w + x];
    for (let y = 0; y < h; y++) {
      blur[y * w + x] = s / SPAN;
      s += tmpB[Math.min(h - 1, y + B + 1) * w + x] - tmpB[Math.max(0, y - B) * w + x];
    }
  }
  const dark = new Uint8Array(N);
  for (let p = 0; p < N; p++) if (lum[p] <= SIL_CUT || blur[p] <= SIL_CUT - 10) dark[p] = 1;

  const bg = new Uint8Array(N);
  if (manual) {
    // 수제: 칠한 곳이 곧 오브제. flood fill 불필요 — 안 칠한 안쪽은 구멍(의도)이다.
    for (let p = 0; p < N; p++) bg[p] = dark[p] ? 0 : 1;
  } else {
  // --- 2. 클로징 + flood fill ---
  const barrier = dark.slice();
  dilate(barrier, R);
  floodBorder(bg, p => !barrier[p]);
  dilate(bg, R, p => !dark[p]);   // 경계 복원 — 닫힌 틈은 R보다 길어 다시 안 뚫린다

  // --- 3. 오프닝: 배경을 E 침식해 실오라기 통로를 끊고, 테두리에 닿는 것만 진짜 배경 ---
  const core = bg.slice();
  for (let it = 0; it < E; it++) {
    const snap = core.slice();
    for (let p = 0; p < N; p++) if (snap[p]) {
      const x = p % w;
      // 이미지 가장자리 줄은 침식 제외 — 씨앗이 사라지면 전부 오브제가 돼버린다
      if (p >= w && p < N - w && x > 0 && x < w - 1 &&
          (!snap[p - w] || !snap[p + w] || !snap[p - 1] || !snap[p + 1])) core[p] = 0;
    }
  }
  const real = new Uint8Array(N);
  floodBorder(real, p => core[p]);
  dilate(real, E, p => bg[p]);
  bg.set(real);
  }

  // --- 4. 잔점 제거 ---
  const compScan = (isMember, onComp) => {
    const seen = new Uint8Array(N);
    for (let p0 = 0; p0 < N; p0++) {
      if (!isMember(p0) || seen[p0]) continue;
      const comp = [p0]; seen[p0] = 1;
      for (let i = 0; i < comp.length; i++) {
        const p = comp[i], x = p % w;
        const step = q => { if (isMember(q) && !seen[q]) { seen[q] = 1; comp.push(q); } };
        if (p >= w) step(p - w);
        if (p < N - w) step(p + w);
        if (x > 0) step(p - 1);
        if (x < w - 1) step(p + 1);
      }
      onComp(comp);
    }
  };
  compScan(p => !bg[p], comp => {
    if (comp.length < N / 2000) for (const p of comp) bg[p] = 1;
  });

  if (!manual) {
  // --- 5. 웅덩이 메꾸기 (방향 비트 + 둘레 접촉비 + 슬릿 모양 예외) ---
  const dirs = new Uint8Array(N);   // 비트: 1 왼쪽에 오브제, 2 오른쪽, 4 위, 8 아래
  for (let y = 0; y < h; y++) {
    let a = 0, b = 0;
    for (let x = 0; x < w; x++) {
      const p = y * w + x, r = y * w + (w - 1 - x);
      if (!bg[p]) a = 1; else dirs[p] |= a;
      if (!bg[r]) b = 1; else dirs[r] |= b << 1;
    }
  }
  for (let x = 0; x < w; x++) {
    let a = 0, b = 0;
    for (let y = 0; y < h; y++) {
      const p = y * w + x, r = (h - 1 - y) * w + x;
      if (!bg[p]) a = 1; else dirs[p] |= a << 2;
      if (!bg[r]) b = 1; else dirs[r] |= b << 3;
    }
  }
  const POP = [0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4];
  compScan(p => bg[p] && POP[dirs[p]] >= 3, comp => {
    if (comp.length >= N / 40) return;
    let obj = 0, open = 0, x0 = w, x1 = 0, y0 = h, y1 = 0;
    for (const p of comp) {
      const x = p % w, y = (p / w) | 0;
      if (x < x0) x0 = x; if (x > x1) x1 = x;
      if (y < y0) y0 = y; if (y > y1) y1 = y;
      const look = q => { if (!bg[q]) obj++; else if (POP[dirs[q]] < 3) open++; };
      if (p >= w) look(p - w);
      if (p < N - w) look(p + w);
      if (x > 0) look(p - 1);
      if (x < w - 1) look(p + 1);
    }
    const slitLike = x1 - x0 + 1 >= 3 * (y1 - y0 + 1);
    if (!slitLike && obj >= 2 * open) for (const p of comp) bg[p] = 0;
  });

  // --- 6. 그림자 제거 — **수렴할 때까지 반복** ---
  // 기준선 cutY(오브제 세로 범위의 하단 22%)는 그림자 자체를 포함해 계산되므로,
  // 맨 아래 지면 선이 maxY를 끌어내려 그 위의 그림자 혀가 기준선 위로 벗어난다.
  // 한 번 지우면 maxY가 올라오고 기준선도 따라 올라와 다음 패스가 마저 잡는다.
  // h/24로는 블러 판정이 부드러운 그림자 그라데이션에 붙인 두께를 못 넘는다.
  // 잘린 포트의 아랫동강·받침(h/10 이상)과 그림자 혀(h/16 이하) 사이 값.
  const THIN = Math.max(6, Math.round(h / 14));
  for (let pass = 0; pass < 3; pass++) {
    let minY = h, maxY = 0;
    for (let p = 0; p < N; p++) if (!bg[p]) { const y = (p / w) | 0;
      if (y < minY) minY = y; if (y > maxY) maxY = y; }
    const cutY = minY + 0.78 * (maxY - minY);
    let removed = 0;
    for (let x = 0; x < w; x++) {
      let y = 0;
      while (y < h) {
        if (bg[y * w + x]) { y++; continue; }
        let y2 = y;
        while (y2 < h && !bg[y2 * w + x]) y2++;
        if (y > cutY && y2 - y < THIN) {
          for (let yy = y; yy < y2; yy++) bg[yy * w + x] = 1;
          removed += y2 - y;
        }
        y = y2;
      }
    }
    compScan(p => !bg[p], comp => {
      let top = h;
      for (const p of comp) { const y = (p / w) | 0; if (y < top) top = y; }
      if (top > cutY && comp.length < N / 150) {
        for (const p of comp) bg[p] = 1;
        removed += comp.length;
      }
    });
    if (!removed) break;
  }
  }   // if (!manual) 끝 — 수제는 그린 대로 믿는다

  // --- 벡터화: 마스크 경계를 폴리곤으로 추출 → RDP 단순화 → SVG ---
  // 픽셀 경계선(오브제/배경 사이 단위 변)을 "오브제가 진행 방향 오른쪽" 규칙으로
  // 모아 고리로 잇는다. fill-rule=evenodd라 감김 방향은 상관없고, 구멍·슬릿도
  // 자동으로 뚫린다. RDP(ε=w/200)가 픽셀 계단을 지우고 곧은 변만 남긴다 —
  // 둥근 배는 0.5% 오차의 다각형(눈에 안 보임), 사각·삼각의 각은 그대로 산다.
  const W1 = w + 1;
  const nextOf = new Map();   // 시작 꼭짓점 → [끝 꼭짓점, ...]
  const addEdge = (a, b) => {
    const arr = nextOf.get(a);
    if (arr) arr.push(b); else nextOf.set(a, [b]);
  };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    if (bg[y * w + x]) continue;
    const p = y * w + x;
    if (y === 0 || bg[p - w]) addEdge(y * W1 + x, y * W1 + x + 1);             // 윗변 →
    if (y === h - 1 || bg[p + w]) addEdge((y + 1) * W1 + x + 1, (y + 1) * W1 + x); // 아랫변 ←
    if (x === 0 || bg[p - 1]) addEdge((y + 1) * W1 + x, y * W1 + x);           // 왼변 ↑
    if (x === w - 1 || bg[p + 1]) addEdge(y * W1 + x + 1, (y + 1) * W1 + x + 1); // 오른변 ↓
  }
  const loops = [];
  for (const [start] of nextOf) {
    while (nextOf.get(start)?.length) {
      const pts = [start];
      let cur = start;
      do {
        const outs = nextOf.get(cur);
        const nxt = outs.pop();
        if (!outs.length) nextOf.delete(cur);
        pts.push(nxt); cur = nxt;
      } while (cur !== start && nextOf.has(cur));
      if (cur === start) { pts.pop(); loops.push(pts); }
    }
  }
  // RDP — 닫힌 고리는 시작점에서 가장 먼 점으로 둘로 갈라 각각 단순화
  const px_ = p => p % W1, py_ = p => (p / W1) | 0;
  const rdp = pts => {
    const EPS = Math.max(2, w / 200);
    const keep = new Uint8Array(pts.length);
    keep[0] = keep[pts.length - 1] = 1;
    const st = [[0, pts.length - 1]];
    while (st.length) {
      const [i, j] = st.pop();
      const ax = px_(pts[i]), ay = py_(pts[i]), bx = px_(pts[j]), by = py_(pts[j]);
      const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy) || 1;
      let far = -1, fd = EPS;
      for (let k = i + 1; k < j; k++) {
        const d = Math.abs(dx * (py_(pts[k]) - ay) - dy * (px_(pts[k]) - ax)) / len;
        if (d > fd) { fd = d; far = k; }
      }
      if (far >= 0) { keep[far] = 1; st.push([i, far], [far, j]); }
    }
    return pts.filter((_, k) => keep[k]);
  };
  const paths = loops.map(pts => {
    let far = 0, fd = -1;
    const ax = px_(pts[0]), ay = py_(pts[0]);
    for (let k = 1; k < pts.length; k++) {
      const d = (px_(pts[k]) - ax) ** 2 + (py_(pts[k]) - ay) ** 2;
      if (d > fd) { fd = d; far = k; }
    }
    const a = rdp(pts.slice(0, far + 1));
    const b = rdp(pts.slice(far).concat(pts[0]));
    const ring = a.concat(b.slice(1, -1));
    return 'M' + ring.map(p => px_(p) + ' ' + py_(p)).join('L') + 'Z';
  });
  mkdirSync(dirname(outSvg), { recursive: true });
  writeFileSync(outSvg,
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}">` +
    `<rect width="100%" height="100%" fill="#fff"/>` +
    `<path d="${paths.join('')}" fill="#666" fill-rule="evenodd"/></svg>\n`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
