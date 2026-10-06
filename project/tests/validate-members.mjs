#!/usr/bin/env node
/**
 * validate-members.mjs — فحص صحة بطاقات الأعضاء
 * ------------------------------------------------------------------
 * يتحقق من: الحقول الإلزامية، صيغة اسم المستخدم، طول الرسالة،
 * بداية الأمر المفضّل بـ git، تفرد أسماء المستخدمين، ومنع البيانات الحساسة.
 *
 * الاستخدام / Usage:  node tests/validate-members.mjs
 * المخرج / Exit code: 0 = ناجح، 1 = يوجد أخطاء
 */

import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MEMBERS_DIR = path.join(ROOT, "data", "members");
const INDEX_FILE = path.join(ROOT, "data", "members-index.json");

const REQUIRED = ["fullName", "github", "role", "favoriteCommand", "message"];
const ALLOWED_ROLES = ["مطوّر", "مصمّم", "مختبر QA", "كاتب توثيق", "قائد فريق"];
const USERNAME_RE = /^[a-z0-9](?:[a-z0-9]|-(?=[a-z0-9])){0,38}$/;
const FORBIDDEN = [/\b\d{7,15}\b/, /@[a-z0-9.-]+\.(com|net|org|edu|jo)\b/i, /password|passwd|token|secret/i];

let errors = 0;
let warnings = 0;
const seen = new Map();

const err = (file, msg) => { console.log(`  ✗ ${file}: ${msg}`); errors++; };
const warn = (file, msg) => { console.log(`  ⚠ ${file}: ${msg}`); warnings++; };

function validateCard(file, card) {
  for (const field of REQUIRED) {
    if (!card[field] || typeof card[field] !== "string" || !card[field].trim())
      err(file, `حقل مفقود أو فارغ / missing field: "${field}"`);
  }
  if (card.github && !USERNAME_RE.test(card.github))
    err(file, `اسم مستخدم غير صالح / invalid username: "${card.github}"`);
  if (card.role && !ALLOWED_ROLES.includes(card.role))
    warn(file, `دور غير معتاد / unusual role: "${card.role}" (المسموح: ${ALLOWED_ROLES.join(" / ")})`);
  if (card.favoriteCommand && !/^git\s/.test(card.favoriteCommand))
    err(file, 'الامر المفضل يجب ان يبدا بـ "git " / favoriteCommand must start with "git "');
  if (card.message && (card.message.trim().length < 10 || card.message.trim().length > 140))
    err(file, `طول الرسالة ${card.message.trim().length} — يجب أن يكون بين 10 و140 حرفاً`);
  if (card.tags && !Array.isArray(card.tags))
    err(file, "tags يجب أن تكون مصفوفة / tags must be an array");

  const raw = JSON.stringify(card);
  FORBIDDEN.forEach((re) => {
    if (re.test(raw)) err(file, `بيانات حساسة أو ممنوعة / sensitive data found (${re})`);
  });

  if (card.github) {
    const key = card.github.toLowerCase();
    if (seen.has(key)) err(file, `اسم مستخدم مكرر مع / duplicate username with: ${seen.get(key)}`);
    else seen.set(key, file);
  }

  // تطابق اسم الملف مع اسم المستخدم (شرط اختياري لكن يمنع التعارضات)
  if (card.github && file.replace(/^\d+-/, "") !== `${card.github}.json`)
    warn(file, `اسم الملف لا يطابق اسم المستخدم / filename does not match username (${card.github}.json)`);
}

async function main() {
  console.log("\n=== فحص بطاقات الأعضاء / Validating member cards ===\n");
  const files = (await readdir(MEMBERS_DIR)).filter(
    (f) => f.endsWith(".json") && !f.startsWith("00-")
  );

  if (files.length === 0) {
    console.log("  ! لا توجد بطاقات بعد / no member cards yet");
  }

  for (const file of files.sort()) {
    const card = JSON.parse(await readFile(path.join(MEMBERS_DIR, file), "utf8"));
    validateCard(file, card);
  }

  // فحص الفهرس
  try {
    const index = JSON.parse(await readFile(INDEX_FILE, "utf8"));
    const listed = new Set(index.files || []);
    for (const file of files) {
      if (!listed.has(file)) err("data/members-index.json", `البطاقة "${file}" غير مُفهرسة — شغّل: node tools/build-index.mjs`);
    }
    for (const file of listed) {
      if (!files.includes(file)) err("data/members-index.json", `الفهرس يشير إلى ملف غير موجود: "${file}"`);
    }
  } catch (e) {
    err("data/members-index.json", `تعذّر قراءة ملف JSON — ${e.message}`);
  }

  console.log(`\n--- النتيجة / Result: ${files.length} بطاقة، ${errors} خطأ، ${warnings} تحذير ---\n`);
  process.exit(errors ? 1 : 0);
}

main().catch((e) => { console.error("خطأ غير متوقع:", e); process.exit(1); });
