#!/usr/bin/env node
/**
 * ci-local.mjs — شغّل نفس فحوص GitHub Actions على جهازك قبل الرفع
 * ci-local.mjs — run the exact CI checks locally before you push.
 *
 * الاستخدام / Usage:   node tools/ci-local.mjs
 * الناتج  / Output:    جدول ✔/✘ لكل فحص، والخروج بكود 1 عند أي فشل.
 */

import { execSync } from "node:child_process";

const STEPS = [
  {
    name: "الفهرس مُحدَّث / index up to date",
    cmd: "node tools/build-index.mjs --check",
    hint: "شغّل: node tools/build-index.mjs ثم أعد الالتزام",
  },
  {
    name: "بطاقات الأعضاء صحيحة / member cards valid",
    cmd: "node tests/validate-members.mjs",
    hint: "اصلح السطور التي تبدأ بـ ✘ في المخرجات أعلاه",
  },
  {
    name: "لا علامات تعارض / no conflict markers",
    // علامات التعارض تبدأ بسبعة رموز متطابقة ثم مسافة واسم (HEAD أو اسم الفرع)
    // Conflict markers: seven identical chars, optionally followed by a ref name.
    // grep يُرجع 1 عند عدم العثور على شيء — وهو النجاح هنا
    cmd: "grep -rInE '^(<{7}|={7}|>{7})( |$)' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=_work . && exit 1 || exit 0",
    hint: "ابحث عن <<<<<<< واحذف العلامات واترك النتيجة الصحيحة",
  },
];

console.log("\n=== فحص محلي يشبه GitHub Actions / Local CI simulation ===\n");

const results = [];
for (const step of STEPS) {
  process.stdout.write(`▸ ${step.name} … `);
  try {
    const out = execSync(step.cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    results.push({ ...step, ok: true });
    console.log("✔ نجح");
    if (out.trim()) console.log(out.trim().split("\n").map((l) => "    " + l).join("\n"));
  } catch (err) {
    results.push({ ...step, ok: false });
    console.log("✘ فشل");
    const out = (err.stdout || "") + (err.stderr || "");
    if (out.trim()) console.log(out.trim().split("\n").map((l) => "    " + l).join("\n"));
    console.log(`    ↳ الحل المقترح: ${step.hint}`);
  }
}

const failed = results.filter((r) => !r.ok);
console.log("\n" + "─".repeat(60));
if (failed.length === 0) {
  console.log("✔ كل الفحوص نجحت — آمن للرفع (git push) / All checks passed.");
  console.log("─".repeat(60) + "\n");
  process.exit(0);
}
console.log(`✘ ${failed.length} من ${results.length} فحص فشل — لا ترفع قبل الإصلاح.`);
console.log("─".repeat(60) + "\n");
process.exit(1);
