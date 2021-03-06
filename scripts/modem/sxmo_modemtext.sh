#!/bin/sh

# include common definitions
# shellcheck source=scripts/core/sxmo_icons.sh
. "$(dirname "$0")/sxmo_icons.sh"
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

set -e

err() {
	sxmo_log "$1"
	echo "$1" | dmenu
	kill $$
}

choosenumbermenu() {
	# Prompt for number
	NUMBER="$(
		printf %b "\n$icon_cls Cancel\n$icon_grp More contacts\n$(sxmo_contacts.sh | grep -E "\+[0-9]+$")" |
		awk NF |
		sxmo_dmenu_with_kb.sh -p "Number" -i |
		cut -d: -f2 |
		tr -d -- '- '
	)"

	if echo "$NUMBER" | grep -q "Morecontacts"; then
		NUMBER="$( #joined words without space is not a bug
			printf %b "\nCancel\n$(sxmo_contacts.sh --all)" |
				grep . |
				sxmo_dmenu_with_kb.sh -p "Number" -i |
				cut -d: -f2 |
				tr -d -- '- '
		)"
	fi

	if printf %s "$NUMBER" | grep -q "Cancel"; then
		exit 1
	elif NUMBER="$(sxmo_validnumber.sh "$NUMBER")"; then
		printf %s "$NUMBER"
	else
		notify-send "That doesn't seem like a valid number"
	fi
}

sendtextmenu() {
	if [ -n "$1" ]; then
		NUMBER="$1"
	else
		NUMBER="$(choosenumbermenu)"
	fi

	[ -z "$NUMBER" ] && exit 1

	DRAFT="$SXMO_LOGDIR/$NUMBER/draft.txt"
	if [ ! -f "$DRAFT" ]; then
		mkdir -p "$(dirname "$DRAFT")"
		echo 'Enter text message here' > "$DRAFT"
	fi

	sxmo_terminal.sh "$EDITOR" "$DRAFT"

	while true
	do
		ATTACHMENTS=
		if [ -f "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" ]; then
			# shellcheck disable=SC2016
			ATTACHMENTS="$(tr '\n' '\0' < "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" | xargs -0 -I{} sh -c 'printf " 📎 "$(basename {})" :: {}\n"')"
		fi

		RECIPIENTS=
		if [ "$(printf %s "$NUMBER" | xargs pn find | wc -l)" -gt 1 ]; then
			# shellcheck disable=SC2016
			RECIPIENTS="$(printf %s "$NUMBER" | xargs pn find | xargs -I{} sh -c 'printf "  "$(sxmo_contacts.sh --name {})" :: {}\n"')"
		fi

		CHOICES="$(printf "%s Send to %s (%s)\n%b\n%s Add Recipient\n%b\n%s Add Attachment\n%s Edit '%s'\n%s Cancel\n" \
			"$icon_snd" "$(sxmo_contacts.sh --name "$NUMBER")" "$NUMBER" "$RECIPIENTS" "$icon_usr" "$ATTACHMENTS" "$icon_att" "$icon_edt" \
			"$(cat "$SXMO_LOGDIR/$NUMBER/draft.txt")" "$icon_cls" \
			| awk NF
		)"

		CONFIRM="$(printf %b "$CHOICES" | dmenu -i -p "Confirm")"
		case "$CONFIRM" in
			*"Send"*)
				if sxmo_modemsendsms.sh "$NUMBER" - < "$DRAFT"; then
					rm "$DRAFT"
					sxmo_log "Sent text to $NUMBER"
					exit 0
				else
					err "Failed to send txt to $NUMBER"
				fi
				;;
			# Remove Attachment
			" 📎"*)
				FILE="$(printf %s "$CONFIRM" | awk -F' :: ' '{print $2}')"  
				sed -i "\|$FILE|d" "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
				if [ ! -s "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt" ] ; then
					rm "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
				fi
				;;
			# Remove Recipient
			" "*)
				if [ "$(printf %s "$NUMBER" | xargs pn find | wc -l)" -gt 1 ]; then 
					OLDNUMBER="$NUMBER"
					RECIPIENT="$(printf %s "$CONFIRM" | awk -F' :: ' '{print $2}')"
					NUMBER="$(printf %s "$OLDNUMBER" | sed "s/$RECIPIENT//")"
					mkdir -p "$SXMO_LOGDIR/$NUMBER"
					DRAFT="$SXMO_LOGDIR/$NUMBER/draft.txt"
					if [ -f "$SXMO_LOGDIR/$OLDNUMBER/draft.txt" ]; then
						# TODO: if there is already a DRAFT warn the user?
						mv "$SXMO_LOGDIR/$OLDNUMBER/draft.txt" "$DRAFT"
					fi
					if [ -f "$SXMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" ]; then
						mv "$SXMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" \
							"$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
					fi
					kill "$(lsof | grep "/$OLDNUMBER/sms.txt" | cut -f1)"
					[ -e "$SXMO_LOGDIR/$NUMBER/sms.txt" ] || touch "$SXMO_LOGDIR/$NUMBER/sms.txt"
					tailtextlog "$NUMBER" &
				fi
				;;
			*"Edit"*)
				sendtextmenu "$NUMBER"
				;;
			*"Add Attachment")
				ATTACHMENT="$(sxmo_files.sh "$HOME" --select-only)"
				if [ -f "$ATTACHMENT" ]; then
					printf "%s\n" "$ATTACHMENT" >> "$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
				fi
				;;
			*"Add Recipient")
				OLDNUMBER="$NUMBER"
				ADDEDNUMBER="$(choosenumbermenu)"

				if ! echo "$ADDEDNUMBER" | grep -q '^+'; then
					echo "We can't add numbers that don't start with +"
				elif echo "$OLDNUMBER" | grep -q "$ADDEDNUMBER"; then
					echo "Number already a recipient."
				else
					NUMBER="$(printf %s%s "$NUMBER" "$ADDEDNUMBER" | xargs pn find | sort -u | tr -d '\n')"
					mkdir -p "$SXMO_LOGDIR/$NUMBER"
					DRAFT="$SXMO_LOGDIR/$NUMBER/draft.txt"
					if [ -f "$SXMO_LOGDIR/$OLDNUMBER/draft.txt" ]; then
						# TODO: if there is already a DRAFT warn the user?
						mv "$SXMO_LOGDIR/$OLDNUMBER/draft.txt" "$DRAFT"
					fi
					if [ -f "$SXMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" ]; then
						mv "$SXMO_LOGDIR/$OLDNUMBER/draft.attachments.txt" \
						"$SXMO_LOGDIR/$NUMBER/draft.attachments.txt"
					fi
					kill "$(lsof | grep "/$OLDNUMBER/sms.txt" | cut -f1)"
					[ -e "$SXMO_LOGDIR/$NUMBER/sms.txt" ] || touch "$SXMO_LOGDIR/$NUMBER/sms.txt"
					tailtextlog "$NUMBER" &
				fi
				;;
			*"Cancel")
				exit 1
				;;
		esac
	done
}

conversationloop() {
	if [ -n "$1" ]; then
		NUMBER="$1"
	else
		NUMBER="$(choosenumbermenu)"
	fi

	set -e

	sxmo_keyboard.sh open 2>> "$SXMO_DEBUGLOG"

	while true; do
		DRAFT="$SXMO_LOGDIR/$NUMBER/draft.txt"
		if [ ! -f "$DRAFT" ]; then
			mkdir -p "$(dirname "$DRAFT")"
			touch "$DRAFT"
		fi

		"$EDITOR" "$DRAFT"
		sxmo_modemsendsms.sh "$NUMBER" - < "$DRAFT" || continue
		rm "$DRAFT"
	done
}

tailtextlog() {
	NUMBER="$1"
	CONTACTNAME="$(sxmo_contacts.sh | grep ": ${NUMBER}$" | cut -d: -f1)"
	[ "???" = "$CONTACTNAME" ] && CONTACTNAME="$CONTACTNAME ($NUMBER)"

	TERMNAME="$NUMBER SMS" sxmo_terminal.sh sh -c "tail -n9999 -f \"$SXMO_LOGDIR/$NUMBER/sms.txt\" | sed \"s|$NUMBER|$CONTACTNAME|g\""
}

readtextmenu() {
	# E.g. only display logfiles for directories that exist and join w contact name
	ENTRIES="$(
	printf %b "$icon_cls Close Menu\n$icon_edt Send a Text\n";
		sxmo_contacts.sh --texted | xargs -IL echo "L logfile"
	)"
	PICKED="$(printf %b "$ENTRIES" | sxmo_dmenu_with_kb.sh -p "Texts" -i)" || exit

	if echo "$PICKED" | grep "Close Menu"; then
		exit 1
	elif echo "$PICKED" | grep "Send a Text"; then
		sendtextmenu
	else
		tailtextlog "$(echo "$PICKED" | cut -d: -f2 | sed 's/^ //' | cut -d' ' -f1 )"
	fi
}

if [ "2" != "$#" ]; then
	readtextmenu
else
	"$@"
fi
