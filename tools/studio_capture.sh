#!/usr/bin/env bash
# Grab the Roblox Studio window to a PNG.
#
#   tools/studio_capture.sh OUT.png [DELAY_SECONDS]
#
# Studio runs under Vinegar/Wine as an X11 client. On GNOME Wayland a grab of the X root window
# comes back solid black, so this reads Studio's own window instead (ffmpeg x11grab -window_id).
# The window id changes every time Studio restarts, so it is looked up by title each call.
set -euo pipefail

out="${1:?usage: studio_capture.sh OUT.png [DELAY_SECONDS]}"
delay="${2:-0}"

wid=$(xwininfo -root -tree 2>/dev/null \
	| awk '/ - Roblox Studio": \("robloxstudiobeta.exe" "robloxstudiobeta.exe"\)/ {print $1; exit}')
if [[ -z "${wid}" ]]; then
	echo "studio_capture: no Roblox Studio window found (is Studio open?)" >&2
	exit 1
fi

sleep "${delay}"
mkdir -p "$(dirname "${out}")"
ffmpeg -loglevel error -y -f x11grab -window_id "${wid}" -i "${DISPLAY:-:0}" -frames:v 1 "${out}"
echo "${out}"
