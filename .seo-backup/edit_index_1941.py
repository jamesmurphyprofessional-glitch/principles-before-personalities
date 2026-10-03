import sys; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
DISC = "Public domain in the United States only; copyright status in other countries may differ. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc."
LONG = "first edition text (1939, with the 1941 printing's revisions)"
Q1A_OLD = "No. The app contains the 1939 first edition, which is in the public domain in the United States. It is not the current fourth edition, and stories added in later editions are not included."
Q1A_NEW = "No. The app contains the " + LONG + ", which is in the public domain in the United States. It is not the current fourth edition, and stories added in later editions are not included."
NQ = "Is this the exact 1939 printing?"
NA = "Not word for word. The app contains the first edition text as revised in the 1941 printing: for example, Step 12 reads “spiritual awakening”, and the “Spiritual Experience” appendix added in that printing is included. That text is in the public domain in the United States. The page numbers are the ones read in meetings, not those of the April 1939 printing."
FREE_OLD = "Yes. There is no price, no account and no subscription. Choose your platform in the Download section of this page."
FREE_NEW = "Yes. There is no price, no account and no subscription. The bundled text is in the public domain in the United States only; copyright status in other countries may differ. Choose your platform in the Download section of this page."
TT_OLD = "No. The app includes only the two 1939 first-edition texts described on this page: the basic text and the personal stories. You can add your own .txt or .md files with Import a text."
TT_NEW = "No. The app includes only the two first-edition texts described on this page: the basic text (1939, with the 1941 printing's revisions) and the personal stories. You can add your own .txt or .md files with Import a text."
pairs = [
 # meta
 ('<meta name="description" content="Free offline reader for the public-domain 1939 Big Book with meeting page numbers. Highlight, bookmark, take notes and search. Mac, Windows, Android, iPhone.">',
  '<meta name="description" content="Free offline reader for the public-domain first edition Big Book (1939 text with 1941 revisions), with meeting page numbers, highlights, notes and search.">'),
 ('<meta property="og:description" content="Read and study the public-domain 1939 Big Book offline,',
  '<meta property="og:description" content="Read and study the public-domain first edition of the Big Book (1939 text with 1941 revisions) offline,'),
 ('<meta name="twitter:description" content="Read and study the public-domain 1939 Big Book offline,',
  '<meta name="twitter:description" content="Read and study the public-domain first edition of the Big Book (1939 text with 1941 revisions) offline,'),
 # JSON-LD SoftwareApplication
 ('"description": "An offline reader and study app for the public-domain 1939 first edition of Alcoholics Anonymous (the Big Book) and its personal stories, with meeting page numbers, highlighting, bookmarks, sticky notes and full-text search. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.",',
  '"description": "Offline reader and study companion for the public-domain first edition of Alcoholics Anonymous (1939 text with 1941 revisions) and its personal stories, with meeting page numbers, highlighting, bookmarks, sticky notes and full-text search. ' + DISC + '",'),
 ('      "applicationCategory": "ReferenceApplication",\n',
  '      "applicationCategory": "ReferenceApplication",\n      "softwareVersion": "1.0.1",\n'),
 # FAQ JSON-LD
 ('"text": "' + Q1A_OLD + '"\n          }\n        },\n',
  '"text": "' + Q1A_NEW + '"\n          }\n        },\n        {\n          "@type": "Question",\n          "name": "' + NQ + '",\n          "acceptedAnswer": {\n            "@type": "Answer",\n            "text": "' + NA + '"\n          }\n        },\n'),
 ('"text": "' + FREE_OLD + '"', '"text": "' + FREE_NEW + '"'),
 ('"text": "' + TT_OLD + '"', '"text": "' + TT_NEW + '"'),
 # hero
 ('reader for the <strong>public-domain 1939 first edition</strong> of <cite>Alcoholics Anonymous</cite>,',
  'reader for the <strong>public-domain ' + LONG + '</strong> of <cite>Alcoholics Anonymous</cite>,'),
 ('<p class="hero-note">Independent project. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.</p>',
  '<p class="hero-note">Independent project. ' + DISC + '</p>'),
 # about
 ('You get the 1939 text with its real page numbers,',
  'You get the ' + LONG + ' with its real page numbers,'),
 # inside
 ('Both are from the <strong>1939 first edition</strong>, which is in the public domain in the United States.',
  'Both come from the <strong>' + LONG + '</strong>, which is in the public domain in the United States.'),
 ('<li><strong>Front matter:</strong> the 1939 Foreword and The Doctor\'s Opinion</li>',
  '<li><strong>Front matter:</strong> the Foreword to the first edition and The Doctor\'s Opinion</li>'),
 ('<li><strong>Appendix:</strong> Spiritual Experience</li>',
  '<li><strong>Appendix:</strong> Spiritual Experience (added in the 1941 printing)</li>'),
 ('<p class="sub">First edition, 1939</p>', '<p class="sub">First edition</p>'),
 ('<p>The personal stories from the 1939 first edition, including',
  '<p>The personal stories from the first edition, including'),
 # visible FAQ
 ('<p>' + Q1A_OLD + '</p>\n        </details>\n',
  '<p>' + Q1A_NEW + '</p>\n        </details>\n        <details>\n          <summary>' + NQ + '</summary>\n          <p>' + NA + '</p>\n        </details>\n'),
 ('<p>' + FREE_OLD + '</p>', '<p>' + FREE_NEW + '</p>'),
 ('<p>' + TT_OLD + '</p>', '<p>' + TT_NEW + '</p>'),
 # footer
 ('<p class="disclaimer">Principles Before Personalities is an independent project. It is not affiliated with, endorsed by, or approved by Alcoholics Anonymous World Services, Inc. The bundled text is the 1939 first edition of <cite>Alcoholics Anonymous</cite>, which is in the public domain in the United States.</p>',
  '<p class="disclaimer">Principles Before Personalities is an independent project. The bundled text is the ' + LONG + ' of <cite>Alcoholics Anonymous</cite>. ' + DISC + '</p>'),
]
apply('site/index.html', '.seo-backup/index.html.pre-1941', pairs)
