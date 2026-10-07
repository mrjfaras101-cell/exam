/* ==========================================================================
   Class Team Hub — app.js
   هذا الملف مسؤول عن قراءة بيانات الأعضاء وبناء بطاقات الصفحة.
   This file loads member data and renders the profile cards.
   يمكن للطلاب تحسينه كتحدٍّ إضافي (بحث، ترتيب، وضع ليلي…).
   ========================================================================== */

const DATA = {
  config: "data/site-config.json",
  index: "data/members-index.json",
  membersDir: "data/members/",
  bundle: "data/members-bundle.js", // نسخة مدمجة تعمل بدون خادم / works from file://
};

const state = { members: [], query: "", role: "all", config: {} };

/* ---------- Helpers ---------- */

async function fetchJSON(path) {
  const res = await fetch(path, { cache: "no-store" });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} — ${path}`);
  return res.json();
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = src;
    s.onload = resolve;
    s.onerror = () => reject(new Error("bundle-not-found"));
    document.head.appendChild(s);
  });
}

function initials(name) {
  return String(name || "?")
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0])
    .join("")
    .toUpperCase();
}

function esc(str) {
  return String(str ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}

/* ---------- Loading ---------- */

async function loadAll() {
  let bundle = null;
  try {
    // المسار المفضّل: ملفات JSON منفصلة (GitHub Pages / خادم محلي)
    const [config, index] = await Promise.all([
      fetchJSON(DATA.config).catch(() => ({})),
      fetchJSON(DATA.index),
    ]);
    const files = Array.isArray(index) ? index : index.files || [];
    const members = [];
    for (const entry of files) {
      const file = typeof entry === "string" ? entry : entry.file;
      try {
        members.push(await fetchJSON(DATA.membersDir + file));
      } catch (err) {
        console.warn("تعذّر قراءة بطاقة / cannot read card:", file, err.message);
      }
    }
    return { config, members };
  } catch (err) {
    console.info("fetch غير متاح (تشغيل محلي) — سيتم استخدام النسخة المدمجة.");
    try {
      await loadScript(DATA.bundle);
      bundle = window.MEMBERS_DATA;
    } catch (e) {
      throw new Error(
        "لم يتم العثور على بيانات الأعضاء. تأكد من وجود data/members-index.json وملفات البطاقات، " +
          "ثم شغّل: node tools/build-index.mjs"
      );
    }
    return { config: (bundle && bundle.config) || {}, members: (bundle && bundle.members) || [] };
  }
}

/* ---------- Rendering ---------- */

function cardHTML(m) {
  const link = `https://github.com/${encodeURIComponent(m.github)}`;
  const tags = (m.tags || [])
    .map((t) => `<span class="tag">${esc(t)}</span>`)
    .join("");
  return `
    <article class="card" role="listitem">
      <div class="card-head">
        <div class="avatar" aria-hidden="true">${esc(initials(m.fullName))}</div>
        <div>
          <h3>${esc(m.fullName)}</h3>
          <p class="uname"><a href="${link}" target="_blank" rel="noopener">@${esc(m.github)}</a></p>
        </div>
      </div>
      <span class="role">${esc(m.role)}</span>
      <p class="message">${esc(m.message)}</p>
      <div class="cmd" dir="ltr">${esc(m.favoriteCommand)}</div>
      ${tags ? `<div class="tags">${tags}</div>` : ""}
    </article>`;
}

function visibleMembers() {
  const q = state.query.trim().toLowerCase();
  return state.members.filter((m) => {
    const okRole = state.role === "all" || m.role === state.role;
    const hay = [m.fullName, m.github, m.role, m.message, ...(m.tags || [])]
      .join(" ")
      .toLowerCase();
    return okRole && (!q || hay.includes(q));
  });
}

function renderStats() {
  const total = state.members.length;
  const roles = new Set(state.members.map((m) => m.role)).size;
  const langs = new Set(state.members.flatMap((m) => m.tags || [])).size;
  document.getElementById("statsBar").innerHTML = `
    <div class="stat"><b>${total}</b><span>عضو في الفريق / members</span></div>
    <div class="stat"><b>${roles}</b><span>أدوار مختلفة / roles</span></div>
    <div class="stat"><b>${langs}</b><span>وسوم ومهارات / tags</span></div>`;
}

function renderFilters() {
  const roles = ["all", ...new Set(state.members.map((m) => m.role))];
  const box = document.getElementById("roleFilters");
  box.innerHTML = roles
    .map(
      (r) =>
        `<button class="chip" type="button" data-role="${esc(r)}" aria-pressed="${
          state.role === r
        }">${r === "all" ? "كل الأدوار / All" : esc(r)}</button>`
    )
    .join("");
  box.querySelectorAll("button").forEach((btn) =>
    btn.addEventListener("click", () => {
      state.role = btn.dataset.role;
      render();
    })
  );
}

function render() {
  const list = visibleMembers();
  document.getElementById("membersGrid").innerHTML = list.map(cardHTML).join("");
  document.getElementById("emptyState").hidden = list.length !== 0;
  renderFilters();
}

/* ---------- Init ---------- */

async function init() {
  const errBox = document.getElementById("errorState");
  try {
    const { config, members } = await loadAll();
    state.config = config || {};
    state.members = members.sort((a, b) =>
      String(a.github).localeCompare(String(b.github))
    );

    if (state.config.siteTitle) document.getElementById("siteTitle").textContent = state.config.siteTitle;
    if (state.config.subtitle) document.getElementById("siteSubtitle").textContent = state.config.subtitle;
    if (state.config.semester) document.getElementById("pillSemester").textContent = state.config.semester;
    if (state.config.instructor) document.getElementById("pillInstructor").textContent = "المدرب: " + state.config.instructor;
    document.getElementById("pillMembers").textContent = `${state.members.length} بطاقة`;
    document.getElementById("lastUpdated").textContent = new Date().toLocaleString("ar-EG");
    document.title = `${state.config.siteTitle || "دليل فريق الصف"} · Class Team Hub`;

    renderStats();
    render();

    document.getElementById("searchInput").addEventListener("input", (e) => {
      state.query = e.target.value;
      render();
    });
  } catch (err) {
    errBox.hidden = false;
    errBox.textContent = "خطأ في تحميل البيانات: " + err.message;
    console.error(err);
  }
}

document.addEventListener("DOMContentLoaded", init);
