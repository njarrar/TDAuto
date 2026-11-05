# Static checks without Godot

For sessions with no Godot binary (for example a cloud container). They do not
replace the engine run: they catch syntax errors and cross-file name and call
mismatches only. Types, engine APIs and behaviour need Godot.

1. **Syntax** (gdtoolkit's GDScript 4 parser):

   ```bash
   python3 -m venv /tmp/gdt && /tmp/gdt/bin/pip install -q "gdtoolkit==4.*"
   ```

   ```bash
   tools/static/parse_all.sh /tmp/gdt/bin/gdparse
   ```

   Files under `prototypes/` that are meant not to parse are listed in
   `parse_all.sh` and skipped.

2. **Names and calls** (Python 3 only):

   ```bash
   python3 tools/static/check_calls.py
   ```

   Reports a method or member a repo class does not declare, and an argument
   count outside a method's signature, for calls through variables typed as repo
   classes. Both scripts print observations and exit 1 if there are any.

Both were seen to fail on seeded bad input on 2026-11-05.

## check_callables.py

`python3 tools/static/check_callables.py` reports method Callables (`obj.method` passed
to `connect` or as an argument) whose method the typed object's class does not declare.
It found `HudLogic._on_became_idle` missing after Mac run 1. Members inherited from an
engine class (a Control's `visible`) print as UNKNOWN, since the script cannot see engine
classes. Exit 1 on any MISSING line.
