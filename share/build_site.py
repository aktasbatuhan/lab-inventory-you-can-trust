"""Build the shareable website in site/ from the console, the deck and the data.

    python3 share/build_site.py && cd site && vercel deploy --prod

site/
  index.html          landing page
  review/             the review console and its data
  deck/               a static viewer for the presentation slides
  api/view.js         logs each view (and each slide shown) to the Vercel logs
  vercel.json         clean URLs, no search indexing
"""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
FONTS = '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600&family=Geist+Mono:wght@400;500&display=swap">'


def tracking(page):
    return f"""<script defer src="/_vercel/insights/script.js"></script>
<script>
window.trackView = function (extra) {{
  try {{
    var body = JSON.stringify(Object.assign({{ page: "{page}", path: location.pathname + location.hash, referrer: document.referrer || null, screen: innerWidth + "x" + innerHeight }}, extra || {{}}));
    if (!(navigator.sendBeacon && navigator.sendBeacon("/api/view", new Blob([body], {{ type: "application/json" }}))))
      fetch("/api/view", {{ method: "POST", body: body, headers: {{ "content-type": "application/json" }}, keepalive: true }});
  }} catch (e) {{}}
}};
window.trackView();
</script>"""


def head(title, page, extra=""):
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<title>{title}</title>
{FONTS}
{extra}
{tracking(page)}
</head>
"""


def build_review():
    out = SITE / "review"
    (out / "data").mkdir(parents=True)
    src = (ROOT / "share/console/index.html").read_text()
    title = re.search(r"<title>(.*?)</title>", src).group(1)
    body = re.sub(r"<title>.*?</title>\n?", "", src)
    body = re.sub(r'<meta name="claude:[^>]*>\n?', "", body)
    body = re.sub(r"<link [^>]*>\n?", "", body)
    # /review is served without a trailing slash, so relative data paths would miss.
    body = body.replace("fetch(`data/${name}.json`)", "fetch(`/review/data/${name}.json`)")
    assert "/review/data/" in body
    reset = "<style>:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>"
    (out / "index.html").write_text(head(title, "review", reset) + "<body>\n" + body + "\n</body>\n</html>\n")
    for f in ("tests.json", "scenarios.json", "sim.json", "schema.json", "principles.json"):
        shutil.copy(ROOT / "share/data" / f, out / "data" / f)


def build_deck():
    out = SITE / "deck"
    (out / "img").mkdir(parents=True)
    shutil.copy(ROOT / "share/deck/img/swimlanes.png", out / "img/swimlanes.png")
    deck = json.loads((ROOT / "share/deck/project/deck.json").read_text())
    slides = []
    for sid in deck["order"]:
        html = (ROOT / "share/deck/project/slides" / f"{sid}.html").read_text().strip()
        html = re.sub(r"/_blob/[0-9a-f]{32}", "/deck/img/swimlanes.png", html)
        # Speaker notes stay private (they live in the meeting brief), never in the public deck.
        html = re.sub(r"\s*<aside>.*?</aside>", "", html, flags=re.S)
        assert "<aside" not in html
        slides.append(html)
    css = """<style>
:root { color-scheme: light; --ink: #142933; --muted: #546874; --line: #e1e8ed; }
html, body { margin: 0; height: 100%; background: #0d1c24; overflow: hidden; font-family: "Geist", Arial, sans-serif; }
.stage { position: fixed; inset: 0; display: grid; place-items: center; }
.frame { position: absolute; left: 50%; top: 50%; width: 1920px; height: 1080px; transform-origin: center center; }
section { position: absolute; inset: 0; width: 1920px; height: 1080px; box-sizing: border-box; overflow: hidden; opacity: 0; visibility: hidden; transition: opacity .25s ease; }
section.on { opacity: 1; visibility: visible; }
section * { box-sizing: border-box; margin: 0; }
section h1 { font-size: 96px; font-weight: 600; line-height: 1.1; }
section h2 { font-size: 64px; font-weight: 600; line-height: 1.15; }
section h3 { font-size: 44px; font-weight: 600; line-height: 1.2; }
section p { font-size: 32px; line-height: 1.4; }
section ul, section ol { padding-left: 1.2em; }
section table { border-collapse: collapse; width: 100%; }
section th, section td { padding: 0.35em 0.6em; text-align: left; vertical-align: top; border-bottom: 1px solid #e1e8ed; }
section th { font-weight: 600; color: #4f6470; }
section img { display: block; }
x-shape { display: block; flex: none; }
x-shape[kind="arrow-right"] { clip-path: polygon(0 32%, 60% 32%, 60% 0, 100% 50%, 60% 100%, 60% 68%, 0 68%); }
x-shape[kind="arrow-left"] { clip-path: polygon(100% 32%, 40% 32%, 40% 0, 0 50%, 40% 100%, 40% 68%, 100% 68%); }
.bar { position: fixed; left: 0; right: 0; bottom: 0; display: flex; align-items: center; gap: 12px; padding: 10px max(16px, env(safe-area-inset-left, 0px)) calc(10px + env(safe-area-inset-bottom, 0px)); color: #b9ccd6; font: 13px "Geist", Arial, sans-serif; background: linear-gradient(transparent, rgb(13 28 36 / 0.9)); opacity: 0; transition: opacity .2s; }
body:hover .bar, .bar:focus-within { opacity: 1; }
.bar button { font: inherit; color: #f2f6f8; background: rgb(255 255 255 / 0.08); border: 1px solid rgb(255 255 255 / 0.15); border-radius: 999px; padding: 6px 14px; cursor: pointer; }
.bar .count { font-family: "Geist Mono", monospace; }
.bar .by { margin-left: auto; }
</style>"""
    body = f"""<body>
<div class="stage"><div class="frame" id="frame">
{chr(10).join(slides)}
</div></div>
<div class="bar">
  <button id="prev" aria-label="Previous slide">Previous</button>
  <button id="next" aria-label="Next slide">Next</button>
  <span class="count" id="count"></span>
  <span class="by">Take-home by Batuhan Aktas for Adaptyv Bio</span>
</div>
<script>
(function () {{
  var slides = Array.prototype.slice.call(document.querySelectorAll("#frame > section"));
  var frame = document.getElementById("frame");
  var i = Math.max(0, Math.min(slides.length - 1, (parseInt(location.hash.slice(1), 10) || 1) - 1));
  var seen = {{}};
  function fit() {{ var s = Math.min(innerWidth / 1920, innerHeight / 1080); frame.style.transform = "translate(-50%, -50%) scale(" + s + ")"; }}
  function show(n) {{
    i = Math.max(0, Math.min(slides.length - 1, n));
    slides.forEach(function (s, k) {{ s.classList.toggle("on", k === i); }});
    document.getElementById("count").textContent = (i + 1) + " / " + slides.length;
    try {{ history.replaceState(null, "", "#" + (i + 1)); }} catch (e) {{}}
    if (!seen[i]) {{ seen[i] = 1; window.trackView && window.trackView({{ slide: i + 1, slide_id: slides[i].id }}); }}
  }}
  document.getElementById("prev").onclick = function () {{ show(i - 1); }};
  document.getElementById("next").onclick = function () {{ show(i + 1); }};
  addEventListener("keydown", function (e) {{
    if (["ArrowRight", "PageDown", " ", "Enter"].indexOf(e.key) >= 0) {{ e.preventDefault(); show(i + 1); }}
    else if (["ArrowLeft", "PageUp", "Backspace"].indexOf(e.key) >= 0) {{ e.preventDefault(); show(i - 1); }}
    else if (e.key === "Home") show(0); else if (e.key === "End") show(slides.length - 1);
  }});
  var x0 = null;
  addEventListener("touchstart", function (e) {{ x0 = e.touches[0].clientX; }}, {{ passive: true }});
  addEventListener("touchend", function (e) {{ if (x0 === null) return; var dx = e.changedTouches[0].clientX - x0; if (Math.abs(dx) > 40) show(i + (dx < 0 ? 1 : -1)); x0 = null; }});
  addEventListener("resize", fit); fit(); show(i);
}})();
</script>
</body>
</html>
"""
    (out / "index.html").write_text(head(deck["title"], "deck", css) + body)


def build_index():
    css = """<style>
:root { color-scheme: light; --paper: #fafbfd; --sheet: #ffffff; --ink: #142933; --muted: #546874; --line: #e1e8ed; --soft: #e9f2f7; --accent: #2091c9; }
@media (prefers-color-scheme: dark) { :root { color-scheme: dark; --paper: #0d1c24; --sheet: #142933; --ink: #eaf1f5; --muted: #93a8b4; --line: #25414f; --soft: #183a4b; --accent: #36b7f6; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--paper); color: var(--ink); font: 16px/1.55 "Geist", Arial, sans-serif; -webkit-font-smoothing: antialiased; }
main { max-width: 980px; margin: 0 auto; padding-block: 72px 64px; padding-left: max(20px, env(safe-area-inset-left, 0px)); padding-right: max(20px, env(safe-area-inset-right, 0px)); display: grid; gap: 28px; }
h1 { font-weight: 500; font-size: clamp(36px, 6vw, 60px); line-height: 1.05; letter-spacing: -0.05em; margin: 0; text-wrap: balance; }
.lede { font-size: 19px; color: var(--muted); max-width: 64ch; margin: 0; }
.cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 16px; }
a.card { display: grid; gap: 8px; padding: 24px; border-radius: 16px; background: var(--sheet); border: 1px solid var(--line); color: inherit; text-decoration: none; transition: border-color .15s; }
a.card:hover, a.card:focus-visible { border-color: var(--accent); outline: none; }
a.card h2 { margin: 0; font-weight: 500; font-size: 24px; letter-spacing: -0.03em; }
a.card p { margin: 0; color: var(--muted); }
a.card span { color: var(--accent); font-weight: 500; }
.by { color: var(--muted); font-size: 14px; }
</style>"""
    body = """<body><main>
<p class="by">Take-home by Batuhan Aktas for Adaptyv Bio</p>
<h1>Lab inventory you can trust</h1>
<p class="lede">A data model where every number can explain where it came from. Facts and rules go in; how much is left, what is usable and why not, where things are and what a bad batch touched are all worked out when someone asks.</p>
<div class="cards">
  <a class="card" href="/deck"><h2>The presentation</h2><p>How the work was done and the decisions that carry it. Arrow keys or swipe to move.</p><span>Open the slides</span></a>
  <a class="card" href="/review"><h2>The review console</h2><p>Every scenario test as a timeline, both simulations as pictures, and all 244 scenarios.</p><span>Open the console</span></a>
  <a class="card" href="https://github.com/aktasbatuhan/lab-inventory-you-can-trust"><h2>The code</h2><p>Schema, tests, queries, simulations and a day-by-day journal of how it was built. Open source.</p><span>Open on GitHub</span></a>
</div>
</main></body></html>
"""
    (SITE / "index.html").write_text(head("Lab Inventory You Can Trust", "home", css) + body)


def build_api():
    (SITE / "api").mkdir()
    (SITE / "api/view.js").write_text("""// Logs each page view and each slide shown. Read them under Logs in the Vercel
// project (filter on "view"). No cookies, and no IP address is kept.
export default async function handler(req, res) {
  if (req.method !== "POST") { res.status(405).end(); return; }
  let data = req.body;
  if (typeof data === "string") { try { data = JSON.parse(data); } catch { data = {}; } }
  data = data || {};
  const h = req.headers;
  const clean = (v, n = 200) => (typeof v === "string" ? v.slice(0, n) : v ?? null);
  console.log(JSON.stringify({
    view: true,
    at: new Date().toISOString(),
    page: clean(data.page, 40),
    slide: Number.isInteger(data.slide) ? data.slide : null,
    slide_id: clean(data.slide_id, 60),
    path: clean(data.path),
    referrer: clean(data.referrer),
    screen: clean(data.screen, 20),
    country: h["x-vercel-ip-country"] || null,
    city: h["x-vercel-ip-city"] ? decodeURIComponent(h["x-vercel-ip-city"]) : null,
    agent: clean(h["user-agent"], 160),
  }));
  res.status(204).end();
}
""")
    (SITE / "package.json").write_text(json.dumps({"name": "lab-inventory-review", "private": True, "type": "module"}, indent=2) + "\n")
    (SITE / "vercel.json").write_text(json.dumps({
        "cleanUrls": True,
        "headers": [{"source": "/(.*)", "headers": [{"key": "X-Robots-Tag", "value": "noindex, nofollow"}]}],
    }, indent=2) + "\n")


def main():
    keep = SITE / ".vercel"
    saved = None
    if keep.exists():
        saved = SITE.parent / ".vercel-keep"
        shutil.rmtree(saved, ignore_errors=True)
        shutil.move(str(keep), str(saved))
    shutil.rmtree(SITE, ignore_errors=True)
    SITE.mkdir()
    if saved:
        shutil.move(str(saved), str(keep))
    build_index()
    build_review()
    build_deck()
    build_api()
    print("built", sum(1 for _ in SITE.rglob("*") if _.is_file()), "files in site/")


if __name__ == "__main__":
    main()
