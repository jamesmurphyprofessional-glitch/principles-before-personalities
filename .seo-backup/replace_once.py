import sys, json
# usage: replace_once.py FILE SPEC.json  (SPEC = list of [old, new])
path, spec = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
for old, new in json.load(open(spec, encoding='utf-8')):
    n = s.count(old)
    if n != 1:
        sys.exit(f"ABORT: {n} matches for: {old[:80]!r}")
    s = s.replace(old, new, 1)
open(path, 'w', encoding='utf-8').write(s)
print("ok", path)
