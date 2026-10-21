# Adaptyv Bio visual brand

Collected 2026-10-21 from public HTML and CSS. No logos or images were copied.

Sources:
- [A] https://www.adaptyvbio.com, CSS at /_next/static/immutable/chunks/2idc1q5emipr5.css
- [B] https://www.adaptyvbio.com/blog (uses the same CSS as A)
- [C] https://docs.adaptyvbio.com (Mintlify, "mint" theme)
- [D] https://foundry.adaptyvbio.com/login, CSS at /_next/static/immutable/chunks/3m282inh_bgo3.css

## 1. Typefaces

| Role | Family | Loaded from | On Google Fonts? |
|---|---|---|---|
| Headings and body (marketing site, blog) | **Geist** (variable, 100 to 900) | Self-hosted woff2 through next/font [A][B] | Yes |
| Mono (marketing site) | **Geist Mono** | Self-hosted through next/font [A] | Yes |
| Docs body and headings | **Inter** | Self-hosted through next/font [C] | Yes |
| Docs code | **Paper Mono** | Self-hosted [C] | No. Use **Geist Mono** instead, since it is already their main mono and has a similar narrow, neutral look. |
| Foundry app | **Inter** | next/font [D] | Yes |

Headings are weight 500 with very tight tracking: the h1 is `font-medium tracking-[-0.06em]`, 60px on desktop, line-height 1.1 [A][B]. Other headings use -0.04em. Body text is mostly 14 to 16px at weight 500 [A].

## 2. Colors (from `:root` and the brand utility classes in [A])

| Token | Hex | Where it is used |
|---|---|---|
| Background | `#FFFFFF` | Most sections [A] |
| Off-white section | `#FAFBFD` | Alternating section background [A] |
| brand-black (text) | `#142933` | Text and headings (also at 70%, 50% and 40% opacity for secondary text), solid pill CTA buttons, the dark footer band [A] |
| brand-cyan (primary) | `#36B7F6` | `--primary` and `--ring`, accent text, small bar glyphs, radial glow on the dark band, first chart color [A] |
| brand-link | `#2091C9` | Links [A] |
| brand-dusty-blue | `#E9F2F7` | Secondary and accent fills, borders, a light tinted section, menu hover [A] |
| Muted | `#F3F3F3` bg, `#666666` text | Muted surfaces [A] |
| Instrument accent | `#809DB3` | Product illustrations of the instrument [A] |
| Chart colors | `#36B7F6`, `#22C55E`, `#FFBB00`, `#8855FF`, `#6B7280` | `--chart-1` to `--chart-5` [A] |
| Docs primary | `#5DB0DD` | Links and accents in both light and dark mode [C] |

Light and dark: the site is light (white, plus pale blue `#E9F2F7`). The only dark area is a navy `#142933` band near the footer, with white text at 50 to 80% opacity and a cyan glow [A]. The docs open in dark mode by default [C]. A `.dark` theme exists in the CSS (`#0A0A0A` bg, `#EDEDED` text, `#222` borders) but the homepage does not use it [A].

## 3. Overall feel

Clean, airy, clinical. Sections have generous padding (py-20 to py-24, max-width 7xl) and content stays sparse and quiet. Corners are mixed: buttons and chips are full pills, cards are rounded-xl, and the base radius is 0.5rem. Imagery is mainly clean product UI and line-style instrument illustrations in muted blue-greys, plus a faint dot grid (`#142933` dots on a 24px spacing). Copy is short, confident and technical ("The Automated Lab for Agentic Biology", "Validate your designs in just 3 weeks"), aimed at protein designers and AI teams.

## 4. Brand dos and don'ts

None published. /brand and /press return 404 [A], and there is no press kit linked. Inferred from usage: use navy and not pure black for text, use cyan only as an accent, and keep the layout mostly white.
