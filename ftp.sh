#!/bin/sh

TARGET_DIR="${CERT_PATH%/}"

cd "$TARGET_DIR" || {
	echo "ERROR: Target directory '$TARGET_DIR' does not exist." >&2
	exit 1
}

ftp -Anv "$FTP_HOST" <<END_SCRIPT
quote USER $FTP_USER
quote PASS $FTP_PASSWD
binary
cd $FTP_CERTS_DIR
prompt
mget $CERT_FILES
quit
END_SCRIPT
