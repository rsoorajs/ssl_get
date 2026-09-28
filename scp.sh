#!/bin/sh

TARGET_DIR="${CERT_PATH%/}"
REMOTE_DIR="${SCP_CERTS_DIR%/}"

cd "$TARGET_DIR" || {
	echo "ERROR: Target directory '$TARGET_DIR' does not exist." >&2
	exit 1
}

if [ -z "$SCP_KEY" ]; then
	for cert in $CERT_FILES; do
		sshpass -p "$SCP_PASSWD" scp \
			-o StrictHostKeyChecking=accept-new \
			-o ConnectTimeout=15 \
			-o PreferredAuthentications="password" \
			"$SCP_USER@$SCP_HOST:$REMOTE_DIR/$cert" "$TARGET_DIR/$cert"
	done
else
	for cert in $CERT_FILES; do
		scp \
			-o StrictHostKeyChecking=accept-new \
			-o ConnectTimeout=15 \
			-o BatchMode=yes \
			-i "$SCP_KEY" \
			"$SCP_USER@$SCP_HOST:$REMOTE_DIR/$cert" "$TARGET_DIR/$cert"
	done
fi
