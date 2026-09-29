#!/bin/sh
#
# Copyright (c) 2021 Miha Kralj
# Copyright (c) 2026 SurfHost.nl
# SPDX-License-Identifier: BSD-2-Clause
#
# Install or remove a speedtest program; prints one line of JSON.
#
#   install_backend.sh ookla | cli | remove-ookla | remove-cli
#
# The Ookla binary comes from a fixed URL and must match a pinned SHA-256
# before anything of it is used. Only the binary is taken out of Ookla's
# package: that package is built for FreeBSD 13 and would put a foreign ABI
# into the package database, while the binary itself only needs base system
# libraries (libc, libc++, libthr, libz, libm) that FreeBSD 15 still ships.
# It is never registered with pkg and never lands in /usr/local/bin.
#
# To move to a new Ookla release: download it, check it, update both values
# below and bump the plugin version.

OOKLA_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-freebsd13-x86_64.pkg"
OOKLA_SHA256="23b20119066df5b08c4f3a8920334ccaab0783780f9b2494629394d1ef33e6f8"

CONF=/usr/local/etc/speedtest-surfhost.conf
OOKLA_DIR=/usr/local/libexec/speedtest-surfhost
OOKLA_BIN=${OOKLA_DIR}/speedtest

reply() {
	# $1 status, $2 message; the message never contains a double quote or
	# backslash, since it is either fixed text or filtered below
	printf '{"status":"%s","message":"%s"}\n' "$1" "$2"
	exit 0
}

clean() {
	# last line of a command's output, safe inside a JSON string
	tail -n 1 | tr -d '"\\' | tr -c '[:print:]' ' '
}

cli_pkg() {
	PYVER=$(/usr/local/bin/python3 -c 'import sys; print("%d%d" % sys.version_info[:2])' 2>/dev/null)
	[ -n "${PYVER}" ] || return 1
	echo "py${PYVER}-speedtest-cli"
}

case "$1" in
ookla)
	if ! grep -qx 'accept_ookla_terms=1' "${CONF}" 2>/dev/null; then
		reply error "Accept the Ookla terms in the settings and save first"
	fi
	TMP=$(mktemp -d /tmp/speedtest-surfhost.XXXXXX) || reply error "Could not create a temporary directory"
	trap 'rm -rf "${TMP}"' EXIT
	if ! OUT=$(fetch -q -T 60 -o "${TMP}/ookla.pkg" "${OOKLA_URL}" 2>&1); then
		reply error "Download from Ookla failed: $(echo "${OUT}" | clean)"
	fi
	GOT=$(sha256 -q "${TMP}/ookla.pkg")
	if [ "${GOT}" != "${OOKLA_SHA256}" ]; then
		reply error "The Ookla download does not match the pinned checksum (got ${GOT}); not installed"
	fi
	# the whole package is one binary and a man page; tar strips the
	# leading slash, so everything lands under ${TMP}
	tar -xf "${TMP}/ookla.pkg" -C "${TMP}" 2>/dev/null
	if [ ! -f "${TMP}/usr/local/bin/speedtest" ]; then
		reply error "The Ookla package does not contain the speedtest binary"
	fi
	mkdir -p "${OOKLA_DIR}"
	install -m 0755 -o root -g wheel "${TMP}/usr/local/bin/speedtest" "${OOKLA_BIN}.new" &&
	    mv -f "${OOKLA_BIN}.new" "${OOKLA_BIN}" || reply error "Could not install the Ookla binary"
	if ! OUT=$(env HOME=/var/db/speedtest-surfhost "${OOKLA_BIN}" --version 2>&1); then
		reply error "The Ookla binary does not run on this system: $(echo "${OUT}" | clean)"
	fi
	reply ok "$(echo "${OUT}" | head -n 1 | clean)"
	;;
cli)
	PKG=$(cli_pkg) || reply error "Could not determine the Python version"
	if ! OUT=$(pkg install -y "${PKG}" 2>&1); then
		reply error "pkg install ${PKG} failed: $(echo "${OUT}" | clean)"
	fi
	reply ok "${PKG} installed"
	;;
remove-ookla)
	rm -f "${OOKLA_BIN}"
	rmdir "${OOKLA_DIR}" 2>/dev/null
	reply ok "Ookla binary removed"
	;;
remove-cli)
	PKG=$(cli_pkg) || reply error "Could not determine the Python version"
	if pkg info -e "${PKG}"; then
		if ! OUT=$(pkg delete -y "${PKG}" 2>&1); then
			reply error "pkg delete ${PKG} failed: $(echo "${OUT}" | clean)"
		fi
	fi
	reply ok "${PKG} removed"
	;;
*)
	reply error "usage: install_backend.sh ookla|cli|remove-ookla|remove-cli"
	;;
esac
