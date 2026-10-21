#!/usr/bin/env bash
set -euo pipefail
mode="${1:?off or on}"
case "$mode" in off) action=disable; airplane_action=enable; flag=1; state=true;; on) action=enable; airplane_action=disable; flag=0; state=false;; *) exit 2;; esac
adb wait-for-device
printf 'Device API: '
adb shell getprop ro.build.version.sdk
# Airplane mode is supported on both API 26 and modern system images.
adb shell settings put global airplane_mode_on "$flag"
if adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state "$state"; then
  printf 'Airplane-mode broadcast delivered.\n'
else
  printf 'Broadcast unavailable; trying connectivity command.\n'
fi
if adb shell cmd connectivity airplane-mode "$airplane_action"; then
  printf 'Connectivity airplane-mode command accepted.\n'
else
  printf 'Connectivity command unavailable on this system image.\n'
fi
# Some images do not provide svc telephony. These are attempts, not proof:
# only actual default-network disappearance below permits the offline test.
if adb shell svc wifi "$action"; then printf 'Wi-Fi toggle accepted.\n'; else printf 'Wi-Fi svc unavailable.\n'; fi
if adb shell svc data "$action"; then printf 'Data toggle accepted.\n'; else printf 'Data svc unavailable.\n'; fi
if [ "$mode" = off ]; then
  for attempt in $(seq 1 15); do
    default_network="$(adb shell dumpsys connectivity | sed -n '/Active default network:/p' | tr -d '\r')"
    printf 'Network verification %s: %s\n' "$attempt" "$default_network"
    if [[ "$default_network" == *'Active default network: none'* ]]; then
      printf 'Device network disconnected; offline test may proceed.\n'
      exit 0
    fi
    sleep 2
  done
  printf 'Device still has a default network; refusing to claim offline.\n' >&2
  exit 1
fi
printf 'Device network enabled; real API download test will verify access.\n'
