#!/bin/bash
# install-ssh-ident.sh - install ssh-ident ( script for wrapping ssh-agent )

#requires: curl sha256sum mktemp

#variables
SOURCE=https://raw.githubusercontent.com/ccontavalli/ssh-ident/master/ssh-ident
SHA2=5268eae5f09067ff05e196f8e4278faf67590cf11724eb6b868642fb8ff0d90e
INSTALL_DIR=${HOME}/bin
INSTALL_AS=ssh

curl -L "${SOURCE}" -o "${INSTALL_DIR}/${INSTALL_AS}"
OK=$?
if [ $OK -eq 0 ]; then
	tmpfile=$(mktemp /tmp/install-ssh-ident.XXXXXX)
	exec 3>"$tmpfile"
	echo "${SHA2}  ${INSTALL_DIR}/${INSTALL_AS}" >&3
	sha256sum --status -c "$tmpfile"
	OK=$?
	if [ $OK -eq 1 ]; then
		rm -f "${INSTALL_DIR}/${INSTALL_AS}"
		echo "Failed to install ssh-ident - sha256 sum mismatch. Please check ${SOURCE} and github."
		exit 1
	fi

	chmod +x "${INSTALL_DIR}/${INSTALL_AS}"
	echo "ssh-ident installed to ${INSTALL_DIR}/${INSTALL_AS}"
	exit 0
else
	echo "Failed to install ssh-ident - failed download. Please check ${SOURCE} and github."
	exit 1
fi
