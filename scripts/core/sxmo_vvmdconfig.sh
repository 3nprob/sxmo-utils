#!/bin/sh

# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

set -e

VVMCONFIG="$VVM_BASE_DIR/vvm"

defaultconfig() {
	cat <<EOF
[Modem Manager]
"Enable VVM": true
"VVM Type": cvvm
"Destination Number": 127
EOF
}

confirm() {
	printf "No\nYes\n" | dmenu -p "Are you sure ?" | grep -q "^Yes$"
}

valuemenu() {
	printf %s "$2" | dmenu -p "$1"
}

editfile() {
	FILE="$1"

	while : ; do
		CHOICE="$(grep "=" < "$FILE" |
			xargs -0 printf "$icon_ret Close Menu\n$icon_rol Default Config\n%b" |
			dmenu -p "VVM Config"
		)"

		case "$CHOICE" in
			"$icon_ret Close Menu")
				return
				;;
			"$icon_rol Default Config")
				confirm && defaultconfig > "$FILE"
				continue
				;;
		esac

		KEY="$(printf %s "$CHOICE" | cut -d= -f1)"
		VALUE="$(printf %s "$CHOICE" | cut -d= -f2-)"
		NEWVALUE="$(valuemenu "$KEY" "$VALUE")"

		sed -i "$FILE" -e "s|^$CHOICE$|$KEY=$NEWVALUE|"
	done
}

newfile() {
	tmp="$(mktemp)"
	defaultfile > "$tmp"
	editfile "$tmp"
	mv "$tmp" "$MMSCONFIG"
}

mkdir -p "$VVM_BASE_DIR"

sxmo_daemons.sh stop vvmd

finish() {
	sxmo_daemons.sh start vvmd vvmd
}
trap 'finish' EXIT

if [ -f "$VVMCONFIG" ]; then
	editfile "$VVMCONFIG"
else
	newfile
fi
