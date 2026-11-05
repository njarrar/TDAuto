#!/usr/bin/env python3
"""Find method Callables (obj.method passed without a call) whose method does not exist.

Usage: python3 tools/static/check_callables.py [root]
Reads every .gd under src/ and tests/. For each `name.member` followed by `)` or `,`,
where `name` is a typed var or parameter of a project class, it reports members that are
neither a method nor a var or signal of that class or its project bases. Engine bases are
not known, so a member found only on an engine class reads as UNKNOWN, not MISSING.
Prints one line per finding and a count; exit 1 when any MISSING line prints.
"""
import glob
import os
import re
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "."
files = glob.glob(os.path.join(root, "src/**/*.gd"), recursive=True) + \
    glob.glob(os.path.join(root, "tests/**/*.gd"), recursive=True)

classes = {}
for f in files:
    s = open(f, encoding="utf-8").read()
    m = re.search(r"^class_name\s+(\w+)(?:\s+extends\s+(\w+))?", s, re.M)
    if not m:
        continue
    base = m.group(2)
    if base is None:
        e = re.search(r"^extends\s+(\w+)", s, re.M)
        base = e.group(1) if e else None
    members = set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)", s, re.M))
    members |= set(re.findall(r"^(?:@\w+(?:\(.*?\))?\s+)*(?:static\s+)?var\s+(\w+)", s, re.M))
    members |= set(re.findall(r"^signal\s+(\w+)", s, re.M))
    members |= set(re.findall(r"^const\s+(\w+)", s, re.M))
    members |= set(re.findall(r"^enum\s+(\w+)", s, re.M))
    classes[m.group(1)] = (members, base)


def lookup(cls, member, depth=0):
    """True: found. False: not in a fully known chain. None: chain reaches an engine class."""
    if depth > 10:
        return None
    if cls not in classes:
        return None
    members, base = classes[cls]
    if member in members:
        return True
    if base is None:
        return False
    if base not in classes:
        return None
    return lookup(base, member, depth + 1)


missing = 0
unknown = 0
for f in files:
    s = open(f, encoding="utf-8").read()
    types = {}
    for n, line in enumerate(s.splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        # The nearest typed declaration above wins, so a reused name reads its latest type.
        for name, t in re.findall(r"\b(\w+)\s*:\s*([A-Z][\w.]*)", line):
            types[name] = t
        for obj, member in re.findall(r"\b([a-z_]\w*)\.(\w+)\s*(?=[),])", line):
            t = types.get(obj)
            if t not in classes:
                continue
            r = lookup(t, member)
            if r is True:
                continue
            base = classes[t][1]
            chain_known = base in (None, "RefCounted", "Object") or base in classes
            if r is None and chain_known and base not in classes:
                print(f"MISSING {os.path.relpath(f, root)}:{n} {obj}: {t} has no {member}")
                missing += 1
            elif r is None:
                print(f"UNKNOWN {os.path.relpath(f, root)}:{n} {obj}: {t}.{member} (engine base)")
                unknown += 1
            else:
                print(f"MISSING {os.path.relpath(f, root)}:{n} {obj}: {t} has no {member}")
                missing += 1
print(f"checked {len(files)} files, {len(classes)} classes, {missing} missing, {unknown} unknown")
sys.exit(1 if missing else 0)
