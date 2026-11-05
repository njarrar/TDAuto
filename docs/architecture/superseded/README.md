# Superseded ADR set

A second set of ADRs 0001 to 0011 was written and reviewed on `main` (PRs #22 to #24)
while the set in `docs/architecture/` was written on the branch that built the game code.
On merging (2026-11-05) the user chose the branch's set, because the code in `src/` and
its 589 passing tests follow it. This folder keeps `main`'s set for history:

- `adr-0001-...-main.md` and `adr-0002` to `adr-0011`: `main`'s versions. Not in force.
- `architecture-review-2026-11-04.md`, `-04b.md` and `architecture-review-2026-11-05-main.md`:
  `main`'s reviews of that set. The last ended FAIL, with a fix round in PR #24.
- `architecture-review-2026-11-05b-main.md`: the independent re-review of that fix round. It
  ended FAIL on one new blocker (a dependency cycle between that set's ADR-0007 and ADR-0011)
  and was finished after the set was superseded, so it gates nothing.

Nothing here is a decision. Before accepting an ADR in `docs/architecture/`, it is worth
checking whether `main`'s review raised a point against the same topic that the branch's
review (`docs/architecture/architecture-review-2026-11-05.md`) did not.
