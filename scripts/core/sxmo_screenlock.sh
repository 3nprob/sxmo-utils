#!/bin/sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

WAKEUPRTC="/sys/class/wakeup/wakeup1/active_count"
MODEMUPRTC="/sys/class/wakeup/wakeup10/active_count"
POWERRTC="/sys/class/wakeup/wakeup5/active_count"

OLD_RTC_WAKECOUNT="$XDG_RUNTIME_DIR/wakeup.rtc.count"
OLD_MODEM_WAKECOUNT="$XDG_RUNTIME_DIR/wakeup.modem.count"
OLD_POWER_WAKECOUNT="$XDG_RUNTIME_DIR/wakeup.power.count"

saveAllEventCounts() {
	#these help us determine the reason of the next wakeup
	cat "$WAKEUPRTC" > "$OLD_RTC_WAKECOUNT"
	cat "$MODEMUPRTC" > "$OLD_MODEM_WAKECOUNT"
	cat "$POWERRTC" > "$OLD_POWER_WAKECOUNT"
	# TODO: add logic for modem wakeup
}

whichWake() {
	#attempt to find the reason why we woke up:
	if [ "$(cat "$POWERRTC")" -gt "$(cat "$OLD_POWER_WAKECOUNT")" ] ; then
		echo "usb power"
	elif [ "$(cat "$MODEMUPRTC")" -gt "$(cat "$OLD_MODEM_WAKECOUNT")" ] ; then
		echo "modem"
	elif [ "$(cat "$WAKEUPRTC")" -gt "$(cat "$OLD_RTC_WAKECOUNT")" ] ; then
		echo "rtc"
	else
		echo "button"
	fi
}

getCurState() {
	#get the current state of the lock
	if sxmo_wm.sh inputevent | grep -q on ; then
		printf "unlock" #normal mode, not locked
	elif sxmo_wm.sh dpms | grep -q off; then
		printf "lock" #locked, but screen on
	else
		printf "off" #locked, and screen off
	fi
}

lock() {
	#locked state with screen on
	sxmo_log "transitioning from $(getCurState) to stage lock"

	# always echo last state first so that user can use it in their hooks
	# TODO: Document SXMO_LASTSTATE
	getCurState > "$SXMO_LASTSTATE"

	sxmo_led.sh blink blue &

	sxmo_wm.sh dpms off
	sxmo_wm.sh inputevent off

	sxmo_daemons.sh stop lisgd

	sxmo_hooks.sh statusbar state_change
	sxmo_hooks.sh statusbar locked

	wait

	# Do we want this hook after disabling all the input devices so users can enable certain devices?
	sxmo_hooks.sh lock
}

unlock() {
	#normal unlocked state, screen on
	sxmo_log "transitioning from $(getCurState) to stage unlock"

	getCurState > "$SXMO_LASTSTATE"

	sxmo_led.sh blink red green &
	LEDPID=$!

	sxmo_wm.sh dpms off
	sxmo_wm.sh inputevent on
	sxmo_hooks.sh lisgdstart

	sxmo_hooks.sh statusbar state_change
	sxmo_hooks.sh statusbar locked

	wait "$LEDPID"

	sxmo_hooks.sh unlock
}

off() {
	#locked state with screen off
	sxmo_log "transitioning from $(getCurState) to stage off"

	getCurState > "$SXMO_LASTSTATE"

	sxmo_led.sh blink blue red &

	sxmo_wm.sh dpms on
	sxmo_wm.sh inputevent off
	sxmo_hooks.sh statusbar locked

	sxmo_daemons.sh stop lisgd

	wait

	sxmo_hooks.sh screenoff
}

crust() {
	sxmo_log "transitioning from $(getCurState) to stage crust"

	getCurState > "$SXMO_LASTSTATE"

	sxmo_led.sh blink red

	saveAllEventCounts

	sxmo_hooks.sh presuspend

	YEARS8_TO_SEC=268435455
	if mnc="$(sxmo_hooks.sh mnc)"; then
		#wake up 10 seconds before the next cron event
		suspend_time="$((mnc-10))"
	fi
	if [ -z "$suspend_time" ] || [ "$suspend_time" -gt "$YEARS8_TO_SEC" ]; then
		suspend_time="$YEARS8_TO_SEC"
	fi
	if [ "$suspend_time" -gt 0 ]; then
		sxmo_log "real crusting now (suspendtime=$suspend_time)"
		rtcwake -m mem -s "$suspend_time" >&2
		#We woke up again
		UNSUSPENDREASON="$(whichWake)"
	else
		sxmo_log "fake crusting now (suspendtime=$suspend_time)"
		UNSUSPENDREASON=rtc # we fake the crust for those seconds
	fi
	echo "$UNSUSPENDREASON" > "$SXMO_UNSUSPENDREASONFILE"

	echo "crust" > "$SXMO_LASTSTATE"

	sxmo_log "woke up from crust (reason=$UNSUSPENDREASON)"

	sxmo_hooks.sh postwake "$UNSUSPENDREASON"
}

case "$1" in
	unlock|lock|off|crust|getCurState)
		"$@"
		exit 0
		;;
	*)
		echo "usage: sxmo_screenlock.sh [lock|unlock|off|crust|rtc|getCurState]">&2
		exit 1
		;;
esac

