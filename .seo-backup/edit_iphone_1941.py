import sys, hashlib; sys.path.insert(0, '.seo-backup')
from pbp_common import apply
P = 'site/iphone/index.html'
def body_hash():
    s = open(P, encoding='utf-8').read()
    i = s.index('</head>') + len('</head>')
    return hashlib.sha256(s[i:].encode()).hexdigest(), s[:i].count('\n')
before = body_hash()
pairs = [
 ('public-domain 1939 first edition of the Big Book on iPhone. A free web app: add it to your Home Screen from Safari and read offline. Not an App Store app.">',
  'public-domain first edition Big Book (1939 text with 1941 revisions) on iPhone. Free web app: add it to your Home Screen from Safari and read offline.">'),
 ('og:description" content="Free installable web app for the public-domain 1939 Big Book.',
  'og:description" content="Free installable web app for the public-domain first edition of Alcoholics Anonymous (1939 text with 1941 revisions).'),
 ('offline. Not affiliated with',
  'offline. Public domain in the United States only; copyright status in other countries may differ. Not affiliated with'),
 ('twitter:description" content="Free installable web app for the public-domain 1939 Big Book.',
  'twitter:description" content="Free installable web app for the public-domain first edition Big Book (1939 text with 1941 revisions).'),
]
apply(P, '.seo-backup/iphone-index.html.pre-1941', pairs, region=('<head>', '</head>'))
after = body_hash()
print('body sha before', before[0]); print('body sha after ', after[0])
print('BODY UNCHANGED' if before[0] == after[0] else 'BODY CHANGED!')
