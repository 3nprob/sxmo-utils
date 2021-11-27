#!/usr/bin/env sh
trap gracefulexit INT TERM

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

gracefulexit() {
	printf "Gracefully exiting %s\n" "$0">&2
	kill -9 0
}

confirm() {
	PICKED="$(printf "Yes\nNo\n" | sxmo_dmenu.sh -p "Confirm $1")"

	if [ "$PICKED" = "Yes" ]; then
		return 0
	else
		return 1
	fi
}

sxmo_type() {
	sxmo_type.sh -s 200 "$@" # dunno why this is necessary but it sucks without
}

programchoicesinit() {
	XPROPOUT="$(sxmo_wm.sh focusedwindow)"
	WMCLASS="${1:-$(printf %s "$XPROPOUT" | grep app: | cut -d" " -f2- | tr '[:upper:]' '[:lower:]')}"
	if [ -z "$XPROPOUT" ]; then
		printf "sxmo_appmenu: detected no active window, no problem, opening system menu\n" >&2
	else
		printf "sxmo_appmenu: opening menu for wmclass %s\n" "$WMCLASS" >&2
	fi

	case "$WMCLASS" in
	scripts )
		# Scripts menu
		# shellcheck disable=SC2015
		CHOICES="
			$(
				if [ -f "$XDG_CONFIG_HOME/sxmo/userscripts" ]; then
					cat "$XDG_CONFIG_HOME/sxmo/userscripts"
				elif [ -d "$XDG_CONFIG_HOME/sxmo/userscripts" ]; then
					find "$XDG_CONFIG_HOME/sxmo/userscripts" \( -type f -o -type l \) -print0 |
						xargs -IF basename F |
						awk "{printf \"$icon_itm %s ^ 0 ^ $XDG_CONFIG_HOME/sxmo/userscripts/%s \\n\", \$0, \$0}" |
						sort -f
				fi
			)
			$icon_mic Record          ^ 0 ^ sxmo_record.sh
			$icon_red Reddit          ^ 0 ^ sxmo_reddit.sh
			$icon_rss RSS             ^ 0 ^ sxmo_rss.sh
			$icon_cam Screenshot      ^ 0 ^ sxmo_screenshot.sh
			$icon_cam Screenshot (selection)	^ 0 ^ sxmo_screenshot.sh selection
			$icon_tmr Timer           ^ 0 ^ sxmo_timer.sh
			$icon_ytb Youtube         ^ 0 ^ sxmo_youtube.sh video
			$icon_ytb Youtube (Audio) ^ 0 ^ sxmo_youtube.sh audio
			$icon_glb Web Search      ^ 0 ^ sxmo_websearch.sh
			$icon_wtr Weather         ^ 0 ^ sxmo_weather.sh
			$icon_cfg Edit Userscripts ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/userscripts
			"
		WINNAME=Scripts
		;;
	applications )
		# Apps menu
		CHOICES="$(sxmo_hooks.sh apps)"
		WINNAME=Apps
		;;
	config )
		# System Control menu
		CHOICES="
			$icon_aru Brightness               ^ 1 ^ sxmo_brightness.sh up
			$icon_ard Brightness               ^ 1 ^ sxmo_brightness.sh down
			$icon_phn Modem Toggle               ^ 1 ^ sxmo_modemmonitortoggle.sh
			$icon_phn Modem Restart              ^ 1 ^ sxmo_modemmonitortoggle.sh restart
			$icon_inf Modem Info                 ^ 0 ^ sxmo_modeminfo.sh
			$icon_phl Modem Log                  ^ 0 ^ sxmo_modemlog.sh
			$icon_img Config MMS                 ^ 1 ^ sxmo_mmsdconfig.sh
			$icon_wif Wifi $(
				rfkill -rn | grep wlan | grep -qE "unblocked unblocked" &&
				printf %b "On → Off" ||  printf %b "Off → On";
				printf %b "^ 1 ^ doas sxmo_wifitoggle.sh"
			)
			$(pgrep -f sxmo_lock_idle.sh > /dev/null && echo "$icon_cfg Stop lock idle ^ 1 ^ pkill -f sxmo_lock_idle.sh" || echo "$icon_cfg Start lock idle ^ 1 ^ setsid -f sxmo_lock_idle.sh")
			$icon_cfg Invert Colors              ^ 1 ^ xcalib -a -invert
			$icon_clk Change Timezone            ^ 1 ^ sxmo_timezonechange.sh
			$icon_ror Autorotate $(
				pgrep -f "$(command -v sxmo_rotateautotoggle.sh)" > /dev/null &&
				printf %b "On → Off ^ 0 ^ sxmo_rotateautotoggle.sh &" ||  printf %b "Off → On ^ 0 ^ sxmo_rotateautotoggle.sh &"
			)
			$icon_lck Proximity Lock $(
				pgrep -f "$(command -v sxmo_proximitylock.sh)" > /dev/null &&
				printf %b "On → Off ^ 0 ^ sxmo_proximitylocktoggle.sh &" ||  printf %b "Off → On ^ 0 ^ sxmo_proximitylocktoggle.sh &"
			)
			$icon_ror Rotate                     ^ 1 ^ sxmo_rotate.sh rotate
			$icon_rol Toggle WM                  ^ 1 ^ sxmo_terminal.sh sxmo_wmtoggle.sh
			$icon_upc Upgrade Pkgs               ^ 0 ^ sxmo_terminal.sh sxmo_upgrade.sh
			$icon_cfg Edit configuration         ^ 0 ^ sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/xinit
			$(command -v pmos-tweaks >/dev/null && echo "$icon_cfg PostmarketOS Tweaks	     ^ 0 ^ GDK_SCALE=1 pmos-tweaks")
			$icon_inf Version                    ^ 0 ^ sxmo_terminal.sh sxmo_version.sh --block
		"
		WINNAME=Config
		;;
	audioout )
		# Audio Out menu
		CURRENTDEV="$(sxmo_audiocurrentdevice.sh)"
		CHOICES="
			$icon_hdp Headphones $([ "$CURRENTDEV" = "Headphone" ] && echo "$icon_chk") ^ 1 ^ sxmo_audioout.sh Headphones
			$icon_spk Speaker $([ "$CURRENTDEV" = "Line Out" ] && echo "$icon_chk")     ^ 1 ^ sxmo_audioout.sh Speaker
			$icon_phn Earpiece $([ "$CURRENTDEV" = "Earpiece" ] && echo "$icon_chk")    ^ 1 ^ sxmo_audioout.sh Earpiece
			$icon_mut None $([ "$CURRENTDEV" = "None" ] && echo "$icon_chk")            ^ 1 ^ sxmo_audioout.sh None
			$icon_aru Volume up                                       ^ 1 ^ sxmo_vol.sh up
			$icon_ard Volume down                                     ^ 1 ^ sxmo_vol.sh down
		"
		WINNAME=Audio
		;;
	power )
		# Power menu
		CHOICES="
			$icon_lck Lock               ^ 0 ^ sxmo_screenlock.sh lock
			$icon_lck Lock (Screen off)  ^ 0 ^ sxmo_screenlock.sh off
			$icon_zzz Suspend            ^ 0 ^ sxmo_screenlock.sh off && sxmo_screenlock.sh crust
			$icon_out Logout             ^ 0 ^ confirm Logout && pkill -9 dwm || pkill -9 sway
			$icon_rld Reboot             ^ 0 ^ confirm Reboot && sxmo_terminal.sh doas reboot
			$icon_pwr Poweroff           ^ 0 ^ confirm Poweroff && sxmo_terminal.sh doas poweroff
		"
		WINNAME=Power
		;;
	*mpv* )
		# MPV
		CHOICES="
			$icon_pau Pause        ^ 0 ^ sxmo_type -k Space
			$icon_fbw Seek       ^ 1 ^ sxmo_type -k Left
			$icon_ffw Seek       ^ 1 ^ sxmo_type -k Right
			$icon_aru App Volume ↑ ^ 1 ^ sxmo_type 0
			$icon_ard App Volume ↓ ^ 1 ^ sxmo_type 9
			$icon_aru Speed up      ^ 1 ^ sxmo_type -k bracketRight
			$icon_ard Speed down    ^ 1 ^ sxmo_type -k bracketLeft
			$icon_cam Screenshot   ^ 1 ^ sxmo_type s
			$icon_itm Loopmark     ^ 1 ^ sxmo_type l
			$icon_inf Info         ^ 1 ^ sxmo_type i
			$icon_inf Seek Info    ^ 1 ^ sxmo_type o
		"
		WINNAME=Mpv
		;;
	*feh* )
		# Feh
		CHOICES="
			$icon_arr Next          ^ 1 ^ sxmo_type -k Space
			$icon_arl Previous      ^ 1 ^ sxmo_type -k BackSpace
			$icon_zmi Zoom in       ^ 1 ^ sxmo_type -k up
			$icon_zmo Zoom out      ^ 1 ^ sxmo_type -k down
			$icon_exp Zoom to fit   ^ 1 ^ sxmo_type -k slash
			$icon_shr Zoom to fill  ^ 1 ^ sxmo_type '!'
			$icon_rol Rotate        ^ 1 ^ sxmo_type -k less
			$icon_ror Rotate        ^ 1 ^ sxmo_type -k greater
			$icon_a2y Flip          ^ 1 ^ sxmo_type -k underscore
			$icon_a2x Mirror        ^ 1 ^ sxmo_type -k bar
			$icon_inf Toggle filename ^ 1 ^ sxmo_type d
		"
		WINNAME=Feh
		;;
	*sxiv* )
		# Sxiv
		CHOICES="
			$icon_arr Next          ^ 1 ^ sxmo_type -k Space
			$icon_arl Previous      ^ 1 ^ sxmo_type -k BackSpace
			$icon_zmi Zoom in       ^ 1 ^ sxmo_type -k equal
			$icon_zmo Zoom out      ^ 1 ^ sxmo_type -k minus
			$icon_rol Rotate        ^ 1 ^ sxmo_type -k less
			$icon_ror Rotate        ^ 1 ^ sxmo_type -k greater
			$icon_a2y Flip          ^ 1 ^ sxmo_type -k question
			$icon_a2x Mirror        ^ 1 ^ sxmo_type -k bar
			$icon_grd Thumbnail     ^ 0 ^ sxmo_type -k Return
		"
		WINNAME=Sxiv
		;;
	*sthotkeys* )
		#  St hotkeys
		CHOICES="
			Send Ctrl-C      ^ 0 ^ sxmo_type -M Ctrl -k c
			Send Ctrl-Z      ^ 0 ^ sxmo_type -M Ctrl -k z
			Send Ctrl-L      ^ 0 ^ sxmo_type -M Ctrl -k l
			Send Ctrl-D      ^ 0 ^ sxmo_type -M Ctrl -k d
			Send Ctrl-A      ^ 0 ^ sxmo_type -M Ctrl -k a
			Send Ctrl-B      ^ 0 ^ sxmo_type -M Ctrl -k b
			Send ESC:w       ^ 0 ^ sxmo_type -k Escape -s 300 -M Shift -k semicolon -m Shift -k w -k Return
			Send ESC:wq      ^ 0 ^ sxmo_type -k Escape -s 300 -M Shift -k semicolon -m Shift -k w -k q -k Return
			Send ESC:wq!     ^ 0 ^ sxmo_type -k Escape -s 300 -M Shift -k semicolon -m Shift -k q -k exclam -k Return
		"
		WINNAME=St
		;;
	*foot*|*st* )
		# First we try to handle the app running inside the terminal:
		WMNAME="${1:-$(printf %s "$XPROPOUT" | grep title: | cut -d" " -f2- | tr '[:upper:]' '[:lower:]')}"
		if printf %s "$WMNAME" | grep -qi -E "(vi|vim|vis|nvim|neovim|kakoune)"; then
			#Vim in foot
			CHOICES="
				$icon_cls Save and Quit    ^ 0 ^ sxmo_type -k Escape -s 300 ':wq' -k Return
				$icon_aru Scroll up        ^ 1 ^ sxmo_type -M Ctrl u
				$icon_ard Scroll down      ^ 1 ^ sxmo_type -M Ctrl d
				$icon_trm Command prompt   ^ 0 ^ sxmo_type -k Escape -s 300 ':'
				$icon_cls Save             ^ 0 ^ sxmo_type -k Escape -s 300 ':w' -k Return
				$icon_cls Quit without saving  ^ 0 ^ sxmo_type -k Escape -s 300 ':q!' -k Return
				$icon_pst Paste Selection  ^ 0 ^ sxmo_type -k Escape -s 300 -k quotedbl -k asterisk -k p
				$icon_pst Paste Clipboard  ^ 0 ^ wl-paste
				$icon_fnd Search           ^ 0 ^ sxmo_type -k Escape -s 300 /
				$icon_zmi Zoom in          ^ 1 ^ sxmo_type -k Prior
				$icon_zmo Zoom out         ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu    ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=Vim
		elif printf %s "$WMNAME" | grep -qi -w "nano"; then
			#Nano in foot
			CHOICES="
				$icon_aru Scroll up       ^ 1 ^ sxmo_type -k Prior
				$icon_ard Scroll down     ^ 1 ^ sxmo_type -k Next
				$icon_sav Save            ^ 0 ^ sxmo_type -M Ctrl o
				$icon_cls Quit            ^ 0 ^ sxmo_type -M Ctrl x
				$icon_pst Paste           ^ 0 ^ sxmo_type -M Ctrl u
				$icon_itm Type complete   ^ 0 ^ sxmo_type -M Shift -M Ctrl u
				$icon_cpy Copy complete   ^ 0 ^ sxmo_type -M Shift -M Ctrl i
				$icon_zmi Zoom in         ^ 1 ^ sxmo_type -k Prior
				$icon_zmo Zoom out        ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu   ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=Nano
		elif printf %s "$WMNAME" | grep -qi -w "tuir"; then
			#tuir (reddit client) in foot
			CHOICES="
				$icon_aru Previous      ^ 1 ^ sxmo_type k
				$icon_ard Next          ^ 1 ^ sxmo_type j
				$icon_aru Scroll up     ^ 1 ^ sxmo_type -k Prior
				$icon_ard Scroll down   ^ 1 ^ sxmo_type -k Next
				$icon_ret Open          ^ 0 ^ sxmo_type o
				$icon_arl Back          ^ 0 ^ sxmo_type h
				$icon_arr Comments      ^ 0 ^ sxmo_type l
				$icon_edt Post          ^ 0 ^ sxmo_type c
				$icon_rld Refresh       ^ 0 ^ sxmo_type r
				$icon_cls Quit          ^ 0 ^ sxmo_type q
				$icon_zmi Zoom in       ^ 1 ^ sxmo_type -k Prior
				$icon_zmo Zoom out      ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=tuir
		elif printf %s "$WMNAME" | grep -qi -w "w3m"; then
			#w3m
			CHOICES="
				$icon_arl Back          ^ 1 ^ sxmo_type b
				$icon_glb Goto URL        ^ 1 ^ sxmo_type u
				$icon_arr Next Link       ^ 1 ^ sxmo_type -k Tab
				$icon_arl Previous Link   ^ 1 ^ sxmo_type -M Shift -k Tab
				$icon_tab Open tab        ^ 0 ^ sxmo_type t
				$icon_cls Close tab       ^ 0 ^ sxmo_type -M Ctrl q
				$icon_itm Next tab        ^ 1 ^ sxmo_type -k braceRight
				$icon_itm Previous tab    ^ 1 ^ sxmo_type -k braceLeft
				$icon_zmi Zoom in          ^ 1 ^ sxmo_type -k Prior
				$icon_zmo Zoom out          ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu   ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=w3m
		elif printf %s "$WMNAME" | grep -qi -w "ncmpcpp"; then
			#ncmpcpp
			CHOICES="
				$icon_lst Playlist        ^ 0 ^ sxmo_type 1
				$icon_fnd Browser         ^ 0 ^ sxmo_type 2
				$icon_fnd Search          ^ 0 ^ sxmo_type 3
				$icon_nxt Next track      ^ 0 ^ sxmo_type -k greater
				$icon_prv Previous track  ^ 0 ^ sxmo_type -k less
				$icon_pau Pause           ^ 0 ^ sxmo_type p
				$icon_stp Stop            ^ 0 ^ sxmo_type s
				$icon_rld Toggle repeat   ^ 0 ^ sxmo_type r
				$icon_sfl Toggle random   ^ 0 ^ sxmo_type z
				$icon_itm Toggle consume  ^ 0 ^ sxmo_type R
				$icon_mnu Terminal menu   ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=ncmpcpp
		elif printf %s "$WMNAME" | grep -qi -w "aerc"; then
			#aerc
			CHOICES="
				$icon_pau Archive	  ^ 1 ^ sxmo_type ':archive flat' -k Return
				$icon_nxt Next Tab	  ^ 0 ^ sxmo_type ':next-tab' -k Return
				$icon_prv Previous Tab	  ^ 0 ^ sxmo_type ':prev-tab' -k Return
				$icon_cls Close Tab	  ^ 0 ^ sxmo_type ':close' -k Return
				$icon_itm Next Part	  ^ 1 ^ sxmo_type ':next-part' -k Return
				$icon_trm xdg-open Part	  ^ 0 ^ sxmo_type ':open' -k Return
			"
			WINNAME=aerc
		elif printf %s "$WMNAME" | grep -qi -E -w "(less|mless)"; then
			#less
			CHOICES="
				$icon_arr Page next       ^ 1 ^ sxmo_type ':n' -k Return
				$icon_arl Page previous   ^ 1 ^ sxmo_type ':p' -k Return
				$icon_cls Quit            ^ 0 ^ sxmo_type q
				$icon_zmi Zoom in         ^ 1 ^ sxmo_type -M Ctrl +
				$icon_zmo Zoom out        ^ 1 ^ sxmo_type -M Ctrl -k Minus
				$icon_aru Scroll up       ^ 1 ^ sxmo_type -k Prior
				$icon_ard Scroll down     ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=less
		elif printf %s "$WMNAME" | grep -qi -w "weechat"; then
			#weechat
			CHOICES="
				$icon_msg Hotlist Next            ^ 1 ^ sxmo_type -M Alt a
				$icon_arl History Previous        ^ 1 ^ sxmo_type -M Alt -k Less
				$icon_arr History Next            ^ 1 ^ sxmo_type -M Alt -k Greater
				$icon_trm Buffer                  ^ 0 ^ sxmo_type '/buffer '
				$icon_aru Scroll up               ^ 1 ^ sxmo_type -k Prior
				$icon_ard Scroll down             ^ 1 ^ sxmo_type -k Next
				$icon_mnu Terminal menu ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=weechat
		elif printf %s "$WMNAME" | grep -qi -w "sms"; then
			# TODO: Ensure $number is valid.
			number="$(printf %s "$WMNAME" | sed -e 's|^\"||' -e 's|\"$||' | cut -f1 -d' ')"
			#sms
			CHOICES="
				$icon_msg Conversation   ^ 0 ^ sxmo_terminal.sh sxmo_modemtext.sh conversationloop $number
				$icon_msg Reply          ^ 0 ^ sxmo_modemtext.sh sendtextmenu $number
				$icon_phn Call           ^ 0 ^ sxmo_modemdial.sh $number
				$([ -d "$LOGDIR/$number/attachments" ] && echo "$icon_att View Attachments ^ 1 ^ sxmo_files.sh $LOGDIR/$number/attachments")
				$(sxmo_contacts.sh --name "$number" | grep -q '???' || echo "$icon_usr Add to contacts ^ 0 ^ sxmo_contactmenu.sh newcontact $number")
				$icon_aru Scroll up       ^ 1 ^ sxmo_type -M Shift -M Ctrl b
				$icon_ard Scroll down     ^ 1 ^ sxmo_type -M Shift -M Ctrl f
				$icon_mnu Terminal menu ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=sms
		elif printf %s "$WMNAME" | grep -qi -w "cmus"; then
			# cmus
			# requires `:set set_term_title=false` in cmus to match the application
			CHOICES="
				$icon_itm Play            ^ 0 ^ cmus-remote -p
				$icon_pau Pause           ^ 0 ^ cmus-remote -u
				$icon_stp Stop            ^ 0 ^ cmus-remote -s
				$icon_nxt Next track      ^ 0 ^ cmus-remote -n
				$icon_prv Previous track  ^ 0 ^ cmus-remote -r
				$icon_rld Toggle repeat   ^ 0 ^ cmus-remote -R
				$icon_sfl Toggle random   ^ 0 ^ cmus-remote -S
				$icon_mnu Terminal menu   ^ 0 ^ sxmo_appmenu.sh $WMCLASS
			"
			WINNAME=cmus
		else
			# Now we fallback to the default terminal menu
			case "$WMCLASS" in
				*st*)
					STSELMODEON="$(
						printf %s "$XPROPOUT" | grep -E '^_ST_SELMODE.+=' | cut -d= -f2 | tr -d ' '
					)"
					CHOICES="
						$icon_itm Type complete   ^ 0 ^ sxmo_type -M Ctrl -M Shift -k u
						$icon_cpy Copy complete   ^ 0 ^ sxmo_type -M Ctrl -M Shift -k i
						$icon_itm Selmode $(
						  [ "$STSELMODEON" = 1 ] &&
						  printf %b 'On → Off' ||
						  printf %b 'Off → On'
						  printf %b '^ 0 ^ sxmo_type -M Ctrl -M Shift -k s'
						)
						$([ "$STSELMODEON" = 1 ] && echo 'Copy selection ^ 0 ^ sxmo_type -M Ctrl -M Shift -k c')
						$icon_pst Paste           ^ 0 ^ sxmo_type -M Ctrl -M Shift -k v
						$icon_zmi Zoom in         ^ 1 ^ sxmo_type -M Ctrl -M Shift -k Prior
						$icon_zmo Zoom out        ^ 1 ^ sxmo_type -M Ctrl -M Shift -k Next
						$icon_aru Scroll up       ^ 1 ^ sxmo_type -M Ctrl -M Shift -k b
						$icon_ard Scroll down     ^ 1 ^ sxmo_type -M Ctrl -M Shift -k f
						$icon_a2x Invert          ^ 1 ^ sxmo_type -M Ctrl -M Shift -k x
						$icon_kbd Hotkeys         ^ 0 ^ sxmo_appmenu.sh sthotkeys
					"
					WINNAME=St
					;;
				*foot*)
					CHOICES="
						$icon_cpy Copy		  ^ 0 ^ sxmo_type -M Shift -M Ctrl c
						$icon_pst Paste           ^ 0 ^ sxmo_type -M Shift -M Ctrl v
						$icon_zmi Zoom in         ^ 1 ^ sxmo_type -M Ctrl +
						$icon_zmo Zoom out        ^ 1 ^ sxmo_type -M Ctrl -k Minus
						$icon_aru Scroll up       ^ 1 ^ sxmo_type -M Shift -k Prior
						$icon_ard Scroll down     ^ 1 ^ sxmo_type -M Shift -k Next
						$icon_lnk URL Mode        ^ 0 ^ sxmo_type -M Shift -M Ctrl -k u
						$icon_kbd Hotkeys         ^ 0 ^ sxmo_appmenu.sh sthotkeys
					"
					WINNAME=Foot
					;;
			esac
		fi
	;;
	*zathura* )
		# Zathura
		CHOICES="
			$icon_flt Open		^ 0 ^ sxmo_type -k o
			$icon_zmi Zoom		^ 1 ^ sxmo_type -k plus
			$icon_zmo Zoom		^ 1 ^ sxmo_type -k minus
			$icon_arl History	^ 1 ^ sxmo_type -M Ctrl -k o
			$icon_arr History	^ 1 ^ sxmo_type -M Ctrl -k i
			$icon_cfg Invert	^ 0 ^ sxmo_type -M Ctrl -k r
			$icon_flt Index		^ 0 ^ sxmo_type -k Tab
		"
		WINNAME=Zathura
		;;
	*netsurf* )
		# Netsurf
		CHOICES="
			$icon_flt Pipe URL          ^ 0 ^ sxmo_urlhandler.sh
			$icon_zmi Zoom            ^ 1 ^ sxmo_type -M Ctrl -k plus
			$icon_zmo Zoom            ^ 1 ^ sxmo_type -M Ctrl -k minus
			$icon_arl History        ^ 1 ^ sxmo_type -M Alt -k Left
			$icon_arr History        ^ 1 ^ sxmo_type -M Alt -k Right
		"
		WINNAME=Netsurf
		;;
	*surf* )
		# Surf
		CHOICES="
			$icon_glb Navigate    ^ 0 ^ sxmo_type -M Ctrl g
			$icon_lnk Link Menu   ^ 0 ^ sxmo_type -M Ctrl d
			$icon_flt Pipe URL    ^ 0 ^ sxmo_urlhandler.sh
			$icon_fnd Search Page ^ 0 ^ sxmo_type -M Ctrl f
			$icon_fnd Find Next   ^ 0 ^ sxmo_type -M Ctrl n
			$icon_zmi Zoom      ^ 1 ^ sxmo_type -M Shift -M Ctrl k
			$icon_zmo Zoom      ^ 1 ^ sxmo_type -M Shift -M Ctrl j
			$icon_aru Scroll    ^ 1 ^ sxmo_type -M Shift -k Space
			$icon_ard Scroll    ^ 1 ^ sxmo_type -k Space
			$icon_itm JS Toggle   ^ 1 ^ sxmo_type -M Shift -M Ctrl s
			$icon_arl History   ^ 1 ^ sxmo_type -M Ctrl h
			$icon_arr History   ^ 1 ^ sxmo_type -M Ctrl l
			$icon_rld Refresh     ^ 0 ^ sxmo_type -M Shift -M Ctrl r
		"
		WINNAME=Surf
		;;
	*firefox* )
		# Firefox
		CHOICES="
			$icon_flt Pipe URL          ^ 0 ^ sxmo_urlhandler.sh
			$icon_tab New Tab           ^ 0 ^ sxmo_type -M Ctrl t
			$icon_win New Window        ^ 0 ^ sxmo_type -M Ctrl n
			$icon_cls Close Tab         ^ 0 ^ sxmo_type -M Ctrl w
			$icon_zmi Zoom            ^ 1 ^ sxmo_type -M Ctrl -k plus
			$icon_zmo Zoom            ^ 1 ^ sxmo_type -M Ctrl -k minus
			$icon_arl History        ^ 1 ^ sxmo_type -M Alt -k Left
			$icon_arr History        ^ 1 ^ sxmo_type -M Alt -k Right
			$icon_rld Refresh     ^ 0 ^ sxmo_type -M Shift -M Ctrl r
		"
		WINNAME=Firefox
		;;
	*lagrange* )
		# Lagrange
		CHOICES="
			$icon_mnu Toggle sidebar ^ 0 ^ sxmo_type -M Shift -M Ctrl p
			$icon_bok Open bookmarks ^ 0 ^ sxmo_type -M Ctrl l && sxmo_type 'about:bookmarks' -k Return
			$icon_pls Add bookmark   ^ 0 ^ sxmo_type -M Ctrl d
			$icon_zmi Zoom           ^ 1 ^ sxmo_type -M Ctrl -k equal
			$icon_zmo Zoom           ^ 1 ^ sxmo_type -M Ctrl -k minus
			$icon_aru Parent dir     ^ 1 ^ sxmo_type -M Alt -k Up
			$icon_arl History        ^ 1 ^ sxmo_type -M Alt -k Left
			$icon_arr History        ^ 1 ^ sxmo_type -M Alt -k Right
			$icon_rld Refresh        ^ 0 ^ sxmo_type -M Ctrl r
		"
		WINNAME=Lagrange
		;;
	*foxtrot* )
		# Foxtrot GPS
		CHOICES="
			$icon_itm Locations           ^ 0 ^ sxmo_gpsutil.sh menulocations
			$icon_cpy Copy                ^ 1 ^ sxmo_gpsutil.sh copy
			$icon_pst Paste               ^ 0 ^ sxmo_gpsutil.sh paste
			$icon_itm Drop Pin            ^ 0 ^ sxmo_gpsutil.sh droppin
			$icon_fnd Region Search       ^ 0 ^ sxmo_gpsutil.sh menuregionsearch
			$icon_itm Region Details      ^ 0 ^ sxmo_gpsutil.sh details
			$icon_zmi Zoom              ^ 1 ^ sxmo_type i
			$icon_zmo Zoom              ^ 1 ^ sxmo_type o
			$icon_itm Map Type            ^ 0 ^ sxmo_gpsutil.sh menumaptype
			$icon_itm Panel Toggle        ^ 1 ^ sxmo_type m
			$icon_itm GPSD Toggle         ^ 1 ^ sxmo_type a
			$icon_usr Locate Me           ^ 0 ^ sxmo_gpsutil.sh gpsgeoclueset
		"
		WINNAME=Maps
		;;
	* )
		# Default system menu (no matches)
		CHOICES="
			$icon_grd Scripts                                            ^ 0 ^ sxmo_appmenu.sh scripts
			$icon_grd Apps                                               ^ 0 ^ sxmo_appmenu.sh applications
			$icon_dir Files                                              ^ 0 ^ sxmo_files.sh
			$(command -v foxtrotgps >/dev/null && echo "$icon_gps Maps   ^ 0 ^ foxtrotgps")
			$icon_phn Dialer                                             ^ 0 ^ sxmo_modemdial.sh
			$icon_msg Texts                                              ^ 0 ^ sxmo_modemtext.sh
			$icon_usr Contacts                                           ^ 0 ^ sxmo_contactmenu.sh
			$icon_bth Bluetooth 										 ^ 1 ^ sxmo_bluetoothmenu.sh
			$(command -v megapixels >/dev/null && echo "$icon_cam Camera ^ 0 ^ GDK_SCALE=2 megapixels")
			$icon_fll Flashlight $(
				grep -qE '^0$' /sys/class/leds/white:flash/brightness &&
				printf %b "Off → On" ||  printf %b "On → Off";
				printf %b "^ 1 ^ sxmo_flashtoggle.sh"
			)
			$icon_net Networks                                           ^ 0 ^ sxmo_networks.sh
			$icon_mus Audio                                              ^ 0 ^ sxmo_appmenu.sh audioout
			$icon_cfg Config                                             ^ 0 ^ sxmo_appmenu.sh config
			$icon_pwr Power                                              ^ 0 ^ sxmo_appmenu.sh power
		"
		WINNAME=Sys
		;;
	esac
}

getprogchoices() {
	# E.g. sets CHOICES var
	programchoicesinit "$@"


	# For the Sys menu decorate at top with notifications if >1 notification
	if [ "$WINNAME" = "Sys" ]; then
		NNOTIFICATIONS="$(find "$NOTIFDIR" -type f | wc -l)"
		if [ "$NNOTIFICATIONS" -gt 0 ]; then
			CHOICES="
				$icon_bel Notifications ($NNOTIFICATIONS) ^ 0 ^ sxmo_notificationsmenu.sh
				$CHOICES
			"
		fi
	fi

	#shellcheck disable=SC2044
	for NOTIFFILE in $(find "$NOTIFDIR" -name 'incomingcall*_notification'); do
		NOTIFACTION="$(head -n1 "$NOTIFFILE")"
		MESSAGE="$(tail -1 "$NOTIFFILE")"
		CHOICES="
			$icon_phn $MESSAGE ^ 0 ^ $NOTIFACTION
			$CHOICES
		"
		break
	done

	# Decorate menu at bottom w/ system menu entry if not system menu
	echo $WINNAME | grep -qv Sys && CHOICES="
		$CHOICES
		$icon_mnu System Menu   ^ 0 ^ sxmo_appmenu.sh sys
	"

	# Decorate menu at bottom w/ close menu entry
	CHOICES="
		$CHOICES
		$icon_cls Close Menu    ^ 0 ^ quit
	"

	CHOICES="$(printf "%s\n" "$CHOICES" | xargs -0 echo | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1')"
}

quit() {
	exit 0
}

mainloop() {
	getprogchoices "$@"
	PICKED="$(
		printf "%s\n" "$CHOICES" |
		cut -d'^' -f1 |
		sxmo_dmenu.sh -i -p "$WINNAME"
	)" || quit
	LOOP="$(printf "%s\n" "$CHOICES" | grep -m1 -F "$PICKED" | cut -d '^' -f2)"
	CMD="$(printf "%s\n" "$CHOICES" | grep -m1 -F "$PICKED" | cut -d '^' -f3)"

	printf "%s\n" "sxmo_appmenu: Eval: <$CMD> from picked <$PICKED> with loop <$LOOP>">&2

	if printf %s "$LOOP" | grep -q 1; then
		eval "$CMD"
		mainloop "$@"
	else
		eval "$CMD" &
		wait
		quit
	fi
}

mainloop "$@"
