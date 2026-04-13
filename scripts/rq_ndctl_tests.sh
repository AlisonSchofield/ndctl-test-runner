#!/bin/bash -e
# SPDX-License-Identifier: CC0-1.0
# Copyright (C) 2021 Intel Corporation. All rights reserved.

: "${NDCTL:=/root/ndctl}"
: "${RQ_NDCTL_TEST_CONF:=/etc/default/rq_ndctl_test.conf}"

rc=0

cleanup()
{
	systemctl poweroff
}

trap cleanup EXIT

set_default_message_loglevel()
(
	local console_loglevel default_loglevel
	console_loglevel=$(awk '{print $1}' /proc/sys/kernel/printk)
	default_loglevel=5
	echo "$console_loglevel $default_loglevel" > /proc/sys/kernel/printk
)
set_default_message_loglevel

if [[ -r "$RQ_NDCTL_TEST_CONF" ]]; then
	# shellcheck disable=SC1090
	source "$RQ_NDCTL_TEST_CONF"
fi

: "${NDCTL_TEST_PROFILE:=all}"
: "${NDCTL_TEST_NAME:=ALL}"
: "${NDCTL_TEST_MESON_ARGS:=}"

sleep 4
echo "======= auto-running $0 ========" > /dev/kmsg
echo "======= test profile: ${NDCTL_TEST_NAME} (${NDCTL_TEST_PROFILE}) ========" > /dev/kmsg

cd "$NDCTL" || {
	printf '<0>FATAL: %s: no %s directory\n' "$0" "$NDCTL" > /dev/kmsg
	exit 1
}

rm -rf build
meson setup build 2>/dev/kmsg
meson configure -Dtest=enabled -Ddestructive=enabled -Ddocs=disabled build 2>/dev/kmsg
meson compile -C build 2>/dev/kmsg
meson install -C build 2>/dev/kmsg

echo "======= ${0##*/} ndctl build done ========" > /dev/kmsg

if [[ "$NDCTL_TEST_PROFILE" == "nvdimm" || "$NDCTL_TEST_PROFILE" == "dax" || "$NDCTL_TEST_PROFILE" == "all" ]]; then
	modprobe -r nfit_test || true
fi

logfile="ndctl-${NDCTL_TEST_PROFILE}-test-$(date +%Y-%m-%d--%H%M%S).log"
meson_cmd=(meson test -C build)
if [[ -n "$NDCTL_TEST_MESON_ARGS" ]]; then
	read -r -a meson_extra_args <<<"$NDCTL_TEST_MESON_ARGS"
	meson_cmd+=("${meson_extra_args[@]}")
fi

dumpfile()
{
(
	local filename
	filename=$(basename "$1")
	local filenamelen
	filenamelen=$(printf '%s' "$filename" | wc -c)
	local maxlen
	maxlen=$((1024-filenamelen-6))
	while IFS= read -t 60 -n "$maxlen" -r line; do
		printf '<5>%s: %s\n' "$filename" "$line" > /dev/kmsg
	done < "$1"
)
}

set +e
echo "======= meson test start ========" > /dev/kmsg
"${meson_cmd[@]}" > "$logfile" 2>&1
rc=$?
echo "======= meson test end rc=$rc ========" > /dev/kmsg
set -e

if [[ $rc -ne 0 ]]; then
	echo "======= test failure logs ========" > /dev/kmsg
	[[ -f "$NDCTL"/build/meson-logs/testlog.txt ]] && dumpfile "$NDCTL"/build/meson-logs/testlog.txt
	[[ -f "$logfile" ]] && dumpfile "$logfile"
else
	rm -f "$logfile"
fi

echo "======= Done $0 rc=$rc ========" > /dev/kmsg
exit $rc
