# Maintaining os-speedtest-surfhost

## Releasing

1. Bump `PLUGIN_VERSION` in `os-speedtest-surfhost/Makefile`, write the release notes in `notes.md` (untracked), commit, tag `v<version>` and push both.
2. On the OPNsense build box:

   ```sh
   fetch -o /root/release-speedtest.sh https://raw.githubusercontent.com/SurfHost/opnsense-plugin-speedtest/main/tools/release.sh
   sh /root/release-speedtest.sh <version>
   ```

   It builds under `net-mgmt/` in `/usr/plugins`, checks the package, and publishes it with `publish.sh` from [SurfHost/opnsense-repo](https://github.com/SurfHost/opnsense-repo), which replaces only this plugin in the shared repository. At the git prompt: user `SurfHost`, password a fine-grained PAT with Contents: write on `SurfHost/opnsense-repo`. Revoke it afterwards.
3. From the workstation: `gh release create v<version> --title "os-speedtest-surfhost <version>" --notes-file notes.md`

The package has no dependencies, so unlike the Entra SSO plugin no build-box preparation is needed beyond `opnsense-code plugins` (done by the script when `/usr/plugins` is missing).

## A new Ookla build

`install_backend.sh` pins one Ookla package by URL and SHA-256. As of September 2026 the newest FreeBSD build Ookla publishes is 1.2.0 for FreeBSD 13 (`ookla-speedtest-1.2.0-freebsd13-x86_64.pkg`); there are no FreeBSD 14 or 15 builds, and the page at speedtest.net/apps/cli no longer answers plain HTTP clients, which is one reason the community plugin's scraper is fragile.

Only the binary is used. It links against base libraries only (libc.so.7, libc++.so.1, libcxxrt.so.1, libthr.so.3, libz.so.6, libm.so.5, librt.so.1, libdl.so.1, libgcc_s.so.1), all present on FreeBSD 15, so it runs on OPNsense 26.x without compat packages.

To move to a newer build:

1. Download it and check that the package holds `/usr/local/bin/speedtest`:
   `fetch <url> && sha256 <file> && tar -tvf <file>`
2. On a test firewall, extract the binary and run `speedtest --version` and a full test.
3. Update `OOKLA_URL` and `OOKLA_SHA256` in `src/opnsense/scripts/OPNsense/SpeedtestSurfHost/install_backend.sh`, bump the plugin version, release. Existing installs keep the old binary; switching the test program to speedtest-cli and back (Save each time) fetches the new one.

## Why no PLUGIN_CONFLICTS

`plugins.mk` only uses `PLUGIN_CONFLICTS` for `make upgrade` on a development box; it never writes a conflicts entry into the package manifest. Declaring os-speedtest-community there would suggest a guarantee pkg does not give. The two plugins share no files, menu keys, configd actions or API paths, so installing both is harmless.
