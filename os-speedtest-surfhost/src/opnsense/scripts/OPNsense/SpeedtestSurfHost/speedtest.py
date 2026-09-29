#!/usr/local/bin/python3
"""
 * Copyright (C) 2021 M. Kralj
 * Copyright (C) 2026 SurfHost.nl
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.

Wrapper around the Ookla speedtest binary for configd and cron. Every command prints exactly one JSON
document and exits 0, so configd never hands the page a traceback.

  speedtest.py version            whether the Ookla binary is ready
  speedtest.py list               nearest servers
  speedtest.py run [id|default]   run a test and store it
  speedtest.py stat               averages, minimum and maximum
  speedtest.py log                latest 50 results, newest first
  speedtest.py recent             the most recent result
  speedtest.py clear              delete the history
"""
import calendar
import configparser
import csv
import fcntl
import json
import os
import re
import statistics
import subprocess
import sys
import syslog
import tempfile
import time
from datetime import datetime

CONF_FILE = '/usr/local/etc/speedtest-surfhost.conf'
DATA_DIR = '/var/db/speedtest-surfhost'
CSV_FILE = DATA_DIR + '/results.csv'
LOCK_FILE = DATA_DIR + '/run.lock'
OOKLA_BIN = '/usr/local/libexec/speedtest-surfhost/speedtest'

# same columns and order as os-speedtest-community, so exported files stay
# interchangeable
FIELDS = ['Timestamp', 'ClientIp', 'ServerId', 'ServerName', 'Country', 'DlSpeed', 'UlSpeed', 'Latency', 'Link']

# configd gives up on a script after 120 seconds; stop the test before that
# so the answer is a readable error instead of a configd timeout
RUN_TIMEOUT = 110
LIST_TIMEOUT = 60


class SpeedtestError(Exception):
    pass


def load_settings(path=CONF_FILE):
    settings = {
        'accept_ookla_terms': '0',
        'server_id': '',
        'device': '',
        'retention_days': '365',
    }
    parser = configparser.ConfigParser(interpolation=None)
    try:
        parser.read(path, encoding='utf-8')
    except configparser.Error:
        return settings
    if parser.has_section('general'):
        for key in settings:
            settings[key] = parser.get('general', key, fallback=settings[key]).strip()
    return settings


def parse_row(row):
    """A stored row as a dict, or None for a header, a short or a damaged row."""
    if len(row) < len(FIELDS):
        return None
    try:
        return {
            'timestamp': float(row[0]),
            'clientip': row[1],
            'serverid': row[2],
            'servername': row[3],
            'country': row[4],
            'download': float(row[5]),
            'upload': float(row[6]),
            'latency': float(row[7]),
            'link': row[8],
        }
    except ValueError:
        return None


def read_rows(path=None):
    path = path or CSV_FILE
    rows = []
    try:
        with open(path, 'r', encoding='utf-8', newline='') as f:
            for row in csv.reader(f, dialect='excel'):
                parsed = parse_row(row)
                if parsed is not None:
                    rows.append(parsed)
    except FileNotFoundError:
        pass
    rows.sort(key=lambda r: r['timestamp'])
    return rows


def to_csv_row(r):
    return [r['timestamp'], r['clientip'], r['serverid'], r['servername'], r['country'],
            r['download'], r['upload'], r['latency'], r['link']]


def write_rows(rows, path=None):
    """Replace the history atomically, so a crash never leaves half a file."""
    path = path or CSV_FILE
    os.makedirs(os.path.dirname(path), mode=0o755, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix='.results.')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f, dialect='excel')
            writer.writerow(FIELDS)
            for r in sorted(rows, key=lambda r: r['timestamp']):
                writer.writerow(to_csv_row(r))
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def prune(rows, retention_days, now=None):
    try:
        days = int(retention_days)
    except ValueError:
        return rows
    if days <= 0:
        return rows
    cutoff = (now if now is not None else time.time()) - days * 86400
    return [r for r in rows if r['timestamp'] >= cutoff]


def utc_epoch(stamp):
    """'2026-09-29T10:00:00Z' or '2026-09-29T10:00:00.123456Z' (both UTC) to epoch."""
    return float(calendar.timegm(time.strptime(stamp[:19], '%Y-%m-%dT%H:%M:%S')))


def local_iso(epoch):
    return datetime.fromtimestamp(epoch).isoformat(sep=' ', timespec='seconds')


def present(r):
    out = dict(r)
    out['date'] = local_iso(r['timestamp'])
    return out


def program(settings):
    """Path of the Ookla binary, or a SpeedtestError explaining why it cannot run."""
    if not os.access(OOKLA_BIN, os.X_OK):
        raise SpeedtestError('The Ookla binary is missing: click Save on the Settings tab to install it')
    if settings['accept_ookla_terms'] != '1':
        raise SpeedtestError('Accept the Ookla terms on the Settings tab first')
    return OOKLA_BIN


def run_program(cmd, timeout):
    # the Ookla binary keeps its licence acceptance under $HOME, which is not
    # set for configd or cron; give it the plugin's own directory
    env = dict(os.environ, HOME=DATA_DIR)
    os.makedirs(DATA_DIR, mode=0o755, exist_ok=True)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        raise SpeedtestError('The test did not finish within %d seconds' % timeout)
    if proc.returncode != 0:
        # report what the program actually complained about; the Ookla
        # binary writes its errors as JSON lines on stderr
        detail = ''
        for stream in (proc.stderr, proc.stdout):
            lines = [line.strip() for line in (stream or '').splitlines() if line.strip()]
            if lines:
                detail = lines[-1]
                try:
                    detail = json.loads(detail).get('message', detail)
                except (ValueError, AttributeError):
                    pass
                break
        raise SpeedtestError(detail or 'exit code %d' % proc.returncode)
    # stderr stays out of stdout, so warnings never end up in the JSON
    return proc.stdout


def cmd_version(settings):
    out = {
        'terms_accepted': settings['accept_ookla_terms'] == '1',
        'installed': os.access(OOKLA_BIN, os.X_OK),
        'ready': False,
        'message': '',
    }
    try:
        path = program(settings)
        text = run_program([path, '--version'], 30)
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        out['message'] = lines[0] if lines else ''
        out['ready'] = True
    except SpeedtestError as e:
        out['message'] = str(e)
    return out


def cmd_list(settings):
    path = program(settings)
    text = run_program([path, '--accept-license', '--accept-gdpr', '--servers', '-f', 'jsonl'], LIST_TIMEOUT)
    servers = []
    for line in text.splitlines():
        try:
            s = json.loads(line)
        except ValueError:
            continue
        servers.append({'id': str(s.get('id', '')), 'name': s.get('name', ''),
                        'location': s.get('location', ''), 'country': s.get('country', '')})
    return servers


def build_command(path, server_id, device):
    # the terms were accepted by a person on the Settings tab (program()
    # refuses otherwise); these flags only stop the binary asking again
    cmd = [path, '--accept-license', '--accept-gdpr', '-f', 'json', '-p', 'no']
    if server_id:
        cmd += ['-s', server_id]
    if device:
        cmd += ['-I', device]
    return cmd


def parse_result(result):
    """One Ookla result in the stored units: Mbit/s and milliseconds."""
    return {
        'timestamp': utc_epoch(result['timestamp']),
        'clientip': result['interface']['externalIp'],
        'serverid': str(result['server']['id']),
        'servername': result['server']['name'] + ', ' + result['server']['location'],
        'country': result['server']['country'],
        # bandwidth is in bytes per second
        'download': round(result['download']['bandwidth'] / 125000, 2),
        'upload': round(result['upload']['bandwidth'] / 125000, 2),
        'latency': round(result['ping']['latency'], 2),
        'link': result.get('result', {}).get('url', ''),
    }


def cmd_run(settings, arg):
    if arg in ('', 'default', '0'):
        server_id = settings['server_id']
    elif re.fullmatch(r'[1-9][0-9]{0,8}', arg):
        server_id = arg
    else:
        raise SpeedtestError('%s is not a valid server id' % arg)
    cmd = build_command(program(settings), server_id, settings['device'])

    os.makedirs(DATA_DIR, mode=0o755, exist_ok=True)
    with open(LOCK_FILE, 'w') as lock:
        # a scheduled test and a click on Run must never measure each other
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SpeedtestError('Another speedtest is running, try again in a minute')
        try:
            result = json.loads(run_program(cmd, RUN_TIMEOUT))
        except ValueError:
            raise SpeedtestError('The test program returned no usable result')
        try:
            row = parse_result(result)
        except (KeyError, TypeError, ValueError) as e:
            raise SpeedtestError('Unexpected test result (%s)' % e)
        rows = read_rows()
        rows.append(row)
        write_rows(prune(rows, settings['retention_days']))
    return present(row)


def cmd_stat():
    rows = read_rows()
    out = {'samples': len(rows)}
    if not rows:
        empty = {'avg': 0, 'min': 0, 'max': 0}
        out.update({'period': {'oldest': '', 'youngest': ''},
                    'latency': dict(empty), 'download': dict(empty), 'upload': dict(empty)})
        return out
    out['period'] = {'oldest': local_iso(rows[0]['timestamp']), 'youngest': local_iso(rows[-1]['timestamp'])}
    for key in ('latency', 'download', 'upload'):
        values = [r[key] for r in rows]
        out[key] = {'avg': round(statistics.mean(values), 2),
                    'min': round(min(values), 2),
                    'max': round(max(values), 2)}
    return out


def cmd_log(limit=50):
    return [present(r) for r in reversed(read_rows()[-limit:])]


def cmd_recent():
    rows = read_rows()
    if not rows:
        return {'error': 'No speedtest results yet'}
    return present(rows[-1])


def cmd_clear():
    try:
        os.unlink(CSV_FILE)
    except FileNotFoundError:
        pass
    return {'status': 'ok'}


def main(argv):
    command = argv[1] if len(argv) > 1 else ''
    arg = argv[2].strip() if len(argv) > 2 else ''
    settings = load_settings()
    try:
        if command == 'version':
            out = cmd_version(settings)
        elif command == 'list':
            out = cmd_list(settings)
        elif command == 'run':
            out = cmd_run(settings, arg)
        elif command == 'stat':
            out = cmd_stat()
        elif command == 'log':
            out = cmd_log()
        elif command == 'recent':
            out = cmd_recent()
        elif command == 'clear':
            out = cmd_clear()
        else:
            out = {'error': 'Unknown command %r' % command}
    except SpeedtestError as e:
        out = {'error': str(e)}
    except Exception as e:  # never a traceback on the page or in the cron mail
        out = {'error': 'Speedtest failed: %s: %s' % (type(e).__name__, e)}
    if command == 'run' and isinstance(out, dict) and 'error' in out:
        # cron throws the output away, so a failing scheduled test is only
        # visible in the system log
        syslog.openlog('speedtest-surfhost')
        syslog.syslog(syslog.LOG_ERR, out['error'])
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
