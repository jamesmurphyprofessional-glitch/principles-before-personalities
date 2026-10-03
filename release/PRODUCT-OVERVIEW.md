# Principles Before Personalities — Product Overview

*Offline reader and study companion for the recovery classics that are in the public domain in the United States.*

Last updated: 2026-09-25 · Source of truth for website copy.

---

## What it is

**Principles Before Personalities** is a distraction-free desktop/mobile reader for the foundational recovery texts, built for people who actually *work* the book: highlight, bookmark, take notes in the margin, and search — all stored privately on the user's own device. Nothing is uploaded; there is no account and no network requirement.

The name refers to the recovery tradition "principles before personalities." The app ships the two public-domain texts below and also lets the reader import their own texts.

## What's inside (bundled content)

The bundled content is the public-domain **first edition text (1939) as revised in its 1941 printing** — including the Twelfth Step's "spiritual awakening" wording (page 60) and the "Spiritual Experience" appendix. It is in the public domain **in the United States only**. It is **not** the current 4th edition, and stories added in later editions are not included. See "Text accuracy notes" below.

1. **Alcoholics Anonymous — "The basic text"**
   - The basic text, labeled with the **meeting page numbers** (the numbering read in meetings today): *Bill's Story* begins on page 1, *How It Works* on page 58, through page 164. These are not the April 1939 printing's own page numbers (for example, *How It Works* was on page 70 in 1939).
   - 14 chapters / ~172 pages, grouped into **Front matter** (Foreword to the first edition, The Doctor's Opinion), **The Book** (Bill's Story, There Is a Solution, More About Alcoholism, We Agnostics, How It Works, …), and **Appendices**.
2. **Personal Stories — "First edition"**
   - The personal stories from the first edition (The Doctor's Nightmare, The Unbeliever, The European Drinker, A Feminine Victory, Our Southern Friend, A Business Man's Recovery, …). The title "The Seventh Month Slip" is now correct (previously shown as "The Seven Month Slip"; its internal id is unchanged so saved notes/highlights still work). Do not quote a story count.
   - ~256 pages.

> Copy note for the site: describe this honestly as the **public-domain first edition text (1939, with the 1941 printing's revisions)** — short form: "the public-domain first edition of Alcoholics Anonymous (1939 text with 1941 revisions)". Say public domain **in the United States**. Do not quote a number of stories. Do not imply affiliation with or endorsement by Alcoholics Anonymous World Services. Do not present it as the current edition.

## Features (every user-facing capability)

- **Two-pane reader** — library sidebar (collapsible books → parts → chapters) beside a warm "paper" reading sheet on a dark background.
- **True page model** — content is paginated into pages labeled with the meeting page numbers; jump directly to any page by number.
- **Chapter navigation** — previous/next chapter, previous/next page, with keyboard shortcuts (⌘←, ⌘→).
- **Five-color highlighter** — yellow, amber, pink, green, blue. Select text and paint; highlights merge and split cleanly, and an **eraser** removes them.
- **Marker / Select / Eraser tools.**
- **Page bookmarks ("marked pages")** — flag any page with a colored ribbon; a "Marked pages" list in the sidebar jumps you back to each one.
- **Sticky notes** — drag-to-place, resizable, five-color sticky notes anchored to a page; chapters show a note indicator when they contain notes.
- **Full-text search** — search within a book with hit count and next/previous navigation (⌘G for Find Next), highlighting the current match on the page.
- **Chapter filter** — quickly filter the sidebar chapter list by name.
- **Import your own text** — open any `.txt` / `.md` file (⌘O); it's auto-split into chapters/pages and added to the library as your own book. Imported books, highlights, and notes stay on the device.
- **Automatic, private persistence** — reading place, highlights, bookmarks, notes, pen/tool choice, and imported books are saved locally (Application Support on macOS) and restored on next launch.
- **Reads offline forever** — no account, no network, no telemetry.

## Platforms & distribution

Delivered as four public `.zip` downloads in `release/`:

| Download | File | What it is |
|---|---|---|
| macOS | `Principles Before Personalities - Mac.zip` | Native SwiftUI `.app` (macOS 14+). |
| Windows | `Principles Before Personalities - Windows.zip` | .NET Framework 4.6.2 desktop app. |
| Android | `Principles Before Personalities - Android.zip` | Installable `.apk` (sideload; enable "install unknown apps"). |
| iPhone | `Principles Before Personalities - iPhone.zip` | Installable **web app (PWA)** you add to the Home Screen from Safari. *Not a native App Store app* — publishing a native iOS binary requires Apple's paid Developer Program, so the iPhone build is a home-screen web app with the same content and features. |

The iPhone PWA is also hostable directly on the website (same web codebase powers the Android app's content).

## Technical shape (for maintainers)

- **macOS:** Swift Package (`Package.swift`, macOS 14+), sources in `Sources/PrinciplesBeforePersonalities/` (`AppMain`, `LibraryModel`, `PageCanvas`, `StickyNotes`, `Resources/library.json`). Built via `scripts/build_app.sh` → `dist/Principles Before Personalities.app`.
- **Windows:** `windows/` — `Program.cs`, `PrinciplesBeforePersonalities.csproj` (.NET Framework 4.6.2), `build.sh`.
- **Content:** single `library.json` (~640 KB) drives every platform; keep it the shared source of content across Mac/Windows/web/Android.

## Fixed in this release (1.0.1)

- **macOS launch crash — fixed.** The shipped Sep 23 macOS build could crash on launch via SwiftPM's `Bundle.module` resource lookup failing inside the assembled `.app`. The source now loads `library.json` through `Bundle.main` with fallbacks (and `scripts/build_app.sh` refuses to build if `Bundle.module` is referenced); the 1.0.1 Mac build was rebuilt and verified to launch and stay running.

## Text accuracy notes

- **1941 wording kept deliberately.** The bundled basic text is the first edition as revised in its 1941 printing (Step 12 "spiritual awakening" on page 60; the "Spiritual Experience" appendix). This text is public domain in the United States: AAWS's own terms of use (https://www.aa.org/terms-of-use) say the First and Second Editions are in the public domain in the US, and no separate 1941 registration or renewal was found. Copy must not claim it is word-for-word the April 1939 printing.
- **Story title corrected:** "The Seven Month Slip" → "The Seventh Month Slip" (chapter id `the-seven-month-slip` kept for saved user data).
- **Story count:** do not quote a number of stories. The April 1939 printing had 29; the bundled "Ace Full—Seven—Eleven" is reportedly from the 1938 draft manuscript. *Open question for James: keep it or drop it?*
- **Open item — non-AA commentary in "Ace Full—Seven—Eleven":** pages 6–8 of that chapter in the bundled text are the source reprint's modern "Prologue" commentary (about distributing free books, recovery rates, with "See also: AA Comes of Age…" footnotes), not first-edition text. Not changed in 1.0.1; it should be trimmed (or the whole story dropped) when James decides the question above.
- **Outside the US:** public-domain status differs by country. AAWS has asserted copyright in Canada and won a case in Germany in 2003. Say "public domain in the United States" only.
