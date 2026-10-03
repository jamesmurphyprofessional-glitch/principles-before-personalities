Principles Before Personalities — iPhone (installable web app)
===============================================================

What this is
------------
This is an installable WEB APP (a "PWA") that you add to your iPhone's Home Screen
from Safari. It is NOT a native App Store app. Publishing a native iOS app requires
Apple's paid Developer Program, so the iPhone version is a Home Screen web app with
the same content and features as the Mac app.

Once added to the Home Screen it opens full-screen like an app and works offline.
There is no account, no tracking, and nothing is uploaded: your highlights, marked
pages, sticky notes, imported texts and reading place are saved only on your phone.

What's inside: the public-domain first edition text (1939, with the 1941 printing's
revisions) of "Alcoholics Anonymous" (meeting page numbers preserved: Bill's Story p. 1,
How It Works p. 58, through p. 164) and the Personal Stories from that first edition.
This is not the current edition.

Public domain in the United States only; copyright status in other countries may differ.
Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.

How to install on iPhone
------------------------
Safari can't open a web app straight out of a .zip or the Files app, so this
folder has to be served by a web server first:

  1. Put this folder on a website (any static host works: your own site, GitHub Pages,
     Netlify, etc.). Paths are relative, so it can live in any sub-folder, e.g.
     https://example.com/app/ . Use HTTPS so that offline mode can switch on.
  2. On your iPhone, open that address in Safari.
  3. Tap the Share button (the square with an up arrow) and choose "Add to Home Screen",
     then tap "Add".
  4. Open "Principles Before Personalities" from your Home Screen. The first time you open it
     (while online), it saves the whole library to your phone. After that it runs
     full-screen and works completely offline, even in airplane mode.

Quick test from a Mac (optional)
--------------------------------
In Terminal, cd into this folder and run:   python3 -m http.server 8000
then open http://localhost:8000 on the Mac. (If you open it from an iPhone over plain
http:// on your Wi-Fi, the reader works and can be added to the Home Screen, but the
offline cache only switches on over HTTPS, so host it for real offline use.)

Using the reader
----------------
- Tap the menu button (top left) for the Library: books, parts and chapters, the chapter
  filter, "Marked pages", and "Import a text" (.txt or .md from the Files app).
- Swipe left/right, or use the arrows at the bottom, to turn pages. Tap the chapter names
  at the bottom to jump to the previous/next chapter. Type a page number to jump to it.
- Highlight: select some text, then tap one of the five colors (yellow, amber, pink, green,
  blue) in the bar that pops up. Tap "Erase" to remove a highlight.
- Bookmark ribbon: tap the bookmark button to mark the page in the current pen color.
- Sticky note: tap the yellow note button. Drag a note by its top strip, resize it from the
  bottom-right corner, pick a color, or remove it with the x.
- Search: tap the magnifier, type at least two letters and press Search; the up/down arrows
  move between matches, and the count shows where you are.

Your notes are saved inside the Home Screen app on this phone. Deleting the Home Screen app
(or clearing Safari website data) deletes them.

Files
-----
index.html, app.js, styles.css ... the reader (plain HTML/CSS/JavaScript, no dependencies)
library-data.js / library.json ... the book content
manifest.webmanifest, service-worker.js, icons/ ... Home Screen install + offline support
