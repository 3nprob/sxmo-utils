#!/bin/sh
tmpfile=$(mktemp /tmp/st-edit.XXXXXX)
trap  'rm "$tmpfile"' 0 1 15
cat > "$tmpfile"
sxmo_terminal.sh "$EDITOR" "$tmpfile"
