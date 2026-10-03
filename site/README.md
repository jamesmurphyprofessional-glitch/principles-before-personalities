# Principles Before Personalities: website

A static showcase site for the app. It is plain HTML and CSS with no JavaScript, no external fonts or CDNs, and no trackers. It deploys to Netlify (or any static host) as-is, with no build step.

## Files

| Path | What it is |
|---|---|
| `index.html` | The whole page (hero, screenshot, features, what's inside, downloads, FAQ) |
| `styles.css` | Styles (system fonts, responsive, dark palette taken from the app icon) |
| `favicon.ico`, `favicon-16.png`, `favicon-32.png`, `apple-touch-icon.png` | Favicons generated from `Assets/icon-source.jpg` |
| `assets/` | App icon (320/512 px), the real Mac app screenshot (WebP + JPEG, 1200/2000 px), and the Open Graph image |
| `downloads/` | The four release zips go here (see below) |
| `.nojekyll` | Only matters on GitHub Pages; Netlify ignores it (harmless) |

## Preview locally

```sh
cd "/Users/jamesmurphy/Principles Before Personalities/site"
python3 -m http.server 8080
```

Then open <http://localhost:8080>. Press Ctrl-C to stop the server.

## Download links

The download buttons use relative links to these files:

- `downloads/Principles-Before-Personalities-Mac.zip`
- `downloads/Principles-Before-Personalities-Windows.zip`
- `downloads/Principles-Before-Personalities-Android.zip`
- `downloads/Principles-Before-Personalities-iPhone.zip`

The release zips in `../release/` have names like `Principles Before Personalities - Mac.zip`. Copy them in with the cleaned-up names:

```sh
cd "/Users/jamesmurphy/Principles Before Personalities"
for p in Mac Windows Android iPhone; do
  cp "release/Principles Before Personalities - $p.zip" "site/downloads/Principles-Before-Personalities-$p.zip"
done
```

**iPhone:** the iPhone build is an installable web app (PWA). People can't add a zip to the Home Screen, so the web app has to be hosted. Unzip it into `site/iphone/` and point the iPhone button's `href` at `iphone/`. People then open that page in Safari and choose Share › Add to Home Screen.

## Publish on Netlify (free plan)

The whole `site/` folder is the publish directory. There's no build command.

**Option A: Netlify CLI**

```sh
npm install -g netlify-cli
cd "/path/to/site"
netlify login                 # opens a browser once to authorize
netlify deploy --dir .        # draft deploy: gives you a preview URL to check
netlify deploy --dir . --prod # publish to the live URL
```

The first `netlify deploy` asks whether to create a new project and lets you choose its name. That name becomes `https://<name>.netlify.app`.

**Option B: drag and drop.** Log in at app.netlify.com, choose the manual (drag-and-drop) deploy option for a new project, and drop the `site` folder. Netlify recommends the CLI instead if a deploy is over about 50 MB or has single files over about 10 MB.

**Free-plan notes** (Netlify's credit-based pricing, checked September 2026):

- The Free plan includes 300 credits a month, with a hard limit.
- Each production deploy costs 15 credits. Draft and preview deploys are free.
- Bandwidth costs 20 credits per GB, and that includes every zip downloaded from the site. With a few production deploys a month, that leaves roughly 12–14 GB of downloads.
- If the credits run out, the site pauses until the next month.
- If downloads grow, attach the zips to a free GitHub Release and point the buttons at the release asset URLs. GitHub serves them without using Netlify credits.

**After the first deploy:** once you know the final URL, you can add `<link rel="canonical" href="https://<name>.netlify.app/">` to `index.html`. You can also change `og:image` / `twitter:image` to absolute URLs so link previews show the image everywhere.

## SEO (added by SEO, 2026-09-25)

The site is live on Netlify at `https://principles-before-personalities.netlify.app/`. That base URL is used in these files:

- `index.html`: canonical, `og:url`, `og:image`, `twitter:image`, and the JSON-LD block (WebSite, SoftwareApplication, FAQPage)
- `iphone/index.html` and `big-book-chapters/index.html`: canonical, `og:url`, `og:image`, `twitter:image` (and the breadcrumb JSON-LD on the chapter page)
- `robots.txt`: the `Sitemap:` line
- `sitemap.xml`: the `<loc>`

If the site moves (custom domain or GitHub Pages), swap it in one go (keep the trailing slash):

```sh
cd "/Users/jamesmurphy/Principles Before Personalities/site"
OLD="https://principles-before-personalities.netlify.app/"
NEW="https://NEW-DOMAIN/"
grep -rl "$OLD" index.html iphone/index.html big-book-chapters/index.html robots.txt sitemap.xml | xargs sed -i '' "s#$OLD#$NEW#g"
```

The FAQ answers on the page and the FAQPage JSON-LD must say the same thing. If you edit a FAQ answer, edit the matching JSON-LD entry too (or ask SEO to).
