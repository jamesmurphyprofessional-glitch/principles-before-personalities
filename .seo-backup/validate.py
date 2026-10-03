import json, os, re, sys, html
from html.parser import HTMLParser
from urllib.parse import urlparse, unquote
SITE = 'site'
VOID = {'area','base','br','col','embed','hr','img','input','link','meta','source','track','wbr'}
OPT_CLOSE = {'p','li','dt','dd','tr','td','th','thead','tbody','option'}
BASE = 'https://principles-before-personalities.netlify.app/'
class P(HTMLParser):
    def __init__(s):
        super().__init__(convert_charrefs=True); s.stack=[]; s.err=[]; s.h1=0; s.ld=[]; s.inld=False; s.buf=''; s.links=[]; s.ids=set()
        s.summ=[]; s.dp=[]; s.cur=None; s.txt=''
    def handle_starttag(s,t,a):
        a=dict(a)
        if 'id' in a: s.ids.add(a['id'])
        if t=='h1': s.h1+=1
        for k in ('href','src'):
            if k in a and a[k]: s.links.append((t,a[k]))
        if 'srcset' in a:
            for part in a['srcset'].split(','): s.links.append((t,part.strip().split()[0]))
        if t=='script' and a.get('type')=='application/ld+json': s.inld=True; s.buf=''
        if t in ('summary','p') : s.cur=t; s.txt=''
        if t not in VOID: s.stack.append((t,s.getpos()))
    def handle_startendtag(s,t,a): s.handle_starttag(t,a); (s.stack.pop() if t not in VOID else None)
    def handle_endtag(s,t):
        if t in VOID: return
        if t=='script' and s.inld: s.ld.append(s.buf); s.inld=False
        if t==s.cur=='summary': s.summ.append(s.txt.strip())
        if t=='p' and s.cur=='p' and any(x[0]=='details' for x in s.stack): s.dp.append(s.txt.strip())
        if s.stack and s.stack[-1][0]==t: s.stack.pop(); return
        s.err.append(f'unexpected </{t}> at {s.getpos()}, open={[x[0] for x in s.stack[-3:]]}')
        for i in range(len(s.stack)-1,-1,-1):
            if s.stack[i][0]==t: del s.stack[i:]; break
    def handle_data(s,d):
        if s.inld: s.buf+=d
        s.txt+=d
ok=True
pages=[]
for root,_,files in os.walk(SITE):
    for f in files:
        if f.endswith('.html'): pages.append(os.path.join(root,f))
for path in sorted(pages):
    p=P(); p.feed(open(path,encoding='utf-8').read()); p.close()
    unclosed=[x for x in p.stack if x[0] not in OPT_CLOSE]
    print(f'== {path}: h1={p.h1} jsonld_blocks={len(p.ld)} parse_errors={len(p.err)} unclosed={unclosed}')
    for e in p.err: print('  ERR',e); ok=False
    if unclosed: ok=False
    if p.h1!=1: print('  ERR h1 count',p.h1); ok=False
    for b in p.ld:
        try: d=json.loads(b); print('  JSON-LD ok:', [g.get('@type') for g in d.get('@graph',[d])])
        except Exception as e: print('  ERR JSON-LD',e); ok=False
        if path.endswith('site/index.html'):
            faq=[g for g in d['@graph'] if g['@type']=='FAQPage'][0]['mainEntity']
            qa=[(q['name'],q['acceptedAnswer']['text']) for q in faq]
            vis=list(zip(p.summ,p.dp))
            norm=lambda x: re.sub(r'\s+',' ',x).strip()
            match = len(qa)==len(vis) and all(norm(a)==norm(c) and norm(b)==norm(dd) for (a,b),(c,dd) in zip(qa,vis))
            print(f'  FAQ JSON-LD vs visible: {len(qa)} vs {len(vis)} match={match}')
            if not match:
                ok=False
                for (a,b),(c,dd) in zip(qa,vis):
                    if norm(a)!=norm(c) or norm(b)!=norm(dd): print('   DIFF',a,'|',c)
    # disclaimer
    txt=open(path,encoding='utf-8').read()
    print('  disclaimer line present:', 'Not affiliated with or endorsed by Alcoholics Anonymous World Services, Inc.' in txt)
    # links
    for t,l in p.links:
        if l.startswith(BASE): rel=l[len(BASE):]; base=SITE
        elif re.match(r'^[a-z]+:',l) or l.startswith('//'): continue
        else: rel=l; base=os.path.dirname(path)
        u=urlparse(rel); frag=u.fragment; pth=unquote(u.path)
        target=os.path.normpath(os.path.join(base,pth)) if pth else path
        if os.path.isdir(target): target=os.path.join(target,'index.html')
        if not os.path.exists(target): print('  BROKEN',t,l,'->',target); ok=False; continue
        if frag and target.endswith('.html'):
            q=P(); q.feed(open(target,encoding='utf-8').read())
            if frag not in q.ids: print('  BROKEN FRAGMENT',l); ok=False
print('ALL OK' if ok else 'PROBLEMS FOUND')
