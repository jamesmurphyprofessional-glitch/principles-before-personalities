import sys; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
pairs = [
 ('- Keep the visible line "Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc." near the top of the page and in the footer.\n',
  '- Keep the visible disclaimer "Public domain in the United States only; copyright status in other countries may differ. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc." in the footer, and at least the non-affiliation sentence near the top of the page.\n'),
 ('- Always say "1939 first edition" and "public domain". Never imply it is the current fourth edition.\n',
  '- Describe the text as "the public-domain first edition text (1939, with the 1941 printing\'s revisions)". Short form: "the public-domain first edition of Alcoholics Anonymous (1939 text with 1941 revisions)". "1939 Big Book" is fine as a search phrase in titles and headings, as long as the nearby copy or meta says the text includes the 1941 revisions. Never claim it is the pure or unaltered 1939 printing, never imply it is the current fourth edition, say "public domain in the United States" (not worldwide), and don\'t quote a number of personal stories.\n'),
 ('- **AlternativeTo and similar directories.** List it as an alternative to other Big Book reader apps, described accurately.\n',
  '- **AlternativeTo and similar directories.** List it as an alternative to other Big Book reader apps, described accurately. (AlternativeTo and SaaSHub rejected the submission; Softpedia (Windows) was submitted on 2026-09-25. See `PBP-LAUNCH-DRAFTS.md`.)\n'),
 ('a short description and a 1939 quotation for each chapter, the 29 personal stories in the 1939 printing,',
  'a short description and a quotation for each chapter, the personal stories in the order of the April 1939 printing,'),
 ('- Backups of every edited file are in `.seo-backup/*-boost`.\n',
  '- Backups of every edited file are in `.seo-backup/*-boost`.\n- **2026-09-25, text wording update (app 1.0.1):** the bundled text is the first edition text (1939, with the 1941 printing\'s revisions: Step 12 "spiritual awakening", the "Spiritual Experience" appendix), public domain in the United States only. Updated `index.html`, `big-book-chapters/index.html` and the `<head>` of `iphone/index.html` (meta/og/twitter descriptions, JSON-LD descriptions, hero notes, footers, "What\'s inside" copy), set `softwareVersion` to 1.0.1 in the SoftwareApplication JSON-LD, updated three FAQ answers and added the FAQ "Is this the exact 1939 printing?" (visible FAQ and FAQPage JSON-LD match, 10 of 10), removed story counts, and updated the tone rules above and `PBP-LAUNCH-DRAFTS.md`. Backups are in `.seo-backup/*.pre-1941`.\n'),
]
apply('SEO-PLAN.md', '.seo-backup/SEO-PLAN.md.pre-1941', pairs)
