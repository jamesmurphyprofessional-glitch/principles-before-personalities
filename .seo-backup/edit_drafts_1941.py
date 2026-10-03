import sys; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
DISC = "Public domain in the United States only; copyright status in other countries may differ. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc."
LONG = "first edition text (1939, with the 1941 printing's revisions)"
pairs = [
 # status note at top
 ('Drafted by SEO on 2026-09-25. **Nothing here has been posted or sent.** James posts each one himself, from his own accounts, if and when he wants to.\n',
  'Drafted by SEO on 2026-09-25. **Nothing here has been posted or sent.** James posts each one himself, from his own accounts, if and when he wants to.\n\n'
  '> **Status, 2026-09-25:** Softpedia (Windows) was already submitted on 2026-09-25 with the earlier wording "based on the public-domain 1939 first edition". AlternativeTo and SaaSHub rejected the submission. The drafts below were updated the same day to the approved wording: the bundled text is the ' + LONG + ', public domain in the United States only.\n'),
 ('- Every listing says it is **free**, uses the **public-domain 1939 first edition** text, and carries the line **"Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc."** Keep those three things if you edit.\n- Don\'t call it the current or fourth edition.',
  '- Every listing says it is **free**, uses the **public-domain ' + LONG + '**, and carries the disclaimer **"' + DISC + '"** Keep those three things if you edit. Short form of the text claim: "the public-domain first edition of Alcoholics Anonymous (1939 text with 1941 revisions)".\n- Don\'t call it the current or fourth edition, and don\'t call it the pure or unaltered 1939 printing. Don\'t quote a number of personal stories.'),
 # AlternativeTo
 ('## 1. AlternativeTo\n\n',
  '## 1. AlternativeTo\n\n**Status:** submitted and rejected (see the note at the top). Kept for reference.\n\n'),
 ('  Free offline reader for the public-domain 1939 Big Book, with highlights, bookmarks, sticky notes and search. No account.\n',
  '  Free offline reader for the public-domain first edition Big Book (1939 text with 1941 revisions), with highlights, bookmarks, sticky notes and search. No account.\n'),
 ('  Principles Before Personalities is a free, distraction-free reader for the public-domain 1939 first edition of *Alcoholics Anonymous* (the "Big Book") and its personal stories.',
  '  Principles Before Personalities is a free, distraction-free reader for the public-domain ' + LONG + ' of *Alcoholics Anonymous* (the "Big Book") and its personal stories.'),
 ('(an installable web app added from Safari, not an App Store app).\n  Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.\n',
  '(an installable web app added from Safari, not an App Store app).\n  ' + DISC + '\n'),
 # Product Hunt
 ('- **Tagline (60 characters max):** A free, offline reader for the 1939 Big Book  *(44 characters)*\n',
  '- **Tagline (60 characters max):** A free, offline reader for the first-edition Big Book  *(53 characters)*\n'),
 ('  A reader for the public-domain 1939 Big Book with meeting page numbers. Highlight, mark pages, add sticky notes and search. No account, no network, nothing uploaded. Free for Mac, Windows, Android and iPhone (web app). Not affiliated with AA World Services.\n  *(257 characters. The full non-affiliation line is in the maker\'s comment below.)*\n',
  '  A reader for the public-domain first edition Big Book (1939 text, 1941 revisions) with meeting page numbers. Highlight, mark pages, add notes and search. No account. Free for Mac, Windows, Android and iPhone (web app). Not affiliated with AA World Services.\n  *(257 characters. The full disclaimer is in the maker\'s comment below.)*\n'),
 ("  > It ships the 1939 first edition, which is in the public domain in the US, so it's free to share. It is not the current edition.",
  "  > It ships the " + LONG + ", which is in the public domain in the United States. It is not the current edition."),
 ("  > It's an independent project, not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc. Feedback welcome, especially on the reading experience.\n",
  "  > It's an independent project. " + DISC + " Feedback welcome, especially on the reading experience.\n"),
 # Show HN
 ('- **Title (80 characters max):** Show HN: An offline, no-account reader for a public-domain 1939 book  *(68)*\n  Alternative: Show HN: A local-only, no-account reader for the 1939 Big Book  *(62)*\n',
  '- **Title (80 characters max):** Show HN: An offline, no-account reader for a public-domain classic  *(66)*\n  Alternative: Show HN: A local-only, no-account reader for the first-edition Big Book  *(71)*\n'),
 ('  > I made a small reader app for the 1939 first edition of *Alcoholics Anonymous* (the "Big Book"). That edition is in the public domain in the US. It\'s free, and I\'m an independent developer, not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.\n',
  '  > I made a small reader app for the first edition of *Alcoholics Anonymous* (the "Big Book"): the 1939 text with the 1941 printing\'s revisions. It\'s free, and I\'m an independent developer. ' + DISC + '\n'),
 # SaaSHub
 ('### SaaSHub\n',
  '### SaaSHub\n\n**Status:** submitted and rejected (see the note at the top). Kept for reference.\n\n'),
 ('- **Tagline:** Free offline reader for the public-domain 1939 Big Book\n',
  '- **Tagline:** Free offline reader for the public-domain first-edition Big Book\n'),
 ('  A free reader and study app for the public-domain 1939 first edition of *Alcoholics Anonymous* (the Big Book) and its personal stories, with meeting page numbers.',
  '  A free reader and study app for the public-domain first edition of *Alcoholics Anonymous* (the Big Book; 1939 text with 1941 revisions) and its personal stories, with meeting page numbers.'),
 ('Mac, Windows, Android, and iPhone (installable web app, not App Store). Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.\n',
  'Mac, Windows, Android, and iPhone (installable web app, not App Store). ' + DISC + '\n'),
 # Softpedia
 ('### Softpedia (Windows and Mac downloads)\n',
  '### Softpedia (Windows and Mac downloads)\n\n**Status:** Windows already submitted on 2026-09-25 with the earlier wording ("based on the public-domain 1939 first edition"). The text below is the updated wording, for the Mac submission or if the listing can be edited.\n\n'),
 ('- **Short description:** Free offline reader for the public-domain 1939 Big Book, with highlights, bookmarks, sticky notes and search.\n- **Long description:** reuse the AlternativeTo full description above, including the non-affiliation line.\n',
  '- **Short description:** Free offline reader for the public-domain first edition Big Book (1939 text with 1941 revisions), with highlights, bookmarks, sticky notes and search.\n- **Long description:** reuse the AlternativeTo full description above, including the full disclaimer.\n'),
 # Outreach email
 ('**Subject:** A free, offline reader for the 1939 Big Book (for your recovery tools list)\n',
  '**Subject:** A free, offline reader for the first-edition Big Book (for your recovery tools list)\n'),
 ('> Principles Before Personalities is a reader for the public-domain 1939 first edition of the Big Book.',
  '> Principles Before Personalities is a reader for the public-domain ' + LONG + ' of the Big Book.'),
 ("> To be clear about what it isn't: it's the 1939 text, not the current edition, and it's an independent project, not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.\n",
  "> To be clear about what it isn't: it's the first edition text, not the current edition, and it's an independent project. " + DISC + "\n"),
 # Reddit
 ('> I made a free reader for the 1939 first edition of the Big Book, which is in the public domain.',
  "> I made a free reader for the first edition of the Big Book (the 1939 text with the 1941 printing's revisions), which is in the public domain in the US."),
 ("> It's the 1939 text, not the current edition. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc. Just something I built",
  "> It's the first edition text, not the current edition. " + DISC + " Just something I built"),
]
apply('PBP-LAUNCH-DRAFTS.md', '.seo-backup/PBP-LAUNCH-DRAFTS.md.pre-1941', pairs)
