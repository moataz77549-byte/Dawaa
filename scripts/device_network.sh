#!/usr/bin/env bash
set -euo pipefail
mode="${1:?off or on}"
case "$mode" in off) action=disable;; on) action=enable;; *) exit 2;; esac
adb wait-for-device
for attempt in 1 2 3; do
  if adb shell svc wifi "$action" && adb shell svc data "$action"; then break; fi
  if [ "$attempt" = 3 ]; then exit 1; fi
  sleep 3
done
if [ "$mode" = off ]; then
  # Wifi changes are asynchronous. Verify actual default-network loss, not a
  # saved telephony setting (mobile_data may be absent on Wi-Fi-only images).
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
printf 'Device network enabled; the real API download test will verify access.\n'
