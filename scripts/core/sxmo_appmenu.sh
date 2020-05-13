#!/usr/bin/env sh
WIN=$(xdotool getwindowfocus)

programchoicesinit() {
  WMCLASS="${1:-$(xprop -id $(xdotool getactivewindow) | grep WM_CLASS | cut -d ' ' -f3-)}"

  # Default system menu (no matches)
  CHOICES="$(echo "
    Scripts            ^ 0 ^ sxmo_appmenu.sh scripts
    Apps               ^ 0 ^ sxmo_appmenu.sh applications
    Volume ↑           ^ 1 ^ sxmo_vol.sh up
    Volume ↓           ^ 1 ^ sxmo_vol.sh down
    Dialer             ^ 0 ^ sxmo_modemcall.sh dial
    Texts              ^ 0 ^ sxmo_modemtext.sh
    Camera             ^ 0 ^ sxmo_camera.sh
    Wifi               ^ 0 ^ st -e "nmtui"
    Config             ^ 0 ^ sxmo_appmenu.sh config
    Logout             ^ 0 ^ pkill -9 dwm
  ")" && WINNAME=Sys

  # Apps menu
  echo $WMCLASS | grep -i "applications" && CHOICES="$(echo "
    Surf            ^ 0 ^ surf
    NetSurf         ^ 0 ^ netsurf
    Sacc            ^ 0 ^ st -e sacc i-logout.cz/1/bongusta
    W3M             ^ 0 ^ st -e w3m duck.com
    St              ^ 0 ^ st
    Firefox         ^ 0 ^ firefox
    Foxtrotgps      ^ 0 ^ foxtrotgps
  ")" && WINNAME=Apps && return

  # Scripts menu
  echo $WMCLASS | grep -i "scripts" && CHOICES="$(echo "
    Timer           ^ 0 ^ sxmo_timermenu.sh
    Youtube         ^ 0 ^ sxmo_youtube.sh video
    Youtube (Audio) ^ 0 ^ sxmo_youtube.sh audio
    Weather         ^ 0 ^ sxmo_weather.sh
    RSS             ^ 0 ^ sxmo_rss.sh
  ")" && WINNAME=Scripts && return

  # System Control menu
  echo $WMCLASS | grep -i "config" && CHOICES="$(echo "
    Volume ↑                   ^ 1 ^ sxmo_vol.sh up
    Volume ↓                   ^ 1 ^ sxmo_vol.sh down
    Brightesss ↑               ^ 1 ^ sxmo_brightness.sh up
    Brightness ↓               ^ 1 ^ sxmo_brightness.sh down
    Modem $(pgrep -f sxmo_modemmonitor.sh >/dev/null && echo -n "On → Off" || echo -n "Off → On") ^ 1 ^ sxmo_modemmonitortoggle.sh
    Modem Info                 ^ 0 ^ sxmo_modeminfo.sh
    Modem Log                  ^ 0 ^ sxmo_modemlog.sh
    Rotate                     ^ 1 ^ rotate
    Wifi                       ^ 0 ^ st -e "nmtui"
    Upgrade Pkgs               ^ 0 ^ st -e sxmo_upgrade.sh
  ")" && WINNAME=Config && return

  # MPV
  echo $WMCLASS | grep -i "mpv" && CHOICES="$(echo "
   Pause        ^ 0 ^ key space
   Seek ←       ^ 1 ^ key Left
   Seek →       ^ 1 ^ key Right
   App Volume ↑ ^ 1 ^ key 0
   App Volume ↓ ^ 1 ^ key 9
   Speed ↑      ^ 1 ^ key bracketright
   Speed ↓      ^ 1 ^ key bracketleft
   Screenshot   ^ 1 ^ key s
   Loopmark     ^ 1 ^ key l
   Info         ^ 1 ^ key i
   Seek Info    ^ 1 ^ key o
  ")" && WINNAME=Mpv && return

  #  St
  echo $WMCLASS | grep -i "st-256color" && CHOICES="$(echo "
      Type complete   ^ 0 ^ key Ctrl+Shift+u
      Copy complete   ^ 0 ^ key Ctrl+Shift+i
      Paste           ^ 0 ^ key Ctrl+Shift+v
      Zoom +          ^ 1 ^ key Ctrl+Shift+Prior
      Zoom -          ^ 1 ^ key Ctrl+Shift+Next
      Scroll ↑        ^ 1 ^ key Ctrl+Shift+b
      Scroll ↓        ^ 1 ^ key Ctrl+Shift+f
      Invert          ^ 1 ^ key Ctrl+Shift+x
      Hotkeys         ^ 0 ^ sxmo_appmenu.sh sthotkeys
  ")" && WINNAME=st && return

  #  St hotkeys
  echo $WMCLASS | grep -i "sthotkeys" && CHOICES="$(echo "
      Send Ctrl-C      ^ 0 ^ key Ctrl+c
      Send Ctrl-L      ^ 0 ^ key Ctrl+l
      Send Ctrl-D      ^ 0 ^ key Ctrl+d
  ")" && WINNAME=st && return

  # Netsurf
  echo $WMCLASS | grep -i netsurf && CHOICES="$(echo "
      Pipe URL          ^ 0 ^ sxmo_urlhandler.sh
      Zoom +            ^ 1 ^ key Ctrl+plus
      Zoom -            ^ 1 ^ key Ctrl+minus
      History  ←      ^ 1 ^ key Alt+Left
      History  →   ^ 1 ^ key Alt+Right
  ")" && WINNAME=netsurf && return

  # Surf
  echo $WMCLASS | grep surf && CHOICES="$(echo "
      Navigate    ^ 0 ^ key Ctrl+g
      Link Menu   ^ 0 ^ key Ctrl+d
      Pipe URL    ^ 0 ^ sxmo_urlhandler.sh
      Zoom +      ^ 1 ^ key Ctrl+Shift+k
      Zoom -      ^ 1 ^ key Ctrl+Shift+j
      Scroll ↑    ^ 1 ^ key Ctrl+space
      Scroll ↓    ^ 1 ^ key Ctrl+b
      JS Toggle   ^ 1 ^ key Ctrl+Shift+s
      Search      ^ 1 ^ key Ctrl+f
      History ←    ^ 1 ^ key Ctrl+h
      History →   ^ 1 ^ key Ctrl+l
  ")" && WINNAME=surf && return

  # Firefox
  echo $WMCLASS | grep -i firefox && CHOICES="$(echo "
      Pipe URL          ^ 0 ^ sxmo_urlhandler.sh
      Zoom +            ^ 1 ^ key Ctrl+plus
      Zoom -            ^ 1 ^ key Ctrl+minus
      History  ←        ^ 1 ^ key Alt+Left
      History  →        ^ 1 ^ key Alt+Right
  ")" && WINNAME=firefox && return

  # Foxtrot GPS
  echo $WMCLASS | grep -i foxtrot && CHOICES="$(echo "
      Zoom +            ^ 1 ^ key i
      Zoom -            ^ 1 ^ key o
      Panel toggle      ^ 1 ^ key m
      Autocenter toggle ^ 0 ^ key a
      Route             ^ 0 ^ key r
      Gmaps Transfer    ^ 0 ^ key o
      Copy Cords        ^ 0 ^ key o
  ")" && WINNAME=gps && return
}

getprogchoices() {
  # E.g. sets CHOICES var
  programchoicesinit $@

  # Decorate menu at top w/ incoming call entry if present
  INCOMINGCALL=$(cat /tmp/sxmo_incomingcall || echo NOCALL)
  echo "$INCOMINGCALL" | grep -v NOCALL && CHOICES="$(echo "
    Pickup $(echo $INCOMINGCALL | cut -d: -f2) ^ 0 ^ sxmo_modemcall.sh pickup $(echo $INCOMINGCALL | cut -d: -f1)
    $CHOICES
  ")"

  # Decorate menu at bottom w/ system menu entry if not system menu
  echo $WINNAME | grep -v Sys && CHOICES="
    $CHOICES
    System Menu   ^ 0 ^ sxmo_appmenu.sh sys
  "

  # Decorate menu at bottom w/ close menu entry
  CHOICES="
    $CHOICES
    Close Menu    ^ 0 ^ quit
  "

  PROGCHOICES="$(echo "$CHOICES" | xargs -0 echo | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1')"
}

rotate() {
  xrandr | grep primary | cut -d' ' -f 5 | grep right && xrandr -o normal || xrandr -o right
}

key() {
  xdotool windowactivate "$WIN"
  xdotool key --clearmodifiers "$1"
  #--window $WIN
}

quit() {
  exit 0
}

mainloop() {
  DMENUIDX=0
  PICKED=""
  ARGS="$@"

  while :
  do
    # E.g. sets PROGCHOICES
    getprogchoices $ARGS

    PICKED="$(
      echo "$PROGCHOICES" |
      cut -d'^' -f1 | 
      dmenu -idx $DMENUIDX -l 14 -c -fn "Terminus-30" -p "$WINNAME"
    )"
    LOOP="$(echo "$PROGCHOICES" | grep -F "$PICKED" | cut -d '^' -f2)"
    CMD="$(echo "$PROGCHOICES" | grep -F "$PICKED" | cut -d '^' -f3)"
    DMENUIDX="$(echo "$PROGCHOICES" | grep -F -n "$PICKED" | cut -d ':' -f1)"
    echo "Eval: <$CMD> from picked <$PICKED> with loop <$LOOP>"
    eval $CMD
    echo $LOOP | grep 1 || quit
  done
}

pgrep -f sxmo_appmenu.sh | grep -Ev "^${$}$" | xargs kill -9
pkill -9 dmenu
mainloop $@