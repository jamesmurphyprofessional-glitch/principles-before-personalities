import sys, shutil, os
def apply(path, backup, pairs, region=None):
    """Exact-once replacements. region=(start_marker,end_marker) restricts matching/editing to that slice."""
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
        print("backup ->", backup)
    else:
        print("backup exists, kept:", backup)
    s = open(path, encoding='utf-8').read()
    if region:
        a = s.index(region[0]); b = s.index(region[1], a) + len(region[1])
        pre, mid, post = s[:a], s[a:b], s[b:]
    else:
        pre, mid, post = '', s, ''
    for old, new in pairs:
        n = mid.count(old)
        if n != 1:
            sys.exit(f"ABORT (nothing written): {n} matches for: {old[:100]!r}")
        mid = mid.replace(old, new, 1)
    out = pre + mid + post
    # guard: file unchanged on disk since we read it
    if open(path, encoding='utf-8').read() != s:
        sys.exit("ABORT: file changed on disk during edit")
    open(path, 'w', encoding='utf-8').write(out)
    print("ok", path, len(pairs), "replacements")
