/**
 * rasterize.mjs — تحويل رسومات SVG إلى PNG عالي الدقة لتضمينها في ملفات Word.
 * Rasterises SVG diagrams to high-resolution PNGs so they can be embedded in DOCX.
 *
 * الاستخدام / Usage:  node tools/rasterize.mjs <outDir> <svg1> <svg2> ...
 */
import fs from 'node:fs';
import path from 'node:path';
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';

const [outDir, ...svgs] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  args: [...chromium.args, '--no-sandbox', '--disable-setuid-sandbox'],
  executablePath: await chromium.executablePath(),
  headless: true,
});

for (const svg of svgs) {
  const raw = fs.readFileSync(svg, 'utf8');
  // نجعل الرسومات بلا شفافية مع خلفية بيضاء نظيفة للطباعة
  const html = raw.replace(
    /(<svg[^>]*>)/,
    '$1<rect width="100%" height="100%" fill="#ffffff"/>'
  );
  const page = await browser.newPage();
  await page.setViewport({ width: 1400, height: 600, deviceScaleFactor: 3 });
  await page.setContent(html, { waitUntil: 'load' });
  await new Promise((r) => setTimeout(r, 120));
  const el = await page.$('svg');
  const out = path.join(outDir, path.basename(svg).replace(/\.svg$/, '.png'));
  await el.screenshot({ path: out, omitBackground: false });
  await page.close();
  console.log('PNG v', out);
}
await browser.close();
