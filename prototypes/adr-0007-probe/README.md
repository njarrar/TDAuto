# adr-0007-probe

Probes for ADR-0007, 4.7.2 macOS arm64. **Caveat: desktop debug editor only, headless, and run without a prior `--import`.** Repeat on a CI Linux runner and a release export before ADR-0007 is Accepted.

| Script | Output | What it shows |
|---|---|---|
| `probe.gd`, `bad.gd`, `good.gd` | `output.txt` | `load()` of a script with a syntax error returns a non-null GDScript; `GdUnitCmdTool.gd` without a class cache prints a parse error and exits 0 |
| `probe2.gd` | `output.txt` | `can_instantiate()` is false and `reload()` is 43 on the broken script |
| `review_probe.gd`, `base_typed.gd`, `child_typed.gd`, `missing_type.gd`, `named.gd`, `broken.tscn` | `output-review.txt` | godot-specialist review: typed-return override and unknown type both fail `can_instantiate()`; a `.tscn` with a missing `ext_resource` loads non-null; `get_global_class_list()` is `[]` without import; `get_global_name()` works |

The gdUnit4 run used a symlink to the repo's `addons/`, since removed; `tests_empty/` is the empty test directory.
