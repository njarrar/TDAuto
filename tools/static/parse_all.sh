#!/usr/bin/env bash
# Parses every .gd file with gdtoolkit's gdparse. Usage: parse_all.sh [path-to-gdparse]
set -u
GDPARSE="${1:-gdparse}"
cd "$(dirname "$0")/../.."
# Fixtures that must not parse (ADR-0001 V3, ADR-0007 V1).
SKIP="prototypes/adr-0001-checks/broken/broken_script.gd
prototypes/adr-0007-harness-check/cases/run4/v1_syntax_test.gd
prototypes/adr-0007-harness-check/cases/run9/helpers/v1_broken_helper.gd"
n=0; bad=0
while IFS= read -r f; do
	if printf '%s\n' "$SKIP" | grep -qxF "$f"; then continue; fi
	n=$((n + 1))
	if ! "$GDPARSE" "$f" > /dev/null 2>&1; then
		bad=$((bad + 1))
		echo "PARSE ERROR: $f"
		"$GDPARSE" "$f" 2>&1 | sed -n '2,8p'
	fi
done < <(find src tests tools prototypes -name '*.gd' -not -path '*/.godot/*' | sort)
echo "parsed $n files, $bad with errors"
[ "$bad" -eq 0 ]
