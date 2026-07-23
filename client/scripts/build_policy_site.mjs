#!/usr/bin/env node

import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "../..");
const outputDirectory = path.join(repositoryRoot, "deploy/policy-site");

const pages = [
  {
    source: "docs/privacy-policy.md",
    output: "privacy.html",
    title: "隐私政策",
    description: "妙记 AI 账本隐私政策，说明数据处理、云同步、语音记账及用户权利。",
  },
  {
    source: "docs/terms-of-service.md",
    output: "terms.html",
    title: "用户协议",
    description: "妙记 AI 账本用户协议。",
  },
  {
    source: "docs/support.md",
    output: "support.html",
    title: "支持",
    description: "妙记 AI 账本支持、问题反馈与账号删除说明。",
  },
];

function escapeHTML(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderInline(value) {
  const tokens = [];
  const reserve = (html) => {
    const token = `@@MIAOJI_TOKEN_${tokens.length}@@`;
    tokens.push([token, html]);
    return token;
  };

  let text = value.replace(/`([^`]+)`/g, (_, code) =>
    reserve(`<code>${escapeHTML(code)}</code>`),
  );

  text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
    const safeHref = escapeHTML(href.trim());
    const external = /^https?:\/\//.test(href.trim());
    const attributes = external ? ' target="_blank" rel="noreferrer"' : "";
    return reserve(`<a href="${safeHref}"${attributes}>${escapeHTML(label)}</a>`);
  });

  text = escapeHTML(text).replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  for (const [token, html] of tokens) {
    text = text.replaceAll(token, html);
  }
  return text;
}

function tableCells(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

function isTableDivider(line) {
  return tableCells(line).every((cell) => /^:?-{3,}:?$/.test(cell));
}

function renderMarkdown(markdown) {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const output = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index].trim();

    if (!line) {
      index += 1;
      continue;
    }

    if (line.startsWith("<!--")) {
      while (index < lines.length && !lines[index].includes("-->")) index += 1;
      index += 1;
      continue;
    }

    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading) {
      const level = heading[1].length;
      output.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
      index += 1;
      continue;
    }

    if (
      index + 1 < lines.length &&
      line.includes("|") &&
      isTableDivider(lines[index + 1])
    ) {
      const headers = tableCells(line);
      index += 2;
      const rows = [];
      while (index < lines.length && lines[index].trim().includes("|")) {
        rows.push(tableCells(lines[index]));
        index += 1;
      }
      output.push(
        `<div class="table-wrap"><table><thead><tr>${headers
          .map((cell) => `<th scope="col">${renderInline(cell)}</th>`)
          .join("")}</tr></thead><tbody>${rows
          .map(
            (row) =>
              `<tr>${row.map((cell) => `<td>${renderInline(cell)}</td>`).join("")}</tr>`,
          )
          .join("")}</tbody></table></div>`,
      );
      continue;
    }

    if (/^-\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^-\s+/.test(lines[index].trim())) {
        items.push(lines[index].trim().replace(/^-\s+/, ""));
        index += 1;
      }
      output.push(`<ul>${items.map((item) => `<li>${renderInline(item)}</li>`).join("")}</ul>`);
      continue;
    }

    if (/^\d+\.\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^\d+\.\s+/.test(lines[index].trim())) {
        items.push(lines[index].trim().replace(/^\d+\.\s+/, ""));
        index += 1;
      }
      output.push(`<ol>${items.map((item) => `<li>${renderInline(item)}</li>`).join("")}</ol>`);
      continue;
    }

    if (line.startsWith(">")) {
      const quote = [];
      while (index < lines.length && lines[index].trim().startsWith(">")) {
        quote.push(lines[index].trim().replace(/^>\s?/, ""));
        index += 1;
      }
      output.push(`<blockquote>${renderInline(quote.join(" "))}</blockquote>`);
      continue;
    }

    if (/^(更新日期|生效日期)：/.test(line)) {
      const metadata = [];
      while (index < lines.length && /^(更新日期|生效日期)：/.test(lines[index].trim())) {
        metadata.push(`<span>${renderInline(lines[index].trim())}</span>`);
        index += 1;
      }
      output.push(`<p class="document-meta">${metadata.join("")}</p>`);
      continue;
    }

    const paragraph = [line];
    index += 1;
    while (index < lines.length) {
      const next = lines[index].trim();
      if (
        !next ||
        /^(#{1,6})\s+/.test(next) ||
        /^-\s+/.test(next) ||
        /^\d+\.\s+/.test(next) ||
        next.startsWith(">") ||
        next.startsWith("<!--") ||
        (next.includes("|") && index + 1 < lines.length && isTableDivider(lines[index + 1]))
      ) {
        break;
      }
      paragraph.push(next);
      index += 1;
    }
    output.push(`<p>${renderInline(paragraph.join(" "))}</p>`);
  }

  return output.join("\n");
}

function layout({ title, description, body, currentPath }) {
  const navItems = [
    ["/privacy", "隐私政策"],
    ["/terms", "用户协议"],
    ["/support", "支持"],
  ];

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHTML(description)}">
  <meta name="theme-color" content="#111827">
  <link rel="canonical" href="https://miaoji.joy-coder.com${currentPath}">
  <link rel="stylesheet" href="/styles.css">
  <title>${escapeHTML(title)}｜妙记 AI 账本</title>
</head>
<body>
  <a class="skip-link" href="#main">跳到正文</a>
  <header class="site-header">
    <div class="header-inner">
      <a class="brand" href="/" aria-label="妙记 AI 账本首页">
        <span class="brand-mark" aria-hidden="true">妙</span>
        <span><strong>妙记</strong><small>AI 账本</small></span>
      </a>
      <nav aria-label="政策页面">
        ${navItems
          .map(
            ([href, label]) =>
              `<a href="${href}"${currentPath === href ? ' aria-current="page"' : ""}>${label}</a>`,
          )
          .join("\n        ")}
      </nav>
    </div>
  </header>
  <main id="main" class="document-shell">
    <article class="document">${body}</article>
  </main>
  <footer>
    <p>© 2026 妙记 AI 账本 · <a href="mailto:zdjoey@126.com">zdjoey@126.com</a></p>
    <!-- 备案通过后在此加入备案号及 https://beian.miit.gov.cn/ 链接。 -->
  </footer>
</body>
</html>
`;
}

const indexHTML = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="妙记 AI 账本官方政策与支持页面。">
  <meta name="theme-color" content="#111827">
  <link rel="canonical" href="https://miaoji.joy-coder.com/">
  <link rel="stylesheet" href="/styles.css">
  <title>妙记 AI 账本｜政策与支持</title>
</head>
<body>
  <a class="skip-link" href="#main">跳到正文</a>
  <header class="site-header">
    <div class="header-inner">
      <a class="brand" href="/" aria-label="妙记 AI 账本首页">
        <span class="brand-mark" aria-hidden="true">妙</span>
        <span><strong>妙记</strong><small>AI 账本</small></span>
      </a>
      <nav aria-label="政策页面">
        <a href="/privacy">隐私政策</a>
        <a href="/terms">用户协议</a>
        <a href="/support">支持</a>
      </nav>
    </div>
  </header>
  <main id="main" class="home-shell">
    <section class="hero">
      <p class="eyebrow">本地优先 · 由你掌控</p>
      <h1>妙记 AI 账本</h1>
      <p>查看妙记的数据处理说明、服务条款和支持方式。</p>
    </section>
    <section class="link-grid" aria-label="政策与支持">
      <a class="link-card" href="/privacy"><span>01</span><h2>隐私政策</h2><p>了解账本、邮箱、录音和云同步数据如何被处理。</p><strong>查看政策 →</strong></a>
      <a class="link-card" href="/terms"><span>02</span><h2>用户协议</h2><p>了解服务范围、账号规则和双方权利义务。</p><strong>查看协议 →</strong></a>
      <a class="link-card" href="/support"><span>03</span><h2>支持</h2><p>获取问题反馈方式以及账号删除说明。</p><strong>获取帮助 →</strong></a>
    </section>
  </main>
  <footer>
    <p>© 2026 妙记 AI 账本 · <a href="mailto:zdjoey@126.com">zdjoey@126.com</a></p>
    <!-- 备案通过后在此加入备案号及 https://beian.miit.gov.cn/ 链接。 -->
  </footer>
</body>
</html>
`;

const styles = `:root {
  color-scheme: light;
  --ink: #111827;
  --muted: #5f6876;
  --line: #e5e7eb;
  --paper: #ffffff;
  --canvas: #f5f6f8;
  --accent: #e87a45;
  --accent-soft: #fff2eb;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", "Microsoft YaHei", sans-serif;
}

* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body { margin: 0; color: var(--ink); background: var(--canvas); line-height: 1.75; }
a { color: #b84c1e; text-underline-offset: 0.2em; }
a:hover { color: #8c3513; }
.skip-link { position: fixed; left: 1rem; top: -5rem; z-index: 20; padding: .6rem 1rem; color: white; background: var(--ink); border-radius: .5rem; }
.skip-link:focus { top: 1rem; }
.site-header { position: sticky; top: 0; z-index: 10; border-bottom: 1px solid rgba(229,231,235,.9); background: rgba(255,255,255,.94); backdrop-filter: blur(12px); }
.header-inner { max-width: 1080px; margin: 0 auto; min-height: 72px; padding: 0 24px; display: flex; align-items: center; justify-content: space-between; gap: 24px; }
.brand { display: inline-flex; align-items: center; gap: 10px; color: var(--ink); text-decoration: none; }
.brand-mark { width: 38px; height: 38px; display: grid; place-items: center; color: white; background: var(--ink); border-radius: 12px; font-weight: 800; }
.brand strong, .brand small { display: block; line-height: 1.25; }
.brand small { color: var(--muted); font-size: 11px; letter-spacing: .12em; text-transform: uppercase; }
nav { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 8px; }
nav a { padding: 7px 10px; color: var(--muted); border-radius: 8px; text-decoration: none; font-size: 14px; }
nav a:hover, nav a[aria-current="page"] { color: var(--ink); background: var(--accent-soft); }
.home-shell, .document-shell { max-width: 1080px; margin: 0 auto; padding: 64px 24px 80px; }
.hero { max-width: 760px; padding: 28px 0 48px; }
.eyebrow { margin: 0 0 10px; color: var(--accent); font-size: 13px; font-weight: 750; letter-spacing: .14em; }
.hero h1 { margin: 0; font-size: clamp(42px, 8vw, 76px); line-height: 1.06; letter-spacing: -.045em; }
.hero > p:last-child { max-width: 620px; margin: 20px 0 0; color: var(--muted); font-size: clamp(18px, 2.4vw, 22px); }
.link-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; }
.link-card { min-height: 270px; padding: 28px; display: flex; flex-direction: column; color: var(--ink); background: var(--paper); border: 1px solid var(--line); border-radius: 20px; text-decoration: none; box-shadow: 0 12px 36px rgba(17,24,39,.05); transition: transform .18s ease, box-shadow .18s ease; }
.link-card:hover { color: var(--ink); transform: translateY(-3px); box-shadow: 0 18px 44px rgba(17,24,39,.1); }
.link-card > span { color: var(--accent); font-size: 13px; font-weight: 800; }
.link-card h2 { margin: 30px 0 8px; font-size: 25px; }
.link-card p { margin: 0 0 24px; color: var(--muted); }
.link-card strong { margin-top: auto; color: #b84c1e; font-size: 14px; }
.document { max-width: 900px; margin: 0 auto; padding: clamp(28px, 5vw, 64px); background: var(--paper); border: 1px solid var(--line); border-radius: 22px; box-shadow: 0 18px 50px rgba(17,24,39,.06); }
.document h1 { margin: 0 0 8px; font-size: clamp(34px, 6vw, 52px); line-height: 1.15; letter-spacing: -.035em; }
.document h2 { margin: 2.2em 0 .65em; padding-top: .35em; border-top: 1px solid var(--line); font-size: clamp(23px, 4vw, 30px); line-height: 1.35; }
.document p { margin: 1em 0; }
.document-meta { display: flex; flex-wrap: wrap; gap: 8px 24px; margin: 0 0 2rem !important; color: var(--muted); font-size: 14px; }
.document ul, .document ol { padding-left: 1.35em; }
.document li + li { margin-top: .45em; }
.document code { padding: .12em .35em; background: #f1f3f5; border-radius: 5px; font-size: .92em; }
blockquote { margin: 1.5rem 0; padding: 1rem 1.2rem; color: #4b5563; background: var(--accent-soft); border-left: 4px solid var(--accent); border-radius: 0 10px 10px 0; }
.table-wrap { margin: 1.5rem 0; overflow-x: auto; border: 1px solid var(--line); border-radius: 12px; }
table { width: 100%; min-width: 720px; border-collapse: collapse; font-size: 14px; line-height: 1.55; }
th, td { padding: 13px 14px; text-align: left; vertical-align: top; border-bottom: 1px solid var(--line); }
th { background: #f7f8fa; font-weight: 750; }
tr:last-child td { border-bottom: 0; }
footer { padding: 28px 24px 44px; color: var(--muted); text-align: center; font-size: 13px; }
footer p { margin: 0; }

@media (max-width: 760px) {
  .header-inner { min-height: auto; padding-top: 13px; padding-bottom: 13px; align-items: flex-start; flex-direction: column; gap: 10px; }
  nav { width: 100%; justify-content: flex-start; overflow-x: auto; flex-wrap: nowrap; }
  nav a { white-space: nowrap; }
  .home-shell, .document-shell { padding: 36px 14px 56px; }
  .hero { padding: 18px 8px 34px; }
  .link-grid { grid-template-columns: 1fr; }
  .link-card { min-height: 220px; }
  .document { padding: 26px 20px 38px; border-radius: 16px; }
}

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  .link-card { transition: none; }
}
`;

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(outputDirectory, { recursive: true });
await writeFile(path.join(outputDirectory, "index.html"), indexHTML);
await writeFile(path.join(outputDirectory, "styles.css"), styles);

for (const page of pages) {
  const markdown = await readFile(path.join(repositoryRoot, page.source), "utf8");
  const currentPath = `/${path.basename(page.output, ".html")}`;
  const html = layout({
    title: page.title,
    description: page.description,
    body: renderMarkdown(markdown),
    currentPath,
  });
  await writeFile(path.join(outputDirectory, page.output), html);
}

await writeFile(
  path.join(outputDirectory, "robots.txt"),
  "User-agent: *\nAllow: /\nSitemap: https://miaoji.joy-coder.com/sitemap.xml\n",
);

await writeFile(
  path.join(outputDirectory, "sitemap.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://miaoji.joy-coder.com/</loc></url>
  <url><loc>https://miaoji.joy-coder.com/privacy</loc></url>
  <url><loc>https://miaoji.joy-coder.com/terms</loc></url>
  <url><loc>https://miaoji.joy-coder.com/support</loc></url>
</urlset>
`,
);

console.log(`Policy site generated at ${outputDirectory}`);
