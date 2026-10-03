import sys, hashlib; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
OLD_ALT = 'The Principles Before Personalities reader on Mac, showing page 89 of the 1939 Big Book">'
NEW_ALT = 'The Principles Before Personalities reader on Mac, showing page 89 of the first edition Big Book text">'
def alts():
    return [('og:image:alt" content="' + OLD_ALT, 'og:image:alt" content="' + NEW_ALT),
            ('twitter:image:alt" content="' + OLD_ALT, 'twitter:image:alt" content="' + NEW_ALT)]
which = sys.argv[1]
if which == 'index':
    pairs = [
     ('<title>1939 Big Book Reader &amp; Study App, Offline | Principles Before Personalities</title>',
      '<title>1939 Big Book (First Edition) Reader | Principles Before Personalities</title>'),
     ('<meta property="og:title" content="Principles Before Personalities: an offline 1939 Big Book reader">',
      '<meta property="og:title" content="Principles Before Personalities: 1939 Big Book (First Edition) Reader">'),
     ('<meta name="twitter:title" content="Principles Before Personalities: an offline 1939 Big Book reader">',
      '<meta name="twitter:title" content="Principles Before Personalities: 1939 Big Book (First Edition) Reader">'),
     *alts(),
     ('<span class="h1-sub">A reader for the 1939 Big Book, made for working the book</span>',
      '<span class="h1-sub">A reader for the first edition Big Book, made for working the book</span>'),
     ("<h2 id=\"inside-title\">What's inside: the 1939 Big Book and its personal stories</h2>",
      "<h2 id=\"inside-title\">What's inside: the first edition Big Book and its personal stories</h2>"),
    ]
    apply('site/index.html', '.seo-backup/index.html.pre-soften', pairs)
elif which == 'chapters':
    H = 'First Edition Big Book Chapters and Page Numbers'
    pairs = [
     ('<title>1939 Big Book Chapters and Page Numbers | Principles Before Personalities</title>',
      '<title>1939 Big Book (First Edition) Chapters | Principles Before Personalities</title>'),
     ('<meta property="og:title" content="1939 Big Book chapters and page numbers">',
      '<meta property="og:title" content="1939 Big Book (First Edition) Chapters">'),
     ('<meta name="twitter:title" content="1939 Big Book chapters and page numbers">',
      '<meta name="twitter:title" content="1939 Big Book (First Edition) Chapters">'),
     *alts(),
     ('"name": "1939 Big Book Chapters and Page Numbers",', '"name": "' + H + '",'),
     ('"name": "1939 Big Book chapters and page numbers",', '"name": "' + H + '",'),
     ('<li aria-current="page">1939 Big Book chapters</li>', '<li aria-current="page">' + H + '</li>'),
     ('<h1 id="page-title">1939 Big Book Chapters and Page Numbers</h1>', '<h1 id="page-title">' + H + '</h1>'),
     ('<h2 id="read-title">Read the 1939 text with these page numbers</h2>',
      '<h2 id="read-title">Read the first edition text with these page numbers</h2>'),
    ]
    apply('site/big-book-chapters/index.html', '.seo-backup/big-book-chapters-index.html.pre-soften', pairs)
elif which == 'iphone':
    P = 'site/iphone/index.html'
    def bh():
        s = open(P, encoding='utf-8').read(); i = s.index('</head>')
        return hashlib.sha256(s[i:].encode()).hexdigest()
    b0 = bh()
    pairs = [
     ('<title>1939 Big Book Web App for iPhone | Principles Before Personalities</title>',
      '<title>1939 Big Book (First Edition) for iPhone | Principles Before Personalities</title>'),
     ('og:title" content="1939 Big Book web app for iPhone: Principles Before Personalities">',
      'og:title" content="1939 Big Book (First Edition) for iPhone: Principles Before Personalities">'),
     ('twitter:title" content="1939 Big Book web app for iPhone: Principles Before Personalities">',
      'twitter:title" content="1939 Big Book (First Edition) for iPhone: Principles Before Personalities">'),
     *alts(),
    ]
    apply(P, '.seo-backup/iphone-index.html.pre-soften', pairs, region=('<head>', '</head>'))
    print('BODY UNCHANGED' if bh() == b0 else 'BODY CHANGED!')
