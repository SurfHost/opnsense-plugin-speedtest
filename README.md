# Speedtest for OPNsense (SurfHost)

`os-speedtest-surfhost` tests your ISP speed straight from the firewall with the Ookla speedtest binary, on demand or on a schedule, keeps the history and shows the latest result and averages on the dashboard.

It is a hardened fork of [os-speedtest-community](https://github.com/mimugmail/opn-repo/tree/main/net-mgmt/speedtest-community) by Miha Kralj (BSD 2-Clause), and is published in the [SurfHost plugin repository](https://github.com/SurfHost/opnsense-repo) together with the other SurfHost plugins.

## What is different from os-speedtest-community

| | os-speedtest-community | os-speedtest-surfhost |
|---|---|---|
| Test program | Choice of speedtest-cli or Ookla, installed by hand | Ookla only, installed with the plugin |
| Ookla binary | URL scraped from speedtest.net at install time, `pkg add -f` as root, no check | Fixed URL, SHA-256 pinned in the plugin, only the binary is extracted; nothing foreign enters the package database |
| Ookla terms | Accepted silently on every run | Explicit checkbox; no test runs until it is ticked |
| History | CSV inside the scripts directory | `/var/db/speedtest-surfhost/results.csv`, atomic writes, retention in days |
| Scheduling | Add a job under System > Settings > Cron yourself | Built-in schedule on the settings tab |
| Multi-WAN | Always the default route | Choose the interface to test from |
| Concurrent runs | A scheduled and a manual test can overlap | Lock, the second one gets a clear message |
| Timestamps | UTC stored as local time, shown labelled GMT | Stored as real UTC, shown in local time |
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

The Ookla binary is downloaded during the install. If that download failed (no internet at that moment), **Save** on the Settings tab retries it.

### 3. Accept the Ookla terms

**Reporting > Speedtest**, tab **Settings**:

1. Tick **Accept Ookla terms** after reading the linked licence and privacy policy. Test results are shared with Ookla.
2. Optionally set a default **Server id**, the **Interface** to test from, and how long to **keep history**.
3. **Save**.

Upgrading from 1.1 with speedtest-cli selected: the first **Save** after the update removes the speedtest-cli package. Results speedtest-cli stored stay in the history; **Clear history** removes them.

### 4. Schedule (optional)

On the **Settings** tab tick **Run on a schedule**, pick the interval and the minute past the hour, and Save. The job is added to the system crontab; nothing needs to be added under System > Settings > Cron.

### 5. Dashboard

**Lobby > Dashboard**, add the **Speedtest** widget.

## Switching from os-speedtest-community

The old history is not carried over; this plugin starts with an empty one.

1. Delete the old speedtest job under **System > Settings > Cron**, if you had one.
2. Remove `os-speedtest-community` on the Plugins page. Its Ookla `speedtest` package is not removed with it: `pkg delete speedtest` if you no longer want it.
3. Install `os-speedtest-surfhost` as above and set up the schedule on its Settings tab.

## Remove

1. Remove the Ookla binary first, in a root shell:
   `sh /usr/local/opnsense/scripts/OPNsense/SpeedtestSurfHost/install_backend.sh remove`
2. Remove the plugin on **System > Firmware > Plugins**.
3. The history is kept in `/var/db/speedtest-surfhost`; `rm -rf /var/db/speedtest-surfhost` removes it.

## Files and commands

- Settings rendered for the scripts: `/usr/local/etc/speedtest-surfhost.conf`
- History: `/var/db/speedtest-surfhost/results.csv` (same columns as os-speedtest-community)
- Ookla binary: `/usr/local/libexec/speedtest-surfhost/speedtest`
- `configctl speedtestsurfhost run default` runs a test from the shell; also selectable as "Run speedtest (SurfHost)" under System > Settings > Cron
- API: `/api/speedtestsurfhost/service/{version,serverlist,run,stat,log,recent,deletelog,reconfigure}`, `/api/speedtestsurfhost/download/csv`

## Maintaining

See [docs/MAINTAINING.md](docs/MAINTAINING.md): releasing, and moving to a new Ookla build.

## Licence

BSD 2-Clause, see [LICENSE](LICENSE). Original work copyright Miha Kralj; the dashboard widget is based on Deciso's; changes copyright SurfHost.nl.
