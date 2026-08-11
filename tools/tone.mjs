// 하이라이트 톤 굽기: v>204(=0.8) 구간만 204~229로 절반 압축 — 예전 CSS dimWhite
// 필터와 동일한 커브를 썸네일 파일에 미리 적용한다. 흰 종이 배경만 가라앉고
// 도자기·그림자(≤204)는 그대로. 런타임 SVG 필터를 없애 스크롤 GPU 부담 제거.
// 사용: node tone.mjs a.jpg b.jpg ...   (제자리 덮어쓰기, JPEG q82)
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

for (const file of process.argv.slice(2)) {
  const tmp = mkdtempSync(join(tmpdir(), 'tone-'));
  try {
    const bmp = join(tmp, 'in.bmp');
    execFileSync('sips', ['-s', 'format', 'bmp', file, '--out', bmp], { stdio: 'ignore' });
    const buf = readFileSync(bmp);
    const dataOff = buf.readUInt32LE(10);
    // 픽셀 전 바이트에 커브 적용 — 행 패딩 바이트도 스치지만 무해하다
    for (let i = dataOff; i < buf.length; i++)
      if (buf[i] > 204) buf[i] = 204 + ((buf[i] - 204) >> 1);
    writeFileSync(bmp, buf);
    execFileSync('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '82',
      bmp, '--out', file], { stdio: 'ignore' });
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}
