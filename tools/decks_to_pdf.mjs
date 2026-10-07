// decks_to_pdf.mjs — طبع عروض الجلسات (HTML) إلى PDF بمقاس الشريحة 16:9
// ============================================================================
// الاستخدام (من مجلد _work/build حيث node_modules):
//   node decks_to_pdf.mjs [--out DIR] <deck1.html> [deck2.html ...]
// لكل ملف: <اسم الملف>.pdf في DIR (أو بجوار الملف إن لم يُحدَّد)، صفحة لكل شريحة.
//
// يعتمد على CSS الطباعة في العروض (@page{size:338mm 190mm;margin:0})
// مع preferCSSPageSize حتى يحترم Chromium مقاس الصفحة المُعرَّف في الشريحة.

import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
let outDir = null;
const files = [];
for (let i = 0; i < argv.length; i += 1) {
  if (argv[i] === '--out') outDir = argv[++i];
  else files.push(argv[i]);
}
if (!files.length) {
  console.error('لا ملفات. الاستخدام: node decks_to_pdf.mjs [--out DIR] deck.html [...]');
  process.exit(2);
}
if (outDir) fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  args: [...chromium.args, '--no-sandbox', '--disable-setuid-sandbox', '--font-render-hinting=none'],
  executablePath: await chromium.executablePath(),
  headless: true,
});

for (const f of files) {
  const abs = path.resolve(f);
  const pdf = outDir
    ? path.join(outDir, path.basename(abs).replace(/\.html$/, '.pdf'))
    : abs.replace(/\.html$/, '.pdf');
  const page = await browser.newPage();
  await page.goto('file://' + abs, { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  // أوقف التكبير/التصغير الخاص بالعرض الحيّ حتى تُطبع الشرائح بمقاسها الأصلي
  await page.evaluate(() => {
    document.querySelectorAll('.slide').forEach((el) => (el.style.transform = 'none'));
    const nav = document.querySelector('nav');
    if (nav) nav.style.display = 'none';
  });
  await new Promise((r) => setTimeout(r, 150));
  await page.pdf({
    path: pdf,
    printBackground: true,
    preferCSSPageSize: true,
    margin: { top: 0, right: 0, bottom: 0, left: 0 },
  });
  await page.close();
  console.log('PDF ✓', path.relative(process.cwd(), pdf));
}

await browser.close();
