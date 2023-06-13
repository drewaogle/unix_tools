#!/bin/bash
# network-connectivity.sh - Verify Network Connectivity
# author: Drew Ogle <drew@aperturedata.io>
#
# Based on ideas from unix.stackexchange.com/questions/190513
# Designed to be run from cron on a schedule of choice.

# where to log
LOGFILE=/var/log/network-connectivity
# date format
DATE="date --rfc-3339=seconds"

# test ip should be public ip. Tests raw connectivity; uses ICMP.
TEST_IP="8.8.8.8"
# tests dns resolving, then ping, also uses ICMP
TEST_DNS_NAME="google.com"
# test connecting to a service.
WEB_HOST="bing.com"
WEB_PORT=443

log() {
	echo "$1" >> "${LOGFILE}"
}

# action on connected
on_connected() {
	log "$(${DATE}): Network Connected"
}

# action on not connected
# arg1 is description
on_disconnected() {
	log "$(${DATE}): Network Disconnected: $1"
}


connectivity_test() {
	FAILED=0
	FAILED_TEST="No Failure"
	ping -q -c 1 -W 1 "${TEST_IP}" >/dev/null;
	if [ $? -ne 0 ]; then
		FAILED=1
		FAILED_TEST="Unable to ping ${TEST_IP}"
	fi

	if [ "$FAILED" -eq 0  ];
	then
		ping -q -c 1 -W 1 ${TEST_DNS_NAME} > /dev/null
		if [ $? -ne 0 ]; then
			FAILED=1
			FAILED_TEST="${FAILED_TEST} Unable to resolve/ping ${TEST_DNS_NAME}"
		fi

	fi

	if [ "$FAILED" -eq 0 ];
	then
		ping -q -c 1 -W 1 ${TEST_DNS_NAME} >/dev/null
		if [ $? -ne 0 ]; then
			FAILED=1
			FAILED_TEST="${FAILED_TEST} Unable to resolve/ping ${TEST_DNS_NAME}"
		fi

	fi

	if [ "$FAILED" -eq 0 ];
	then
		nc -zw1 ${WEB_HOST} ${WEB_PORT} >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			FAILED=1
			FAILED_TEST="${FAILED_TEST} Unable to open port to web host ${WEB_HOST} on port ${WEB_PORT}"
		fi
	fi

	if [ "$FAILED" -ne 0 ]; then
		on_disconnected "${FAILED_TEST}"

	else
		on_connected
	fi

}
connectivity_test
#on_connected
#on_disconnected "Test"
