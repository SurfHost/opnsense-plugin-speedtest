#!/bin/sh
#
# Copyright (c) 2026 SurfHost.nl
# SPDX-License-Identifier: BSD-2-Clause
#
# One-shot release driver for the OPNsense build box. Fetch this file
# standalone, give it the version, and it does everything up to the push:
#
#   fetch -o /root/release-speedtest.sh https://raw.githubusercontent.com/SurfHost/opnsense-plugin-speedtest/main/tools/release.sh
#   sh /root/release-speedtest.sh 1.0
#
# It clones the v<version> tag, builds the package under net-mgmt/ in the
# opnsense/plugins tree, verifies its contents and then hands it to
# publish.sh of SurfHost/opnsense-repo, which replaces only this plugin in
# the shared repository. The single interactive moment is the gh-pages push:
# enter SurfHost and paste a fine-grained PAT (Contents: write on
# SurfHost/opnsense-repo). The GitHub release itself is created from a
# workstation, since gh is not available on OPNsense.

set -eu

VERSION=${1:?usage: sh release.sh <version, e.g. 1.0>}
TAG="v${VERSION}"
REPO=https://github.com/SurfHost/opnsense-plugin-speedtest.git
PUBLISH_SH=https://raw.githubusercontent.com/SurfHost/opnsense-repo/main/tools/publish.sh
PAGES=https://surfhost.github.io/opnsense-repo
CHECKOUT=/root/speedtest-surfhost
PLUGINS_SRC=${PLUGINS_SRC:-/usr/plugins}
CATEGORY=net-mgmt
PORTNAME=speedtest-surfhost
PLUGIN_SUBDIR=os-speedtest-surfhost
BUILD_DIR="${PLUGINS_SRC}/${CATEGORY}/${PORTNAME}"

ABI=$(pkg config abi)
echo "==> releasing ${TAG} for ${ABI}"

pkg install -y git

if ! git ls-remote --exit-code --tags "${REPO}" "refs/tags/${TAG}" >/dev/null 2>&1; then
    echo "!!! tag ${TAG} is not on GitHub; push it from the workstation first:" >&2
    echo "      git tag ${TAG} && git push origin ${TAG}" >&2
    exit 1
fi

rm -rf "${CHECKOUT}"
git clone --depth 1 --branch "${TAG}" "${REPO}" "${CHECKOUT}"

STAMPED=$(sed -n 's/^PLUGIN_VERSION=[[:space:]]*\([^[:space:]]*\).*/\1/p' \
    "${CHECKOUT}/${PLUGIN_SUBDIR}/Makefile")
if [ "${STAMPED}" != "${VERSION}" ]; then
    echo "!!! tag ${TAG} carries PLUGIN_VERSION=${STAMPED}, not ${VERSION}" >&2
    echo "    bump the Makefile, commit, retag, and run again" >&2
    exit 1
fi

echo "==> building"
if [ ! -d "${PLUGINS_SRC}/Mk" ]; then
    echo "    fetching the opnsense/plugins tree into ${PLUGINS_SRC}"
    opnsense-code plugins
fi
rm -rf "${BUILD_DIR}"
mkdir -p "${PLUGINS_SRC}/${CATEGORY}"
cp -R "${CHECKOUT}/${PLUGIN_SUBDIR}" "${BUILD_DIR}"
( cd "${BUILD_DIR}" && make package )

PKG=$(find "${BUILD_DIR}" -name "os-${PORTNAME}-${VERSION}.pkg" -type f | head -n 1)
if [ -z "${PKG}" ]; then
    echo "!!! no os-${PORTNAME}-${VERSION}.pkg produced under ${BUILD_DIR}" >&2
    find "${BUILD_DIR}" -name '*.pkg' >&2
    exit 1
fi
echo "==> built ${PKG}"

echo "==> verifying package contents"
FILES=$(pkg info -F "${PKG}" -l)
for WANT in \
    'plugins\.inc\.d/speedtestsurfhost\.inc' \
    'SpeedtestSurfHost/speedtest\.py' \
    'SpeedtestSurfHost/install_backend\.sh' \
    'actions_speedtestsurfhost\.conf' \
    'templates/OPNsense/SpeedtestSurfHost/speedtest-surfhost\.conf' \
    'widgets/SpeedtestSurfHost\.js' \
    'widgets/Metadata/SpeedtestSurfHost\.xml'
do
    echo "${FILES}" | grep -q "${WANT}" \
        || { echo "!!! ${WANT} missing from the package" >&2; exit 1; }
done
if echo "${FILES}" | grep -Eq '__pycache__|\.pyc|\.ruff_cache'; then
    echo '!!! stray cache files in the package (plist ships everything in the tree)' >&2
    exit 1
fi
if [ -n "$(pkg query -F "${PKG}" '%dn')" ]; then
    echo '!!! the package has dependencies it should not have:' >&2
    pkg query -F "${PKG}" '%dn %dv' >&2
    exit 1
fi
echo "==> verified"

git config --global user.name >/dev/null 2>&1 || git config --global user.name "SurfHost"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "hans@surfhost.nl"

fetch -qo /tmp/publish.sh "${PUBLISH_SH}"
sh /tmp/publish.sh "${PKG}"

echo "==> plugin version according to the published repository:"
( fetch -qo - "${PAGES}/${ABI}/packagesite.pkg" | tar -xO -f - packagesite.yaml \
    | grep -o "\"name\":\"os-${PORTNAME}\",\"origin\":\"[^\"]*\",\"version\":\"[^\"]*\"" ) \
    || echo '    (not visible yet; Pages deploys lag a minute or two)'

# double quotes on purpose: the command is pasted into cmd.exe on the
# workstation, and cmd does not treat single quotes as quoting
echo "==> done. Remaining, from the workstation:"
echo "      gh release create ${TAG} --title \"os-${PORTNAME} ${VERSION}\" --notes-file notes.md"
