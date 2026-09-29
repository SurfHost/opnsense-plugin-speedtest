# Speedtest for OPNsense (SurfHost)

`os-speedtest-surfhost` runs internet speed tests from the firewall itself, on demand or on a schedule, keeps the history and shows the latest result and averages on the dashboard.

It is a hardened fork of [os-speedtest-community](https://github.com/mimugmail/opn-repo/tree/main/net-mgmt/speedtest-community) by Miha Kralj (BSD 2-Clause), and is published in the [SurfHost plugin repository](https://github.com/SurfHost/opnsense-repo) together with the other SurfHost plugins.

## What is different from os-speedtest-community

| | os-speedtest-community | os-speedtest-surfhost |
|---|---|---|
| Ookla binary | URL scraped from speedtest.net at install time, `pkg add -f` as root, no check | Fixed URL, SHA-256 pinned in the plugin, only the binary is extracted; nothing foreign enters the package database |
| Ookla terms | Accepted silently on every run | Explicit checkbox; the Ookla program refuses to install or run without it |
| History | CSV inside the scripts directory | `/var/db/speedtest-surfhost/results.csv`, atomic writes, retention in days |
| Scheduling | Add a job under System > Settings > Cron yourself | Built-in schedule on the settings tab |
| Multi-WAN | Always the default route | Choose the interface to test from |
| Concurrent runs | A scheduled and a manual test can overlap | Lock, the second one gets a clear message |
| Timestamps | UTC stored as local time, shown labelled GMT | Stored as real UTC, shown in local time; imported history is corrected |
| Failures | Sometimes a traceback, scheduled failures invisible | Always a readable message; failed scheduled tests go to the system log |
| Dashboard | Legacy and new widget | New (24.7+) widget only |

## Install

### 1. Add the SurfHost repository (once per firewall)

In a root shell on the firewall (SSH or console, option 8):

```sh
fetch -o /usr/local/etc/pkg/repos/surfhost.conf https://surfhost.github.io/opnsense-repo/surfhost.conf
pkg update
```

If the firewall already has `surfhost.conf` from the Entra SSO plugin, run the same command: it overwrites the old file with the new address.

### 2. Install the plugin

**System > Firmware > Plugins**, click **Click to view the community plugins**, install `os-speedtest-surfhost`. Use this page rather than `pkg install`, so OPNsense keeps the plugin registered.

### 3. Pick and install the test program

**Reporting > Speedtest**, tab **Settings**:

1. **Test program**: `speedtest-cli` (from the OPNsense package repository) or **Ookla speedtest** (usually more accurate above a few hundred Mbit/s).
2. For Ookla, tick **Accept Ookla terms** after reading the linked licence and privacy policy. Test results are shared with Ookla either way; speedtest-cli uses the same speedtest.net servers.
3. Optionally set a default **Server id**, the **Interface** to test from, and how long to **keep history**.
4. **Save**, then on the **Speedtest** tab click **Install**.

### 4. Schedule (optional)

On the **Settings** tab tick **Run on a schedule**, pick the interval and the minute past the hour, and Save. The job is added to the system crontab; nothing needs to be added under System > Settings > Cron.

### 5. Dashboard

**Lobby > Dashboard**, add the **Speedtest** widget.

## Switching from os-speedtest-community

Both plugins have their own menu entry and files, so they can be installed at the same time while you switch.

1. Install `os-speedtest-surfhost` as above. Its post-install step imports the old history once (`/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv`), correcting the timestamps. **Import community history** on the Speedtest tab does the same again later and skips rows it already has.
2. Delete the old speedtest job under **System > Settings > Cron**, if you had one, and set up the schedule here instead.
3. Remove `os-speedtest-community` on the Plugins page. Its Ookla `speedtest` package is not removed with it: `pkg delete speedtest` if you no longer want it. The old CSV stays on disk; delete it once you have checked the import.

## Remove

1. On the Speedtest tab click **Remove** to delete the test program (the Ookla binary, or the speedtest-cli package).
2. Remove the plugin on **System > Firmware > Plugins**.
3. The history is kept in `/var/db/speedtest-surfhost`; `rm -rf /var/db/speedtest-surfhost` removes it.

## Files and commands

- Settings rendered for the scripts: `/usr/local/etc/speedtest-surfhost.conf`
- History: `/var/db/speedtest-surfhost/results.csv` (same columns as os-speedtest-community)
- Ookla binary: `/usr/local/libexec/speedtest-surfhost/speedtest`
- `configctl speedtestsurfhost run default` runs a test from the shell; also selectable as "Run speedtest (SurfHost)" under System > Settings > Cron
- API: `/api/speedtestsurfhost/service/{version,serverlist,run,stat,log,recent,deletelog,import,install,reconfigure}`, `/api/speedtestsurfhost/download/csv`

## Maintaining

See [docs/MAINTAINING.md](docs/MAINTAINING.md): releasing, and moving to a new Ookla build.

## Licence

BSD 2-Clause, see [LICENSE](LICENSE). Original work copyright Miha Kralj; the dashboard widget is based on Deciso's; changes copyright SurfHost.nl.
