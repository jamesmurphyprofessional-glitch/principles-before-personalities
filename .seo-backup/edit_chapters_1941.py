import sys; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
DISC = "Public domain in the United States only; copyright status in other countries may differ. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc."
LONG = "first edition text (1939, with the 1941 printing's revisions)"
pairs = [
 ('<meta name="description" content="The chapters of the public-domain 1939 first edition of the Big Book, with meeting page numbers and original 1939 page numbers, a short description of each chapter, and the personal stories.">',
  '<meta name="description" content="Chapters of the public-domain first edition Big Book (1939 text with 1941 revisions), with meeting and April 1939 page numbers, summaries and the stories.">'),
 ('<meta property="og:description" content="Every chapter of the public-domain 1939 Big Book with its page numbers and a short description, plus the 1939 personal stories.">',
  '<meta property="og:description" content="Every chapter of the public-domain first edition Big Book (1939 text with 1941 revisions) with its page numbers and a short description, plus the first edition personal stories.">'),
 ('<meta name="twitter:description" content="Every chapter of the public-domain 1939 Big Book with its page numbers and a short description, plus the 1939 personal stories.">',
  '<meta name="twitter:description" content="Every chapter of the public-domain first edition Big Book (1939 text with 1941 revisions) with its page numbers and a short description, plus the first edition personal stories.">'),
 ('"description": "The chapters of the public-domain 1939 first edition of Alcoholics Anonymous (the Big Book), with meeting page numbers, original 1939 page numbers and a short description of each chapter. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.",',
  '"description": "The chapters of the public-domain first edition of Alcoholics Anonymous (the Big Book; 1939 text with 1941 revisions), with meeting page numbers, original April 1939 page numbers and a short description of each chapter. ' + DISC + '",'),
 ('<p class="lede">A chapter-by-chapter guide to the <strong>public-domain 1939 first edition</strong> of <cite>Alcoholics Anonymous</cite>: where each chapter starts, what it covers, and which personal stories the 1939 edition contained.</p>',
  '<p class="lede">A chapter-by-chapter guide to the <strong>public-domain first edition</strong> of <cite>Alcoholics Anonymous</cite> (1939, with the 1941 printing\'s revisions): where each chapter starts, what it covers, and which personal stories the first edition contained.</p>'),
 ('<p class="hero-note">Independent project. Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.</p>',
  '<p class="hero-note">Independent project. ' + DISC + '</p>'),
 ('The Principles Before Personalities app lays out the 1939 text with these meeting page numbers,',
  'The Principles Before Personalities app lays out the ' + LONG + ' with these meeting page numbers,'),
 ('<caption>Front matter of the 1939 first edition</caption>',
  '<caption>Front matter of the first edition</caption>'),
 ('<p class="note">The 1939 first edition has no Preface. The Preface and the forewords to later editions were added after 1939 and are not part of this text.</p>',
  '<p class="note">The first edition has no Preface. The Preface and the forewords to later editions are not part of this text.</p>'),
 ('Quotations are from the 1939 text.</p>',
  'Quotations are from the app\'s ' + LONG + '.</p>'),
 ('<h2 id="stories-title">Personal stories in the 1939 first edition</h2>',
  '<h2 id="stories-title">Personal stories in the first edition</h2>'),
 ('The app\'s basic text also includes the appendix <i>Spiritual Experience</i>. That appendix was added in a later printing of the first edition, as its own opening lines explain.</p>',
  'The app\'s basic text is the first edition as revised in the 1941 printing: Step 12 reads <q>spiritual awakening</q>, and the appendix <i>Spiritual Experience</i> is included. That appendix was added in the 1941 printing; its own opening lines refer back to the first printing.</p>'),
 ('<p>Principles Before Personalities is a free, offline reader for the public-domain 1939 text.',
  '<p>Principles Before Personalities is a free, offline reader for the public-domain ' + LONG + '.'),
 ('<p class="disclaimer">Principles Before Personalities is an independent project. It is not affiliated with, endorsed by, or approved by Alcoholics Anonymous World Services, Inc. The bundled text is the 1939 first edition of <cite>Alcoholics Anonymous</cite>, which is in the public domain in the United States.</p>',
  '<p class="disclaimer">Principles Before Personalities is an independent project. The bundled text is the ' + LONG + ' of <cite>Alcoholics Anonymous</cite>. ' + DISC + '</p>'),
]
apply('site/big-book-chapters/index.html', '.seo-backup/big-book-chapters-index.html.pre-1941', pairs)
