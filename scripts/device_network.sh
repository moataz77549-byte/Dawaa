#!/usr/bin/env bash
set -euo pipefail
mode="${1:?off or on}"
case "$mode" in off) desired=0; action=disable;; on) desired=1; action=enable;; *) exit 2;; esac
# Wait for system services after boot; adb failures are retried, never accepted as proof.
adb wait-for-device
for attempt in 1 2 3; do
  if adb shell svc wifi "$action" && adb shell svc data "$action"; then break; fi
  if [ "$attempt" = 3 ]; then exit 1; fi
  sleep 3
done
wifi="$(adb shell settings get global wifi_on | tr -d '\r')"
mobile="$(adb shell settings get global mobile_data | tr -d '\r')"
if [ "$mode" = off ]; then
  [ "$wifi" = "$desired" ]
  [ "$mobile" = "$desired" ]
fi
printf 'Device network mode: %s; wifi_on=%s; mobile_data=%s\n' "$mode" "$wifi" "$mobile"
