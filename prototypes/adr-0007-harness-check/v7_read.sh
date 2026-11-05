#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V7: read the export preset files.
# Usage: ./v7_read.sh <project copy folder> [exported .zip or .apk]
# Prints filter keys and which file holds keystore fields. Values of any
# password, user or keystore key are replaced, never printed.
set -u
P="${1:?project folder}"
PKG="${2:-}"
for f in "$P/export_presets.cfg" "$P/.godot/export_credentials.cfg"; do
	echo "== $f"
	if [ ! -f "$f" ]; then
		echo "absent"
		continue
	fi
	grep -nE '^(name|platform|export_filter|include_filter|exclude_filter)=' "$f"
	grep -niE 'password|keystore|user' "$f" | sed -E 's/=.*/=<value hidden>/'
	echo "non-empty password lines: $(grep -cE 'password[^=]*=".+"' "$f")"
done
if [ -n "$PKG" ]; then
	echo "== $PKG"
	echo "entries under tests/: $(unzip -l "$PKG" | grep -c 'tests/')"
	unzip -l "$PKG" | grep 'tests/' | head -n 10
fi
