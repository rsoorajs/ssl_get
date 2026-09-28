#!/bin/sh

# Purpose: Check expiration date of SSL in timeframe
# and retrieve new SSL certs from remote,
# either via scp or ftp, if expiring within a given timeframe

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Returns the raw "notAfter=..." string (identical to previous output)
get_expiration_date() {
	PEM=$1
	/usr/bin/openssl x509 -enddate -noout -in "$PEM" 2>/dev/null
}

# Returns 0 (true) if file does not exist, or will expire within $DAYS
check_cert() {
	PEM=$1
	DAYS=$2
	if [ ! -f "$PEM" ]; then
		return 0
	fi
	! /usr/bin/openssl x509 -checkend "$DAYS" -noout -in "$PEM" >/dev/null 2>&1
}

# Validates cert integrity and web server config before reloading
validate_and_reload() {
	PEM=$1

	if ! /usr/bin/openssl x509 -in "$PEM" -noout >/dev/null 2>&1; then
		echo "ERROR: Certificate $PEM is invalid or corrupted! Skipping reload." >&2
		return 1
	fi

	if command -v nginx >/dev/null 2>&1; then
		if ! nginx -t >/dev/null 2>&1; then
			echo "ERROR: Nginx configuration test failed! Skipping reload." >&2
			return 1
		fi
	fi

	echo "Reloading service.."
	/bin/bash -c "${RESTART_CMD:-systemctl reload nginx}"
}

# Bourne shell(sh) syntax to source
. "$SCRIPTPATH/.env"

# Get first entry, split by space character
CERT_NAME=${CERT_FILES%% *}

# Safely strip trailing slash and combine
PEM="${CERT_PATH%/}/$CERT_NAME"

# 14 days in seconds
DAYS="1209600"

echo "Checking SSL expiration date of $CERT_NAME.."

# Check result and optionally retrieve new
if check_cert "$PEM" "$DAYS"; then
	echo "Cert not exists or will expire within $((DAYS / 60 / 60 / 24)) days. \
Checking for new certificate.."
	# shellcheck source=/dev/null
	. "$SCRIPTPATH/$USE_SCRIPT"
	sleep 1
	expirationdate=$(get_expiration_date "$PEM")
	echo "Cert retrieved: $expirationdate"
	validate_and_reload "$PEM"
else
	echo "$PEM"
	expirationdate=$(get_expiration_date "$PEM")
	echo "Expiration date not yet reached ($expirationdate)"
fi
