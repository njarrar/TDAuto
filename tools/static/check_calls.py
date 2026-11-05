#!/usr/bin/env python3
"""Static cross-file check for TowerRiot GDScript. Needs Python 3 only, no Godot.

Run from the repo root: python3 tools/static/check_calls.py

For each call `name.method(args)` where `name` is typed as a repo class (a member
`var name: Type`, a local `var name: Type`, or a parameter `name: Type`, scoped to
the function it is in), it reports a method the class (or a repo parent) does not
declare, and an argument count outside the method's signature. It also reports
`Type.member` on a repo class that declares no such member.

It cannot see methods a class inherits from a Godot class (Node, Control...), so
it stays silent on those. It prints observations and exits 1 if there are any; it
does not rank them.
"""
import glob
import re
import sys

ROOTS = ("src", "tests", "tools")
OBJECT_METHODS = {
    "new", "get", "set", "call", "callv", "has_method", "free", "get_script",
    "connect", "disconnect", "is_connected", "emit", "get_signal_connection_list",
    "get_signal_list", "get_script_signal_list", "get_class", "is_class",
    "notification", "set_meta", "get_meta", "has_meta", "get_instance_id",
    "to_string", "get_property_list", "property_list_changed",
    # Enum dictionaries.
    "keys", "values", "find_key", "size", "has",
}
TYPED = re.compile(r"\b(\w+)\s*:\s*([A-Z]\w+)\b")
MEMBER = re.compile(r"(?m)^(?:@onready\s+|@export\s+)?var\s+(\w+)\s*:\s*([A-Z]\w+)\b")
CALL = re.compile(r"\b(\w+)\.(\w+)\s*\(")
STATIC_ATTR = re.compile(r"\b([A-Z]\w+)\.([A-Za-z_]\w*)\b(?!\s*\()")
FUNC_START = re.compile(r"(?m)^(?=(?:static\s+)?func\s)")


def strip(text):
    text = re.sub(r'"""[\s\S]*?"""', '""', text)
    text = re.sub(r'r?"(?:\\.|[^"\\\n])*"', '""', text)
    text = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", text)
    return re.sub(r"#[^\n]*", "", text)


def balanced(text, i):
    """text[i] is '('. Returns the text inside the matching parentheses."""
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    return ""


def split_args(args):
    out, depth, cur = [], 0, ""
    for ch in args:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return [a for a in out if a.strip()]


class Index:
    def __init__(self, texts):
        self.parent, self.names, self.sigs = {}, {}, {}
        for text in texts.values():
            m = re.search(r"^class_name\s+(\w+)(?:\s+extends\s+(\w+))?", text, re.M)
            if not m:
                continue
            cls = m.group(1)
            self.parent[cls] = m.group(2)
            names = set(re.findall(
                r"(?m)^(?:const|var|signal|enum|class|static var|@onready var|@export var)\s+(\w+)", text))
            for body in re.findall(r"(?ms)^enum\s+\w+\s*\{([^}]*)\}", text):
                names |= set(re.findall(r"\b([A-Z_][A-Z0-9_]*)\b", body))
            sigs = {}
            for fm in re.finditer(r"(?m)^(?:static\s+)?func\s+(\w+)\s*\(", text):
                params = split_args(balanced(text, fm.end() - 1))
                variadic = any(p.strip().startswith("...") for p in params)
                required = sum(1 for p in params if "=" not in p and not p.strip().startswith("..."))
                sigs[fm.group(1)] = (required, None if variadic else len(params))
            self.names[cls] = names | set(sigs)
            self.sigs[cls] = sigs

    def known(self, cls):
        return cls in self.names

    def chain(self, cls):
        while cls in self.names:
            yield cls
            cls = self.parent.get(cls)

    def godot_rooted(self, cls):
        last = None
        for last in self.chain(cls):
            pass
        root = self.parent.get(last) if last else None
        return root not in (None, "RefCounted", "Object")

    def has(self, cls, name):
        return any(name in self.names[c] for c in self.chain(cls))

    def sig(self, cls, name):
        for c in self.chain(cls):
            if name in self.sigs[c]:
                return self.sigs[c][name]
        return None


def check_file(path, text, index):
    out = []
    members = {m.group(1): m.group(2) for m in MEMBER.finditer(text) if index.known(m.group(2))}
    for chunk in FUNC_START.split(text):
        types = dict(members)
        for m in TYPED.finditer(chunk):
            if index.known(m.group(2)):
                types[m.group(1)] = m.group(2)
        for m in CALL.finditer(chunk):
            var, meth = m.groups()
            cls = types.get(var) or (var if index.known(var) else None)
            if cls is None or meth in OBJECT_METHODS:
                continue
            sig = index.sig(cls, meth)
            if sig is None:
                if not index.has(cls, meth) and not index.godot_rooted(cls):
                    out.append(f"{path}: {var}.{meth}(): {cls} declares no {meth}")
                continue
            given = len(split_args(balanced(chunk, m.end() - 1)))
            required, most = sig
            if given < required or (most is not None and given > most):
                span = f"{required} to {most}" if most is not None else f"{required} or more"
                out.append(f"{path}: {var}.{meth}() given {given} args; {cls}.{meth} takes {span}")
    for m in STATIC_ATTR.finditer(text):
        cls, attr = m.groups()
        if index.known(cls) and attr not in OBJECT_METHODS and not index.has(cls, attr) \
                and not index.godot_rooted(cls):
            out.append(f"{path}: {cls}.{attr}: not declared on {cls}")
    return out


def main():
    files = sorted(f for root in ROOTS for f in glob.glob(root + "/**/*.gd", recursive=True))
    texts = {f: strip(open(f, encoding="utf-8").read()) for f in files}
    index = Index(texts)
    findings = sorted({x for f in files for x in check_file(f, texts[f], index)})
    for line in findings:
        print(line)
    print(f"checked {len(files)} files, {len(index.names)} classes, {len(findings)} findings")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
